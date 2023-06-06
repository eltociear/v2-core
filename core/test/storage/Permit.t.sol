pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/storage/Permit.sol";
import "../../src/storage/Account.sol";
import "../test-utils/MockCoreStorage.sol";

contract ExposedPermit is CoreState, Test {
    using Permit for Permit.Data;

    // Exposed functions
    function load() external pure returns (bytes32 s) {
        Permit.Data storage p = Permit.load();
        assembly {
            s := p.slot
        }
    }

    function getAllowance(uint128 accountId) external view returns (Permit.PackedAllowance memory) {
        Permit.Data storage p = Permit.load();
        return p.allowance[accountId];
    }

    function getNonce(uint128 accountId) external view returns (uint256) {
        Permit.Data storage p = Permit.load();
        return p.nonce[accountId];
    }

    function permit(Permit.PackedAllowance memory allowanceDetails, uint256 nonce, bytes calldata signature) external {
        Permit.load().permit(allowanceDetails, nonce, signature);
    }

    function onlyPermit(bytes memory encodedCommand, uint128 accountId) external returns (uint256) {
        Permit.load().onlyPermit(encodedCommand, accountId);
    }

    function validatePermit(bytes memory encodedCommand, uint128 accountId, address sender) external returns (bool) {
        return Permit.load().validatePermit(encodedCommand, accountId, sender);
    }

    function isPermitValid(Permit.PackedAllowance memory allowanceDetails) external returns (bool) {
        return Permit.load().isPermissionValid(allowanceDetails);
    }

    function getPermitSignature(
        Permit.PackedAllowance memory allowanceDetails,
        uint256 nonce,
        uint256 privateKey
    ) external returns (bytes memory) {
        bytes32 permitHash = keccak256(abi.encode(
            Permit._ALLOWANCE_HASH,
            allowanceDetails.encodedCommand,
            allowanceDetails.expiration,
            allowanceDetails.spender,
            allowanceDetails.accountId,
            nonce
        ));

        bytes32 _HASHED_NAME = keccak256("Permit2");
        bytes32 _TYPE_HASH =
            keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                EIP712._buildDomainSeparator(_TYPE_HASH, _HASHED_NAME),
                permitHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function createAccount(uint128 accountId, address owner) external {
        Account.create(accountId, owner);
    }
}

contract PermitTest is Test {
    using SafeCastU256 for uint256;
    using SafeCastI256 for int256;

    ExposedPermit internal permitContract;

    address internal from;
    uint256 internal fromPrivateKey;

    function setUp() public {
        permitContract = new ExposedPermit();
        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);
    }

    function test_Permit() public {
        uint128 accountId = 100;
        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200);

        permitContract.createAccount(accountId, from);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand:  abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200), 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: accountId
        });

        bytes memory sig = permitContract.getPermitSignature(permit, 1, fromPrivateKey);
        vm.prank(from);
        permitContract.permit(
            permit,
            1,
            sig
        );

        // check if permit was recorded correctly
        Permit.PackedAllowance memory resultingPermit = permitContract.getAllowance(accountId);
        assertEq(resultingPermit.encodedCommand, abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, 100, 1, 12653, 200));
        assertEq(resultingPermit.expiration, uint48(block.timestamp));
        assertEq(resultingPermit.spender, address(this));
        assertEq(resultingPermit.accountId, accountId);
        assertEq(permitContract.getNonce(accountId), 1);
    }

    function test_MultiplePermits() public {
        uint128 accountId = 100;
        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200);

        permitContract.createAccount(accountId, from);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand:  abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200), 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: accountId
        });

        bytes memory sig = permitContract.getPermitSignature(permit, 1, fromPrivateKey);
        vm.prank(from);
        permitContract.permit(
            permit,
            1,
            sig
        );

        // check if permit was recorded correctly
        Permit.PackedAllowance memory resultingPermit = permitContract.getAllowance(accountId);
        assertEq(resultingPermit.encodedCommand, abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, 100, 1, 12653, 200));
        assertEq(resultingPermit.expiration, uint48(block.timestamp));
        assertEq(resultingPermit.spender, address(this));
        assertEq(resultingPermit.accountId, accountId);
        assertEq(permitContract.getNonce(accountId), 1);

        bytes memory sig2 = permitContract.getPermitSignature(permit, 2, fromPrivateKey);
        permitContract.permit(
            permit,
            2,
            sig2
        );
        assertEq(permitContract.getNonce(accountId), 2);
    }

    function test_PermitSentFromNonOwnerAddress() public {
        uint128 accountId = 100;
        permitContract.createAccount(accountId, from);

        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand: encodedCommand, 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: accountId
        });

        bytes memory sig = permitContract.getPermitSignature(permit, 1, fromPrivateKey);
        //bytes memory sigExtra = bytes.concat(sig, bytes1(uint8(1)));
        vm.prank(address(2));
        permitContract.permit(
            permit,
            1,
            sig
        );

        Permit.PackedAllowance memory resultingPermit = permitContract.getAllowance(accountId);
        assertEq(resultingPermit.encodedCommand, abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, 100, 1, 12653, 200));
        assertEq(resultingPermit.expiration, uint48(block.timestamp));
        assertEq(resultingPermit.spender, address(this));
        assertEq(resultingPermit.accountId, accountId);
        assertEq(permitContract.getNonce(accountId), 1);
    }

    function test_RevertWhen_Permit_SignedByWrongAddress() public {
        uint128 accountId = 100;
        permitContract.createAccount(accountId, from);
        permitContract.createAccount(101, address(3));

        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand: encodedCommand, 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: 101
        });

        bytes memory sig = permitContract.getPermitSignature(permit, 1, fromPrivateKey);
        //bytes memory sigExtra = bytes.concat(sig, bytes1(uint8(1)));
        vm.prank(address(3));
        vm.expectRevert(abi.encodeWithSelector(SignatureVerification.InvalidSigner.selector));
        permitContract.permit(
            permit,
            1,
            sig
        );
    }

    function test_RevertWhen_Permit_FaultySignature() public {
        uint128 accountId = 100;
        permitContract.createAccount(accountId, from);
        permitContract.createAccount(101, address(3));

        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand: encodedCommand, 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: 101
        });

        bytes memory sig = bytes("1000010000100001000010000100001000010000100001000010000100001000");

        vm.prank(address(3));
        vm.expectRevert(abi.encodeWithSelector(SignatureVerification.InvalidSignature.selector));
        permitContract.permit(
            permit,
            1,
            sig
        );
    }

    function test_RevertWhen_Permit_MissmatchNonce() public {
        uint128 accountId = 100;
        permitContract.createAccount(accountId, from);

        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 2, 12653, 200);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand: encodedCommand, 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: accountId
        });

        bytes memory sig = permitContract.getPermitSignature(permit, 2, fromPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(SignatureVerification.InvalidSigner.selector));
        permitContract.permit(
            permit,
            1,
            sig
        );
    }

    function test_RevertWhen_Permit_UsedSignatureTwice() public {
        uint128 accountId = 100;
        permitContract.createAccount(accountId, from);

        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 2, 12653, 200);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand: encodedCommand, 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: accountId
        });

        bytes memory sig = permitContract.getPermitSignature(permit, 1, fromPrivateKey);
        permitContract.permit(
            permit,
            1,
            sig
        );

        assertEq(permitContract.getNonce(accountId), 1);

        vm.expectRevert(abi.encodeWithSelector(SignatureVerification.InvalidSigner.selector));
        permitContract.permit(
            permit,
            2,
            sig
        );

        vm.expectRevert(abi.encodeWithSelector(Permit.InvalidNonce.selector, 100, 1, 1));
        permitContract.permit(
            permit,
            1,
            sig
        );
    }

    function test_OnlyPermit() public {
        uint128 accountId = 100;
        permitContract.createAccount(accountId, from);

        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand: encodedCommand, 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: accountId
        });

        vm.expectRevert(abi.encodeWithSelector(Permit.InvalidPermit.selector));
        permitContract.onlyPermit(encodedCommand, accountId);

        bytes memory sig = permitContract.getPermitSignature(permit, 1, fromPrivateKey);
        permitContract.permit(
            permit,
            1,
            sig
        );

        // checks and deletes permit
        permitContract.onlyPermit(encodedCommand, accountId);

        Permit.PackedAllowance memory resultingPermit = permitContract.getAllowance(accountId);
        assertEq(resultingPermit.encodedCommand, abi.encode());
        assertEq(resultingPermit.expiration, 0);
        assertEq(resultingPermit.spender, address(0));
        assertEq(resultingPermit.accountId, 0);
        assertEq(permitContract.getNonce(accountId), 1);

        // checks and deletes permit
        vm.expectRevert(abi.encodeWithSelector(Permit.InvalidPermit.selector));
        permitContract.onlyPermit(encodedCommand, accountId);
    }

    function test_ValidatePermit() public {
        uint128 accountId = 100;
        permitContract.createAccount(accountId, from);

        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand: encodedCommand, 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: accountId
        });

        // check fase before giving permit
        bool valid = permitContract.validatePermit(encodedCommand, accountId, address(this));
        assertFalse(valid);

        bytes memory sig = permitContract.getPermitSignature(permit, 1, fromPrivateKey);
        permitContract.permit(
            permit,
            1,
            sig
        );

        // check false for wrong spender
        valid = permitContract.validatePermit(encodedCommand, accountId, address(3));
        assertFalse(valid);

        // check false for wrong accountId
        valid = permitContract.validatePermit(encodedCommand, 101, address(this));
        assertFalse(valid);

        // check false for wrong encodedCommand
        bytes memory badEncodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12853, 200);
        valid = permitContract.validatePermit(badEncodedCommand, accountId, address(this));
        assertFalse(valid);

        // check details were not deleted
        Permit.PackedAllowance memory resultingPermit = permitContract.getAllowance(accountId);
        assertEq(resultingPermit.encodedCommand, encodedCommand);
        assertEq(resultingPermit.expiration, uint48(block.timestamp));
        assertEq(resultingPermit.spender, address(this));
        assertEq(resultingPermit.accountId, accountId);
        assertEq(permitContract.getNonce(accountId), 1);

        // checks and deletes permit
        valid = permitContract.validatePermit(encodedCommand, accountId, address(this));
        assertTrue(valid);

        // check it can't be reused
        valid = permitContract.validatePermit(encodedCommand, accountId, address(this));
        assertFalse(valid);
    }

    function test_IsPermissionValid() public {
        uint128 accountId = 100;
        permitContract.createAccount(accountId, from);

        bytes memory encodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12653, 200);
        Permit.PackedAllowance memory permit = Permit.PackedAllowance({
            encodedCommand: encodedCommand, 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: accountId
        });

        Permit.PackedAllowance memory falsePermit = Permit.PackedAllowance({
            encodedCommand: encodedCommand, 
            expiration: uint48(block.timestamp),
            spender: address(this),
            accountId: accountId
        });

        // check fase before giving permit
        bool valid = permitContract.isPermitValid(permit);
        assertFalse(valid);

        bytes memory sig = permitContract.getPermitSignature(permit, 1, fromPrivateKey);
        permitContract.permit(
            permit,
            1,
            sig
        );

        // check false for wrong spender
        falsePermit.spender = address(3);
        valid = permitContract.isPermitValid(falsePermit);
        assertFalse(valid);
        falsePermit.spender = address(this);

        // check false for wrong accountId
        falsePermit.accountId = 101;
        valid = permitContract.isPermitValid(falsePermit);
        assertFalse(valid);
        falsePermit.accountId = accountId;

        // check false for wrong encodedCommand
        bytes memory badEncodedCommand = abi.encode(Permit.V2_INSTRUMENT_TAKER_ORDER, accountId, 1, 12853, 200);
        falsePermit.encodedCommand = badEncodedCommand;
        valid = permitContract.isPermitValid(falsePermit);
        assertFalse(valid);
        falsePermit.encodedCommand = encodedCommand;

        // check false for wrong expiration
        falsePermit.expiration = uint48(block.timestamp - 1);
        valid = permitContract.isPermitValid(falsePermit);
        assertFalse(valid);

        // check details were not deleted
        Permit.PackedAllowance memory resultingPermit = permitContract.getAllowance(accountId);
        assertEq(resultingPermit.encodedCommand, encodedCommand);
        assertEq(resultingPermit.expiration, uint48(block.timestamp));
        assertEq(resultingPermit.spender, address(this));
        assertEq(resultingPermit.accountId, accountId);

        // checks and deletes permit
        valid = permitContract.isPermitValid(permit);
        assertTrue(valid);

        // check it can be reused
        valid = permitContract.isPermitValid(permit);
        assertTrue(valid);
    }
}
