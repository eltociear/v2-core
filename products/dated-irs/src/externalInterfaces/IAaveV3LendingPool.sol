// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title IPool
 * @author Aave
 * @notice Defines the basic interface for an Aave V3 Pool.
 */
interface IAaveV3LendingPool {
    /**
     * @notice Returns the normalized income of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve's normalized income
     */
    function getReserveNormalizedIncome(address asset) external view returns (uint256);
}