//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../src/modules/ProductModule.sol";
import "../test-utils/MockCoreStorage.sol";

contract EnhancedProductModule is ProductModule, CoreState {
  function _distributeFees(
      uint128 payingAccountId, uint128 receivingAccountId, UD60x18 atomicFee, 
      address collateralType, int256 annualizedNotional
  ) public returns (uint256 fee) {
    return distributeFees(payingAccountId, receivingAccountId, atomicFee, collateralType, annualizedNotional);
  }

  function configureNewProductAndMarket(string memory productName, UD60x18 atomicMakerFee, UD60x18 atomicTakerFee) 
    public returns (uint128 productId, uint128 marketId) 
  {
    products.push(new MockProduct(productName));
    productId = mockProduct(address(products[products.length-1]), productName, Constants.PRODUCT_OWNER);
    marketId = productId * 10;
    MarketFeeConfiguration.set(
      MarketFeeConfiguration.Data({
        productId: productId, marketId: productId * 10, feeCollectorAccountId: 999, 
        atomicMakerFee: atomicMakerFee, atomicTakerFee: atomicTakerFee
    }));
  }
}

contract ProductModuleTest is Test {
  event ProductRegistered(address indexed product, uint128 indexed productId, address indexed sender);

  EnhancedProductModule internal productModule;

  function setUp() public {
      productModule = new EnhancedProductModule();
  }

  function test_GetAccountUnrealizedPnL() public {
    assertEq(productModule.getAccountUnrealizedPnL(1, 100, Constants.TOKEN_0), 100e18);
  }

  function test_GetAccountAnnualizedExposures() public {
    Account.Exposure[] memory exposures = productModule.getAccountAnnualizedExposures(1, 100, Constants.TOKEN_0);
    
    assertEq(exposures.length, 2);

    assertEq(exposures[0].marketId, 10);
    assertEq(exposures[0].filled, 100e18);
    assertEq(exposures[0].unfilledLong, 200e18);
    assertEq(exposures[0].unfilledShort, 200e18);

    assertEq(exposures[1].marketId, 11);
    assertEq(exposures[1].filled, 200e18);
    assertEq(exposures[1].unfilledLong, 300e18);
    assertEq(exposures[1].unfilledShort, 400e18);
  }

  function test_RegisterProduct() public {
    MockProduct product3 = new MockProduct("Product 3");

    vm.prank(Constants.PRODUCT_CREATOR);

    vm.expectEmit(true, true, true, true, address(productModule));
    emit ProductRegistered(address(product3), 3, Constants.PRODUCT_CREATOR);

    productModule.registerProduct(address(product3), "Product 3");
  }

  function test_revertWhen_RegisterProduct_NoPermission() public {
    MockProduct product3 = new MockProduct("Product 3");

    vm.expectRevert(abi.encodeWithSelector(FeatureFlag.FeatureUnavailable.selector, bytes32("registerProduct")));
    productModule.registerProduct(address(product3), "Product 3");
  }

  function test_revertWhen_RegisterProduct_NoInterfaceSupport() public {
    vm.prank(Constants.PRODUCT_CREATOR);
    vm.expectRevert(abi.encodeWithSelector(IProductModule.IncorrectProductInterface.selector, address(232323)));
    productModule.registerProduct(address(232323), "Product 3");
  }

  function test_CloseAccount() public {
    Account.Exposure[] memory emptyExposures;
    productModule.getProducts()[0].mockGetAccountAnnualizedExposures(100, Constants.TOKEN_0, emptyExposures);

    Account.Exposure[] memory exposuresBefore = productModule.getProducts()[0].getAccountAnnualizedExposures(100, Constants.TOKEN_0);
    assertEq(exposuresBefore.length, 2);

    vm.prank(Constants.ALICE);
    //todo: check event was emitted
    productModule.closeAccount(1, 100, Constants.TOKEN_0);

    Account.Exposure[] memory exposuresAfter = productModule.getProducts()[0].getAccountAnnualizedExposures(100, Constants.TOKEN_0);
    assertEq(exposuresAfter.length, 0);
  }

  function test_revertWhen_CloseAccount_NoPermission() public {
    vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, 100, address(this)));
    productModule.closeAccount(1, 100, Constants.TOKEN_0);
  }

  function test_distributeFees() public {
    uint256 fees = productModule._distributeFees(100, 101, UD60x18.wrap(1e16), Constants.TOKEN_0, 80e18);
    assertEq(fees, 8e17);
    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE - 8e17);
    assertEq(productModule.getCollateralBalance(101, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE + 8e17);

    fees = productModule._distributeFees(101, 100, UD60x18.wrap(1e16), Constants.TOKEN_0, -80e18);
    assertEq(fees, 8e17);
    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE);
    assertEq(productModule.getCollateralBalance(101, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE);
  }

  function test_revertWhen_distributeFees_InsufficientFunds() public {
    vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientCollateral.selector, Constants.DEFAULT_TOKEN_0_BALANCE + 1));
    productModule._distributeFees(100, 101, UD60x18.wrap(1e18), Constants.TOKEN_0, int256(Constants.DEFAULT_TOKEN_0_BALANCE + 1));
  }

  function test_revertWhen_distributeFees_InvalidAccountId() public {
    vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 454545));
    productModule._distributeFees(454545, 101, UD60x18.wrap(1e18), Constants.TOKEN_0, 1);

    vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 454545));
    productModule._distributeFees(100, 454545, UD60x18.wrap(1e18), Constants.TOKEN_0, 1);
  }

  function test_propagateTakerOrder_SameProduct() public {
    //todo: check event emitted once implemented
    assertEq(productModule.getActiveProductsLength(100), 2);
    vm.prank(address(productModule.getProducts()[0]));
    productModule.propagateTakerOrder(100, 1, 10, Constants.TOKEN_0, 100e18);
    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE - 5e18);
    assertEq(productModule.getCollateralBalance(999, Constants.TOKEN_0), 5e18);
    assertEq(productModule.getActiveProductsLength(100), 2);
  }

  function test_propagateTakerOrder_SameProduct_NegativeNotional() public {
    //todo: check event emitted once implemented
    assertEq(productModule.getActiveProductsLength(100), 2);
    vm.prank(address(productModule.getProducts()[0]));
    productModule.propagateTakerOrder(100, 1, 10, Constants.TOKEN_0, -100e18);
    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE - 5e18);
    assertEq(productModule.getCollateralBalance(999, Constants.TOKEN_0), 5e18);
    assertEq(productModule.getActiveProductsLength(100), 2);
  }

  function test_propagateTakerOrder_NewProduct() public {
    (uint128 productId, uint128 marketId) = productModule.configureNewProductAndMarket(
      "Product3", UD60x18.wrap(2e16), UD60x18.wrap(25e15)
    );
    
    //todo: check event emitted once implemented
    assertEq(productModule.getActiveProductsLength(100), 2);

    vm.prank(address(productModule.getProducts()[productModule.getProducts().length-1]));
    productModule.propagateTakerOrder(100, productId, marketId, Constants.TOKEN_0, 100e18);

    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE - 25e17);
    assertEq(productModule.getCollateralBalance(999, Constants.TOKEN_0), 25e17);

    assertEq(productModule.getActiveProductsLength(100), 3);
    assertEq(productModule.getActiveProduct(100, productModule.getActiveProductsLength(100)), productId);
  }

  function test_revertWhen_propagateTakerOrder_NotProduct() public {
    vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, address(this)));
    productModule.propagateTakerOrder(100, 1, 10, Constants.TOKEN_0, 100e18);
  }

  function test_revertWhen_propagateTakerOrder_InvalidAccountId() public {
    vm.prank(address(productModule.getProducts()[0]));
    vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 454545));
    productModule.propagateTakerOrder(454545, 1, 10, Constants.TOKEN_0, 1);
  }

  function test_revertWhen_propagateTakerOrder_InsufficientFunds() public {
    vm.prank(address(productModule.getProducts()[0]));
    vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientCollateral.selector, Constants.DEFAULT_TOKEN_0_BALANCE + 1));
    productModule.propagateTakerOrder(100, 1, 10, Constants.TOKEN_0, int256(20 * (Constants.DEFAULT_TOKEN_0_BALANCE + 1)));
  }

  function test_revertWhen_propagateTakerOrder_ImCheck() public {
    uint256 uPnL = 100e18;
    uint256 im = 1800e18;

    vm.prank(address(productModule.getProducts()[0]));
    vm.expectRevert(abi.encodeWithSelector(Account.AccountBelowIM.selector, 100));
    productModule.propagateTakerOrder(
      100, 1, 10, Constants.TOKEN_0, int256(20 * (Constants.DEFAULT_TOKEN_0_BALANCE - im - uPnL) + 1e18)
    );
  }

  function test_propagateMakerOrder() public {
    //todo: check event emitted once implemented
    assertEq(productModule.getActiveProductsLength(100), 2);
    vm.prank(address(productModule.getProducts()[0]));
    productModule.propagateMakerOrder(100, 1, 10, Constants.TOKEN_0, 100e18);
    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE - 1e18);
    assertEq(productModule.getCollateralBalance(999, Constants.TOKEN_0), 1e18);
    assertEq(productModule.getActiveProductsLength(100), 2);
  }

  function test_propagateMakerOrder_NegativeNotional() public {
    //todo: check event emitted once implemented
    assertEq(productModule.getActiveProductsLength(100), 2);
    vm.prank(address(productModule.getProducts()[0]));
    productModule.propagateMakerOrder(100, 1, 10, Constants.TOKEN_0, -100e18);
    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE - 1e18);
    assertEq(productModule.getCollateralBalance(999, Constants.TOKEN_0), 1e18);
    assertEq(productModule.getActiveProductsLength(100), 2);
  }

  function test_propagateMakerOrder_NewProduct() public {
    (uint128 productId, uint128 marketId) = productModule.configureNewProductAndMarket(
      "Product3", UD60x18.wrap(2e16), UD60x18.wrap(25e15)
    );
    
    //todo: check event emitted once implemented
    assertEq(productModule.getActiveProductsLength(100), 2);

    vm.prank(address(productModule.getProducts()[productModule.getProducts().length-1]));
    productModule.propagateMakerOrder(100, productId, marketId, Constants.TOKEN_0, 100e18);

    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE - 2e18);
    assertEq(productModule.getCollateralBalance(999, Constants.TOKEN_0), 2e18);

    assertEq(productModule.getActiveProductsLength(100), 3);
    assertEq(productModule.getActiveProduct(100, productModule.getActiveProductsLength(100)), productId);
  }

  function test_revertWhen_propagateMakerOrder_NotProduct() public {
    vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, address(this)));
    productModule.propagateMakerOrder(100, 1, 10, Constants.TOKEN_0, 100e18);
  }

  function test_revertWhen_propagateMakerOrder_InvalidAccountId() public {
    vm.prank(address(productModule.getProducts()[0]));
    vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 454545));
    productModule.propagateMakerOrder(454545, 1, 10, Constants.TOKEN_0, 1);
  }

  function test_revertWhen_propagateMakerOrder_ImCheck() public {
    uint256 uPnL = 100e18;
    uint256 im = 1800e18;

    vm.prank(address(productModule.getProducts()[0]));
    vm.expectRevert(abi.encodeWithSelector(Account.AccountBelowIM.selector, 100));
    productModule.propagateMakerOrder(
      100, 1, 10, Constants.TOKEN_0, int256(100 * (Constants.DEFAULT_TOKEN_0_BALANCE - im - uPnL) + 1e18)
    );
  }

  function test_revertWhen_propagateMakerOrder_InsufficientFunds() public {
    vm.prank(address(productModule.getProducts()[0]));
    vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientCollateral.selector, Constants.DEFAULT_TOKEN_0_BALANCE + 1));
    productModule.propagateMakerOrder(100, 1, 10, Constants.TOKEN_0, int256(100 * (Constants.DEFAULT_TOKEN_0_BALANCE + 1)));
  }

  function test_propagateCashflow() public {
    //todo: event
    vm.prank(address(productModule.getProducts()[0]));
    productModule.propagateCashflow(100, 1, Constants.TOKEN_0, 123e18);
    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE + 123e18);

    vm.prank(address(productModule.getProducts()[0]));
    productModule.propagateCashflow(100, 1, Constants.TOKEN_0, -120e18);
    assertEq(productModule.getCollateralBalance(100, Constants.TOKEN_0), Constants.DEFAULT_TOKEN_0_BALANCE + 3e18);
  }

  function test_revertWhen_propagateCashflow_InsufficientFunds() public {
    vm.prank(address(productModule.getProducts()[0]));
    vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientCollateral.selector, Constants.DEFAULT_TOKEN_0_BALANCE + 1));
    productModule.propagateCashflow(100, 1, Constants.TOKEN_0, -int256(Constants.DEFAULT_TOKEN_0_BALANCE+1));
  }

  function test_revertWhen_propagateCashflow_NotProduct() public {
    vm.expectRevert(abi.encodeWithSelector(AccessError.Unauthorized.selector, address(this)));
    productModule.propagateCashflow(100, 1, Constants.TOKEN_0, 1);
  }

  function test_revertWhen_propagateCashflow_InvalidAccountId() public {
    vm.prank(address(productModule.getProducts()[0]));
    vm.expectRevert(abi.encodeWithSelector(Account.AccountNotFound.selector, 454545));
    productModule.propagateCashflow(454545, 1, Constants.TOKEN_0, 1);
  }

  // todo: see if imcheck is needed in propagate cashflow
  // function test_revertWhen_propagateCashflow_ImCheck() public {
  //   uint256 uPnL = 100e18;
  //   uint256 im = 1800e18;

  //   vm.prank(address(productModule.getProducts()[0]));
  //   vm.expectRevert(abi.encodeWithSelector(Account.AccountBelowIM.selector, 100));
  //   productModule.propagateCashflow(100, 1, Constants.TOKEN_0, -int256(Constants.DEFAULT_TOKEN_0_BALANCE - im - uPnL + 1));
  // }
}