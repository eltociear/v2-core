// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/// @title Oracle Manager Interface
interface IOracleManager {
    function getRateIndexSnapshot(uint128 marketId, uint256 timestamp)
        external
        view
        returns (uint256 rateIndexSnapshot);
    function getRateIndexCurrent(uint128 marketId) external view returns (uint256 rateIndexCurrent);
    function getGwap(uint128 productId, uint128 marketId, uint256 maturityTimestamp)
        external
        view
        returns (uint256 datedIRSGwap);
}
