// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {VaultController} from '@contracts/core/VaultController.sol';
import {VaultDeployer} from '@contracts/core/VaultDeployer.sol';
import {USDA} from '@contracts/core/USDA.sol';
import {GovernorCharlie} from '@contracts/governance/GovernorCharlie.sol';
import {AmphoraProtocolToken} from '@contracts/governance/AmphoraProtocolToken.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/oracles/ChainlinkOracleRelay.sol';
import {AnchoredViewRelay} from '@contracts/periphery/oracles/AnchoredViewRelay.sol';
import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';
import {UniswapV3OracleRelay} from '@contracts/periphery/oracles/UniswapV3OracleRelay.sol';
import {ThreeLines0_100} from '@contracts/utils/ThreeLines0_100.sol';
import {AMPHClaimer} from '@contracts/core/AMPHClaimer.sol';
import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IVaultDeployer} from '@interfaces/core/IVaultDeployer.sol';
import {TestConstants} from '@test/utils/TestConstants.sol';
import {IVault} from '@interfaces/core/IVault.sol';

import {FakeBaseRewardPool} from '@scripts/fakes/FakeBaseRewardPool.sol';
import {FakeBooster} from '@scripts/fakes/FakeBooster.sol';
import {FakeVirtualRewardsPool} from '@scripts/fakes/FakeVirtualRewardsPool.sol';
import {FakeWethOracle} from '@scripts/fakes/FakeWethOracle.sol';
import {MintableToken} from '@scripts/fakes/MintableToken.sol';

