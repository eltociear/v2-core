// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IMarketConfigurationModule.sol";
import "../storage/MarketConfiguration.sol";
import "@voltz-protocol/util-modules/src/storage/FeatureFlag.sol";

/**
 * @title Module for configuring a market
 * @dev See IMarketConfigurationModule.
 */
contract MarketConfigurationModule is IMarketConfigurationModule {
    using MarketConfiguration for MarketConfiguration.Data;

    bytes32 private constant _CONFIGURE_MARKET_FEATURE_FLAG = "createOracle";

    /**
     * @inheritdoc IMarketConfigurationModule
     */
    function configureMarket(MarketConfiguration.Data memory config) external {
        FeatureFlag.ensureAccessToFeature(_CONFIGURE_MARKET_FEATURE_FLAG);

        MarketConfiguration.set(config);

        emit MarketConfigured(config);
    }

    /**
     * @inheritdoc IMarketConfigurationModule
     */
    // solc-ignore-next-line func-mutability
    function getMarketConfiguration(uint128 irsMarketId) external pure returns (MarketConfiguration.Data memory config) {
        return MarketConfiguration.load(irsMarketId);
    }
}
