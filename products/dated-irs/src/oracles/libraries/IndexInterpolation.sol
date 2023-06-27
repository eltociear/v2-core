/*
Licensed under the Voltz v2 License (the "License"); you
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import { UD60x18, ud } from "@prb/math/UD60x18.sol";

/**
 * @title Library for variable rate oracle liquidity index interpolation
 */
library IndexInterpolation {

    function interpolateIndexValue(
        UD60x18 beforeIndex,
        uint256 beforeTimestampWad,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestampWad,
        uint256 queryTimestampWad
    )
    public
    pure
    returns (UD60x18 interpolatedIndex)
    {
        // todo: custom error
        require(queryTimestampWad > beforeTimestampWad, "Unordered timestamps");

        if (atOrAfterTimestampWad == queryTimestampWad) {
            return atOrAfterIndex;
        }

        // todo: custom error
        require(queryTimestampWad < atOrAfterTimestampWad, "Unordered timestamps");
        UD60x18 totalDelta = atOrAfterIndex.sub(beforeIndex);

        UD60x18 proportionOfPeriodElapsed =
        ud(queryTimestampWad - beforeTimestampWad).div(ud(atOrAfterTimestampWad - beforeTimestampWad));
        return proportionOfPeriodElapsed.mul(totalDelta).add(beforeIndex);
    }
}
