pragma solidity >=0.8.19;

import "oz/token/ERC721/ERC721.sol";
import "oz/token/ERC721/extensions/ERC721URIStorage.sol";
import "oz/utils/Strings.sol";
import "oz/utils/cryptography/MerkleProof.sol";
import "oz/utils/Counters.sol";
import "oz/access/Ownable.sol";
import "forge-std/console.sol";

// todo: rename variables post refactor

contract AccessPassNFT is Ownable, ERC721URIStorage {

    /// @dev mapping used to track whitelisted merkle roots
    mapping(bytes32 => string) public rootData;

    // the root used to claim a given token ID. Required to get the base URI.
    mapping(uint256 => bytes32) public tokenData;

    /// @notice tracks the number of minted access passes
    using Counters for Counters.Counter;
    Counters.Counter private _tokenSupply;

    /** @notice Information needed for the NewValidRoot event.
     */
    struct RootInfo {
        bytes32 merkleRoot;
        string baseMetadataURI; // The folder URI from which individual token URIs can be derived. Must therefore end with a slash.
    }

    event RedeemAccessPassNFT(address account, uint256 tokenId);
    event NewValidRoot(RootInfo rootInfo);
    event InvalidatedRoot(bytes32 merkleRoot);

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    /** @notice Registers a new root as being valid. This allows it to be used in access pass verifications.
     * @dev Apart from the root and the URI, the input values are only used for logging
     */
    function addNewRoot(RootInfo memory rootInfo) public onlyOwner {
        require(
            bytes(rootInfo.baseMetadataURI).length > 0,
            "cannot set empty root URI"
        );
        require(
            bytes(rootData[rootInfo.merkleRoot]).length == 0,
            "cannot overwrite non-empty URI"
        );
        rootData[rootInfo.merkleRoot] = rootInfo.baseMetadataURI;
        emit NewValidRoot(rootInfo);
    }

    /** @notice Removes a root from whitelist. It can no longer be used for access pass validations.
     * @notice This should only be used in case a faulty root was submitted.
     * @notice If a user already redeemed an access pass based on the faulty root,
     * the badge cannot be burnt.
     */
    function deleteRoot(bytes32 merkleRoot) public onlyOwner {
        delete rootData[merkleRoot];
        emit InvalidatedRoot(merkleRoot);
    }

    /** @notice Total supply getter. Returns the total number of minted access passes so far.
     */
    function totalSupply() public view returns (uint256) {
        return _tokenSupply.current();
    }

    /** @notice Total supply getter. Returns the total number of minted access passes so far.
     * @param account: user's address
     * @param merkleRoot: merkle root associated with this badge
     * @param accessPassId: access pass ID
     */
    function getTokenIdHash(
        address account,
        bytes32 merkleRoot,
        uint96 accessPassId
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(account, merkleRoot, accessPassId));
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721URIStorage) returns (string memory) {
        string memory rootURI = rootData[tokenData[tokenId]];
        return
        string(
            abi.encodePacked(
                rootURI,
                ".json"
            )
        );
    }


    /** @notice Total supply getter. Returns the total number of minted badges so far.
     * @param account: merkle tree leaf account address
     * @param proof: merkle tree proof of the leaf
     * @param merkleRoot: merkle tree root based on which the proof is verified
     */
    function redeem(
        address account,
        bytes32[] calldata proof,
        bytes32 merkleRoot
    ) public returns (uint256) {
        require(
            _verify(_leaf(account), proof, merkleRoot),
            "Invalid Merkle proof"
        );

        bytes32 tokenIdHash = getTokenIdHash(
            account,
            merkleRoot
        );
        uint256 tokenId = uint256(tokenIdHash);
//        console.log(tokenId);

        _tokenSupply.increment();
        _safeMint(account, tokenId);

        tokenData[tokenId] = merkleRoot;

        emit RedeemAccessPassNFT(account, tokenId);

        return tokenId;
    }

    /** @notice Supports redemption of multiple access passes in one transaction
     * @dev Each claim must present its own root and a full proof, even if this involves duplication
     * @param account is the address of the user
     * @param proofs are the one bytes32[] proofs for each leaf
     * @param merkleRoots the merkel roots - one bytes32 for each leaf
     */
    function multiRedeem(
        address account,
        bytes32[][] calldata proofs,
        bytes32[] memory merkleRoots
    ) public returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](proofs.length);

        for (uint256 i = 0; i < proofs.length; i++) {
            tokenIds[i] = redeem(account, proofs[i], merkleRoots[i]);
        }
        return tokenIds;
    }

    /** @notice Encoded the leaf information
     * @param account: account address
     */
    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    /** @notice Verification that the hash of the actor address and information
     * is correctly stored in the Merkle tree i.e. the proof is validated
     */
    function _verify(
        bytes32 encodedLeaf,
        bytes32[] memory proof,
        bytes32 merkleRoot
    ) internal view returns (bool) {
        require(bytes(rootData[merkleRoot]).length > 0, "Unrecognised merkle root");
        return MerkleProof.verify(proof, merkleRoot, encodedLeaf);
    }
}

