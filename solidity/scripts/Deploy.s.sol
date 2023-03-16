// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {VaultController} from '@contracts/core/VaultController.sol';
import {USDA} from '@contracts/core/USDA.sol';
import {GovernorCharlieDelegate} from '@contracts/governance/GovernorDelegate.sol';
import {GovernorCharlieDelegator} from '@contracts/governance/GovernorDelegator.sol';
import {AmphoraProtocolToken} from '@contracts/governance/AmphoraProtocolToken.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/ChainlinkOracleRelay.sol';
import {AnchoredViewRelay} from '@contracts/periphery/AnchoredViewRelay.sol';
import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';
import {UniswapV3OracleRelay} from '@contracts/periphery/UniswapV3OracleRelay.sol';
import {ThreeLines0_100} from '@contracts/utils/ThreeLines0_100.sol';

import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {TestConstants} from '@test/utils/TestConstants.sol';

abstract contract Deploy is Script, TestConstants {
  VaultController public vaultController;
  USDA public usda;

  CurveMaster public curveMaster;
  ThreeLines0_100 public threeLines;

  AmphoraProtocolToken public amphToken;
  GovernorCharlieDelegator public governorBase;
  GovernorCharlieDelegate public governorImplementation;

  // uniswapv3 oracles
  UniswapV3OracleRelay public uniswapRelayEthUsdc;
  // Chainlink oracles
  ChainlinkOracleRelay public chainlinkEth;
  // AnchoredView relayers
  AnchoredViewRelay public anchoredViewEth;

  uint256 public initialAmphSupply = 100_000_000 ether;

  function _deploy(address _deployer) internal {
    address[] memory _tokens = new address[](1);

    // TODO: pass deployer rights to governance?
    vm.startBroadcast(_deployer);

    // Deploy governance and amph token
    amphToken = new AmphoraProtocolToken();
    console.log('AMPHORA_TOKEN: ', address(amphToken));
    amphToken.initialize(_deployer, initialAmphSupply);
    governorImplementation = new GovernorCharlieDelegate();
    governorBase = new GovernorCharlieDelegator(address(amphToken), address(governorImplementation));
    console.log('GOVERNOR_DELEGATOR: ', address(governorBase));

    // Deploy and initialize VaultController
    vaultController = new VaultController();
    console.log('VAULT_CONTROLLER: ', address(vaultController));
    vaultController.initialize(IVaultController(address(0)), _tokens);

    // Deploy and initialize USDA
    usda = new USDA();
    console.log('USDA: ', address(usda));
    usda.initialize(SUSD_ADDRESS);

    // Deploy curve
    // TODO: check the values
    threeLines = new ThreeLines0_100(2 ether, 0.05 ether, 0.045 ether, 0.5 ether, 0.55 ether);
    console.log('THREE_LINES_0_100: ', address(threeLines));

    // Deploy CurveMaster
    curveMaster = new CurveMaster();
    console.log('CURVE_MASTER: ', address(curveMaster));

    // Deploy uniswapRelayEthUsdc oracle relay
    // TODO: check the values
    uniswapRelayEthUsdc = new UniswapV3OracleRelay(60, USDC_WETH_POOL_ADDRESS, true, 1_000_000_000_000, 1);
    console.log('UNISWAP_ETH_USDC_ORACLE: ', address(uniswapRelayEthUsdc));
    // Deploy chainlinkEth oracle relay
    chainlinkEth = new ChainlinkOracleRelay(CHAINLINK_ETH_FEED_ADDRESS, 10_000_000_000, 1);
    console.log('CHAINLINK_ETH_FEED: ', address(chainlinkEth));
    // Deploy anchoredViewEth relay
    anchoredViewEth = new AnchoredViewRelay(address(uniswapRelayEthUsdc), address(chainlinkEth), 10, 100);
    console.log('ANCHORED_VIEW_RELAY: ', address(anchoredViewEth));

    // Add curveMaster to VaultController
    vaultController.registerCurveMaster(address(curveMaster));
    // Set VaultController address for usda
    usda.addVaultController(address(vaultController));
    // Register WETH as acceptable erc20 to vault controller
    vaultController.registerErc20(
      WETH_ADDRESS, WETH_LTV, address(anchoredViewEth), LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );
    // Register USDA
    vaultController.registerUSDA(address(usda));
    // Set curve
    curveMaster.setCurve(address(0), address(threeLines));
    // Set pauser
    usda.setPauser(_deployer);

    vm.stopBroadcast();
  }
}

contract DeployMainnet is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_MAINNNET_PRIVATE_KEY'));

  function run() external {
    _deploy(deployer);
  }
}

contract DeployGoerli is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_GOERLI_PRIVATE_KEY'));

  function run() external {
    _deploy(deployer);
  }
}

contract DeployLocal is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_ANVIL_LOCAL_PRIVATE_KEY'));

  function run() external {
    _deploy(deployer);
  }
}
