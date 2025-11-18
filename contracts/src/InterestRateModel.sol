// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title InterestRateModel
/// @notice Two-slope utilization-based interest rate model inspired by Compound
/// @dev Stateless library — all functions are pure, no storage reads/writes
contract InterestRateModel {
    /// @notice Basis points divisor (100% = 10,000)
    uint256 public constant BPS_DIVISOR = 10_000;

    /// @notice The utilization rate (kink) where the interest rate slope changes
    uint256 public constant KINK = 8_000; // 80%

    /// @notice The base interest rate (at 0% utilization)
    uint256 public constant BASE_RATE = 200; // 2%

    /// @notice The multiplier of utilization before the kink
    uint256 public constant MULTIPLIER = 1_000; // 10%

    /// @notice The multiplier of utilization after the kink
    uint256 public constant JUMP_MULTIPLIER = 10_000; // 100%

    /// @notice The percentage of interest kept by the protocol
    uint256 public constant RESERVE_FACTOR = 1_000; // 10%

    /// @notice Calculates the utilization rate of the pool
    /// @param borrows Total amount borrowed
    /// @param liquidity Total liquidity in the pool
    /// @return The utilization rate in basis points (BPS)
    function getUtilization(uint256 borrows, uint256 liquidity) public pure returns (uint256) {
        if (borrows == 0) return 0;
        if (liquidity == 0) return BPS_DIVISOR;
        return (borrows * BPS_DIVISOR) / liquidity;
    }

    /// @notice Calculates the annual borrow interest rate
    /// @param borrows Total amount borrowed
    /// @param liquidity Total liquidity in the pool
    /// @return The borrow rate in basis points (BPS)
    function getBorrowRate(uint256 borrows, uint256 liquidity) public pure returns (uint256) {
        uint256 util = getUtilization(borrows, liquidity);

        if (util <= KINK) {
            return ((util * MULTIPLIER) / BPS_DIVISOR) + BASE_RATE;
        } else {
            uint256 normalRate = ((KINK * MULTIPLIER) / BPS_DIVISOR) + BASE_RATE;
            uint256 excessUtil = util - KINK;
            return ((excessUtil * JUMP_MULTIPLIER) / BPS_DIVISOR) + normalRate;
        }
    }

    /// @notice Calculates the annual supply interest rate
    /// @param borrows Total amount borrowed
    /// @param liquidity Total liquidity in the pool
    /// @return The supply rate in basis points (BPS)
    function getSupplyRate(uint256 borrows, uint256 liquidity) external pure returns (uint256) {
        uint256 util = getUtilization(borrows, liquidity);
        uint256 borrowRate = getBorrowRate(borrows, liquidity);
        
        // supplyRate = borrowRate * utilization * (1 - reserveFactor)
        uint256 spread = BPS_DIVISOR - RESERVE_FACTOR;
        return (borrowRate * util * spread) / (BPS_DIVISOR * BPS_DIVISOR);
    }
}
