// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/storage/ProductCreator.sol";

contract ExposedProductCreator { }

contract ProductCreatorTest is Test {
    ExposedProductCreator internal productCreator;

    function setUp() public {
        productCreator = new ExposedProductCreator();
    }
}
