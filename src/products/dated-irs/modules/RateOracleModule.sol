// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IRateOracleModule.sol";
import "../storage/VariableRateOracle.sol";
import "../interfaces/IVAMMPoolModule.sol";

/**
 * @title Module for managing rate oracles connected to the Dated IRS Product
 * @dev See IRateOracleModule
 *  // todo: register a new rate oracle
 */
contract RateOracleManager is IRateOracleModule {
    using VariableRateOracle for VariableRateOracle.Data;
    /**
     * @inheritdoc IRateOracleModule
     */

    function getRateIndexCurrent(uint128 marketId) external view override returns (uint256 rateIndexCurrent) {
        return VariableRateOracle.load(marketId).getRateIndexCurrent();
    }

    /**
     * @inheritdoc IRateOracleModule
     */
    function getRateIndexMaturity(
        uint128 marketId,
        uint256 maturityTimestamp
    )
        external
        override
        returns (uint256 rateIndexMaturity)
    {
        return VariableRateOracle.load(marketId).getRateIndexMaturity(maturityTimestamp);
    }

    // todo: do we want this function to return something?
    // todo: needs a feature flag to check for permission to register new variable rate oracles
    // todo: can we enable editing existing rate oracles?
    function registerVariableOracle(uint128 marketId, address oracleAddress) external override {
        if (_isVariableOracleRegistered(marketId)) {
            return;
        }

        if (!_validateVariableOracleAddress(oracleAddress)) {
            revert InvalidVariableOracleAddress(oracleAddress);
        }

        // register the variable rate oracle
        VariableRateOracle.create(marketId, oracleAddress);
        emit VariableRateOracleRegistered(marketId, oracleAddress);
    }

    function _isVariableOracleRegistered(uint128 marketId) internal returns (bool isRegistered) { }

    function _validateVariableOracleAddress(address oracleAddress) internal returns (bool isValid) { }
}