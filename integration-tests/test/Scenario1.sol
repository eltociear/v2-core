pragma solidity >=0.8.19;

import "./utils/BaseScenario.sol";

import "@voltz-protocol/core/src/storage/CollateralConfiguration.sol";
import "@voltz-protocol/core/src/storage/ProtocolRiskConfiguration.sol";
import "@voltz-protocol/core/src/storage/MarketFeeConfiguration.sol";

import "@voltz-protocol/products-dated-irs/src/storage/ProductConfiguration.sol";
import "@voltz-protocol/products-dated-irs/src/storage/MarketConfiguration.sol";

import {Config} from "@voltz-protocol/periphery/src/storage/Config.sol";
import {Commands} from "@voltz-protocol/periphery/src/libraries/Commands.sol";
import "@voltz-protocol/periphery/src/interfaces/external/IAllowanceTransfer.sol";
import {IWETH9} from "@voltz-protocol/periphery/src/interfaces/external/IWETH9.sol";

import "@voltz-protocol/v2-vamm/utils/vamm-math/TickMath.sol";
import {ExtendedPoolModule} from "@voltz-protocol/v2-vamm/test/PoolModule.t.sol";
import {VammConfiguration, IRateOracle} from "@voltz-protocol/v2-vamm/utils/vamm-math/VammConfiguration.sol";

import { ud60x18 } from "@prb/math/UD60x18.sol";

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
        PERMIT2: IAllowanceTransfer(address(0)), // todo: deploy permit2
        VOLTZ_V2_CORE_PROXY: address(coreProxy),
        VOLTZ_V2_DATED_IRS_PROXY: address(datedIrsProxy),
        VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(vammProxy),
        VOLTZ_V2_ACCOUNT_NFT_PROXY: address(accountNftProxy)
      })
    );

    vm.stopPrank();

    //todo: set initial aave lending pool index to 1 (maybe in base?)
  }

  function test() public {
    setConfigs();

    address user1 = vm.addr(1);
    vm.startPrank(user1);

    token.mint(user1, 1001e18);

    // todo: remove when periphery is fixed
    coreProxy.createAccount(1);
    token.approve(address(coreProxy), 1001e18);
    coreProxy.deposit(1, address(token), 1000e18);
    coreProxy.grantPermission(1, bytes32("ADMIN"), address(peripheryProxy));

    bytes memory commands = abi.encodePacked(
      // bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
      // bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
      bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
    );
    bytes[] memory inputs = new bytes[](1);
    // inputs[0] = abi.encode(1);
    // inputs[1] = abi.encode(1, address(token), 1000);
    inputs[0] = abi.encode(
      1,  // accountId
      marketId,
      maturityTimestamp,
      -14100, // 4.1%
      -13620, // 3.9% 
      extendedPoolModule.getLiquidityForBase(-14100, -13620, 1000)    
    );
    peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    vm.stopPrank();

    address user2 = vm.addr(2);
    vm.startPrank(user2);

    token.mint(user2, 501e18);

    // todo: remove when periphery is fixed
    coreProxy.createAccount(2);
    token.approve(address(coreProxy), 501e18);
    coreProxy.deposit(2, address(token), 500e18);
    coreProxy.grantPermission(2, bytes32("ADMIN"), address(peripheryProxy));

    commands = abi.encodePacked(
      // bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
      bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
    );
    inputs = new bytes[](1);
    // inputs[0] = abi.encode(1, address(token), 1000);
    inputs[0] = abi.encode(
      2,  // accountId
      marketId,
      maturityTimestamp,
      500e18,
      0 // todo: compute this properly
    );
    peripheryProxy.execute(commands, inputs, block.timestamp + 1);

    // console.logInt(datedIrsProxy.getAccountAnnualizedExposures(1, address(token))[0].filled);
    // console.logInt(datedIrsProxy.getAccountAnnualizedExposures(2, address(token))[0].filled);
  }
}