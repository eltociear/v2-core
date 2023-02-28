// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../utils/helpers/SetUtil.sol";
import "../../utils/helpers/SafeCast.sol";
import "./DatedIRSPosition.sol";
import "../../oracles/storage/OracleManagerStorage.sol";
import "../../interfaces/IOracleManager.sol";

/**
 * @title Object for tracking a portfolio of dated interest rate swap positions
 */
library DatedIRSPortfolio {
    using DatedIRSPosition for DatedIRSPosition.Data;
    using SetUtil for SetUtil.UintSet;
    using SafeCastU256 for uint256;

    struct Data {
        /**
         * @dev Numeric identifier for the account that owns the portfolio.
         * @dev Since a given account can only own a single portfolio in a given dated product
         * the id of the portfolio is the same as the id of the account
         * @dev There cannot be an account and hence dated portfolio with id zero
         */
        uint128 accountId;
        /**
         * @dev marketId (e.g. aUSDC lend) --> maturityTimestamp (e.g. 31st Dec 2023) --> DatedIRSPosition object with filled balances
         */
        mapping(uint128 => mapping(uint256 => DatedIRSPosition.Data)) positions;
        /**
         * @dev Ids of all the markets in which the account has active positions
         * todo: needs logic to mark active markets
         */
        SetUtil.UintSet activeMarkets;
        /**
         * @dev marketId (e.g. aUSDC lend) -> activeMaturities (e.g. 31st Dec 2023)
         */
        mapping(uint128 => SetUtil.UintSet) activeMaturitiesPerMarket;
    }

    /**
     * @dev Returns the portfolio stored at the specified portfolio id
     * @dev Same as account id of the account that owns the portfolio of dated irs positions
     */
    function load(uint128 accountId) internal pure returns (Data storage portfolio) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.DatedIRSPortfolio", accountId));
        assembly {
            portfolio.slot := s
        }
    }

    /**
     * @dev Creates a portfolio for a given id, the id of the portfolio and the account that owns it are the same
     */
    function create(uint128 id) internal returns (Data storage portfolio) {
        portfolio = load(id);
        // note, the portfolio id is the same as the account id that owns this portfolio
        portfolio.accountId = id;
    }

    /**
     * @dev note: given that all the accounts are single-token, unrealizedPnL for a given account is in terms
     * of the settlement token of that account
     * todo: introduce unrealized pnl from pool as well
     * todo: this function looks expesive and feels like there's room for optimisations
     */
    function getAccountUnrealizedPnL(Data storage self) internal view returns (int256 unrealizedPnL) {
        SetUtil.UintSet storage _activeMarkets = self.activeMarkets;
        for (uint256 i = 1; i < _activeMarkets.length(); i++) {
            uint128 marketId = _activeMarkets.valueAt(i).to128();
            SetUtil.UintSet storage _activeMaturities = self.activeMaturitiesPerMarket[marketId];
            for (uint256 j = 1; i < _activeMaturities.length(); i++) {
                uint256 maturityTimestamp = _activeMaturities.valueAt(j);
                DatedIRSPosition.Data memory position = self.positions[marketId][maturityTimestamp];
                // time_delta = max(0, (maturity - self.block.timestamp) / YEAR_IN_SECONDS)
                int256 timeDeltaAnnualized = ((maturityTimestamp - block.timestamp) / 31540000).toInt();

                OracleManagerStorage.Data memory oracleManager = OracleManagerStorage.load();
                int256 currentLiquidityIndex =
                    IOracleManager(oracleManager.oracleManagerAddress).getRateIndexCurrent(marketId).toInt();

                int256 gwap = IOracleManager(oracleManager.oracleManagerAddress).getDatedIRSGwap(
                    marketId, maturityTimestamp
                ).toInt();

                int256 unwindQuote = position.baseBalance * currentLiquidityIndex * (gwap * timeDeltaAnnualized + 1);
            }
        }
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function updatePosition(
        Data storage self,
        uint128 marketId,
        uint256 maturityTimestamp,
        int256 baseDelta,
        int256 quoteDelta
    ) internal {
        DatedIRSPosition.Data storage position = self.positions[marketId][maturityTimestamp];
        position.update(baseDelta, quoteDelta);
    }

    /**
     * @dev create, edit or close an irs position for a given marketId (e.g. aUSDC lend) and maturityTimestamp (e.g. 31st Dec 2023)
     */
    function settle(Data storage self, uint128 marketId, uint256 maturityTimestamp)
        internal
        returns (int256 settlementCashflow)
    {
        DatedIRSPosition.Data storage position = self.positions[marketId][maturityTimestamp];

        OracleManagerStorage.Data memory oracleManager = OracleManagerStorage.load();
        int256 liquidityIndexMaturity =
            IOracleManager(oracleManager.oracleManagerAddress).getRateIndexSnapshot(marketId, maturityTimestamp).toInt();

        settlementCashflow = position.baseBalance * liquidityIndexMaturity + position.quoteBalance;
        position.settle();
    }
}
