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

struct DeployVars {
  address deployer;
  IERC20 cvxAddress;
  IERC20 crvAddress;
  IERC20 sUSDAddress;
  IERC20 wethAddress;
  address booster;
  address wethOracle;
  bool giveOwnershipToGov;
}

abstract contract Deploy is Script, TestConstants {
  uint256 public constant initialAmphSupply = 100_000_000 ether;

  uint256 public constant cvxRate = 10 ether; // 10 AMPH per 1 CVX
  uint256 public constant crvRate = 0.5 ether; // 0.5 AMPH per 1 CVX

  uint256 public constant cvxRewardFee = 0.02 ether;
  uint256 public constant crvRewardFee = 0.01 ether;

  function _deploy(DeployVars memory _deployVars)
    internal
    returns (
      AmphoraProtocolToken _amphToken,
      GovernorCharlie _governor,
      VaultController _vaultController,
      VaultDeployer _vaultDeployer,
      AMPHClaimer _amphClaimer,
      USDA _usda
    )
  {
    address[] memory _tokens;

    // TODO: pass deployer rights to governance?
    vm.startBroadcast(_deployVars.deployer);

    // Deploy governance and amph token
    _amphToken = new AmphoraProtocolToken(_deployVars.deployer, initialAmphSupply);
    console.log('AMPHORA_TOKEN: ', address(_amphToken));
    _governor = new GovernorCharlie(address(_amphToken));
    console.log('GOVERNOR: ', address(_governor));

    // Deploy VaultController & VaultDeployer
    _vaultDeployer = new VaultDeployer(_deployVars.cvxAddress, _deployVars.crvAddress);
    console.log('VAULT_DEPLOYER: ', address(_vaultDeployer));
    _vaultController =
    new VaultController(IVaultController(address(0)), _tokens, IAMPHClaimer(address(0)), _vaultDeployer, 0.01e18, _deployVars.booster, 0.005e18);
    console.log('VAULT_CONTROLLER: ', address(_vaultController));

    // Deploy claimer
    _amphClaimer =
    new AMPHClaimer(address(_vaultController), IERC20(address(_amphToken)), _deployVars.cvxAddress, _deployVars.crvAddress, cvxRate, crvRate, cvxRewardFee, crvRewardFee);
    console.log('AMPH_CLAIMER: ', address(_amphClaimer));
    _amphToken.mint(address(_amphClaimer), 1_000_000 ether); // Mint amph to start LM program

    // Change AMPH claimer
    _vaultController.changeClaimerContract(_amphClaimer);

    // Deploy and initialize USDA
    _usda = new USDA(_deployVars.sUSDAddress);
    console.log('USDA: ', address(_usda));

    {
      // Deploy curve
      ThreeLines0_100 _threeLines = new ThreeLines0_100(2 ether, 0.1 ether, 0.005 ether, 0.25 ether, 0.5 ether);
      console.log('THREE_LINES_0_100: ', address(_threeLines));

      // Deploy CurveMaster
      CurveMaster _curveMaster = new CurveMaster();
      console.log('CURVE_MASTER: ', address(_curveMaster));
      // Set curve
      _curveMaster.setCurve(address(0), address(_threeLines));
      // Add _curveMaster to VaultController
      _vaultController.registerCurveMaster(address(_curveMaster));
    }

    // If custom wethOracle not set, deploy new ones
    if (_deployVars.wethOracle == address(0)) {
      // Deploy uniswapRelayEthUsdc oracle relay
      UniswapV3OracleRelay _uniswapRelayEthUsdc =
        new UniswapV3OracleRelay(7200, USDC_WETH_POOL_ADDRESS, true, 1_000_000_000_000, 1);
      console.log('UNISWAP_ETH_USDC_ORACLE: ', address(_uniswapRelayEthUsdc));
      // Deploy chainlinkEth oracle relay
      ChainlinkOracleRelay _chainlinkEth =
        new ChainlinkOracleRelay(CHAINLINK_ETH_FEED_ADDRESS, 10_000_000_000, 1, 1 hours);
      console.log('CHAINLINK_ETH_FEED: ', address(_chainlinkEth));
      // Deploy anchoredViewEth relay
      AnchoredViewRelay _anchoredViewEth =
        new AnchoredViewRelay(address(_uniswapRelayEthUsdc), address(_chainlinkEth), 20, 100, 10, 100);
      console.log('ANCHORED_VIEW_RELAY: ', address(_anchoredViewEth));
      _deployVars.wethOracle = address(_anchoredViewEth);
    }

    // Set VaultController address for _usda
    _usda.addVaultController(address(_vaultController));
    // Register WETH as acceptable erc20 to vault controller
    _vaultController.registerErc20(
      address(_deployVars.wethAddress), WETH_LTV, _deployVars.wethOracle, LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );
    // Register USDA
    _vaultController.registerUSDA(address(_usda));
    // Set pauser
    _usda.setPauser(_deployVars.deployer);

    // if (_giveOwnershipToGov) {
    //   _changeOwnership(
    //     _deployer, address(_governor), _amphToken, _vaultController, _amphClaimer, _usda, _curveMaster, chainlinkEth
    //   );
    // }

    vm.stopBroadcast();
  }

  /// @dev If _oracle is address(0), will deploy a new fake oracle
  /// @dev If _lpToken is address(0), will deploy a new fake lp token
  function _addFakeCurveLP(
    MintableToken _cvx,
    MintableToken _crv,
    FakeBooster fakeBooster,
    address _fakeLpReceiver,
    address _oracle,
    address _lpToken,
    VaultController _vaultController
  ) internal {
    if (_oracle == address(0)) {
      // Deploy for convex rewards
      FakeWethOracle fakeRewardsOracle1 = new FakeWethOracle();
      fakeRewardsOracle1.setPrice(500 * 1e18);
      console.log('FAKE_ORACLE_1: ', address(fakeRewardsOracle1));
      _oracle = address(fakeRewardsOracle1);
    }

    if (_lpToken == address(0)) {
      MintableToken fakeLp1 = new MintableToken('LPToken');
      fakeLp1.mint(_fakeLpReceiver, 1_000_000 ether);
      console.log('FAKE_LP', address(fakeLp1));
      _lpToken = address(fakeLp1);
    }

    uint256 _oneEther = 1 ether;
    uint256 _rewardsPerSecond = _oneEther / 3600; // 1 token per hour
    console.log('FAKE_BOOSTER: ', address(fakeBooster));
    console.log('CRV: ', address(_crv));

    FakeBaseRewardPool fakeBaseRewardPool1 =
      new FakeBaseRewardPool(address(fakeBooster), _crv, _rewardsPerSecond, address(_lpToken));

    _crv.mint(address(fakeBaseRewardPool1), 1_000_000_000 ether);

    uint256 _pid = fakeBooster.addPoolInfo(address(_lpToken), address(fakeBaseRewardPool1));

    // Add cvx rewards
    console.log('CVX', address(_cvx));
    FakeVirtualRewardsPool fakeVirtualRewardsPool =
      new FakeVirtualRewardsPool(fakeBaseRewardPool1, _cvx, _rewardsPerSecond);

    _cvx.mint(address(fakeVirtualRewardsPool), 1_000_000_000 ether);

    fakeBaseRewardPool1.addExtraReward(fakeVirtualRewardsPool);

    for (uint256 i = 0; i < 2; i++) {
      // Add extra rewards
      MintableToken _fakeRewardsToken = new MintableToken(string.concat('RewardToken', Strings.toString(i+1)));
      console.log(string.concat('REWARD_TOKEN', Strings.toString(i + 1)), ': ', address(_fakeRewardsToken));
      FakeVirtualRewardsPool fakeExtraVirtualRewardsPool =
        new FakeVirtualRewardsPool(fakeBaseRewardPool1, _fakeRewardsToken, _rewardsPerSecond * (i + 2));

      _fakeRewardsToken.mint(address(fakeExtraVirtualRewardsPool), 1_000_000_000 ether);

      fakeBaseRewardPool1.addExtraReward(fakeExtraVirtualRewardsPool);
    }

    // Register curveLP token
    _vaultController.registerErc20(
      address(_lpToken), WETH_LTV, address(_oracle), LIQUIDATION_INCENTIVE, type(uint256).max, _pid
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
    DeployVars memory _deployVars = DeployVars(
      deployer,
      IERC20(CVX_ADDRESS),
      IERC20(CRV_ADDRESS),
      IERC20(SUSD_ADDRESS),
      IERC20(WETH_ADDRESS),
      BOOSTER,
      address(0),
      true
    );

    _deploy(_deployVars);
  }
}

contract DeployGoerli is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_GOERLI_PRIVATE_KEY'));

  function run() external {
    DeployVars memory _deployVars = DeployVars(
      deployer,
      IERC20(CVX_ADDRESS),
      IERC20(CRV_ADDRESS),
      IERC20(SUSD_ADDRESS),
      IERC20(WETH_ADDRESS),
      BOOSTER,
      address(0),
      true
    );

    _deploy(_deployVars);
  }
}

