// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IPoolConfigurationModule.sol";
import "../storage/PoolConfiguration.sol";
import "../../../utils/storage/OwnableStorage.sol";

/**
 * @title Module for configuring the pool linked to the dated irs product
 * @dev See IPoolConfigurationModule.
 */
contract PoolConfigurationModule is IPoolConfigurationModule {
    using PoolConfiguration for PoolConfiguration.Data;

    /**
     * @inheritdoc IPoolConfigurationModule
     */
    function configurePool(PoolConfiguration.Data memory config) external { }

    /**
     * @inheritdoc IPoolConfigurationModule
     */
    function getPoolConfiguration() external view returns (PoolConfiguration.Data memory config) { }
}
