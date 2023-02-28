//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./interfaces/IDatedIRSProduct.sol";
import "../accounts/storage/Account.sol";
import "./storage/DatedIRSPortfolio.sol";
import "./storage/DatedIRSMarketConfiguration.sol";
import "../utils/helpers/SafeCast.sol";
import "../margin-engine/storage/Collateral.sol";
import "../pools/interfaces/IDatedIRSVAMMPool.sol";

/**
 * @title Dated Interest Rate Swap Product
 * @dev See IDatedIRSProduct
 */

contract DatedIRSProduct is IDatedIRSProduct {
    using Account for Account.Data;
    using DatedIRSPortfolio for DatedIRSPortfolio.Data;
    using SafeCastI256 for int256;
    using Collateral for Collateral.Data;

    /**
     * @inheritdoc IDatedIRSProduct
     */
    function initiateTakerOrder(
        address poolAddress,
        uint128 accountId,
        uint128 marketId,
        uint256 maturityTimestamp,
        int256 baseAmount
    ) external override returns (int256 executedBaseAmount, int256 executedQuoteAmount) {
        // note, in the beginning will just have a single pool id
        // in the future, products and pools should have a many to many relationship
        // check if account exists
        // check if market id is valid + check there is an active pool with maturityTimestamp requested
        Account.Data storage account = Account.loadAccountAndValidateOwnership(accountId);
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        IDatedIRSVAMMPool pool = IDatedIRSVAMMPool(poolAddress);
        (executedBaseAmount, executedQuoteAmount) = pool.executeDatedTakerOrder(marketId, maturityTimestamp, baseAmount);
        portfolio.updatePosition(marketId, maturityTimestamp, executedBaseAmount, executedQuoteAmount);
        // todo: mark product in the account object (see python implementation for more details, solidity uses setutil though)
        // todo: process taker fees (these should also be returned)
        account.imCheck();
    }

    /**
     * @inheritdoc IDatedIRSProduct
     */
    function initiateMakerOrder(
        address poolAddress,
        uint128 accountId,
        uint128 marketId,
        uint256 maturityTimestamp,
        uint256 priceLower,
        uint256 priceUpper,
        int256 requestedBaseAmount
    ) external override returns (int256 executedBaseAmount) {
        Account.Data storage account = Account.loadAccountAndValidateOwnership(accountId);
        IDatedIRSVAMMPool pool = IDatedIRSVAMMPool(poolAddress);
        executedBaseAmount =
            pool.executeDatedMakerOrder(marketId, maturityTimestamp, priceLower, priceUpper, requestedBaseAmount);
        // todo: mark product
        // todo: process maker fees (these should also be returned)
        account.imCheck();
    }
    /**
     * @inheritdoc IDatedIRSProduct
     */

    function settle(uint128 accountId, uint128 marketId, uint256 maturityTimestamp) external override {
        Account.Data storage account = Account.load(accountId);
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        int256 settlementCashflowInQuote = portfolio.settle(marketId, maturityTimestamp);

        address quoteToken = DatedIRSMarketConfiguration.load(marketId).quoteToken;

        if (settlementCashflowInQuote > 0) {
            account.collaterals[quoteToken].increaseCollateralBalance(settlementCashflowInQuote.toUint());
        } else {
            account.collaterals[quoteToken].decreaseCollateralBalance((-settlementCashflowInQuote).toUint());
        }
    }

    /**
     * @inheritdoc IProduct
     */
    function name(uint128 productId) external pure override returns (string memory) {
        return "Dated IRS Product";
    }

    /**
     * @inheritdoc IProduct
     */
    function getAccountUnrealizedPnL(uint128 accountId) external view override returns (int256 unrealizedPnL) {
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        return portfolio.getAccountUnrealizedPnL();
    }

    /**
     * @inheritdoc IProduct
     */
    function getAccountAnnualizedExposures(uint128 accountId)
        external
        view
        override
        returns (Account.Exposure[] memory exposures)
    {}

    /**
     * @inheritdoc IProduct
     */
    function closeAccount(uint128 accountId, address poolAddress) external override {
        DatedIRSPortfolio.Data storage portfolio = DatedIRSPortfolio.load(accountId);
        portfolio.closeAccount(poolAddress);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IProduct).interfaceId || interfaceId == this.supportsInterface.selector;
    }
}
