pragma solidity >=0.8.19;

import {DeployProtocol} from "../../src/utils/DeployProtocol.sol";
import {ScenarioHelper, IRateOracle, VammConfiguration, Utils} from "../utils/ScenarioHelper.sol";
import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";
import {MockAaveLendingPool} from "@voltz-protocol/products-dated-irs/test/mocks/MockAaveLendingPool.sol";

import {ERC20Mock} from "../utils/ERC20Mock.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

contract Scenario1 is ScenarioHelper {
    uint32 maturityTimestamp = 1692356400;
    uint128 marketId = 1;

    function setUp() public {
        // COMPLETE WITH ACTORS' ADDRESSES
        address[] memory accessPassOwners = new address[](2);
        accessPassOwners[0] = owner; // note: do not change owner's index 0
        accessPassOwners[1] = address(1);
        setUpAccessPassNft(accessPassOwners);
        redeemAccessPass(owner, 1, 0);

        acceptOwnerships();
        enableFeatures();
        configureProtocol({
            imMultiplier: ud60x18(1.5e18),
            liquidatorRewardParameter: ud60x18(0.05e18),
            feeCollectorAccountId: 999
        });
        registerDatedIrsProduct(1);
        configureMarket({
            rateOracleAddress: address(contracts.aaveV3RateOracle),
            // note, let's keep as bridged usdc for now
            tokenAddress: address(token),
            productId: 1,
            marketId: marketId,
            feeCollectorAccountId: 999,
            liquidationBooster: 0,
            cap: 100000e6,
            atomicMakerFee: ud60x18(0),
            atomicTakerFee: ud60x18(0.0002e18),
            riskParameter: ud60x18(0.013e18),
            twapLookbackWindow: 259200,
            maturityIndexCachingWindowInSeconds: 3600
        });
        vm.warp(1689699303);
        uint32[] memory times = new uint32[](2);
        times[0] = uint32(block.timestamp - 86400*4); // note goes back 4 days, while lookback is 3 days, so should be fine?
        times[1] = uint32(block.timestamp - 86400*3);
        int24[] memory observedTicks = new int24[](2);
        observedTicks[0] = -12240; // 3.4% note worth double checking
        observedTicks[1] = -12240; // 3.4%
        deployPool({
            immutableConfig: VammConfiguration.Immutable({
                maturityTimestamp: maturityTimestamp, // Fri Aug 18 2023 11:00:00 GMT+0000
                _maxLiquidityPerTick: type(uint128).max,
                _tickSpacing: 60,
                marketId: marketId
            }),
            mutableConfig: VammConfiguration.Mutable({
                priceImpactPhi: ud60x18(0),
                priceImpactBeta: ud60x18(0),
                spread: ud60x18(0.001e18),
                rateOracle: IRateOracle(address(contracts.aaveV3RateOracle)),
                minTick: -15780,  // 4.85%
                maxTick: 15780    // 0.2%
            }),
            initTick: -12240, // 3.4%
            // todo: note, is this sufficient, or should we increase? what's the min gap between consecutive observations?
            observationCardinalityNext: 20,
            makerPositionsPerAccountLimit: 1,
            times: times,
            observedTicks: observedTicks
        });

        MockAaveLendingPool(address(contracts.aaveV3RateOracle.aaveLendingPool()))
            .setReserveNormalizedIncome(ERC20Mock(address(token)), ud60x18(1e18));
    }

    function test_happy_path() public {
        executeMakerOrder({
            _marketId: marketId,
            _maturityTimestamp: maturityTimestamp,
            accountId: 1,
            user: address(1),
            count: 1,
            merkleIndex: 1, // NEW taker
            toDeposit: 10,
            baseAmount: 100,
            tickLower: -13800,
            tickUpper: -13740
        });

        (
            bool liquidatable,
            uint256 initialMarginRequirement,
            uint256 liquidationMarginRequirement,
            uint256 highestUnrealizedLoss
        ) = contracts.coreProxy.isLiquidatable(1, address(token));

        assertEq(liquidatable, false);
    }

}