// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@voltz-protocol/core/src/interfaces/ICollateralModule.sol";
import "@voltz-protocol/core/src/interfaces/IAccountModule.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC721.sol";
import "../storage/Config.sol";
import "./Payments.sol";

/**
 * @title Perform withdrawals and deposits to and from the v2 collateral module
 */
library V2Core {
    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) internal {
        Payments.approveERC20Core(collateralType, tokenAmount);
        ICollateralModule(Config.load().VOLTZ_V2_CORE_PROXY).deposit(accountId, collateralType, tokenAmount);
    }

    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) internal {
        ICollateralModule(Config.load().VOLTZ_V2_CORE_PROXY).withdraw(accountId, collateralType, tokenAmount);
        Payments.pay(collateralType, msg.sender, tokenAmount);
    }

    function createAccount(uint128 requestedId) internal {
        address coreProxy = Config.load().VOLTZ_V2_CORE_PROXY;
        IAccountModule(coreProxy).createAccount(requestedId);
        IERC721(coreProxy).safeTransferFrom(address(this), msg.sender, requestedId);
    }
}
