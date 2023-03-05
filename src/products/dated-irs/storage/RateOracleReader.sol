// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IRateOracle.sol";
import "src/utils/helpers/Time.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

library RateOracleReader {
    /**
     * @dev Thrown if the index-at-maturity is requested before maturity.
     */
    error MaturityNotReached();

    struct PreMaturityData {
        uint40 lastKnownTimestamp;
        UD60x18 lastKnownIndex; // TODO - truncate indices to UD40x18 (nned to define this and faciliate checked casting) to save a
            // storage slot here and elsewhere
    }

    struct Data {
        uint128 marketId;
        address oracleAddress;
        mapping(uint256 => PreMaturityData) rateIndexPreMaturity;
        mapping(uint256 => UD60x18) rateIndexAtMaturity;
    }

    function load(uint128 marketId) internal pure returns (Data storage oracle) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.RateOracleReader", marketId));
        assembly {
            oracle.slot := s
        }
    }

    function create(uint128 marketId, address oracleAddress) internal returns (Data storage oracle) {
        oracle = load(marketId);
        oracle.marketId = marketId;
        oracle.oracleAddress = oracleAddress;
    }

    function getRateIndexCurrent(Data storage self, uint256 maturityTimestamp) internal view returns (UD60x18 rateIndexCurrent) {
        if (block.timestamp >= maturityTimestamp) {
            // maturity timestamp has passed
            UD60x18 rateIndexMaturity = self.rateIndexAtMaturity[maturityTimestamp];

            if (rateIndexMaturity.unwrap() == 0) {
                UD60x18 currentIndex = IRateOracle(self.oracleAddress).getCurrentIndex();

                PreMaturityData memory cache = self.rateIndexPreMaturity[maturityTimestamp];

                if (cache.lastKnownTimestamp == 0) {
                    // todo: revert
                }

                rateIndexMaturity = IRateOracle(self.oracleAddress).interpolateIndexValue({
                    beforeIndex: cache.lastKnownIndex,
                    beforeTimestamp: cache.lastKnownTimestamp,
                    atOrAfterIndex: currentIndex,
                    atOrAfterTimestamp: block.timestamp,
                    queryTimestamp: maturityTimestamp
                });
            }
            return rateIndexMaturity;
        } else {
            UD60x18 currentIndex = IRateOracle(self.oracleAddress).getCurrentIndex();
            return currentIndex;
        }
    }

    function getRateIndexMaturity(Data storage self, uint256 maturityTimestamp) internal view returns (UD60x18 rateIndexMaturity) {
        if (block.timestamp < maturityTimestamp) {
            revert MaturityNotReached();
        }

        return getRateIndexCurrent(self, maturityTimestamp);
    }
}
