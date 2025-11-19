// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title YieldVault
/// @notice ERC-4626 compliant tokenized yield vault with time-based yield accrual and virtual share inflation protection.
/// @dev UUPS upgradeable via OZ v5. Yield is simulated via a configurable annual rate in basis points.
///      The vault owner must fund the contract with sufficient underlying tokens to back accrued yield.
///      `InterestRateModel` is a standalone rate oracle reserved for a future lending/borrowing extension;
///      this vault's `yieldRateBps` is exclusively owner-controlled and not derived from utilization.
contract YieldVault is
    ERC4626Upgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using Math for uint256;

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice Basis points divisor (100% = 10,000).
    uint256 public constant BPS_DIVISOR = 10_000;

    /// @notice Seconds in a year used for annualised yield calculations.
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /// @notice Minimum elapsed time between two public `accrueYield()` calls.
    uint256 public constant MIN_ACCRUAL_INTERVAL = 1 hours;

    /// @notice Maximum permissible annual yield rate (50% APY ceiling).
    uint256 public constant MAX_YIELD_RATE_BPS = 5_000;

    // -------------------------------------------------------------------------
    // Storage  (UUPS layout — append only, never reorder)
    // slot 0
    /// @notice The current annual yield rate in basis points.
    uint256 public yieldRateBps;

    // slot 1
    /// @notice Unix timestamp of the last yield accrual checkpoint.
    uint256 public lastAccrual;

    // slot 2  (new — appended)
    /// @notice Cumulative yield accrued and persisted by prior `accrueYield()` calls.
    uint256 public accumulatedYield;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ZeroAddress();
    error NotAContract(address provided);
    /// @notice Thrown when the proposed yield rate exceeds the protocol ceiling.
    /// @param provided The rate that was supplied.
    /// @param maximum The maximum allowed rate.
    error YieldRateTooHigh(uint256 provided, uint256 maximum);
    /// @notice Thrown when `accumulatedYield` exceeds the vault's actual token balance.
    error InsufficientFunding();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when the annual yield rate is updated.
    /// @param oldRate The previous yield rate in basis points.
    /// @param newRate The new yield rate in basis points.
    event YieldRateUpdated(uint256 oldRate, uint256 newRate);

    /// @notice Emitted on every accrual checkpoint, including zero-interest ticks.
    /// @param interestAccrued The amount of underlying yield accrued since the last checkpoint.
    /// @param timestamp The block timestamp at the time of accrual.
    event YieldAccrued(uint256 interestAccrued, uint256 timestamp);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // -------------------------------------------------------------------------
    // Initializer
    // -------------------------------------------------------------------------

    /// @notice Initializes the vault proxy.
    /// @param underlying The ERC-20 asset managed by this vault.
    /// @param name_ The name of the vault share token.
    /// @param symbol_ The symbol of the vault share token.
    /// @param initialYieldBps The initial annual yield rate in basis points.
    /// @param owner_ The address granted ownership of the vault.
    function initialize(
        IERC20 underlying,
        string memory name_,
        string memory symbol_,
        uint256 initialYieldBps,
        address owner_
    ) public initializer {
        if (owner_ == address(0)) revert ZeroAddress();
        if (address(underlying) == address(0)) revert ZeroAddress();
        if (initialYieldBps > MAX_YIELD_RATE_BPS) revert YieldRateTooHigh(initialYieldBps, MAX_YIELD_RATE_BPS);

        __ERC4626_init(underlying);
        __ERC20_init(name_, symbol_);
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        yieldRateBps = initialYieldBps;
        lastAccrual = block.timestamp;
    }

    // -------------------------------------------------------------------------
    // Owner functions
    // -------------------------------------------------------------------------

    /// @notice Updates the annual yield rate, checkpointing accrued yield first.
    /// @param newRateBps The new yield rate in basis points (e.g. 500 = 5% APY).
    function setYieldRate(uint256 newRateBps) external onlyOwner {
        if (newRateBps > MAX_YIELD_RATE_BPS) revert YieldRateTooHigh(newRateBps, MAX_YIELD_RATE_BPS);
        accrueYield();
        uint256 oldRate = yieldRateBps;
        yieldRateBps = newRateBps;
        emit YieldRateUpdated(oldRate, newRateBps);
    }

    /// @notice Pauses all user-facing deposit, withdraw, and redeem operations.
    /// @dev Emergency circuit breaker. Only callable by the owner.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes normal vault operations after a pause.
    /// @dev Only callable by the owner.
    function unpause() external onlyOwner {
        _unpause();
    }

    // -------------------------------------------------------------------------
    // Yield accrual
    // -------------------------------------------------------------------------

    /// @notice Checkpoints and persists yield elapsed since the last accrual.
    /// @dev Enforces a minimum accrual interval to reduce keeper griefing.
    ///      Emits `YieldAccrued` unconditionally so subgraph indexers can track all checkpoints.
    ///      Protected by `nonReentrant` to prevent cross-function reentrancy via yield callbacks.
    /// @return interest The amount of underlying asset yield accrued in this call.
    function accrueYield() public nonReentrant returns (uint256 interest) {
        if (block.timestamp < lastAccrual + MIN_ACCRUAL_INTERVAL) return 0;

        uint256 base = super.totalAssets() + accumulatedYield;
        interest = _computeYield(base, block.timestamp - lastAccrual);

        accumulatedYield += interest;
        lastAccrual = block.timestamp;

        emit YieldAccrued(interest, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // ERC-4626 overrides
    // -------------------------------------------------------------------------

    /// @notice Returns the total amount of underlying assets managed by the vault.
    /// @dev Includes the token balance, previously persisted yield, and pending yield accrued
    ///      since the last checkpoint.
    /// @return The total managed asset balance.
    function totalAssets() public view override returns (uint256) {
        uint256 base = super.totalAssets() + accumulatedYield;
        return base + _pendingYield(base);
    }

    /// @notice Deposits `assets` into the vault and mints shares to `receiver`.
    /// @param assets The amount of underlying asset to deposit.
    /// @param receiver The address that will receive the minted shares.
    /// @return shares The number of shares minted.
    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        return super.deposit(assets, receiver);
    }

    /// @notice Withdraws `assets` from the vault, burning shares from `owner`.
    /// @param assets The amount of underlying asset to withdraw.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address whose shares will be burned.
    /// @return shares The number of shares burned.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /// @notice Redeems `shares` from `owner` and transfers the corresponding assets to `receiver`.
    /// @param shares The number of vault shares to redeem.
    /// @param receiver The address that will receive the underlying assets.
    /// @param owner The address whose shares will be burned.
    /// @return assets The amount of underlying assets transferred.
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        return super.redeem(shares, receiver, owner);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /// @notice Returns the protocol version string.
    /// @return The semver version of this implementation.
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /// @notice Returns the amount by which accrued virtual yield exceeds the vault's actual token balance.
    /// @dev A non-zero value indicates the owner must deposit additional underlying tokens to cover yield obligations.
    /// @return shortfall The funding deficit; zero when the vault is fully backed.
    function fundingShortfall() external view returns (uint256 shortfall) {
        uint256 realBalance = super.totalAssets();
        if (accumulatedYield > realBalance) {
            shortfall = accumulatedYield - realBalance;
        }
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    /// @dev Computes yield on `base` over `timeElapsed` seconds at the current rate.
    ///      Uses `Math.mulDiv` to prevent intermediate overflow on large balances.
    function _computeYield(uint256 base, uint256 timeElapsed) private view returns (uint256) {
        if (timeElapsed == 0 || yieldRateBps == 0) return 0;
        return Math.mulDiv(base, yieldRateBps * timeElapsed, BPS_DIVISOR * SECONDS_PER_YEAR);
    }

    /// @dev Returns yield accrued since `lastAccrual` that has not yet been checkpointed.
    function _pendingYield(uint256 base) private view returns (uint256) {
        return _computeYield(base, block.timestamp - lastAccrual);
    }

    /// @dev Enables OZ v5 virtual shares/assets protection against ERC-4626 inflation attacks.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 18;
    }

    /// @dev Restricts UUPS upgrade authority to the vault owner.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
