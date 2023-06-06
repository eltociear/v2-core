pragma solidity >=0.8.19;

import "../storage/Permit.sol";

/**
 * @title Permit Module Interface.
 * @notice Manages the permit system for middle-man. Allows signing permits and retreiving signature nonces.
 */
interface IPermitModule {

    /**
     * @notice Grants permission to spender to execute specific command once in the same tx
     * for account accountId.
     * @param accountId Account for which the permit applies to.
     * @param nonce Signature nonce of account id.
     * @param spender Address of permit spender.
     * @param encodedCommand Bytes encoding of permitted command and inputs.
     * @param signature Signed permit (by account owner)
     *
     * Requirements:
     *
     * - accountId owner must own the account to give permission
     */
    function permit(
        uint128 accountId,
        uint256 nonce,
        address spender,
        bytes calldata encodedCommand,
        bytes calldata signature
    ) external;

    /**
     * @notice Retreives account permission nonce.
     * @param accountId Account for which to retreive nonce.
     */
    function getAccountNonce(uint128 accountId) external returns (uint256 nonce);
}
