// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/storage/ProtocolRiskConfiguration.sol";

contract ExposedProtocolRiskConfiguration { }

contract ProtocolRiskConfigurationTest is Test {
    ExposedProtocolRiskConfiguration internal protocolRiskConfiguration;

    function setUp() public {
        protocolRiskConfiguration = new ExposedProtocolRiskConfiguration();
    }
}
