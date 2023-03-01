// SPDX-License-Identifier: Apache-2.0
pragma solidity =0.8.17;
import "../interfaces/IRateOracle.sol";
import "../../utils/helpers/Time.sol";

import { UD60x18, ud } from "@prb/math/UD60x18.sol";

contract RateOracleReader {
    IRateOracle public rateOracle;
    uint40 public settlementTimestamp;
    uint40 public recentIndexTimestamp;
    UD60x18 public settlementIndex;
    UD60x18 public recentIndex; // TODO: Compress to 216 bytes and store in same slot as recentIndexTimestamp, for efficiency?

    constructor(
        IRateOracle _rateOracle,
        uint40 _settlementTimestamp
    )
    {
        require(
            address(_rateOracle) != address(0),
            "rate oracle unknown"
        );

        // Get the time from the rate oracle
        rateOracle = _rateOracle;
        settlementTimestamp = _settlementTimestamp;
    }

    function getCurrentLiquidityIndexAndUpdateCache()
        public
        returns (uint40 newTimestamp, UD60x18 newIndex)
    {
        (newTimestamp, newIndex) = rateOracle.getLastUpdatedIndex();
        if (newTimestamp >= settlementTimestamp) {
            // TODO: calculate and save index at settlement timestamp
            //settlementRate = interpolateRateValue()
        } else {
            // TODO: be more efficient by only saving update to storage periodically. E.g. once a day, or if we are at least halfway to settlment time since last write
            recentIndexTimestamp = newTimestamp;
            recentIndex = newIndex;
        }

        return (newTimestamp, newIndex);
    }
}
