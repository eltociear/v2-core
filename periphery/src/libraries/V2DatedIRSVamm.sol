// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@voltz-protocol/products-dated-irs/src/interfaces/IPool.sol";
import "../storage/Config.sol";

/**
 * @title Performs swaps and settements on top of the v2 dated irs instrument
 */
library V2DatedIRSVamm {
    function initiateDatedMakerOrder(
        uint128 accountId,
        uint128 marketId,
        uint32 maturityTimestamp,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta
    )
        internal
     {
        IPool(Config.load().VOLTZ_V2_DATED_IRS_VAMM_PROXY)
            .initiateDatedMakerOrder(accountId, marketId, maturityTimestamp, tickLower, tickUpper, liquidityDelta);
    }
}
