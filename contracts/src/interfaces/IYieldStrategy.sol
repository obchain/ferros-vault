// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IYieldStrategy
/// @notice Standard interface for yield-generating strategies plugged into YieldVault.
/// @dev Any ERC-4626-compatible yield source implements this interface.
///      Swap implementations without modifying the vault — only `setStrategy()` needed.
interface IYieldStrategy {
    /// @notice Returns the address of the underlying ERC-20 asset managed by this strategy.
    function asset() external view returns (address);

    /// @notice Returns the total amount of underlying assets held or accrued by this strategy.
    /// @dev Must include any pending yield not yet checkpointed.
    function totalAssets() external view returns (uint256);

    /// @notice Deposits `assets` of underlying into the strategy.
    /// @dev Caller must have approved this contract to spend `assets` beforehand.
    /// @param assets Amount of underlying asset to deposit.
    function deposit(uint256 assets) external;

    /// @notice Withdraws `assets` of underlying from the strategy to the caller.
    /// @param assets Amount of underlying asset to withdraw.
    function withdraw(uint256 assets) external;
}
