pragma solidity >=0.8.19;

import "./Account.sol";
import "@voltz-protocol/util-contracts/src/signature/SignatureVerification.sol";
import "@voltz-protocol/util-contracts/src/signature/EIP712.sol";

/**
 * @title Object for tracking an accounts permissions based on one time permits.
 */

library Permit {
    using SignatureVerification for bytes;
    using Permit for Permit.Data;

    error InvalidPermit();
    error InvalidNonce(uint128 accountId, uint256 currentNonce, uint256 givenNonce);

    /**
     * @notice Permissioned commands code  
     * @dev Command Types. Maximum supported command at this moment is 0x3f.
     */
    uint256 public constant V2_CORE_DEPOSIT = 0x00;
    uint256 public constant V2_CORE_WITHDRAW = 0x01;
    uint256 public constant V2_INSTRUMENT_CLOSE_ACCOUNT = 0x02;
    uint256 public constant V2_INSTRUMENT_SETTLE = 0x03;
    uint256 public constant V2_CORE_CREATE_ACCOUNT = 0x04;
    uint256 public constant V2_INSTRUMENT_TAKER_ORDER = 0x05;

    bytes32 public constant _ALLOWANCE_HASH =
        keccak256("PackedAllowance(bytes encodedCommand,uint48 expiration,address spender,uint128 accountId,uint256 nonce)");

    /// @notice The saved permissions
    /// @dev This info is saved per owner, per token, per spender and all signed over in the permit message
    /// @dev Setting amount to type(uint160).max sets an unlimited approval
    struct PackedAllowance {
        // encoded imputs of the command alongsinde the command code
        bytes encodedCommand;
        /// @dev ensures the permission is used in the same tx
        uint48 expiration;
        address spender;
        uint128 accountId;
    }

    struct Data {
        /// note: this mappring can be singular (one at the time) as it's removed after being used in the same tx
        /// @dev Indexed in the order of account Id, spender address, alowence details
        /// @dev The stored word saves the allowed amount, expiration on the allowance, and nonce
        mapping(uint128 => PackedAllowance) allowance;

        /// @dev account Id permission nonce to prevent reusing signature
        mapping(uint128 => uint256) nonce;
    }

    /**
     * @dev Returns the permit details  stored.
     */
    function load() internal pure returns (Data storage permitData) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.Permit"));
        assembly {
            permitData.slot := s
        }
    }

    /**
     * @dev Reverts if the specified permission is unknown to the account RBAC system.
     * used by swap function to check if msg.sender is allowed to interact with contract
     */
    function isPermissionValid(Data storage self, PackedAllowance memory _permit) internal view returns (bool) {
        PackedAllowance memory allowance = self.allowance[_permit.accountId];
        if (
            allowance.spender != _permit.spender ||
            allowance.expiration != block.timestamp ||
            _permit.expiration != block.timestamp ||
            keccak256(allowance.encodedCommand) != keccak256(_permit.encodedCommand) ||
            allowance.accountId != _permit.accountId
        ) {
            return false;
        }
        return true;
    }

    function validatePermit(
        Data storage self,
        bytes memory encodedCommand,
        uint128 accountId,
        address sender
    ) internal returns (bool) {
        PackedAllowance memory allowance = PackedAllowance({
                encodedCommand: encodedCommand, 
                expiration: uint48(block.timestamp),
                spender: sender,
                accountId: accountId
        });
        bool valid = self.isPermissionValid(allowance);
        if (valid) {
            // cancel allowance
            delete self.allowance[accountId];
        }
        return valid;
    }

    function onlyPermit(Data storage self, bytes memory encodedCommand, uint128 accountId) internal {
        if (!self.validatePermit(encodedCommand, accountId, msg.sender)) {
            revert InvalidPermit();
        }
    }

    /**
     * @dev Gives permit
     */
    function permit(Data storage self, PackedAllowance memory allowanceDetails, uint256 nonce, bytes calldata signature) internal {
        uint128 accountId = allowanceDetails.accountId;

        // note prevents reusing signatures as nonce is part of signature
        if (nonce != self.nonce[accountId] + 1) {
            revert InvalidNonce(accountId, self.nonce[accountId], nonce);
        }

        // Verify the signer address from the signature.
        address owner = Account.load(accountId).rbac.owner; // accountId specified must be owned by the signer
        signature.verify(EIP712._hashTypedData(hash(allowanceDetails, nonce)), owner);

        // note limits spender approval to 1 single command and single spender at a time
        allowanceDetails.expiration = uint48(block.timestamp);
        self.allowance[accountId] = allowanceDetails;
        self.nonce[accountId] = nonce;
    }

    function hash(PackedAllowance memory allowanceDetails, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            _ALLOWANCE_HASH,
            allowanceDetails.encodedCommand,
            allowanceDetails.expiration,
            allowanceDetails.spender,
            allowanceDetails.accountId,
            nonce
        ));
    }
}
