// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice EIP712 helpers for permit2
/// @dev Maintains cross-chain replay protection in the event of a fork
/// @dev Reference: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol
library EIP712 {

    bytes32 private constant _HASHED_NAME = keccak256("Permit2");
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice Builds a domain separator using the current chainId and contract address.
    function _buildDomainSeparator(bytes32 typeHash, bytes32 nameHash) public view returns (bytes32) {
        return keccak256(abi.encode(typeHash, nameHash, block.chainid, address(this)));
    }

    /// @notice Creates an EIP-712 typed data hash
    function _hashTypedData(bytes32 dataHash) internal view returns (bytes32) {
        bytes32 domainSeparator = _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME);
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, dataHash));
    }
}
