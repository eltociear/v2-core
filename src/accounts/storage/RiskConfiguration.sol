//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Tracks protocol-wide risk settings
 */
library RiskConfiguration {
    struct Data {
        // todo: can we pack parameters in a more gas/storage efficient way?
        /**
         * @dev Id of the product for which we store risk configurations
         */
        uint128 productId;
        /**
         * @dev Id of the market for which we store risk configurations
         */
        uint128 marketId;
        /**
         * @dev Risk Parameters are multiplied by notional exposures to derived shocked cashflow calculations
         */
        int256 riskParameter;
        /**
         * @dev IM Multipliers are used to introduce a buffer between the liquidation and initial margin requirements
         * where IM = imMultiplier * LM
         */
        int256 imMultiplier;
        /**
         * @dev Liquidator reward parameters are multiplied by the im delta caused by the liquidation to get the liquidator reward amount
         */
        int256 liquidatorRewardParameter;
    }

    /**
     * @dev Loads the RiskConfiguration object for the given collateral type.
     * @param productId Id of the product (e.g. IRS) for which we want to query the risk configuration
     * @param marketId Id of the market (e.g. aUSDC lend) for which we want to query the risk configuration
     * @return riskConfiguration The RiskConfiguration object.
     */
    // todo: stopped here
    function load(uint128 productId, uint128 marketId) internal pure returns (Data storage riskConfiguration) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.RiskConfiguration", productId, marketId));
        assembly {
            riskConfiguration.slot := s
        }
    }

    /**
     * @dev Sets the risk configuration for a given productId & marketId pair
     * @param config The RiskConfiguration object with all the risk parameters
     */
    function set(Data memory config) internal {
        Data storage storedConfig = load(config.productId, config.marketId);

        storedConfig.productId = config.productId;
        storedConfig.marketId = config.marketId;
        storedConfig.riskParameter = config.riskParameter;
        storedConfig.imMultiplier = config.imMultiplier;
        storedConfig.liquidatorRewardParameter = config.liquidatorRewardParameter;
    }
}
