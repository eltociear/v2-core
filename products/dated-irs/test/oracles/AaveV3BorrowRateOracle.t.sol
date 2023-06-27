/*
Licensed under the Voltz v2 License (the "License"); you
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import "../mocks/MockAaveLendingPool.sol";
import "../../src/oracles/AaveV3BorrowRateOracle.sol";
import "../../src/interfaces/IRateOracle.sol";
import "oz/interfaces/IERC20.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC165.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";

contract AaveV3RateOracleTest is Test {

    // todo: consider abstracting duplicate tests once rate oracle functions are stateless libraries

    using { unwrap } for UD60x18;

    address constant TEST_UNDERLYING_ADDRESS = 0x1122334455667788990011223344556677889900;
    IERC20 constant TEST_UNDERLYING = IERC20(TEST_UNDERLYING_ADDRESS);
    uint256 constant FACTOR_PER_SECOND = 1000000001000000000;
    uint256 constant INDEX_AFTER_SET_TIME = 1000010000050000000;
    UD60x18 initValue = ud(1e18);

    MockAaveLendingPool mockLendingPool;
    AaveV3BorrowRateOracle rateOracle;

    function setUp() public virtual {
        mockLendingPool = new MockAaveLendingPool();
        mockLendingPool.setReserveNormalizedVariableDebt(TEST_UNDERLYING, initValue);
        rateOracle = new AaveV3BorrowRateOracle(
            mockLendingPool,
            TEST_UNDERLYING_ADDRESS
        );
    }

    function test_SetIndexInMock() public {
        assertEq(mockLendingPool.getReserveNormalizedVariableDebt(TEST_UNDERLYING_ADDRESS), initValue.unwrap() * 1e9);
    }

    function test_InitCurrentIndex() public {
        assertEq(rateOracle.getCurrentIndex().unwrap(), initValue.unwrap());
    }

    function test_InitLastUpdatedIndex() public {
        (uint32 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();
        assertEq(index.unwrap(), initValue.unwrap());
        assertEq(time, Time.blockTimestampTruncated());
    }

    function test_InterpolateIndexValue() public {
        UD60x18 index = rateOracle.interpolateIndexValue(
            ud(1e18), // UD60x18 beforeIndex
            0, // uint256 beforeTimestamp
            ud(1.1e18), // UD60x18 atOrAfterIndex
            100, // uint256 atOrAfterTimestamp
            50 // uint256 queryTimestamp
        );
        assertEq(index.unwrap(), 1.05e18);
    }

    function test_RevertWhen_InterpolateUnorderedBeforeTime() public {
        vm.expectRevert(bytes("Unordered timestamps"));
        rateOracle.interpolateIndexValue(
            ud(1e18), // UD60x18 beforeIndex
            51, // uint256 beforeTimestamp
            ud(1.1e18), // UD60x18 atOrAfterIndex
            100, // uint256 atOrAfterTimestamp
            50 // uint256 queryTimestamp
        );
    }

    function test_RevertWhen_InterpolateUnorderedAfterTime() public {
        vm.expectRevert(bytes("Unordered timestamps"));
        rateOracle.interpolateIndexValue(
            ud(1e18), // UD60x18 beforeIndex
            0, // uint256 beforeTimestamp
            ud(1.1e18), // UD60x18 atOrAfterIndex
            49, // uint256 atOrAfterTimestamp
            50 // uint256 queryTimestamp
        );
    }

    function test_InterpolateIndexValueAtKnownTime() public {
        UD60x18 index = rateOracle.interpolateIndexValue(
            ud(1e18), // UD60x18 beforeIndex
            0, // uint256 beforeTimestamp
            ud(1.1e18), // UD60x18 atOrAfterIndex
            50, // uint256 atOrAfterTimestamp
            50 // uint256 queryTimestamp
        );
        assertEq(index.unwrap(), 1.1e18);
    }

    function test_SetNonZeroIndexInMock() public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        vm.warp(Time.blockTimestampTruncated() + 10000);
        assertApproxEqRel(
            mockLendingPool.getReserveNormalizedVariableDebt(TEST_UNDERLYING_ADDRESS),
            INDEX_AFTER_SET_TIME * 1e9,
            1e7 // 0.000000001% error
        );
    }

    function test_NonZeroCurrentIndex() public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        vm.warp(Time.blockTimestampTruncated() + 10000);
        assertApproxEqAbs(rateOracle.getCurrentIndex().unwrap(), INDEX_AFTER_SET_TIME, 1e7);
    }

    function test_NonZeroLastUpdatedIndex() public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        vm.warp(Time.blockTimestampTruncated() + 10000);

        (uint32 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();

        assertApproxEqRel(index.unwrap(), INDEX_AFTER_SET_TIME, 1e17);
        assertEq(time, Time.blockTimestampTruncated());
    }

    function test_SupportsInterfaceIERC165() public {
        assertTrue(rateOracle.supportsInterface(type(IERC165).interfaceId));
    }

    function test_SupportsInterfaceIRateOracle() public {
        assertTrue(rateOracle.supportsInterface(type(IRateOracle).interfaceId));
    }

    function test_SupportsOtherInterfaces() public {
        assertFalse(rateOracle.supportsInterface(type(IERC20).interfaceId));
    }

    // ------------------- FUZZING -------------------

    /**
     * @dev should fail in the following cases:
     * - give a negative index if before & at values are inverted (time & index)
     * -
     */
    function testFuzz_RevertWhen_InterpolateIndexValueWithUnorderedValues(
        UD60x18 beforeIndex,
        uint256 beforeTimestamp,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestamp,
        uint256 queryTimestamp
    )
    public
    {
        vm.expectRevert();
        vm.assume(atOrAfterTimestamp != queryTimestamp);
        vm.assume(
            beforeIndex.gt(atOrAfterIndex) || beforeTimestamp >= atOrAfterTimestamp
            || (queryTimestamp > atOrAfterTimestamp || queryTimestamp <= beforeTimestamp)
        );

        UD60x18 index =
        rateOracle.interpolateIndexValue(beforeIndex, beforeTimestamp, atOrAfterIndex, atOrAfterTimestamp, queryTimestamp);
    }

    function testFuzz_SetNonZeroIndexInMock(uint256 factorPerSecond, uint16 timePassed) public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        // not bigger than 72% apy per year
        vm.assume(factorPerSecond <= 1.0015e18 && factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        vm.warp(Time.blockTimestampTruncated() + timePassed);
        assertTrue(mockLendingPool.getReserveNormalizedVariableDebt(TEST_UNDERLYING_ADDRESS) >= initValue.unwrap());
    }

    function testFuzz_NonZeroCurrentIndexAfterTimePasses(uint256 factorPerSecond, uint16 timePassed) public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        // not bigger than 72% apy per year
        vm.assume(factorPerSecond <= 1.0015e18 && factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        vm.warp(Time.blockTimestampTruncated() + timePassed);

        UD60x18 index = rateOracle.getCurrentIndex();

        assertTrue(index.gte(initValue));
    }

    function testFuzz_NonZeroLatestUpdateAfterTimePasses(uint256 factorPerSecond, uint16 timePassed) public {
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(FACTOR_PER_SECOND));
        // not bigger than 72% apy per year
        vm.assume(factorPerSecond <= 1.0015e18 && factorPerSecond >= 1e18);
        mockLendingPool.setFactorPerSecond(TEST_UNDERLYING, ud(factorPerSecond));
        vm.warp(Time.blockTimestampTruncated() + timePassed);

        (uint32 time, UD60x18 index) = rateOracle.getLastUpdatedIndex();

        assertTrue(index.gte(initValue));
        assertEq(time, Time.blockTimestampTruncated());
    }

    // function testFuzz_success_interpolateIndexValue(
    //     uint256 beforeIndex,
    //     uint40 beforeTimestamp,
    //     uint256 atOrAfterIndex,
    //     uint40 atOrAfterTimestamp,
    //     uint40 queryTimestamp
    // ) public {
    //     // bounding not to lose precision
    //     // should we also enforce this in the function?
    //     vm.assume(atOrAfterIndex < 1e38);
    //     vm.assume(beforeIndex >= 1 && beforeTimestamp >= 1 && beforeIndex >= 1e18);

    //     vm.assume(beforeIndex < atOrAfterIndex);
    //     vm.assume(queryTimestamp <= atOrAfterTimestamp && queryTimestamp > beforeTimestamp);

    //     UD60x18 beforeIndexWad = ud(beforeIndex);
    //     UD60x18 atOrAfterIndexWad = ud(atOrAfterIndex);
    //     uint256 beforeTimestampWad = beforeTimestamp * 1e18;
    //     uint256 atOrAfterTimestampWad = atOrAfterTimestamp * 1e18;
    //     uint256 queryTimestampWad = queryTimestamp * 1e18;

    //     UD60x18 index = rateOracle.interpolateIndexValue(
    //         beforeIndexWad,
    //         beforeTimestampWad,
    //         atOrAfterIndexWad,
    //         atOrAfterTimestampWad,
    //         queryTimestampWad
    //     );

    //     assertTrue(index.gte(beforeIndexWad)); // does it need library for comparison?
    //     assertTrue(index.lte(atOrAfterIndexWad));

    //     console2.log("index:", unwrap(index));

    //     // slopes should be equal
    //     if(unwrap(index.sub(beforeIndexWad).div(index)) < 1e9) {
    //         console2.log("time:", unwrap(ud(beforeTimestampWad).div(ud(atOrAfterTimestampWad))));
    //         console2.log("index dif:", unwrap(beforeIndexWad.div(atOrAfterIndexWad)));
    //         assertTrue(
    //             unwrap(ud(beforeTimestampWad).div(ud(atOrAfterTimestampWad))) < 1e9
    //             || unwrap(beforeIndexWad.div(atOrAfterIndexWad)) < 1e9
    //         );
    //     } else {
    //         console2.log("ok");
    //         assertApproxEqRel(
    //             unwrap(atOrAfterIndexWad.sub(beforeIndexWad).div(index.sub(beforeIndexWad))),
    //             unwrap(ud(atOrAfterTimestampWad - beforeTimestampWad).div(ud(queryTimestampWad - beforeTimestampWad))),
    //             5e16 // 5% error
    //         );
    //     }

    // }
}