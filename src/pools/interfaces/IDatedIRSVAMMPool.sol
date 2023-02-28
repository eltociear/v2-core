// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../interfaces/IPool.sol";

/**
 * @title Dated Interest Rate Swap VAMM Pool
 * @dev Implementation of DatedIRSVAMMPool is in a separate repo
 * @dev See IDatedIRSVAMMPool
 */

interface IDatedIRSVAMMPool is IPool {
    /**
     * @notice Executes a dated maker order against a vamm that provided liquidity to a given marketId & maturityTimestamp pair
     * @param marketId Id of the market in which the lp wants to provide liqudiity
     * @param maturityTimestamp Timestamp at which a given market matures
     * @param fixedRateLower Lower Fixed Rate of the range order
     * @param fixedRateUpper Upper Fixed Rate of the range order
     * @param baseAmount Amount of notional provided to a given vamm in terms of the virtual base tokens of the market
     */
    function executeDatedMakerOrder(
        uint128 marketId,
        uint256 maturityTimestamp,
        uint256 fixedRateLower,
        uint256 fixedRateUpper,
        uint256 baseAmount
    ) external;
}
