// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@voltz-protocol/core/src/interfaces/ICollateralModule.sol";
import "@voltz-protocol/core/src/interfaces/IPermitModule.sol";
import "../storage/Config.sol";

/**
 * @title Perform withdrawals and deposits to and from the v2 collateral module
 */
library V2Core {
    function deposit(address depositFrom, uint128 accountId, address collateralType, uint256 tokenAmount) internal {
        ICollateralModule(Config.load().VOLTZ_V2_CORE_PROXY).deposit(depositFrom, accountId, collateralType, tokenAmount);
    }

    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) internal {
        ICollateralModule(Config.load().VOLTZ_V2_CORE_PROXY).withdraw(accountId, collateralType, tokenAmount);
    }

    function permit(
        uint128 accountId,
        uint256 nonce,
        address spender,
        bytes calldata encodedCommand,
        bytes calldata signature
    ) internal {
        IPermitModule(Config.load().VOLTZ_V2_CORE_PROXY).permit(accountId, nonce, spender, encodedCommand, signature);
    }
}
