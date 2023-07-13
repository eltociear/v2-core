pragma solidity >=0.8.19;

import {BatchScript} from "../utils/BatchScript.sol";

import {CoreProxy, AccountNftProxy} from "../proxies/Core.sol";
import {DatedIrsProxy} from "../proxies/DatedIrs.sol";
import {PeripheryProxy} from "../proxies/Periphery.sol";
import {VammProxy} from "../proxies/Vamm.sol";

import {AccessPassNFT} from "@voltz-protocol/access-pass-nft/src/AccessPassNFT.sol";

import {AccessPassConfiguration} from "@voltz-protocol/core/src/storage/AccessPassConfiguration.sol";
import {CollateralConfiguration} from "@voltz-protocol/core/src/storage/CollateralConfiguration.sol";
import {ProtocolRiskConfiguration} from "@voltz-protocol/core/src/storage/ProtocolRiskConfiguration.sol";
import {MarketFeeConfiguration} from "@voltz-protocol/core/src/storage/MarketFeeConfiguration.sol";
import {MarketRiskConfiguration} from "@voltz-protocol/core/src/storage/MarketRiskConfiguration.sol";
import {AaveV3RateOracle} from "@voltz-protocol/products-dated-irs/src/oracles/AaveV3RateOracle.sol";
import {AaveV3BorrowRateOracle} from "@voltz-protocol/products-dated-irs/src/oracles/AaveV3BorrowRateOracle.sol";

