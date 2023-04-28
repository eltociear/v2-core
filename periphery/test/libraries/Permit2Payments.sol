//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/libraries/Payments.sol";
import "../../src/libraries/Constants.sol";
import "../../src/storage/Config.sol";
import "../../src/interfaces/external/IAllowanceTransfer.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";
import "solmate/src/utils/SafeTransferLib.sol";

contract ExposedPermit2Payments {
    function setUp(Config.Data memory config) external {
        Config.set(config);
    }

    // exposed functions
}

contract PaymentsTest is Test {
    ExposedPayments internal exposedPayments;

    function setUp() public {
        exposedPermit2Payments = new ExposedPermit2Payments();
        exposedPermit2Payments.setUp(
            Config.Data({
                WETH9: IWETH9(address(1)),
                PERMIT2: IAllowanceTransfer(address(10)),
                VOLTZ_V2_CORE_PROXY: address(0),
                VOLTZ_V2_DATED_IRS_PROXY: address(0),
                VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(0)
            })
        );
    }
}
