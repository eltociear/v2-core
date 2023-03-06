//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/storage/CollateralConfiguration.sol";
import "../test-utils/MockCoreStorage.sol";

contract ExposedCollateralConfiguration is CoreState {

}

contract CollateralTest is Test {
    ExposedCollateralConfiguration collateralConfiguration;

    function setUp() public {
        collateralConfiguration = new ExposedCollateralConfiguration();
    }

    function test_
}
