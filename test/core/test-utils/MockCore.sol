//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./MockAccount.sol";
import "./MockProduct.sol";
import "./Constants.sol";
import "../../../src/core/storage/MarketRiskConfiguration.sol";
import "forge-std/Test.sol";

contract MockCore is MockAccount, MockProduct { }

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
 * @dev Market risk configurations:
 *        - - productId: 1
 *          - marketId: 10
 *          - riskParameter: 1
 *
 *        - - productId: 1
 *          - marketId: 11
 *          - riskParameter: 1
 *
 *        - - productId: 2
 *          - marketId: 20
 *          - riskParameter: 1
 * @dev Accounts:
 *        - Alice:
 *          - id: 100
 *          - owner: ALICE
 *          - default balances: (TOKEN_0, 1000), (TOKEN_1, 1000)
 *          - product IDs: 1, 2
 *          - settlement token: TOKEN_0
 *
 *          - mocked exposures: 
 *            - (productId: 1, marketId: 10): 
 *              - filled: 100
 *              - unfilled long: 200
 *              - unfilled short: -200
 *
 *            - (productId: 1, marketId: 11): 
 *              - filled: 200
 *              - unfilled long: 300
 *              - unfilled short: -400
 *
 *            - (productId: 2, marketId: 20): 
 *              - filled: -50
 *              - unfilled long: 150
 *              - unfilled short: -150
 * 
 *          - margin requirements: (im, 1800), (lm, 900)
 *
 *          - mocked uPnLs: 
 *            - (productId: 1) : 100
 *            - (productId: 1) : -200
 * @dev Protocol risk configurations:
 *        - im multiplier: 2
 *        - liquidator reward: 0
 *
 */
contract MockCoreState is MockCore, Test {
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
            balances[0] = CollateralBalance({ token: Constants.TOKEN_0, balanceD18: 1000e18 });

            balances[1] = CollateralBalance({ token: Constants.TOKEN_1, balanceD18: 1000e18 });

            uint128[] memory activeProductIds = new uint128[](2);
            activeProductIds[0] = 1;
            activeProductIds[1] = 2;

            mockAccount(100, Constants.ALICE, balances, activeProductIds, Constants.TOKEN_0);
        }

        // Mock Calls to Product Smart Contracts regarding Alice account
        mockAliceCalls();

        // Set market risk configuration
        MarketRiskConfiguration.set(MarketRiskConfiguration.Data({ productId: 1, marketId: 10, riskParameter: 1e18 }));

        // Set market risk configuration
        MarketRiskConfiguration.set(MarketRiskConfiguration.Data({ productId: 1, marketId: 11, riskParameter: 1e18 }));

        // Set market risk configuration
        MarketRiskConfiguration.set(MarketRiskConfiguration.Data({ productId: 2, marketId: 20, riskParameter: 1e18 }));

        // Set protocol risk configuration
        ProtocolRiskConfiguration.set(ProtocolRiskConfiguration.Data({ imMultiplier: 2e18, liquidatorRewardParameter: 0 }));
    }

    function mockAliceCalls() internal {
        // Mock account (id:100) exposures to product (id:1) and markets (ids: 10, 11)
        {
            Account.Exposure[] memory mockExposures = new Account.Exposure[](2);

            mockExposures[0] = Account.Exposure({
                marketId: 10, 
                filled: 100e18, 
                unfilledLong: 200e18, 
                unfilledShort: -200e18 
            });

            mockExposures[1] = Account.Exposure({ 
                marketId: 11, 
                filled: 200e18, 
                unfilledLong: 300e18, 
                unfilledShort: -400e18 
            });

            vm.mockCall(
                Constants.PRODUCT_ADDRESS_1,
                abi.encodeWithSelector(IProduct.getAccountAnnualizedExposures.selector, 100),
                abi.encode(mockExposures)
            );
        }
        
        // Mock account (id: 100) account closure to product (id: 1)
        {
            vm.mockCall(
                Constants.PRODUCT_ADDRESS_1, 
                abi.encodeWithSelector(IProduct.closeAccount.selector, 100), 
                abi.encode()
            );
        }

        // Mock account (id: 100) unrealized PnL in product (id: 1)
        {
            vm.mockCall(
                Constants.PRODUCT_ADDRESS_1, 
                abi.encodeWithSelector(IProduct.getAccountUnrealizedPnL.selector, 100), 
                abi.encode(100e18)
            );
        }

        // Mock account (id:100) exposures to product (id:2) and markets (ids: 20)
        {
            Account.Exposure[] memory mockExposures = new Account.Exposure[](1);

            mockExposures[0] = Account.Exposure({
                marketId: 20, 
                filled: -50e18, 
                unfilledLong: 150e18, 
                unfilledShort: -150e18 
            });

            vm.mockCall(
                Constants.PRODUCT_ADDRESS_2,
                abi.encodeWithSelector(IProduct.getAccountAnnualizedExposures.selector, 100),
                abi.encode(mockExposures)
            );
        }
        
        // Mock account (id: 100) account closure to product (id: 2)
        {
            vm.mockCall(
                Constants.PRODUCT_ADDRESS_2, 
                abi.encodeWithSelector(IProduct.closeAccount.selector, 100), 
                abi.encode()
            );
        }

        // Mock account (id: 100) unrealized PnL in product (id: 2)
        {
            vm.mockCall(
                Constants.PRODUCT_ADDRESS_2, 
                abi.encodeWithSelector(IProduct.getAccountUnrealizedPnL.selector, 100), 
                abi.encode(-200e18)
            );
        }
    }
}
