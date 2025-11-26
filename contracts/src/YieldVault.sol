// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IYieldStrategy} from "./interfaces/IYieldStrategy.sol";

/// @title YieldVault
/// @notice ERC-4626 tokenized yield vault. Delegates asset management to a pluggable
///         IYieldStrategy — swap strategies without migrating user funds.
/// @dev UUPS upgradeable via OZ v5. Performance fee minted as shares to feeRecipient
///      on each harvest using the share-dilution formula so the invariant
///      `feeShares / totalSupply == feeAssets / totalAssets` holds exactly (CRIT-02).
///      Inflation attack mitigated via `_decimalsOffset() = 18` (OZ v5 virtual shares).
///      Strategy migration requires the vault to be paused (MED-01).
contract YieldVault is
    ERC4626Upgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant BPS_DIVISOR = 10_000;

    /// @notice Maximum performance fee: 30%.
    uint256 public constant MAX_PERFORMANCE_FEE_BPS = 3_000;

    // -------------------------------------------------------------------------
    // Storage  (UUPS layout — append only, never reorder)
    // -------------------------------------------------------------------------

    // slot 0
    /// @notice The active yield strategy — receives all deposited assets.
    IYieldStrategy public strategy;

    // slot 1
    /// @notice Recipient of performance fee shares.
    address public feeRecipient;

    // slot 2
    /// @notice Performance fee in basis points charged on yield (default 10%).
    uint256 public performanceFeeBps;

    // slot 3
    /// @notice Total strategy assets recorded at last harvest checkpoint.
    uint256 public lastHarvestAssets;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ZeroAddress();
    error NotAContract(address provided);
    error FeeTooHigh(uint256 provided, uint256 maximum);
    error StrategyAssetMismatch(address strategyAsset, address vaultAsset);
    /// @notice Thrown when setStrategy is called while the vault is not paused.
    error MustBePaused();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when the yield strategy is updated.
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);

    /// @notice Emitted when the fee recipient is updated.
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    /// @notice Emitted when the performance fee rate is updated.
    event PerformanceFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    /// @notice Emitted on each fee harvest.
    /// @param gain Yield earned since last harvest.
    /// @param feeShares Shares minted to feeRecipient.
    event Harvested(uint256 gain, uint256 feeShares);

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
    /// @param strategy_ The initial yield strategy — must share the same underlying asset.
    /// @param feeRecipient_ Address that receives performance fee shares.
    /// @param performanceFeeBps_ Initial performance fee in basis points (e.g. 1000 = 10%).
    /// @param owner_ The address granted ownership of the vault.
    function initialize(
        IERC20 underlying,
        string memory name_,
        string memory symbol_,
        address strategy_,
        address feeRecipient_,
        uint256 performanceFeeBps_,
        address owner_
    ) public initializer {
        if (owner_ == address(0)) revert ZeroAddress();
        if (address(underlying) == address(0)) revert ZeroAddress();
        if (strategy_ == address(0)) revert ZeroAddress();
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        if (strategy_.code.length == 0) revert NotAContract(strategy_);
        if (performanceFeeBps_ > MAX_PERFORMANCE_FEE_BPS) {
            revert FeeTooHigh(performanceFeeBps_, MAX_PERFORMANCE_FEE_BPS);
        }

        address strategyAsset = IYieldStrategy(strategy_).asset();
        if (strategyAsset != address(underlying)) {
            revert StrategyAssetMismatch(strategyAsset, address(underlying));
        }

        __ERC4626_init(underlying);
        __ERC20_init(name_, symbol_);
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        strategy = IYieldStrategy(strategy_);
        feeRecipient = feeRecipient_;
        performanceFeeBps = performanceFeeBps_;

        // Initialise baseline to avoid treating pre-existing strategy balance as gain (LOW-02).
        lastHarvestAssets = IYieldStrategy(strategy_).totalAssets();
    }

    // -------------------------------------------------------------------------
    // Owner functions
    // -------------------------------------------------------------------------

    /// @notice Replaces the active yield strategy.
    /// @dev Vault MUST be paused before migration to prevent deposits landing in the old
    ///      strategy mid-migration (MED-01). Measures actual received tokens instead of
    ///      trusting strategy.totalAssets() to prevent shortfall on illiquid strategies (HIGH-01).
    /// @param newStrategy Address of the new IYieldStrategy implementation.
    function setStrategy(address newStrategy) external onlyOwner nonReentrant {
        if (!paused()) revert MustBePaused();
        if (newStrategy == address(0)) revert ZeroAddress();
        if (newStrategy.code.length == 0) revert NotAContract(newStrategy);

        address newAsset = IYieldStrategy(newStrategy).asset();
        if (newAsset != asset()) revert StrategyAssetMismatch(newAsset, asset());

        _harvest();

        uint256 oldBalance = strategy.totalAssets();
        if (oldBalance > 0) {
            uint256 balBefore = IERC20(asset()).balanceOf(address(this));
            strategy.withdraw(oldBalance);
            uint256 received = IERC20(asset()).balanceOf(address(this)) - balBefore;

            if (received > 0) {
                IERC20(asset()).forceApprove(newStrategy, received);
                IYieldStrategy(newStrategy).deposit(received);
                // Revoke residual approval (LOW-03).
                IERC20(asset()).forceApprove(newStrategy, 0);
            }
        }

        emit StrategyUpdated(address(strategy), newStrategy);
        strategy = IYieldStrategy(newStrategy);
        lastHarvestAssets = IYieldStrategy(newStrategy).totalAssets();
    }

    /// @notice Updates the performance fee recipient.
    /// @param newRecipient Address of the new fee recipient.
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    /// @notice Updates the performance fee rate.
    /// @param newFeeBps New performance fee in basis points.
    function setPerformanceFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_PERFORMANCE_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_PERFORMANCE_FEE_BPS);
        emit PerformanceFeeUpdated(performanceFeeBps, newFeeBps);
        performanceFeeBps = newFeeBps;
    }

    /// @notice Pauses all user-facing deposit, withdraw, and redeem operations.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes normal vault operations after a pause.
    function unpause() external onlyOwner {
        _unpause();
    }

    // -------------------------------------------------------------------------
    // Harvest
    // -------------------------------------------------------------------------

    /// @notice Harvests yield and mints performance fee shares to feeRecipient.
    /// @dev Restricted to owner to eliminate permissionless harvest sandwich attack (HIGH-02).
    function harvest() external onlyOwner nonReentrant {
        _harvest();
    }

    // -------------------------------------------------------------------------
    // ERC-4626 overrides
    // -------------------------------------------------------------------------

    /// @notice Returns total assets managed by the active strategy.
    function totalAssets() public view override returns (uint256) {
        return strategy.totalAssets();
    }

    /// @notice Deposits `assets` into the vault, forwarding them to the strategy.
    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        return super.deposit(assets, receiver);
    }

    /// @notice Mints exactly `shares` vault shares by depositing the required assets.
    function mint(uint256 shares, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        return super.mint(shares, receiver);
    }

    /// @notice Withdraws `assets` from the strategy to `receiver`.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /// @notice Redeems `shares` for underlying assets from the strategy.
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
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    // -------------------------------------------------------------------------
    // Internal — ERC-4626 hooks
    // -------------------------------------------------------------------------

    /// @dev After OZ transfers assets from caller into this contract, forward to strategy.
    ///      Revokes residual approval after deposit (LOW-03).
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);
        IERC20(asset()).forceApprove(address(strategy), assets);
        strategy.deposit(assets);
        IERC20(asset()).forceApprove(address(strategy), 0);
        lastHarvestAssets = strategy.totalAssets();
    }

    /// @dev Pull assets from strategy before OZ transfers them to receiver.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        strategy.withdraw(assets);
        lastHarvestAssets = strategy.totalAssets();
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // -------------------------------------------------------------------------
    // Internal — fee harvest
    // -------------------------------------------------------------------------

    /// @dev Share-dilution formula: mints fee shares so that
    ///      feeShares / (totalSupply + feeShares) == feeAssets / totalAssets.
    ///      This preserves the ERC-4626 share/asset invariant (CRIT-02).
    function _harvest() internal {
        uint256 current = strategy.totalAssets();
        if (current <= lastHarvestAssets) {
            lastHarvestAssets = current;
            return;
        }

        uint256 gain = current - lastHarvestAssets;
        uint256 feeAssets = Math.mulDiv(gain, performanceFeeBps, BPS_DIVISOR);

        lastHarvestAssets = current;

        if (feeAssets == 0 || feeRecipient == address(0) || feeAssets >= current) return;

        uint256 supply = totalSupply();
        // feeShares = supply * feeAssets / (current - feeAssets)
        uint256 feeShares = Math.mulDiv(supply, feeAssets, current - feeAssets, Math.Rounding.Floor);
        if (feeShares == 0) return;

        _mint(feeRecipient, feeShares);
        emit Harvested(gain, feeShares);
    }

    // -------------------------------------------------------------------------
    // Internal — inflation protection
    // -------------------------------------------------------------------------

    /// @dev OZ v5 virtual shares offset — prevents first-depositor inflation attack.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 18;
    }

    /// @dev Restricts UUPS upgrade authority to the vault owner.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
