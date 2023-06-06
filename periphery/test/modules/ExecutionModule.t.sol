pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/ExecutionModule.sol";
import "../../src/interfaces/external/IWETH9.sol";
import "../../src/modules/ConfigurationModule.sol";
import "../utils/MockAllowanceTransfer.sol";
import "../utils/MockWeth.sol";

contract ExtendedExecutionModule is ExecutionModule, ConfigurationModule {
    function setOwner(address account) external {
        OwnableStorage.Data storage ownable = OwnableStorage.load();
        ownable.owner = account;
    }
}

contract ExecutionModuleTest is Test {

    ExtendedExecutionModule exec;
    address core = address(111);
    address instrument = address(112);
    address exchange = address(113);

    MockWeth mockWeth = new MockWeth("MockWeth", "Mock WETH");

    function setUp() public {
        exec = new ExtendedExecutionModule();
        exec.setOwner(address(this));
        exec.configure(Config.Data({
            WETH9: mockWeth,
            PERMIT2: new MockAllowanceTransfer(),
            VOLTZ_V2_CORE_PROXY: core,
            VOLTZ_V2_DATED_IRS_PROXY: instrument,
            VOLTZ_V2_DATED_IRS_VAMM_PROXY: exchange
        }));
    }

    function testExecCommand_Swap() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, 101, 1678786786, 100, 0);

        vm.mockCall(
            instrument,
            abi.encodeWithSelector(
                IProductIRSModule.initiateTakerOrder.selector,
                1, 101, 1678786786, 100, 0
            ),
            abi.encode(100, -100)
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_Settle() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, 101, 1678786786);

        vm.mockCall(
            instrument,
            abi.encodeWithSelector(
                IProductIRSModule.settle.selector,
                1, 101, 1678786786
            ),
            abi.encode(100, -100)
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_Mint() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, 101, 1678786786);

        vm.mockCall(
            exchange,
            abi.encodeWithSelector(
                IPool.initiateDatedMakerOrder.selector,
                1, 101, 1678786786, -6600, -6000, 10389000
            ),
            abi.encode()
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_Withdraw() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_WITHDRAW)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, address(56), 100000);

        vm.mockCall(
            core,
            abi.encodeWithSelector(
                ICollateralModule.deposit.selector,
                1, address(56), 100000
            ),
            abi.encode()
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_Deposit() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_DEPOSIT)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, address(56), 100000);

        vm.mockCall(
            core,
            abi.encodeWithSelector(
                ICollateralModule.deposit.selector,
                address(this), 1, address(56), 100000
            ),
            abi.encode()
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_Permit() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory sig = bytes("1000010000100001000010000100001000010000100001000010000100001000");
        bytes memory encodedCommand = abi.encode(Permit.V2_CORE_WITHDRAW, 1, address(56), 100000);
        address spender = address(2);
        uint256 nonce = 1;

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_DEPOSIT)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, nonce, spender, sig, encodedCommand);

        vm.mockCall(
            core,
            abi.encodeWithSelector(
                IPermitModule.permit.selector,
                1, nonce, spender, sig, encodedCommand
            ),
            abi.encode()
        );

        exec.execute(commands, inputs, deadline);
    }

    function testExecCommand_WrapETH() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(20000);

        vm.mockCall(
            address(mockWeth),
            20000,
            abi.encodeWithSelector(IWETH9.deposit.selector),
            abi.encode()
        );
        vm.deal(address(this), 20000);
        uint256 initBalance = address(this).balance;
        uint256 initBalanceExec = address(exec).balance;

        exec.execute{value: 20000}(commands, inputs, deadline);

        assertEq(initBalance, address(this).balance + 20000);
        assertEq(initBalanceExec, address(exec).balance - 20000);
    }

    function testExecMultipleCommands() public {
        uint256 deadline = block.timestamp + 1;
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)), bytes1(uint8(Commands.V2_CORE_DEPOSIT)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(20000);
        inputs[1] = abi.encode(1, address(56), 100000);

        vm.mockCall(
            address(mockWeth),
            20000,
            abi.encodeWithSelector(IWETH9.deposit.selector),
            abi.encode()
        );
        vm.mockCall(
            core,
            abi.encodeWithSelector(
                ICollateralModule.deposit.selector,
                address(this), 1, address(56), 100000
            ),
            abi.encode()
        );
        vm.deal(address(this), 20000);
        uint256 initBalance = address(this).balance;
        uint256 initBalanceExec = address(exec).balance;

        exec.execute{value: 20000}(commands, inputs, deadline);

        assertEq(initBalance, address(this).balance + 20000);
        assertEq(initBalanceExec, address(exec).balance - 20000);
    }

    function test_RevertWhen_UnknownCommand() public {
        uint256 deadline = block.timestamp + 1;
        uint256 mockCommand = 0x07;
        bytes memory commands = abi.encodePacked(bytes1(uint8(mockCommand)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, 101, 1678786786, 100, 0);

        vm.expectRevert(abi.encodeWithSelector(
            Dispatcher.InvalidCommandType.selector,
            uint8(bytes1(uint8(mockCommand)) & Commands.COMMAND_TYPE_MASK)
        ));
        exec.execute(commands, inputs, deadline);
    }

}