// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title YieldVault
/// @notice ERC-4626 compliant tokenized yield vault with time-based yield accrual
/// @dev UUPS upgradeable, uses OpenZeppelin v5 upgradeable contracts.
///      Yield is simulated via a configurable annual rate. The vault owner must fund
///      the contract with sufficient underlying tokens to back accrued yield.
contract YieldVault is
    ERC4626Upgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Math for uint256;

    /// @notice Basis points divisor (100% = 10,000)
    uint256 public constant BPS_DIVISOR = 10_000;

    /// @notice Seconds in a year for annual yield calculation
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /// @notice The current annual yield rate in basis points
    uint256 public yieldRateBps;

    /// @notice The timestamp of the last yield accrual
    uint256 public lastAccrual;

    /// @notice Emitted when the yield rate is updated
    /// @param oldRate The previous yield rate
    /// @param newRate The new yield rate
    event YieldRateUpdated(uint256 oldRate, uint256 newRate);

    /// @notice Emitted when yield is accrued
    /// @param interestAccrued The amount of asset yield accrued
    /// @param timestamp The time of accrual
    event YieldAccrued(uint256 interestAccrued, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the vault proxy
    /// @param underlying The asset to be managed by the vault
    /// @param name_ The name of the vault token
    /// @param symbol_ The symbol of the vault token
    /// @param initialYieldBps The initial annual yield rate in basis points
    /// @param owner_ The address of the vault owner
    function initialize(
        IERC20 underlying,
        string memory name_,
        string memory symbol_,
        uint256 initialYieldBps,
        address owner_
    ) public initializer {
        __ERC4626_init(underlying);
        __ERC20_init(name_, symbol_);
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        yieldRateBps = initialYieldBps;
        lastAccrual = block.timestamp;
    }

    /// @notice Sets a new annual yield rate
    /// @param newRateBps The new yield rate in basis points (e.g., 500 = 5%)
    function setYieldRate(uint256 newRateBps) external onlyOwner {
        accrueYield();
        uint256 oldRate = yieldRateBps;
        yieldRateBps = newRateBps;
        emit YieldRateUpdated(oldRate, newRateBps);
    }

    /// @notice Accrues yield based on elapsed time since last accrual
    /// @dev Updates lastAccrual and returns the amount of virtual yield added
    function accrueYield() public returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastAccrual;
        if (timeElapsed == 0) return 0;

        uint256 assets = totalAssets();
        uint256 interest = (assets * yieldRateBps * timeElapsed) / (BPS_DIVISOR * SECONDS_PER_YEAR);

        lastAccrual = block.timestamp;
        if (interest > 0) {
            emit YieldAccrued(interest, block.timestamp);
        }

        return interest;
    }

    /// @notice Returns the total amount of assets managed by the vault
    /// @dev Includes the underlying balance plus any simulated pending yield
    function totalAssets() public view override returns (uint256) {
        uint256 underlyingBalance = super.totalAssets();
        uint256 timeElapsed = block.timestamp - lastAccrual;

        if (timeElapsed == 0 || yieldRateBps == 0) {
            return underlyingBalance;
        }

        uint256 pendingYield = (underlyingBalance * yieldRateBps * timeElapsed) /
            (BPS_DIVISOR * SECONDS_PER_YEAR);

        return underlyingBalance + pendingYield;
    }

    /// @notice Deposits assets and mints vault shares
    /// @dev Adds reentrancy protection on top of ERC4626 deposit
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /// @notice Withdraws assets by burning vault shares
    /// @dev Adds reentrancy protection on top of ERC4626 withdraw
    function withdraw(uint256 assets, address receiver, address owner) public override nonReentrant returns (uint256) {
        return super.withdraw(assets, receiver, owner);
    }

    /// @notice Redeems shares for underlying assets
    /// @dev Adds reentrancy protection on top of ERC4626 redeem
    function redeem(uint256 shares, address receiver, address owner) public override nonReentrant returns (uint256) {
        return super.redeem(shares, receiver, owner);
    }

    /// @notice Returns the protocol version
    /// @return The version string
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /// @dev Required by UUPSUpgradeable — only owner can upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
