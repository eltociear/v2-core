pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "@voltz-protocol/core/src/storage/Account.sol";
import {DatedIrsRouter, DatedIrsProxy} from "../../src/DatedIrs.sol";

contract TestUtils is Test {

    function assertAlmostEq(int256 a, int256 b, uint256 eps) public {
        assertGe(a, b - int256(eps));
        assertLe(a, b + int256(eps));
    }

    function assertAlmostEq(int256 a, uint256 b, uint256 eps) public {
        assertGe(a, int256(b - eps));
        assertLe(a, int256(b + eps));
    }

    function assertAlmostEq(uint256 a, uint256 b, uint256 eps) public {
        assertGe(a, b - eps);
        assertLe(a, b + eps);
    }

}

contract ExposuresUtil {
    function getAccountAnnualizedExposuresTaker(DatedIrsProxy datedIrsProxy, uint128 accountId, address collateralType) public returns (int256) {
        (Account.Exposure[] memory exp,,)= datedIrsProxy.getAccountTakerAndMakerExposures(accountId, collateralType);
        return exp[0].annualizedNotional;
    }

    function getAccountAnnualizedExposuresMakerLong(DatedIrsProxy datedIrsProxy, uint128 accountId, address collateralType) public returns (int256) {
        (,,Account.Exposure[] memory exp)= datedIrsProxy.getAccountTakerAndMakerExposures(accountId, collateralType);
        return exp[0].annualizedNotional;
    }

    function getAccountAnnualizedExposuresMakerShort(DatedIrsProxy datedIrsProxy, uint128 accountId, address collateralType) public returns (int256) {
        (,Account.Exposure[] memory exp,)= datedIrsProxy.getAccountTakerAndMakerExposures(accountId, collateralType);
        return exp[0].annualizedNotional;
    }
}