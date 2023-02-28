// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IOracleManager.sol";

/**
 * @title Module for managing oracles connected to the protocol
 * @dev See IOracleManager
 */
contract OracleManager is IOracleManager {
    /**
     * @inheritdoc IOracleManager
     */
    function getRateIndexSnapshot(uint128 marketId, uint256 maturityTimestamp)
        external
        view
        returns (uint256 rateIndexSnapshot)
    {}
    /**
     * @inheritdoc IOracleManager
     */
    function getRateIndexCurrent(uint128 marketId) external view returns (uint256 rateIndexCurrent) {}

    /**
     * @inheritdoc IOracleManager
     */
    function getDatedIRSGwap(uint128 marketId, uint256 maturityTimestamp)
        external
        view
        returns (uint256 datedIRSGwap)
    {}
}
