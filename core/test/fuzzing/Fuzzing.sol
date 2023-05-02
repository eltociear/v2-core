//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./Hevm.sol";

import "../../src/modules/AccountTokenModule.sol";

import "../../src/modules/AccountModule.sol";
import "../../src/modules/CollateralModule.sol";

import "@voltz-protocol/util-contracts/src/storage/OwnableStorage.sol";
import "@voltz-protocol/util-contracts/src/helpers/AddressUtil.sol";

import "oz/mocks/ERC20Mock.sol";

contract ProxyAccountTokenModule is AccountTokenModule {
  constructor(address _owner) {
    OwnableStorage.load().owner = _owner;
  }
}

contract Proxy is AccountModule, CollateralModule { 
  function mockAssociatedSystem() internal {
    ProxyAccountTokenModule accountTokenModuleProxy = new ProxyAccountTokenModule(address(this));
    AssociatedSystem.load("accountNFT").proxy = address(accountTokenModuleProxy);
  }

  constructor() {
    mockAssociatedSystem();
  }

  function mockCollateralConfig(address tokenAddress) external {
    CollateralConfiguration.Data memory config;
    config.depositingEnabled = true;
    config.liquidationBooster = 5e16;
    config.tokenAddress = tokenAddress;
    config.cap = 10000e18;

    CollateralConfiguration.set(config);
  }

  function getCollateralConfig(address token) external pure returns (CollateralConfiguration.Data memory collateralConfig) {
    collateralConfig = CollateralConfiguration.load(token);
  }
}

contract WrappedStorage {
  struct AccountData {
    address owner;
    uint256 balance;
    uint256 boosterBalance;
  }
  
  uint128[] accounts;
  mapping(uint128 => AccountData) accountData;

  ERC20Mock token;
}

abstract contract WrappedAccountModule is WrappedStorage {
  function proxy() internal virtual returns (Proxy);

  function checks() internal virtual;

  function wCreateAccount(address owner, uint128 requestedAccountId) public {
    if (owner == address(0) || requestedAccountId == 0) {
      return;
    }

    address existingOwner = accountData[requestedAccountId].owner;
    bool expectRevert = existingOwner != address(0) || AddressUtil.isContract(owner);

    hevm.prank(owner);
    try proxy().createAccount(requestedAccountId) {
      assert(!expectRevert);

      AccountData memory data;
      data.owner = owner;
      accountData[requestedAccountId] = data;

      accounts.push(requestedAccountId);
    } catch {
      assert(expectRevert);
    }

    checks();
  }

  function accountChecks() internal {
    for (uint i = 0; i < accounts.length; i += 1) {
      uint128 id = accounts[i];
      assert(proxy().getAccountOwner(id) == accountData[id].owner);
    }
  }
}

abstract contract WrappedCollateralModule is WrappedStorage {
  constructor() {
    token = new ERC20Mock();
    proxy().mockCollateralConfig(address(token));
  }

  function proxy() internal virtual returns (Proxy);

  function checks() internal virtual;

  function wDeposit(address user, uint128 accountId, uint256 mintAndApproveAmount, uint256 depositAmount) public {
    AccountData storage data = accountData[accountId];
    token.mint(user, mintAndApproveAmount - token.balanceOf(user));
    hevm.prank(user);
    token.approve(address(proxy()), mintAndApproveAmount);

    uint256 actualDepositAmount = 
      depositAmount + 
      proxy().getCollateralConfig(address(token)).liquidationBooster - 
      accountData[accountId].boosterBalance;
    bool expectRevert = data.owner == address(0) || mintAndApproveAmount < actualDepositAmount;

    hevm.prank(user);
    try proxy().deposit(accountId, address(token), depositAmount) {
      assert(!expectRevert);

      data.balance += depositAmount;
      data.boosterBalance = proxy().getCollateralConfig(address(token)).liquidationBooster;
    } catch {
      assert(expectRevert);
    }

    checks();
  }
}

contract WrappedProxy is WrappedAccountModule, WrappedCollateralModule {
  Proxy _proxy;

  function proxy() internal override(WrappedAccountModule, WrappedCollateralModule) returns (Proxy) {
    if (address(_proxy) == address(0)) {
      _proxy = new Proxy();
    }
    return _proxy;
  }

  function checks() internal override(WrappedAccountModule, WrappedCollateralModule) {
    accountChecks();
  }
}

import "forge-std/Test.sol";
contract FoundryWrappedProxy is WrappedProxy, Test {
  function test_myTest() public {
    console.log(address(_proxy));
    wCreateAccount(address(0xa329c0648769a73afac7f9381e08fb43dbea72),5000000000000000001);
  }
}