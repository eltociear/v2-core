//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Tracks protocol-wide risk settings
 */
library RiskConfiguration {
    struct Data {
        /**
         * @dev Risk Parameter Mapping: productId (e.g. Dated IRS) => marketId (e.g. aUSDC lend) => riskParameter (e.g. 0.1)
         */
        mapping(uint128 => mapping(uint128 => int256)) riskParameterMapping;
    }
}
