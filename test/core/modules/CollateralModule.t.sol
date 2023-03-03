//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "../../../src/core/modules/CollateralModule.sol";
import "../test-utils/MockCore.sol";

contract EnhancedCollateralModule is CollateralModule, MockCoreState {}

contract CollateralModuleTest is Test {
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;

    event Deposited(uint128 indexed accountId, address indexed collateralType, uint256 tokenAmount, address indexed sender);
    event Withdrawn(uint128 indexed accountId, address indexed collateralType, uint256 tokenAmount, address indexed sender);

    EnhancedCollateralModule internal collateralModule;

    function setUp() public {
        collateralModule = new EnhancedCollateralModule();
    }

    function test_GetAccountCollateralBalance() public {
        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0), 
            Constants.DEFAULT_TOKEN_0_BALANCE
        );
    }

    function test_GetAccountCollateralBalance_NoSettlementToken() public {
        assertEq(
            collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_1), 
            Constants.DEFAULT_TOKEN_1_BALANCE
        );
    }

    function test_GetTotalAccountValue() public {
        int256 uPnL = 100e18;
        assertEq(
            collateralModule.getTotalAccountValue(100), 
            Constants.DEFAULT_TOKEN_0_BALANCE.toInt() - uPnL
        );
    }

    function test_GetAccountCollateralBalanceAvailable() public { 
        uint256 uPnL = 100e18;
        uint256 im = 1800e18;

        assertEq(
            collateralModule.getAccountCollateralBalanceAvailable(100, Constants.TOKEN_0), 
            Constants.DEFAULT_TOKEN_0_BALANCE - uPnL - im
        );
    }

    function test_GetAccountCollateralBalanceAvailable_NoSettlementToken() public {
        assertEq(
            collateralModule.getAccountCollateralBalanceAvailable(100, Constants.TOKEN_1), 
            Constants.DEFAULT_TOKEN_1_BALANCE
        );
    }

    function testFuzz_GetAccountCollateralBalanceAvailable_OtherToken(address otherToken) public {
        vm.assume(otherToken != Constants.TOKEN_0);
        vm.assume(otherToken != Constants.TOKEN_1);

        assertEq(collateralModule.getAccountCollateralBalanceAvailable(100, otherToken), 0);
    }

    function testFuzz_Deposit(address depositor) public {
        uint256 amount = 500e18;

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(amount)
        );

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, collateralModule, amount),
            abi.encode()
        );

        vm.prank(depositor);

        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Deposited(100, Constants.TOKEN_0, amount, depositor);

        collateralModule.deposit(100, Constants.TOKEN_0, amount);

        uint256 collateralBalance = collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0);
        
        assertEq(collateralBalance, Constants.DEFAULT_TOKEN_0_BALANCE + amount);
    }

    function testFuzz_revertWhen_Deposit_WithNotEnoughAllowance(address depositor) public {
        uint256 amount = 500e18;

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.allowance.selector, depositor, collateralModule),
            abi.encode(0)
        );

        vm.expectRevert(abi.encodeWithSelector(IERC20.InsufficientAllowance.selector, amount, 0));
        vm.prank(depositor);
        collateralModule.deposit(100, Constants.TOKEN_0, amount);
    }

    function testFuzz_revertWhen_Deposit_WithCollateralTypeNotEnabled(address depositor) public {
        uint256 amount = 500e18;

        vm.expectRevert(abi.encodeWithSelector(CollateralConfiguration.CollateralDepositDisabled.selector, Constants.TOKEN_1));
        vm.prank(depositor);
        collateralModule.deposit(100, Constants.TOKEN_1, amount);
    }

    function test_Withdraw() public {
        uint256 amount = 500e18;

        vm.mockCall(
            Constants.TOKEN_0,
            abi.encodeWithSelector(IERC20.transfer.selector, Constants.ALICE, amount),
            abi.encode()
        );

        vm.expectEmit(true, true, true, true, address(collateralModule));
        emit Withdrawn(100, Constants.TOKEN_0, amount, Constants.ALICE);

        vm.prank(Constants.ALICE);

        collateralModule.withdraw(100, Constants.TOKEN_0, amount);

        uint256 collateralBalance = collateralModule.getAccountCollateralBalance(100, Constants.TOKEN_0);
        
        assertEq(collateralBalance, Constants.DEFAULT_TOKEN_0_BALANCE - amount);
    }

    function test_revertWhen_Withdraw_UnautohorizedAccount(address otherAddress) public {
        vm.assume(otherAddress != Constants.ALICE);

        uint256 amount = 500e18;

        vm.expectRevert(abi.encodeWithSelector(Account.PermissionDenied.selector, 100, otherAddress));
        vm.prank(otherAddress);
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);
    }

    function test_revertWhen_Withdraw_MoreThanBalance() public {
        uint256 amount = 10500e18;

        vm.prank(Constants.ALICE);
        vm.expectRevert(abi.encodeWithSelector(Collateral.InsufficientCollateral.selector, amount));
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);
    }

    function test_revertWhen_Withdraw_WhenIMNoLongerSatisfied() public {
        uint256 amount = 9500e18;

        vm.prank(Constants.ALICE);
        vm.expectRevert(abi.encodeWithSelector(Account.AccountBelowIM.selector, 100));
        collateralModule.withdraw(100, Constants.TOKEN_0, amount);
    }
}
