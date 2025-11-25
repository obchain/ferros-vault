// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IYieldStrategy} from "../interfaces/IYieldStrategy.sol";
import {IMintable} from "../interfaces/IMintable.sol";

/// @title MockYieldSource
/// @notice Simulated ERC-4626-compatible yield source for testnet deployments.
/// @dev Generates yield by minting new underlying tokens at a configurable annual rate.
///      No external protocol dependency — fully self-contained for Ethereum Sepolia testing.
///      Replace with a real strategy (Aave, Compound, etc.) for production by implementing
///      IYieldStrategy against the target protocol.
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
    IERC20 public immutable underlying;

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

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Deploys the mock yield source with a configurable APY.
    /// @param underlying_ The mintable ERC-20 token used as the underlying asset.
    /// @param apyBps_ Initial annual yield rate in basis points.
    /// @param owner_ Address granted ownership of this contract.
    constructor(address underlying_, uint256 apyBps_, address owner_) Ownable(owner_) {
        if (underlying_ == address(0)) revert ZeroAddress();
        if (apyBps_ > MAX_APY_BPS) revert ApyTooHigh(apyBps_, MAX_APY_BPS);

        underlying = IERC20(underlying_);
        apyBps = apyBps_;
        lastAccrual = block.timestamp;
    }

    // -------------------------------------------------------------------------
    // IYieldStrategy
    // -------------------------------------------------------------------------

    /// @inheritdoc IYieldStrategy
    function asset() external view override returns (address) {
        return address(underlying);
    }

    /// @inheritdoc IYieldStrategy
    function totalAssets() public view override returns (uint256) {
        uint256 balance = underlying.balanceOf(address(this));
        return balance + _pendingYield(balance);
    }

    /// @inheritdoc IYieldStrategy
    /// @dev Caller (YieldVault) must have approved this contract before calling.
    function deposit(uint256 assets) external override {
        if (assets == 0) revert ZeroAmount();
        underlying.safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @inheritdoc IYieldStrategy
    /// @dev Sends `assets` of underlying back to caller (YieldVault).
    function withdraw(uint256 assets) external override {
        if (assets == 0) revert ZeroAmount();
        // Checkpoint yield before any balance change
        _accrueYield();
        underlying.safeTransfer(msg.sender, assets);
    }

    // -------------------------------------------------------------------------
    // Yield accrual
    // -------------------------------------------------------------------------

    /// @notice Checkpoints and mints all pending yield into this contract.
    /// @dev Callable by anyone — permissionless keeper pattern.
    function accrueYield() external {
        _accrueYield();
    }

    /// @notice Updates the annual yield rate, checkpointing pending yield first.
    /// @param newApyBps New annual yield rate in basis points.
    function setApy(uint256 newApyBps) external onlyOwner {
        if (newApyBps > MAX_APY_BPS) revert ApyTooHigh(newApyBps, MAX_APY_BPS);
        _accrueYield();
        emit ApyUpdated(apyBps, newApyBps);
        apyBps = newApyBps;
    }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    function _accrueYield() internal {
        uint256 elapsed = block.timestamp - lastAccrual;
        if (elapsed == 0) return;

        uint256 balance = underlying.balanceOf(address(this));
        uint256 yieldAmount = _pendingYield(balance);
        lastAccrual = block.timestamp;

        if (yieldAmount == 0) return;

        totalYieldAccrued += yieldAmount;
        IMintable(address(underlying)).mint(address(this), yieldAmount);

        emit YieldAccrued(yieldAmount, block.timestamp);
    }

    function _pendingYield(uint256 balance) internal view returns (uint256) {
        if (apyBps == 0 || balance == 0) return 0;
        uint256 elapsed = block.timestamp - lastAccrual;
        return Math.mulDiv(balance, apyBps * elapsed, BPS_DIVISOR * SECONDS_PER_YEAR);
    }
}