import {ERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

abstract contract Deploy is Script, TestConstants {
  VaultController public vaultController;
  VaultDeployer public vaultDeployer;
  AMPHClaimer public amphClaimer;
  USDA public usda;

  CurveMaster public curveMaster;
  ThreeLines0_100 public threeLines;

  AmphoraProtocolToken public amphToken;
  GovernorCharlie public governor;

  // uniswapv3 oracles
  UniswapV3OracleRelay public uniswapRelayEthUsdc;
  // Chainlink oracles
  ChainlinkOracleRelay public chainlinkEth;
  // AnchoredView relayers
  AnchoredViewRelay public anchoredViewEth;

  uint256 public initialAmphSupply = 100_000_000 ether;

  uint256 public cvxRate = 10 ether; // 10 AMPH per 1 CVX
  uint256 public crvRate = 0.5 ether; // 0.5 AMPH per 1 CVX

  uint256 public cvxRewardFee = 0.02 ether;
  uint256 public crvRewardFee = 0.01 ether;

  function _deploy(
    address _deployer,
    IERC20 _cvxAddress,
    IERC20 _crvAddress,
    IERC20 _sUSDAddress,
    IERC20 _wethAddress,
    address _booster,
    address _wethOracle,
    bool _giveOwnershipToGov
  ) internal {
    address[] memory _tokens = new address[](1);

    // TODO: pass deployer rights to governance?
    vm.startBroadcast(_deployer);

    // Deploy governance and amph token
    amphToken = new AmphoraProtocolToken(_deployer, initialAmphSupply);
    console.log('AMPHORA_TOKEN: ', address(amphToken));
    governor = new GovernorCharlie(address(amphToken));
    console.log('GOVERNOR: ', address(governor));

    // Deploy VaultController & VaultDeployer
    vaultController = new VaultController(_booster);
    console.log('VAULT_CONTROLLER: ', address(vaultController));
    vaultDeployer = new VaultDeployer(IVaultController(address(vaultController)), _cvxAddress, _crvAddress);
    console.log('VAULT_DEPLOYER: ', address(vaultDeployer));

    // Deploy claimer
    amphClaimer =
    new AMPHClaimer(address(vaultController), IERC20(address(amphToken)), _cvxAddress, _crvAddress, cvxRate, crvRate, cvxRewardFee, crvRewardFee);
    console.log('AMPH_CLAIMER: ', address(amphClaimer));
    amphToken.mint(address(amphClaimer), 1_000_000 ether); // Mint amph to start LM program

    // Initialize vault controller
    vaultController.initialize(IVaultController(address(0)), _tokens, amphClaimer, vaultDeployer, 0.01e18);

    // Deploy and initialize USDA
    usda = new USDA(_sUSDAddress);
    console.log('USDA: ', address(usda));

    // Deploy curve
    threeLines = new ThreeLines0_100(2 ether, 0.1 ether, 0.005 ether, 0.25 ether, 0.5 ether);
    console.log('THREE_LINES_0_100: ', address(threeLines));

    // Deploy CurveMaster
    curveMaster = new CurveMaster();
    console.log('CURVE_MASTER: ', address(curveMaster));

    // If custom wethOracle not set, deploy new ones
    if (_wethOracle == address(0)) {
      // Deploy uniswapRelayEthUsdc oracle relay
      uniswapRelayEthUsdc = new UniswapV3OracleRelay(7200, USDC_WETH_POOL_ADDRESS, true, 1_000_000_000_000, 1);
      console.log('UNISWAP_ETH_USDC_ORACLE: ', address(uniswapRelayEthUsdc));
      // Deploy chainlinkEth oracle relay
      chainlinkEth = new ChainlinkOracleRelay(CHAINLINK_ETH_FEED_ADDRESS, 10_000_000_000, 1, 1 hours);
      console.log('CHAINLINK_ETH_FEED: ', address(chainlinkEth));
      // Deploy anchoredViewEth relay
      anchoredViewEth = new AnchoredViewRelay(address(uniswapRelayEthUsdc), address(chainlinkEth), 20, 100, 10, 100);
      console.log('ANCHORED_VIEW_RELAY: ', address(anchoredViewEth));
      _wethOracle = address(anchoredViewEth);
    }

    // Add curveMaster to VaultController
    vaultController.registerCurveMaster(address(curveMaster));
    // Set VaultController address for usda
    usda.addVaultController(address(vaultController));
    // Register WETH as acceptable erc20 to vault controller
    vaultController.registerErc20(
      address(_wethAddress), WETH_LTV, _wethOracle, LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );
    // Register USDA
    vaultController.registerUSDA(address(usda));
    // Set curve
    curveMaster.setCurve(address(0), address(threeLines));
    // Set pauser
    usda.setPauser(_deployer);

    if (_giveOwnershipToGov) {
      _changeOwnership(
        _deployer, address(governor), amphToken, vaultController, amphClaimer, usda, curveMaster, chainlinkEth
      );
    }

    vm.stopBroadcast();
  }

  function _addFakeCurveLP(
    MintableToken _cvx,
    MintableToken _crv,
    FakeBooster fakeBooster,
    address _fakeLpReceiver
  ) internal {
    // Deploy for convex rewards
    FakeWethOracle fakeRewardsOracle1 = new FakeWethOracle();
    fakeRewardsOracle1.setPrice(500 * 1e18);

    MintableToken fakeLp1 = new MintableToken('FakeLP1');
    fakeLp1.mint(_fakeLpReceiver, 1_000_000 ether);
    uint256 _oneEther = 1 ether;
    uint256 _rewardsPerSecond = _oneEther / 3600; // 1 token per hour
    console.log('FAKE_BOOSTER: ', address(fakeBooster));
    console.log('CRV: ', address(_crv));
    console.log('FAKE_LP', address(fakeLp1));

    FakeBaseRewardPool fakeBaseRewardPool1 =
      new FakeBaseRewardPool(address(fakeBooster), _crv, _rewardsPerSecond, address(fakeLp1));

    _crv.mint(address(fakeBaseRewardPool1), 1_000_000_000 ether);

    uint256 _pid = fakeBooster.addPoolInfo(address(fakeLp1), address(fakeBaseRewardPool1));

    // Add cvx rewards
    console.log('CVX', address(_cvx));
    FakeVirtualRewardsPool fakeVirtualRewardsPool =
      new FakeVirtualRewardsPool(fakeBaseRewardPool1, _cvx, _rewardsPerSecond);

    _cvx.mint(address(fakeVirtualRewardsPool), 1_000_000_000 ether);

    fakeBaseRewardPool1.addExtraReward(fakeVirtualRewardsPool);

    for (uint256 i = 0; i < 3; i++) {
      // Add extra rewards
      MintableToken _fakeRewardsToken = new MintableToken(string.concat('FakeRewardsToken', Strings.toString(i+1)));
      console.log(string.concat('FAKE_REWARDS_TOKEN', Strings.toString(i + 1)), ': ', address(_fakeRewardsToken));
      FakeVirtualRewardsPool fakeExtraVirtualRewardsPool =
        new FakeVirtualRewardsPool(fakeBaseRewardPool1, _fakeRewardsToken, _rewardsPerSecond * (i + 2));

      _fakeRewardsToken.mint(address(fakeExtraVirtualRewardsPool), 1_000_000_000 ether);

      fakeBaseRewardPool1.addExtraReward(fakeExtraVirtualRewardsPool);
    }

    // Register curveLP token
    vaultController.registerErc20(
      address(fakeLp1), WETH_LTV, address(fakeRewardsOracle1), LIQUIDATION_INCENTIVE, type(uint256).max, _pid
    );
  }

  function _changeOwnership(
    address _usdaPauser,
    address _governor,
    AmphoraProtocolToken _amphToken,
    VaultController _vaultController,
    AMPHClaimer _amphClaimer,
    USDA _usda,
    CurveMaster _curveMaster,
    ChainlinkOracleRelay _chainlinkEth
  ) internal {
    //AMPH
    _amphToken.transferOwnership(_governor);
    //vault controller
    _vaultController.transferOwnership(_governor);
    //amph claimer
    _amphClaimer.transferOwnership(_governor);
    //usda
    //TODO: Pauser powers should remain in a wallet controller by team for fast reaction but ownership is for gov
    _usda.setPauser(_usdaPauser);
    _usda.transferOwnership(_governor);
    //curveMaster
    _curveMaster.transferOwnership(_governor);
    //chainlinkEth
    if (address(_chainlinkEth) != address(0)) _chainlinkEth.transferOwnership(_governor);
  }
}

contract DeployMainnet is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_MAINNNET_PRIVATE_KEY'));

  function run() external {
    _deploy(
      deployer,
      IERC20(CVX_ADDRESS),
      IERC20(CRV_ADDRESS),
      IERC20(SUSD_ADDRESS),
      IERC20(WETH_ADDRESS),
      BOOSTER,
      address(0),
      true
    );
  }
}

