/*
Licensed under the Voltz v2 License (the "License"); you 
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/core/LICENSE
*/
pragma solidity >=0.8.19;

import "../interfaces/ICollateralModule.sol";
import "../storage/Account.sol";
import "../storage/CollateralConfiguration.sol";
import "@voltz-protocol/util-contracts/src/token/ERC20Helper.sol";
import "../storage/Collateral.sol";
import "@voltz-protocol/util-modules/src/storage/FeatureFlag.sol";

/**
 * @title Module for managing user collateral.
 * @dev See ICollateralModule.
 */
contract CollateralModule is ICollateralModule {
    using ERC20Helper for address;
    using CollateralConfiguration for CollateralConfiguration.Data;
    using Account for Account.Data;
    using AccountRBAC for AccountRBAC.Data;
    using Collateral for Collateral.Data;
    using SafeCastI256 for int256;
    using SafeCastU256 for uint256;

    bytes32 private constant _GLOBAL_FEATURE_FLAG = "global";

    /**
     * @inheritdoc ICollateralModule
     */
    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) external override {
        FeatureFlag.ensureAccessToFeature(_GLOBAL_FEATURE_FLAG);
        CollateralConfiguration.collateralEnabled(collateralType);
        Account.Data storage account = Account.exists(accountId);
        address depositFrom = msg.sender;
        address self = address(this);

        uint256 allowance = IERC20(collateralType).allowance(depositFrom, self);
        if (allowance < tokenAmount) {
            revert IERC20.InsufficientAllowance(tokenAmount, allowance);
        }

        uint256 currentBalance = IERC20(collateralType).balanceOf(self);
        uint256 collateralCap = CollateralConfiguration.load(collateralType).cap;
        if (collateralCap < currentBalance + tokenAmount) {
            revert CollateralCapExceeded(
                collateralType, collateralCap, currentBalance, tokenAmount
            );
        }

        collateralType.safeTransferFrom(depositFrom, self, tokenAmount);

        account.collaterals[collateralType].increaseCollateralBalance(tokenAmount);
        emit Collateral.CollateralUpdate(accountId, collateralType, tokenAmount.toInt(), block.timestamp);

        emit Deposited(accountId, collateralType, tokenAmount, msg.sender, block.timestamp);
    }

    /**
     * @inheritdoc ICollateralModule
     */
    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) external override {
        FeatureFlag.ensureAccessToFeature(_GLOBAL_FEATURE_FLAG);
        Account.Data storage account =
            Account.loadAccountAndValidatePermission(accountId, AccountRBAC._ADMIN_PERMISSION, msg.sender);

        uint256 collateralBalance = account.collaterals[collateralType].balance;
        if (tokenAmount > collateralBalance) {
            account.collaterals[collateralType].decreaseCollateralBalance(collateralBalance);
            emit Collateral.CollateralUpdate(accountId, collateralType, -collateralBalance.toInt(), block.timestamp);
        } else {
            account.collaterals[collateralType].decreaseCollateralBalance(tokenAmount);
            emit Collateral.CollateralUpdate(accountId, collateralType, -tokenAmount.toInt(), block.timestamp);
        }

        account.imCheck(collateralType);

        collateralType.safeTransfer(msg.sender, tokenAmount);

        emit Withdrawn(accountId, collateralType, tokenAmount, msg.sender, block.timestamp);
    }

    /**
     * @inheritdoc ICollateralModule
     */
    function getAccountCollateralBalance(uint128 accountId, address collateralType)
        external
        view
        override
        returns (uint256 collateralBalance)
    {
        return Account.load(accountId).getCollateralBalance(collateralType);
    }

    /**
     * @inheritdoc ICollateralModule
     */
    function getAccountCollateralBalanceAvailable(uint128 accountId, address collateralType)
        external
        override
        view
        returns (uint256 collateralBalanceAvailable)
    {
        return Account.load(accountId).getCollateralBalanceAvailable(collateralType);
    }


}
