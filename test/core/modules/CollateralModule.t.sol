//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/modules/CollateralModule.sol";
import "../test-utils/MockCore.sol";

contract EnhancedCollateralModule is CollateralModule, MockCoreState {
    constructor() MockCoreState() {}
}

contract CollateralModuleTest is Test {
    EnhancedCollateralModule internal collateralModule;

    function setUp() public {
        collateralModule = new EnhancedCollateralModule();

        setupProducts();
        setupRiskConfigurations();
        setupProtocolRiskConfigurations();
    }

    function setupProducts() public {
        // Mock Alice's account exposures to product ID 1 and markets IDs 10, 11
        Account.Exposure[] memory mockExposures = new Account.Exposure[](2);
        mockExposures[0] = Account.Exposure({ marketId: 10, filled: 100e18, unfilledLong: 200e18, unfilledShort: -200e18 });

        mockExposures[1] = Account.Exposure({ marketId: 11, filled: 200e18, unfilledLong: 300e18, unfilledShort: -400e18 });

        vm.mockCall(
            Constants.PRODUCT_ADDRESS_1, 
            abi.encodeWithSelector(IProduct.getAccountAnnualizedExposures.selector, 100), 
            abi.encode(mockExposures)
        );

        // Mock account closure to product ID 1
        vm.mockCall(
            Constants.PRODUCT_ADDRESS_1, 
            abi.encodeWithSelector(IProduct.closeAccount.selector, 100), 
            abi.encode()
        );

        // Mock account uPnL in product ID 1
        vm.mockCall(
            Constants.PRODUCT_ADDRESS_1, 
            abi.encodeWithSelector(IProduct.getAccountUnrealizedPnL.selector, 100), 
            abi.encode(100e18)
        );

        // Mock account exposures to product ID 2 and markets IDs 20
        mockExposures = new Account.Exposure[](1);
        mockExposures[0] = Account.Exposure({ marketId: 20, filled: -50e18, unfilledLong: 150e18, unfilledShort: -150e18 });

        vm.mockCall(
            Constants.PRODUCT_ADDRESS_2, 
            abi.encodeWithSelector(IProduct.getAccountAnnualizedExposures.selector, 100), 
            abi.encode(mockExposures)
        );

        // Mock account closure to product ID 2
        vm.mockCall(
            Constants.PRODUCT_ADDRESS_2, 
            abi.encodeWithSelector(IProduct.closeAccount.selector, 100), 
            abi.encode()
        );

        // Mock account uPnL in product ID 2
        vm.mockCall(
            Constants.PRODUCT_ADDRESS_2, 
            abi.encodeWithSelector(IProduct.getAccountUnrealizedPnL.selector, 100), 
            abi.encode(-200e18)
        );
    }

    function setupRiskConfigurations() public {
        // Mock risk parameter for product ID 1 and market ID 10
        bytes32 slot = keccak256(abi.encode("xyz.voltz.MarketRiskConfiguration", 1, 10));
        assembly {
            slot := add(slot, 1)
        }
        vm.store(address(collateralModule), slot, bytes32(abi.encode(1e18)));

        // Mock risk parameter for product ID 1 and market ID 11
        slot = keccak256(abi.encode("xyz.voltz.MarketRiskConfiguration", 1, 11));
        assembly {
            slot := add(slot, 1)
        }
        vm.store(address(collateralModule), slot, bytes32(abi.encode(1e18)));

        // Mock risk parameter for product ID 2 and market ID 20
        slot = keccak256(abi.encode("xyz.voltz.MarketRiskConfiguration", 2, 20));
        assembly {
            slot := add(slot, 1)
        }
        vm.store(address(collateralModule), slot, bytes32(abi.encode(1e18)));
    }

    function setupProtocolRiskConfigurations() public {
        bytes32 slot = keccak256(abi.encode("xyz.voltz.ProtocolRiskConfiguration"));
        vm.store(address(collateralModule), slot, bytes32(abi.encode(2e18)));
    }

    function test_GetAccountCollateralBalance() public {
        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0), 
            350e18
        );

        assertEq(
            collateralModule.getAccountCollateralBalance(101, Constants.TOKEN_1), 
            300e18
        );
    }

    function test_GetTotalAccountValue() public {
        assertEq(
            collateralModule.getTotalAccountValue(100), 
            250e18
        );
    }

    function test_GetAccountCollateralBalanceAvailable() public {}

    function test_GetAccountCollateralBalanceAvailable_OtherToken() public {
        assertEq(
            collateralModule.getAccountCollateralBalanceAvailable(100, Constants.TOKEN_1), 
            100e18
        );
    }
}