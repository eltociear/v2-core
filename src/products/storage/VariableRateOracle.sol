// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

library VariableRateOracle {
    struct Data {
        address oracleAddress;
    }

    function load(address oracleAddress) internal pure returns (Data storage oracle) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.VariableRateOracle", oracleAddress));
        assembly {
            oracle.slot := s
        }
    }

    function create(address oracleAddress) internal returns (Data storage oracle) {
        oracle = load(oracleAddress);
        oracle.oracleAddress = oracleAddress;
    }

    // get rate index current
    // get rate index at maturity
}
