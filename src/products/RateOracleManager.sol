// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./interfaces/IRateOracleManager.sol";

/**
 * @title Module for managing rate oracles connected to the Dated IRS Product
 * @dev See IRateOracleManager
 */
contract RateOracleManager is IRateOracleManager {
    /**
     * @inheritdoc IRateOracleManager
     */
    function getRateIndexCurrent(uint128 marketId) external view returns (uint256 rateIndexCurrent) {}

    /**
     * @inheritdoc IRateOracleManager
     */
    function getRateIndexSnapshot(uint128 marketId, uint256 maturityTimestamp)
        external
        view
        returns (uint256 rateIndexSnapshot)
    {}

    /**
     * @inheritdoc IRateOracleManager
     */
    function getDatedIRSGwap(uint128 marketId, uint256 maturityTimestamp)
        external
        view
        returns (uint256 datedIRSGwap)
    {}
}
