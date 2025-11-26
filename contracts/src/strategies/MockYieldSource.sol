// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IYieldStrategy} from "../interfaces/IYieldStrategy.sol";
import {IMintable} from "../interfaces/IMintable.sol";

/// @title MockYieldSource
/// @notice Simulated yield source for Ethereum Sepolia testnet deployments only.
/// @dev Generates yield by minting new underlying tokens at a configurable annual rate.
///      No external protocol dependency — fully self-contained for testnet testing.
///      `deposit` and `withdraw` are restricted to the authorised vault address set at
///      construction to prevent unauthorised fund extraction (CRIT-01).
///      Replace with a real strategy (e.g. Aave, Compound) for production use.
contract MockYieldSource is IYieldStrategy, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant BPS_DIVISOR = 10_000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_APY_BPS = 5_000; // 50% ceiling

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice The underlying ERC-20 token managed by this strategy.
    // slither-disable-next-line naming-convention
    IERC20 public immutable underlying;

    /// @notice The sole address permitted to call `deposit` and `withdraw`.
    /// @dev Set via `setVault()` once after construction. Immutable once set.
    address public vault;

    /// @notice Annual yield rate in basis points (e.g. 1000 = 10% APY).
    uint256 public apyBps;

    /// @notice Unix timestamp of the last yield accrual checkpoint.
    uint256 public lastAccrual;

    /// @notice Total yield minted and added to this contract since deployment.
    uint256 public totalYieldAccrued;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ApyTooHigh(uint256 provided, uint256 maximum);
    error ZeroAddress();
    error ZeroAmount();
    /// @notice Thrown when a caller other than the authorised vault calls deposit or withdraw.
    error NotVault(address caller);

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when yield is minted into the strategy.
    /// @param yieldMinted Amount of underlying tokens minted as yield.
    /// @param timestamp Block timestamp of the accrual.
    event YieldAccrued(uint256 yieldMinted, uint256 timestamp);

    /// @notice Emitted when the APY rate is updated.
    /// @param oldApy Previous rate in basis points.
    /// @param newApy New rate in basis points.
    event ApyUpdated(uint256 oldApy, uint256 newApy);

    /// @notice Emitted when the authorised vault address is set.
    /// @param vault The vault address granted deposit/withdraw access.
    event VaultSet(address indexed vault);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    /// @dev Restricts deposit and withdraw to the authorised vault only.
    modifier onlyVault() {
        if (msg.sender != vault) revert NotVault(msg.sender);
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Deploys the mock yield source.
    /// @param underlying_ The mintable ERC-20 token used as the underlying asset.
    /// @param apyBps_ Initial annual yield rate in basis points.
    /// @param owner_ Address granted ownership (APY configuration) of this contract.
    constructor(address underlying_, uint256 apyBps_, address owner_) Ownable(owner_) {
        if (underlying_ == address(0)) revert ZeroAddress();
        if (apyBps_ > MAX_APY_BPS) revert ApyTooHigh(apyBps_, MAX_APY_BPS);

        underlying = IERC20(underlying_);
        apyBps = apyBps_;
        lastAccrual = block.timestamp;
    }

    /// @notice Sets the authorised vault address. Can only be called once by the owner.
    /// @dev Called after vault proxy deployment since the vault address is not known at
    ///      strategy construction time. Immutable once set.
    /// @param vault_ The vault proxy address authorised to call deposit and withdraw.
    function setVault(address vault_) external onlyOwner {
        if (vault_ == address(0)) revert ZeroAddress();
        if (vault != address(0)) revert NotVault(msg.sender); // already set
        vault = vault_;
        emit VaultSet(vault_);
    }

    // -------------------------------------------------------------------------
    // IYieldStrategy
    // -------------------------------------------------------------------------

    /// @inheritdoc IYieldStrategy
    function asset() external view override returns (address) {
        return address(underlying);
    }

    /// @inheritdoc IYieldStrategy
    /// @dev Returns only physically checkpointed balance — pending yield excluded
    ///      to prevent double-counting in vault harvest calculations (HIGH-03).
    function totalAssets() public view override returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    /// @inheritdoc IYieldStrategy
    /// @dev Restricted to authorised vault only (CRIT-01).
    ///      Caller must have approved this contract to spend `assets` beforehand.
    function deposit(uint256 assets) external override onlyVault {
        if (assets == 0) revert ZeroAmount();
        underlying.safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IYieldStrategy
    /// @dev Restricted to authorised vault only (CRIT-01).
    ///      Checkpoints yield before transfer so balance is accurate post-withdrawal.
    function withdraw(uint256 assets) external override onlyVault {
        if (assets == 0) revert ZeroAmount();
        _accrueYield();
        underlying.safeTransfer(msg.sender, assets);
    }

    // -------------------------------------------------------------------------
    // Yield accrual
    // -------------------------------------------------------------------------

    /// @notice Checkpoints and mints all pending yield into this contract.
    /// @dev Permissionless keeper — anyone can advance the yield checkpoint.
    function accrueYield() external {
        _accrueYield();
    }

    /// @notice Updates the annual yield rate, checkpointing pending yield first.
    /// @param newApyBps New annual yield rate in basis points.
    function setApy(uint256 newApyBps) external onlyOwner {
        if (newApyBps > MAX_APY_BPS) revert ApyTooHigh(newApyBps, MAX_APY_BPS);

        // Compute pending yield at the current (old) rate before updating state.
        uint256 elapsed = block.timestamp - lastAccrual;
        uint256 balance = underlying.balanceOf(address(this));
        uint256 yieldAmount = elapsed >= 1 ? _pendingYield(balance, elapsed) : 0;

        // Update all state and emit events before external calls (CEI).
        lastAccrual = block.timestamp;
        if (yieldAmount >= 1) totalYieldAccrued += yieldAmount;
        emit ApyUpdated(apyBps, newApyBps);
        apyBps = newApyBps;
        if (yieldAmount >= 1) emit YieldAccrued(yieldAmount, block.timestamp);

        // External call last.
        if (yieldAmount >= 1) {
            IMintable(address(underlying)).mint(address(this), yieldAmount);
        }
    }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    function _accrueYield() internal {
        uint256 elapsed = block.timestamp - lastAccrual;
        if (elapsed < 1) return;

        uint256 balance = underlying.balanceOf(address(this));
        uint256 yieldAmount = _pendingYield(balance, elapsed);
        lastAccrual = block.timestamp;

        if (yieldAmount < 1) return;

        totalYieldAccrued += yieldAmount;
        emit YieldAccrued(yieldAmount, block.timestamp);
        IMintable(address(underlying)).mint(address(this), yieldAmount);
    }

    function _pendingYield(uint256 balance, uint256 elapsed) internal view returns (uint256) {
        if (apyBps < 1 || balance < 1 || elapsed < 1) return 0;
        return Math.mulDiv(balance, apyBps * elapsed, BPS_DIVISOR * SECONDS_PER_YEAR);
    }
}
