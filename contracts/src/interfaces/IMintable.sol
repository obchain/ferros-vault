// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IMintable
/// @notice Minimal interface for ERC-20 tokens that support permissioned minting.
/// @dev Used by MockYieldSource to simulate yield on testnet.
interface IMintable {
    /// @notice Mints `amount` tokens to `to`.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external;
}