contract DeployGoerliOpenDeployment is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_GOERLI_PRIVATE_KEY'));
  address public constant wethGoerli = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
  address public constant linkGoerli = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
  address public constant ethUSD = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
  address public constant linkUSD = 0x48731cF7e84dc94C5f84577882c14Be11a5B7456;

  function run() external {
    vm.startBroadcast(deployer);
    MintableToken cvx = new MintableToken('CVX');
    MintableToken crv = new MintableToken('CRV');
    FakeBooster fakeBooster = new FakeBooster();

    // Deploy a copy of sUSDA
    MintableToken susdCopy = new MintableToken('sUSD');
    susdCopy.mint(deployer, 1_000_000 ether);
    console.log('sUSD_COPY: ', address(susdCopy));

    // Chainlink ETH/USD
    ChainlinkOracleRelay _chainlinkEth = new ChainlinkOracleRelay(ethUSD, 10_000_000_000, 1, 100 days);
    console.log('CHAINLINK_ETH_FEED: ', address(_chainlinkEth));

    vm.stopBroadcast();
    DeployVars memory _deployVars =
      DeployVars(deployer, cvx, crv, susdCopy, IERC20(wethGoerli), address(fakeBooster), address(_chainlinkEth), false);
    (,, VaultController _vaultController,,, USDA _usda) = _deploy(_deployVars);

    vm.startBroadcast(deployer);
    susdCopy.approve(address(_usda), 1_000_000 ether);
    _usda.donate(500_000 ether);
    {
      // Chainlink LINK/USD
      ChainlinkOracleRelay _chainlinkLink = new ChainlinkOracleRelay(linkUSD, 10_000_000_000, 1, 100 days);
      console.log('CHAINLINK_LINK_FEED: ', address(_chainlinkLink));
      _addFakeCurveLP(cvx, crv, fakeBooster, deployer, address(_chainlinkLink), linkGoerli, _vaultController);
    }
    vm.stopBroadcast();
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

    DeployVars memory _deployVars = DeployVars(
      deployer, cvx, crv, susdCopy, IERC20(address(wethSepolia)), address(fakeBooster), address(fakeWethOracle), false
    );

    (,, VaultController _vaultController,,,) = _deploy(_deployVars);

    vm.startBroadcast(deployer);
    _addFakeCurveLP(cvx, crv, fakeBooster, deployer, address(0), address(0), _vaultController);
    vm.stopBroadcast();
  }
}

contract DeployLocal is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_ANVIL_LOCAL_PRIVATE_KEY'));

  function run() external {
    DeployVars memory _deployVars = DeployVars(
      deployer,
      IERC20(CVX_ADDRESS),
      IERC20(CRV_ADDRESS),
      IERC20(SUSD_ADDRESS),
      IERC20(WETH_ADDRESS),
      BOOSTER,
      address(0),
      true
    );

    _deploy(_deployVars);
  }
}
