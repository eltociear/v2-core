//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./MockAccount.sol";
import "./MockProduct.sol";
import "./Constants.sol";

contract MockCore is MockAccount, MockProduct {}

/**
 * @dev Core storage mocks for accounts and products
  * @dev Products:
 *        - - id: 1
 *          - product address: PRODUCT_ADDRESS_1
 *          - name: "Product 1"
 *          - owner: PRODUCT_OWNER
 *
 *        - - id: 2
 *          - product address: PRODUCT_ADDRESS_2
 *          - name: "Product 2"
 *          - owner: PRODUCT_OWNER
 * @dev Accounts:
 *        - - id: 100
 *          - owner: ALICE
 *          - balances: (TOKEN_0, 350), (TOKEN_1, 100)
 *          - product IDs: 1, 2
 *          - settlement token: TOKEN_0
 *
 *        - - id: 101
 *          - owner: BOB
 *          - balances: (TOKEN_0, 150), (TOKEN_1, 300)
 *          - product IDs: 1, 2
 *          - settlement token: TOKEN_1
 */
contract MockCoreState is MockCore {
    constructor() {

        // Create product (id: 1)
        {
            uint128 productId = mockProduct(Constants.PRODUCT_ADDRESS_1, "Product 1", Constants.PRODUCT_OWNER);
            require(productId == 1, "Mock Core: Unexpected Product Id (1)");
        }

        // Create product (id: 2)
        {
            uint128 productId = mockProduct(Constants.PRODUCT_ADDRESS_2, "Product 2", Constants.PRODUCT_OWNER);
            require(productId == 2, "Mock Core: Unexpected Product Id (2)");
        }
        
        // Create account (id: 100)
        {
            CollateralBalance[] memory balances = new CollateralBalance[](2);
            balances[0] = CollateralBalance({
                token: Constants.TOKEN_0,
                balanceD18: 350e18
            }); 

            balances[1] = CollateralBalance({
                token: Constants.TOKEN_1,
                balanceD18: 100e18
            });

            uint128[] memory activeProductIds = new uint128[](2);
            activeProductIds[0] = 1;
            activeProductIds[1] = 2;

            mockAccount(
                100,
                Constants.ALICE,
                balances,
                activeProductIds,
                Constants.TOKEN_0
            );
        }
        
        // Create account (id: 101)
        {
            CollateralBalance[] memory balances = new CollateralBalance[](2);
            balances[0] = CollateralBalance({
                token: Constants.TOKEN_0,
                balanceD18: 150e18
            }); 

            balances[1] = CollateralBalance({
                token: Constants.TOKEN_1,
                balanceD18: 300e18
            });

            uint128[] memory activeProductIds = new uint128[](2);
            activeProductIds[0] = 1;
            activeProductIds[1] = 2;

            mockAccount(
                101,
                Constants.BOB,
                balances,
                activeProductIds,
                Constants.TOKEN_1
            );
        }
    }
}