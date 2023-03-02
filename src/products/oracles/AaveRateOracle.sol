// SPDX-License-Identifier: Apache-2.0

pragma solidity =0.8.17;

import "../interfaces/IRateOracle.sol";
import "../externalInterfaces/IAaveV3LendingPool.sol";
import "../../utils/helpers/Time.sol";
// import "../rate_oracles/CompoundingRateOracle.sol";
import { UD60x18, ud } from "@prb/math/UD60x18.sol";

contract AaveRateOracle is IRateOracle {
    IAaveV3LendingPool public aaveLendingPool;
    address public immutable underlying;

    // uint8 public constant override UNDERLYING_YIELD_BEARING_PROTOCOL_ID = 1; // id of aave v2 is 1

    constructor(
        IAaveV3LendingPool _aaveLendingPool,
        address _underlying
    ) {
        require(
            address(_aaveLendingPool) != address(0),
            "aave pool must exist"
        );
        
        underlying = _underlying;
        aaveLendingPool = _aaveLendingPool;
    }

    /// @inheritdoc IRateOracle
    function getLastUpdatedIndex()
        public
        view
        override
        returns (uint40 timestamp, UD60x18 liquidityIndex)
    {
        uint256 liquidityIndexInRay = aaveLendingPool.getReserveNormalizedIncome(underlying);
        // if (liquidityIndex == 0) {
        //     revert CustomErrors.AavePoolGetReserveNormalizedIncomeReturnedZero();
        // }

        // Convert index from Aave's "ray" (decimal scaled by 10^27) to UD60x18 (decimal scaled by 10^18)
        return (Time.blockTimestampTruncated(), ud(liquidityIndexInRay / 1e9));
    }

    /// @inheritdoc IRateOracle
    function getCurrentIndex()
        external
        view
        override
        returns (UD60x18 liquidityIndex)
    {
        uint256 liquidityIndexInRay = aaveLendingPool.getReserveNormalizedIncome(underlying);
        // if (liquidityIndex == 0) {
        //     revert CustomErrors.AavePoolGetReserveNormalizedIncomeReturnedZero();
        // }

        // Convert index from Aave's "ray" (decimal scaled by 10^27) to UD60x18 (decimal scaled by 10^18)
        return ud(liquidityIndexInRay / 1e9);
    }

    /// @dev Given [beforeOrAt, atOrAfter] where the timestamp for which the counterfactual is calculated is within that range (but does not touch any of the bounds)
    /// @dev We can calculate the apy for [beforeOrAt, atOrAfter] --> refer to this value as apyFromBeforeOrAtToAtOrAfter
    /// @dev Then we want a counterfactual rate value which results in apy_before_after if the apy is calculated between [beforeOrAt, timestampForCounterfactual]
    /// @dev Hence (1+rateValueWei/beforeOrAtRateValueWei)^(1/timeInYears) = apyFromBeforeOrAtToAtOrAfter
    /// @dev Hence rateValueWei = beforeOrAtRateValueWei * (1+apyFromBeforeOrAtToAtOrAfter)^timeInYears - 1)
    function interpolateIndexValue(
        // uint256 beforeOrAtRateValueRay,
        // uint256 apyFromBeforeOrAtToAtOrAfterWad,
        // uint256 timeDeltaBeforeOrAtToQueriedTimeWad
        uint256 beforeIndexeRay,
        uint256 beforeTimeStamp,
        uint256 afterIndexRay,
        uint256 afterTimestamp,
        uint40 queryTimestamp
    ) public pure returns (uint256 indexRay) {
        // uint256 timeInYearsWad = FixedAndVariableMath.accrualFact(
        //     timeDeltaBeforeOrAtToQueriedTimeWad
        // );
        // uint256 apyPlusOne = apyFromBeforeOrAtToAtOrAfterWad + ONE_IN_WAD;
        // uint256 factorInWad = PRBMathUD60x18.pow(apyPlusOne, timeInYearsWad);
        // uint256 factorInRay = WadRayMath.wadToRay(factorInWad);
        // rateValueRay = WadRayMath.rayMul(beforeOrAtRateValueRay, factorInRay);
        // TODO: implement with index rather than APY inputs
        return 0;
    }

    // /// @dev Given [beforeOrAt, atOrAfter] where the timestamp for which the counterfactual is calculated is within that range (but does not touch any of the bounds)
    // /// @dev We can calculate the apy for [beforeOrAt, atOrAfter] --> refer to this value as apyFromBeforeOrAtToAtOrAfter
    // /// @dev Then we want a counterfactual rate value which results in apy_before_after if the apy is calculated between [beforeOrAt, timestampForCounterfactual]
    // /// @dev Hence (1+rateValueWei/beforeOrAtRateValueWei)^(1/timeInYears) = apyFromBeforeOrAtToAtOrAfter
    // /// @dev Hence rateValueWei = beforeOrAtRateValueWei * (1+apyFromBeforeOrAtToAtOrAfter)^timeInYears - 1)
    // function interpolateRateValue(
    //     uint256 beforeOrAtRateValueRay,
    //     uint256 apyFromBeforeOrAtToAtOrAfterWad,
    //     uint256 timeDeltaBeforeOrAtToQueriedTimeWad
    // ) public pure override returns (uint256 rateValueRay) {
    //     uint256 timeInYearsWad = FixedAndVariableMath.accrualFact(
    //         timeDeltaBeforeOrAtToQueriedTimeWad
    //     );
    //     uint256 apyPlusOne = apyFromBeforeOrAtToAtOrAfterWad + ONE_IN_WAD;
    //     uint256 factorInWad = PRBMathUD60x18.pow(apyPlusOne, timeInYearsWad);
    //     uint256 factorInRay = WadRayMath.wadToRay(factorInWad);
    //     rateValueRay = WadRayMath.rayMul(beforeOrAtRateValueRay, factorInRay);
    // }
}
