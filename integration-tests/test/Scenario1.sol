pragma solidity >=0.8.19;

import "./utils/BaseScenario.sol";

import "@voltz-protocol/core/src/storage/CollateralConfiguration.sol";
import "@voltz-protocol/core/src/storage/ProtocolRiskConfiguration.sol";
import "@voltz-protocol/core/src/storage/MarketFeeConfiguration.sol";

import "@voltz-protocol/products-dated-irs/src/storage/ProductConfiguration.sol";
import "@voltz-protocol/products-dated-irs/src/storage/MarketConfiguration.sol";

import {Config} from "@voltz-protocol/periphery/src/storage/Config.sol";
import {Commands} from "@voltz-protocol/periphery/src/libraries/Commands.sol";
import {IWETH9} from "@voltz-protocol/periphery/src/interfaces/external/IWETH9.sol";

import "@voltz-protocol/v2-vamm/utils/vamm-math/TickMath.sol";
import {ExtendedPoolModule} from "@voltz-protocol/v2-vamm/test/PoolModule.t.sol";
import {VammConfiguration, IRateOracle} from "@voltz-protocol/v2-vamm/utils/vamm-math/VammConfiguration.sol";

import { ud60x18, div } from "@prb/math/UD60x18.sol";

contract Scenario1 is BaseScenario {
  uint128 productId;
  uint128 marketId;
  uint32 maturityTimestamp;
  ExtendedPoolModule extendedPoolModule; // used to convert base to liquidity :)

  function setUp() public {
    super._setUp();
    marketId = 1;
    maturityTimestamp = uint32(block.timestamp) + 172800;
    extendedPoolModule = new ExtendedPoolModule();
  }

  function setConfigs() public {
    vm.startPrank(owner);

    coreProxy.configureCollateral(
      CollateralConfiguration.Data({
        depositingEnabled: true,
        liquidationBooster: 1e18,
        tokenAddress: address(token),
        cap: 1000000e18
      })
    );
    coreProxy.configureProtocolRisk(
      ProtocolRiskConfiguration.Data({
        imMultiplier: UD60x18.wrap(2e18),
        liquidatorRewardParameter: UD60x18.wrap(5e16)
      })
    );

    productId = coreProxy.registerProduct(address(datedIrsProxy), "Dated IRS Product");

    datedIrsProxy.configureMarket(
      MarketConfiguration.Data({
        marketId: marketId,
        quoteToken: address(token)
      })
    );
    datedIrsProxy.setVariableOracle(
      1,
      address(aaveRateOracle)
    );
    datedIrsProxy.configureProduct(
      ProductConfiguration.Data({
        productId: productId,
        coreProxy: address(coreProxy),
        poolAddress: address(vammProxy)
      })
    );

    coreProxy.configureMarketFee(
      MarketFeeConfiguration.Data({
        productId: productId,
        marketId: marketId,
        feeCollectorAccountId: feeCollectorAccountId,
        atomicMakerFee: UD60x18.wrap(1e16),
        atomicTakerFee: UD60x18.wrap(5e16)
      })
    );
    coreProxy.configureMarketRisk(
      MarketRiskConfiguration.Data({
        productId: productId, 
        marketId: marketId, 
        riskParameter: SD59x18.wrap(1e18), 
        twapLookbackWindow: 86400
      })
    );

    VammConfiguration.Immutable memory immutableConfig = VammConfiguration.Immutable({
        maturityTimestamp: maturityTimestamp,
        _maxLiquidityPerTick: type(uint128).max,
        _tickSpacing: 60,
        marketId: marketId
    });

    VammConfiguration.Mutable memory mutableConfig = VammConfiguration.Mutable({
        priceImpactPhi: ud60x18(1e17), // 0.1
        priceImpactBeta: ud60x18(125e15), // 0.125
        spread: ud60x18(3e15), // 0.3%
        rateOracle: IRateOracle(address(aaveRateOracle))
    });

    vammProxy.setProductAddress(address(datedIrsProxy));
    vammProxy.createVamm(
      1,
      TickMath.getSqrtRatioAtTick(-13860), // price = 4%
      immutableConfig,
      mutableConfig
    );

    peripheryProxy.configure(
      Config.Data({
        WETH9: IWETH9(address(874392112)),  // todo: deploy weth9 mock
        VOLTZ_V2_CORE_PROXY: address(coreProxy),
        VOLTZ_V2_DATED_IRS_PROXY: address(datedIrsProxy),
        VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(vammProxy),
        VOLTZ_V2_ACCOUNT_NFT_PROXY: address(accountNftProxy)
      })
    );

    vm.stopPrank();

    aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(1e18));
  }

  function runTest(bool doSwap, bool doClose) public {
    setConfigs();

    uint256 NUMBER_OF_LPS = 500;

    for (uint256 i = 1; i <= NUMBER_OF_LPS; i++) {
      address user1 = vm.addr(i);
      vm.startPrank(user1);

      int24 minTick = -14100 - int24(uint24(i*60));
      int24 maxTick = -13620 + int24(uint24(i*60));

      token.mint(user1, 1001e18);

      token.approve(address(peripheryProxy), 1001e18);

      bytes memory commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      bytes[] memory inputs = new bytes[](4);
      inputs[0] = abi.encode(i);
      inputs[1] = abi.encode(address(token), 1001e18);
      inputs[2] = abi.encode(i, address(token), 1000e18);
      inputs[3] = abi.encode(
        i,  // accountId
        marketId,
        maturityTimestamp,
        minTick, // 3.9% 
        maxTick, // 4.1%
        extendedPoolModule.getLiquidityForBase(-minTick , maxTick, 10000e18)    
      );
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);

      vm.stopPrank();
    }


    uint256 user2_id = 2000;
    address user2 = vm.addr(user2_id);
    vm.startPrank(user2);

    token.mint(user2, 5010000e18);

    token.approve(address(peripheryProxy), 5010000e18);

    bytes memory commands;
    bytes[] memory inputs;
    
    if (doSwap) {
      commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      inputs = new bytes[](4);
      // bytes[] memory inputs = new bytes[](3);
      inputs[0] = abi.encode(user2_id);
      inputs[1] = abi.encode(address(token), 501e18);
      inputs[2] = abi.encode(user2_id, address(token), 500e18);
      inputs[3] = abi.encode(
        user2_id,  // accountId
        marketId,
        maturityTimestamp,
        5000000e18,
        0 // todo: compute this properly
      );
    } else {
      commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT))
      );
      inputs = new bytes[](3);
      inputs[0] = abi.encode(user2_id);
      inputs[1] = abi.encode(address(token), 501e18);
      inputs[2] = abi.encode(user2_id, address(token), 500e18);
    }
    peripheryProxy.execute(commands, inputs, block.timestamp + 1);
    vm.stopPrank();

    if (doClose) {
      // uint128 accountToClose = user2_id;
      uint128 accountToClose = 5;
      address addressToCloseWith = vm.addr(accountToClose);

      commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CLOSE_ACCOUNT))
      );
      inputs = new bytes[](1);
      inputs[0] = abi.encode(
        productId,  // productId
        accountToClose,  // accountId
        address(token) // collateralType
      );
      vm.startPrank(addressToCloseWith);
      peripheryProxy.execute(commands, inputs, block.timestamp + 1);
      vm.stopPrank();
    }

    // aaveLendingPool.setReserveNormalizedIncome(IERC20(token), ud60x18(101e16));

    // uint256 traderExposure = div(ud60x18(500e18 * 2 * 1.01), ud60x18(365 * 1e18)).unwrap();
    // uint256 eps = 1000; // 1e-15 * 1e18

    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, -int256(traderExposure - eps));
    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled, -int256(traderExposure + eps));

    // assertGe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, int256(traderExposure - eps));
    // assertLe(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled, int256(traderExposure + eps));
  }

  function testGasCostWithSwap() public {
    runTest(true, false);
  }

  function testGasCostWithSwapAndAccountClosure() public {
    runTest(true, true);
  }

  function testGasCostWithoutSwap() public {
    runTest(false, false);
  }

}