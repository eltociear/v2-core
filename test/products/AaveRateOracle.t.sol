pragma solidity 0.8.17;

import "./mocks/MockAaveLendingPool.sol";
import "oz/interfaces/IERC20.sol";
import { UD60x18, convert } from "@prb/math/UD60x18.sol";
import { PRBMathAssertions } from "@prb/math/test/Assertions.sol";
import { console2 } from "forge-std/console2.sol";



contract AaveRateOracle_Test is PRBMathAssertions {
    address constant TEST_UNDERLYING_ADDRESS = 0x1122334455667788990011223344556677889900;
    IERC20 constant TEST_UNDERLYING = IERC20(TEST_UNDERLYING_ADDRESS);
    MockAaveLendingPool mockLendingPool;

    function setUp() public {
        mockLendingPool = new MockAaveLendingPool();
        mockLendingPool.setReserveNormalizedIncome(TEST_UNDERLYING, convert(42));
    }

    function testReserveNormalizedIncome() public {
        assertEq(mockLendingPool.getReserveNormalizedIncome(TEST_UNDERLYING_ADDRESS), 42e27);
    }
}