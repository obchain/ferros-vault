// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {YieldVault} from "./YieldVault.sol";

/// @title VaultFactory
/// @notice Factory contract that deploys ERC-1967 proxy instances of YieldVault
/// @dev Each vault is a minimal proxy sharing the same YieldVault implementation
contract VaultFactory is Ownable {
    /// @notice The current implementation address for new YieldVault proxies
    address public implementation;

    /// @notice Maps underlying asset to its deployed vaults
    mapping(address => address[]) public assetToVaults;

    /// @notice List of all deployed vaults
    address[] public vaultList;

    error ZeroAddress();

    /// @notice Emitted when a new vault is deployed
    /// @param vault The address of the new vault proxy
    /// @param asset The underlying asset
    /// @param owner The owner of the new vault
    event VaultCreated(address indexed vault, address indexed asset, address indexed owner);

    /// @notice Emitted when the implementation address is updated
    /// @param oldImplementation The previous implementation
    /// @param newImplementation The new implementation
    event ImplementationUpdated(address oldImplementation, address newImplementation);

    /// @notice Initializes the factory with the vault implementation
    /// @param implementation_ The address of the logic contract
    /// @param initialOwner The address of the factory owner
    constructor(address implementation_, address initialOwner) Ownable(initialOwner) {
        if (implementation_ == address(0)) revert ZeroAddress();
        implementation = implementation_;
        emit ImplementationUpdated(address(0), implementation_);
    }

    /// @notice Deploys a new YieldVault proxy
    /// @param asset The underlying asset
    /// @param name The name of the vault token
    /// @param symbol The symbol of the vault token
    /// @param initialYieldBps The initial yield rate in basis points
    /// @return vault The address of the newly deployed vault
    function createVault(
        address asset,
        string memory name,
        string memory symbol,
        uint256 initialYieldBps
    ) external returns (address vault) {
        if (asset == address(0)) revert ZeroAddress();

        bytes memory data = abi.encodeWithSelector(
            YieldVault.initialize.selector,
            asset,
            name,
            symbol,
            initialYieldBps,
            msg.sender
        );

        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        vault = address(proxy);

        assetToVaults[asset].push(vault);
        vaultList.push(vault);

        emit VaultCreated(vault, asset, msg.sender);
    }

    /// @notice Updates the implementation address for future proxies
    /// @param newImplementation The new logic contract address
    function setImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        address old = implementation;
        implementation = newImplementation;
        emit ImplementationUpdated(old, newImplementation);
    }

    /// @notice Returns the list of vaults for a given asset
    /// @param asset The underlying asset
    /// @return A list of vault addresses
    function getVaults(address asset) external view returns (address[] memory) {
        return assetToVaults[asset];
    }

    /// @notice Returns the total number of vaults deployed
    /// @return The count of vaults
    function allVaultsCount() external view returns (uint256) {
        return vaultList.length;
    }
}
