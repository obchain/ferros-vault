// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title InterestRateModel
/// @notice Two-slope utilization-based interest rate model inspired by Compound.
/// @dev Stateless library — all functions are pure, no storage reads or writes.
///      This is a standalone rate oracle reserved for a future lending/borrowing extension.
///      The current YieldVault uses a fixed `yieldRateBps` set by the owner and does not
///      consume this library at runtime.
library InterestRateModel {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice Basis points divisor (100% = 10,000).
    uint256 internal constant BPS_DIVISOR = 10_000;

    /// @notice The utilization kink — above this point the jump multiplier activates.
    uint256 internal constant KINK = 8_000; // 80%

    /// @notice The base borrow rate at 0% utilization.
    uint256 internal constant BASE_RATE = 200; // 2%

    /// @notice The rate multiplier applied below the kink.
    uint256 internal constant MULTIPLIER = 1_000; // 10%

    /// @notice The rate multiplier applied above the kink.
    uint256 internal constant JUMP_MULTIPLIER = 10_000; // 100%

    /// @notice The fraction of borrow interest retained as protocol reserves.
    uint256 internal constant RESERVE_FACTOR = 1_000; // 10%

    // Compile-time invariants — will cause an underflow compile error if violated.
    uint256 private constant _ASSERT_RESERVE = BPS_DIVISOR - RESERVE_FACTOR;
    uint256 private constant _ASSERT_KINK = BPS_DIVISOR - KINK;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when `borrows > 0` but `liquidity == 0`, which is an impossible pool state.
    error InvalidPoolState();

    // -------------------------------------------------------------------------
    // Functions
    // -------------------------------------------------------------------------

    /// @notice Calculates the pool utilization rate.
    /// @param borrows Total outstanding borrows.
    /// @param liquidity Total liquidity supplied to the pool.
    /// @return The utilization rate in basis points.
    function getUtilization(uint256 borrows, uint256 liquidity) internal pure returns (uint256) {
        if (borrows == 0) return 0;
        if (liquidity == 0) revert InvalidPoolState();
        return (borrows * BPS_DIVISOR) / liquidity;
    }

    /// @notice Calculates the annual borrow interest rate for the given pool state.
    /// @param borrows Total outstanding borrows.
    /// @param liquidity Total liquidity supplied to the pool.
    /// @return The annual borrow rate in basis points.
    function getBorrowRate(uint256 borrows, uint256 liquidity) internal pure returns (uint256) {
        uint256 util = getUtilization(borrows, liquidity);

        if (util <= KINK) {
            return ((util * MULTIPLIER) / BPS_DIVISOR) + BASE_RATE;
        } else {
            uint256 normalRate = ((KINK * MULTIPLIER) / BPS_DIVISOR) + BASE_RATE;
            uint256 excessUtil = util - KINK;
            return ((excessUtil * JUMP_MULTIPLIER) / BPS_DIVISOR) + normalRate;
        }
    }

    /// @notice Calculates the annual supply interest rate for the given pool state.
    /// @dev supplyRate = borrowRate * utilization * (1 − reserveFactor) / BPS_DIVISOR²
    /// @param borrows Total outstanding borrows.
    /// @param liquidity Total liquidity supplied to the pool.
    /// @return The annual supply rate in basis points.
    function getSupplyRate(uint256 borrows, uint256 liquidity) internal pure returns (uint256) {
        uint256 util = getUtilization(borrows, liquidity);
        uint256 borrowRate = getBorrowRate(borrows, liquidity);
        uint256 spread = BPS_DIVISOR - RESERVE_FACTOR;
        return (borrowRate * util * spread) / (BPS_DIVISOR * BPS_DIVISOR);
    }
}
