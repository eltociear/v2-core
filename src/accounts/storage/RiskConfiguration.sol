//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Tracks protocol-wide risk settings
 */
library RiskConfiguration {
    struct Data {
        // todo: can we pack parameters in a more gas/storage efficient way?
        /**
         * @dev Risk Parameter Mapping: productId (e.g. Dated IRS) => marketId (e.g. aUSDC lend) => riskParameter (e.g. 0.1)
         */
        mapping(uint128 => mapping(uint128 => int256)) riskParameters;
        /**
         * @dev Initial Margin (IM) Requirement Multiplier Mapping: productId (e.g. Dated IRS) => marketId (e.g. aUSDC lend) => imMultiplier (e.g. 1.5)
         * @dev IM Multipliers are used to introduce a buffer between the liquidation and initial margin requirements
         * where IM = imMultiplier * LM
         */
        mapping(uint128 => mapping(uint128 => int256)) imMultipliers;
        /**
         * @dev Liquidator Reward Parameter Mapping: productId (e.g. Dated IRS) => marketId (e.g. aUSDC lend) => riskParameter (e.g. 0.1)
         * @dev Liquidator reward parameters are multiplied by the im delta caused by the liquidation to get the liquidator reward amount
         */
        mapping(uint128 => mapping(uint128 => int256)) liquidatorRewardParameters;
    }
}
