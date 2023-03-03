//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../../src/core/storage/Account.sol";

/**
 * @title Object for mocking account storage
 */
contract MockAccount {
    using SetUtil for SetUtil.UintSet;

    struct CollateralBalance {
        address token;
        uint256 balanceD18;
    }

    function mockAccount(
        uint128 accountId,
        address owner,
        CollateralBalance[] memory balances,
        uint128[] memory activeProductIds,
        address settlementToken
    ) public {
        // Mock account
        Account.Data storage account = Account.create(accountId, owner);
        account.settlementToken = settlementToken;

        for (uint256 i = 0; i < balances.length; i++) {
            address token = balances[i].token;
            uint256 balanceD18 = balances[i].balanceD18;

            account.collaterals[token].balanceD18 = balanceD18;
        }

        for (uint256 i = 0; i < activeProductIds.length; i++) {
            uint128 productId = activeProductIds[i];
            account.activeProducts.add(productId);
        }
    }
}