contract DeployGoerli is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_GOERLI_PRIVATE_KEY'));

  function run() external {
    _deploy(
      deployer,
      IERC20(CVX_ADDRESS),
      IERC20(CRV_ADDRESS),
      IERC20(SUSD_ADDRESS),
      IERC20(WETH_ADDRESS),
      BOOSTER,
      address(0),
      true
    );
  }
}

contract DeploySepolia is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_SEPOLIA_PRIVATE_KEY'));
  address wethSepolia = 0xf531B8F309Be94191af87605CfBf600D71C2cFe0;

  function run() external {
    vm.startBroadcast(deployer);
    MintableToken cvx = new MintableToken('CVX');
    MintableToken crv = new MintableToken('CRV');
    FakeBooster fakeBooster = new FakeBooster();

    // Deploy a copy of sUSDA
    MintableToken susdCopy = new MintableToken('sUSD');
    susdCopy.mint(deployer, 1_000_000 ether);
    console.log('sUSD_COPY: ', address(susdCopy));

    // Deploy FakeWethOracle
    FakeWethOracle fakeWethOracle = new FakeWethOracle();
    console.log('FAKE_WETH_ORACLE: ', address(fakeWethOracle));
    vm.stopBroadcast();

    _deploy(
      deployer, cvx, crv, susdCopy, IERC20(address(wethSepolia)), address(fakeBooster), address(fakeWethOracle), false
    );

    vm.startBroadcast(deployer);
    _addFakeCurveLP(cvx, crv, fakeBooster, deployer);
    vm.stopBroadcast();
  }
}

contract DeployLocal is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_ANVIL_LOCAL_PRIVATE_KEY'));

  function run() external {
    _deploy(
      deployer,
      IERC20(CVX_ADDRESS),
      IERC20(CRV_ADDRESS),
      IERC20(SUSD_ADDRESS),
      IERC20(WETH_ADDRESS),
      BOOSTER,
      address(0),
      true
    );
  }
}
