pragma solidity >=0.8.19;

import "../interfaces/IPermitModule.sol";

/**
 * @title Permit Module.
 * @dev See IPermitModule.
 */
contract PermitModule is IPermitModule {
    using Permit for Permit.Data;

    /**
     * @inheritdoc IPermitModule
     */
    function permit(
        uint128 accountId,
        uint256 nonce,
        address spender,
        bytes calldata encodedCommand,
        bytes calldata signature
    ) external override {
        Permit.PackedAllowance memory allowance = Permit.PackedAllowance({
                encodedCommand: encodedCommand, 
                expiration: uint48(block.timestamp),
                spender: spender,
                accountId: accountId
        });
        Permit.load().permit(allowance, nonce, signature);
    }

    /**
     * @inheritdoc IPermitModule
     */
    function getAccountNonce(uint128 accountId) external override returns (uint256 nonce){
        return Permit.load().nonce[accountId];
    }
}
