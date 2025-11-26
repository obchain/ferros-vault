// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {YieldVault} from "./YieldVault.sol";

/// @title VaultFactory
/// @notice Factory that deploys ERC-1967 proxy instances of YieldVault.
/// @dev Each vault is an independent UUPS proxy sharing the same YieldVault implementation.
///      Asset creation is gated behind an owner-managed allowlist to prevent deployment of
///      arbitrary or malicious tokens.
///      Note: `InterestRateModel` is a standalone rate oracle reserved for a future
///      lending/borrowing extension. Vault yield rates are owner-controlled and are not
///      dynamically derived from utilization in this version.
contract VaultFactory is Ownable2Step, ReentrancyGuard {
    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice The YieldVault logic contract used when deploying new proxies.
    address public implementation;

    /// @notice Maps an underlying asset to all vaults deployed for it.
    mapping(address => address[]) public assetToVaults;

    /// @notice Flat list of every vault deployed by this factory.
    address[] public vaultList;

    /// @notice Tracks which underlying assets are approved for vault creation.
    mapping(address => bool) public approvedAssets;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ZeroAddress();
    error NotAContract(address provided);
    /// @notice Thrown when `createVault` is called with an asset that has not been approved.
    /// @param asset The asset address that was rejected.
    error AssetNotApproved(address asset);

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new vault proxy is deployed.
    /// @param vault The address of the newly created vault proxy.
    /// @param asset The underlying asset of the vault.
    /// @param owner The initial owner assigned to the vault.
    event VaultCreated(address indexed vault, address indexed asset, address indexed owner);

    /// @notice Emitted when the shared implementation address is updated.
    /// @param oldImplementation The previous implementation address.
    /// @param newImplementation The new implementation address.
    event ImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);

    /// @notice Emitted when an asset is added to the creation allowlist.
    /// @param asset The approved asset address.
    event AssetApproved(address indexed asset);

    /// @notice Emitted when an asset is removed from the creation allowlist.
    /// @param asset The revoked asset address.
    event AssetRevoked(address indexed asset);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Deploys the factory and sets the initial vault implementation.
    /// @param implementation_ The address of the deployed YieldVault logic contract.
    /// @param initialOwner The address that will own and administer this factory.
    constructor(address implementation_, address initialOwner) Ownable(initialOwner) {
        if (implementation_ == address(0)) revert ZeroAddress();
        if (implementation_.code.length == 0) revert NotAContract(implementation_);
        implementation = implementation_;
        emit ImplementationUpdated(address(0), implementation_);
    }

    // -------------------------------------------------------------------------
    // Owner functions
    // -------------------------------------------------------------------------

    /// @notice Adds an asset to the vault creation allowlist.
    /// @param asset The ERC-20 token address to approve.
    function approveAsset(address asset) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (asset.code.length == 0) revert NotAContract(asset);
        approvedAssets[asset] = true;
        emit AssetApproved(asset);
    }

    /// @notice Removes an asset from the vault creation allowlist.
    /// @dev Existing vaults for the asset are unaffected.
    /// @param asset The ERC-20 token address to revoke.
    function revokeAsset(address asset) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        approvedAssets[asset] = false;
        emit AssetRevoked(asset);
    }

    /// @notice Replaces the implementation address used for future vault proxies.
    /// @dev Existing proxies are unaffected; each vault upgrades independently via UUPS.
    /// @param newImplementation The address of the new YieldVault logic contract.
    function setImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        if (newImplementation.code.length == 0) revert NotAContract(newImplementation);
        address old = implementation;
        implementation = newImplementation;
        emit ImplementationUpdated(old, newImplementation);
    }

    // -------------------------------------------------------------------------
    // Vault creation
    // -------------------------------------------------------------------------

    /// @notice Deploys a new ERC-1967 YieldVault proxy and registers it in the factory.
    /// @dev Restricted to the factory owner to prevent arbitrary callers from becoming
    ///      vault owners with full UUPS upgrade and fee-configuration authority (HIGH-04).
    ///      The asset must be pre-approved via `approveAsset`.
    /// @param asset The address of the ERC-20 underlying asset.
    /// @param name The name of the vault share token.
    /// @param symbol The symbol of the vault share token.
    /// @param strategy The IYieldStrategy the vault will deposit into.
    /// @param feeRecipient Address that receives performance fee shares.
    /// @param performanceFeeBps Initial performance fee in basis points.
    /// @param vaultOwner Address that will own and administer the deployed vault.
    /// @return vault The address of the deployed vault proxy.
    function createVault(
        address asset,
        string memory name,
        string memory symbol,
        address strategy,
        address feeRecipient,
        uint256 performanceFeeBps,
        address vaultOwner
    ) external onlyOwner nonReentrant returns (address vault) {
        if (vaultOwner == address(0)) revert ZeroAddress();
        if (asset == address(0)) revert ZeroAddress();
        if (strategy == address(0)) revert ZeroAddress();
        if (feeRecipient == address(0)) revert ZeroAddress();
        if (asset.code.length == 0) revert NotAContract(asset);
        if (strategy.code.length == 0) revert NotAContract(strategy);
        if (!approvedAssets[asset]) revert AssetNotApproved(asset);

        bytes memory data = abi.encodeWithSelector(
            YieldVault.initialize.selector,
            asset,
            name,
            symbol,
            strategy,
            feeRecipient,
            performanceFeeBps,
            vaultOwner
        );

        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vault = address(proxy);

        assetToVaults[asset].push(vault);
        vaultList.push(vault);

        emit VaultCreated(vault, asset, vaultOwner);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /// @notice Returns all vaults deployed for a given underlying asset.
    /// @param asset The ERC-20 asset address to query.
    /// @return An array of vault proxy addresses.
    function getVaults(address asset) external view returns (address[] memory) {
        return assetToVaults[asset];
    }

    /// @notice Returns the total number of vaults deployed by this factory.
    /// @return The length of `vaultList`.
    function allVaultsCount() external view returns (uint256) {
        return vaultList.length;
    }
}