import {ProductConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/ProductConfiguration.sol";
import {MarketConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/MarketConfiguration.sol";

import {VammConfiguration} from "@voltz-protocol/v2-vamm/utils/vamm-math/VammConfiguration.sol";

import {Config} from "@voltz-protocol/periphery/src/storage/Config.sol";

import {Ownable} from "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";
import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";

contract SetupProtocol is BatchScript {
  struct Contracts {
    CoreProxy coreProxy;
    DatedIrsProxy datedIrsProxy;
    PeripheryProxy peripheryProxy;
    VammProxy vammProxy;

    AaveV3RateOracle aaveV3RateOracle;
    AaveV3BorrowRateOracle aaveV3BorrowRateOracle;
  }
  Contracts contracts;

  struct Settings {
    bool multisig;
    address multisigAddress;
    bool multisigSend;
  }
  Settings settings;

  struct Metadata {
    uint256 chainId;
    address owner;

    AccessPassNFT accessPassNft;
    AccountNftProxy accountNftProxy;
  }
  Metadata metadata;

  bytes32 internal constant _GLOBAL_FEATURE_FLAG = "global";
  bytes32 internal constant _CREATE_ACCOUNT_FEATURE_FLAG = "createAccount";
  bytes32 internal constant _NOTIFY_ACCOUNT_TRANSFER_FEATURE_FLAG = "notifyAccountTransfer";
  bytes32 internal constant _REGISTER_PRODUCT_FEATURE_FLAG = "registerProduct";

  constructor(
    Contracts memory _contracts,
    Settings memory _settings
  ) {
    contracts = _contracts;
    settings = _settings;

    AccessPassConfiguration.Data memory accessPassConfig = contracts.coreProxy.getAccessPassConfiguration();
    metadata.accessPassNft = AccessPassNFT(accessPassConfig.accessPassNFTAddress);

    (address accountNftProxyAddress, ) = contracts.coreProxy.getAssociatedSystem(bytes32("accountNFT"));
    metadata.accountNftProxy = AccountNftProxy(payable(accountNftProxyAddress));

    Chain memory chain = getChain(vm.envString("CHAIN"));
    metadata.chainId = chain.chainId;

    metadata.owner = contracts.coreProxy.owner();
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////               ERC20              /////////////////
  ////////////////////////////////////////////////////////////////////

  function erc20_approve(IERC20 token, address spender, uint256 amount) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      token.approve(spender, amount);
    } else {
      addToBatch(
        address(token),
        abi.encodeCall(
          token.approve,
          (spender, amount)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////             CORE PROXY           /////////////////
  ////////////////////////////////////////////////////////////////////

  function acceptOwnership(address ownableProxyAddress) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      Ownable(ownableProxyAddress).acceptOwnership();
    } else {
      addToBatch(
        ownableProxyAddress,
        abi.encodeCall(
          Ownable.acceptOwnership,
          ()
        )
      );
    }
  }

  function setFeatureFlagAllowAll(bytes32 feature, bool allowAll) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.setFeatureFlagAllowAll(
        feature, allowAll
      );
    } else {
      addToBatch(
        address(contracts.coreProxy),
        abi.encodeCall(
          contracts.coreProxy.setFeatureFlagAllowAll, 
          (feature, allowAll)
        )
      );
    }
  }

  function addToFeatureFlagAllowlist(bytes32 feature, address account) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.addToFeatureFlagAllowlist(feature, account);
    } else {
      addToBatch(
        address(contracts.coreProxy), 
        abi.encodeCall(
          contracts.coreProxy.addToFeatureFlagAllowlist, 
          (feature, account)
        )
      );
    }
  }

  function setPeriphery(address peripheryAddress) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.setPeriphery(peripheryAddress);
    } else {
      addToBatch(
        address(contracts.coreProxy),
        abi.encodeCall(
          contracts.coreProxy.setPeriphery,
          (peripheryAddress)
        )
      );
    }
  }

  function configureMarketRisk(MarketRiskConfiguration.Data memory config) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.configureMarketRisk(config);
    } else {
      addToBatch(
        address(contracts.coreProxy),
        abi.encodeCall(
          contracts.coreProxy.configureMarketRisk,
          (config)
        )
      );
    }
  }

  function configureProtocolRisk(ProtocolRiskConfiguration.Data memory config) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.configureProtocolRisk(config);
    } else {
      addToBatch(
        address(contracts.coreProxy),
        abi.encodeCall(
          contracts.coreProxy.configureProtocolRisk,
          (config)
        )
      );
    }
  }

  function configureAccessPass(AccessPassConfiguration.Data memory config) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.configureAccessPass(config);
    } else {
      addToBatch(
        address(contracts.coreProxy),
        abi.encodeCall(
          contracts.coreProxy.configureAccessPass,
          (config)
        )
      );
    }
  }

  function registerProduct(address product, string memory name) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.registerProduct(product, name);
    } else {
      addToBatch(
        address(contracts.coreProxy),
        abi.encodeCall(
          contracts.coreProxy.registerProduct,
          (product, name)
        )
      );
    }
  }

  function configureCollateral(CollateralConfiguration.Data memory config) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.configureCollateral(config);
    } else {
      addToBatch(
        address(contracts.coreProxy),
        abi.encodeCall(
          contracts.coreProxy.configureCollateral,
          (config)
        )
      );
    }
  }

  function createAccount(uint128 requestedAccountId, address accountOwner) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.createAccount(requestedAccountId, accountOwner);
    } else {
      addToBatch(
        address(contracts.coreProxy),
        abi.encodeCall(
          contracts.coreProxy.createAccount,
          (requestedAccountId, accountOwner)
        )
      );
    }
  }

  function configureMarketFee(MarketFeeConfiguration.Data memory config) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.coreProxy.configureMarketFee(config);
    } else {
      addToBatch(
        address(contracts.coreProxy),
        abi.encodeCall(
          contracts.coreProxy.configureMarketFee,
          (config)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////             DATED IRS            /////////////////
  ////////////////////////////////////////////////////////////////////

  function configureProduct(ProductConfiguration.Data memory config) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.datedIrsProxy.configureProduct(config);
    } else {
      addToBatch(
        address(contracts.datedIrsProxy),
        abi.encodeCall(
          contracts.datedIrsProxy.configureProduct,
          (config)
        )
      );
    }
  }

  function configureMarket(MarketConfiguration.Data memory config) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.datedIrsProxy.configureMarket(config);
    } else {
      addToBatch(
        address(contracts.datedIrsProxy),
        abi.encodeCall(
          contracts.datedIrsProxy.configureMarket,
          (config)
        )
      );
    }
  }

  function setVariableOracle(uint128 marketId, address oracleAddress, uint256 maturityIndexCachingWindowInSeconds) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.datedIrsProxy.setVariableOracle(marketId, oracleAddress, maturityIndexCachingWindowInSeconds);
    } else {
      addToBatch(
        address(contracts.datedIrsProxy),
        abi.encodeCall(
          contracts.datedIrsProxy.setVariableOracle,
          (marketId, oracleAddress, maturityIndexCachingWindowInSeconds)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////                VAMM              /////////////////
  ////////////////////////////////////////////////////////////////////

  function setProductAddress(address productAddress) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.vammProxy.setProductAddress(productAddress);
    } else {
      addToBatch(
        address(contracts.vammProxy),
        abi.encodeCall(
          contracts.vammProxy.setProductAddress,
          (productAddress)
        )
      );
    }
  }

  function createVamm(
    uint128 marketId, 
    uint160 sqrtPriceX96, 
    VammConfiguration.Immutable memory config, 
    VammConfiguration.Mutable memory mutableConfig
  ) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.vammProxy.createVamm(marketId, sqrtPriceX96, config, mutableConfig);
    } else {
      addToBatch(
        address(contracts.vammProxy),
        abi.encodeCall(
          contracts.vammProxy.createVamm,
          (marketId, sqrtPriceX96, config, mutableConfig)
        )
      );
    }
  }

  function increaseObservationCardinalityNext(
    uint128 marketId, 
    uint32 maturityTimestamp, 
    uint16 observationCardinalityNext
  ) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.vammProxy.increaseObservationCardinalityNext(
        marketId, maturityTimestamp, observationCardinalityNext
      );
    } else {
      addToBatch(
        address(contracts.vammProxy),
        abi.encodeCall(
          contracts.vammProxy.increaseObservationCardinalityNext,
          (marketId, maturityTimestamp, observationCardinalityNext)
        )
      );
    }
  }

  function setMakerPositionsPerAccountLimit(uint256 makerPositionsPerAccountLimit) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.vammProxy.setMakerPositionsPerAccountLimit(makerPositionsPerAccountLimit);
    } else {
      addToBatch(
        address(contracts.vammProxy),
        abi.encodeCall(
          contracts.vammProxy.setMakerPositionsPerAccountLimit,
          (makerPositionsPerAccountLimit)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////             PERIPHERY            /////////////////
  ////////////////////////////////////////////////////////////////////

  function periphery_configure(Config.Data memory config) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.peripheryProxy.configure(config);
    } else {
      addToBatch(
        address(contracts.peripheryProxy),
        abi.encodeCall(
          contracts.peripheryProxy.configure,
          (config)
        )
      );
    }
  }

  function periphery_execute(bytes memory commands, bytes[] memory inputs, uint256 deadline) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      contracts.peripheryProxy.execute(commands, inputs, deadline);
    } else {
      addToBatch(
        address(contracts.peripheryProxy),
        abi.encodeCall(
          contracts.peripheryProxy.execute,
          (commands, inputs, deadline)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////          ACCESS PASS NFT         /////////////////
  ////////////////////////////////////////////////////////////////////

  function addNewRoot(AccessPassNFT.RootInfo memory rootInfo) public {
    if (!settings.multisig) {
      vm.broadcast(metadata.owner);
      metadata.accessPassNft.addNewRoot(rootInfo);
    } else {
      addToBatch(
        address(metadata.accessPassNft),
        abi.encodeCall(
          metadata.accessPassNft.addNewRoot,
          (rootInfo)
        )
      );
    }
  }
}