// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@voltz-protocol/products-dated-irs/src/interfaces/IProductIRSModule.sol";
import "../storage/Config.sol";

/**
 * @title Performs swaps and settements on top of the v2 dated irs instrument
 */
library V2DatedIRS {
    function initiateDatedMakerOrder(
        uint128 accountId,
        uint128 marketId,
        uint256 maturityTimestamp,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta
    )
        internal
    {
        (executedBaseAmount, executedQuoteAmount) = IPoolModule(Config.load().VOLTZ_V2_DATED_IRS_VAMM_PROXY)
            .initiateDatedMakerOrder(accountId, marketId, maturityTimestamp, tickLower, tickUpper, liquidityDelta);
    }
}
