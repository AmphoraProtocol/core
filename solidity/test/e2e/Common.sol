// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {console} from 'forge-std/console.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';

import {VaultController} from '@contracts/core/VaultController.sol';
import {CappedToken} from '@contracts/utils/CappedToken.sol';
import {USDA} from '@contracts/core/USDA.sol';
import {AmphoraProtocolTokenDelegate} from '@contracts/governance/TokenDelegate.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/ChainlinkOracleRelay.sol';
import {AnchoredViewRelay} from '@contracts/periphery/AnchoredViewRelay.sol';
import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';
import {OracleMaster} from '@contracts/periphery/OracleMaster.sol';
import {UniswapV3OracleRelay} from '@contracts/periphery/UniswapV3OracleRelay.sol';
import {UniswapV3TokenOracleRelay} from '@contracts/periphery/UniswapV3TokenOracleRelay.sol';
import {ThreeLines0_100} from '@contracts/utils/ThreeLines0_100.sol';

import {IWUSDA} from '@interfaces/core/IWUSDA.sol';
import {IVault} from '@interfaces/core/IVault.sol';

import {IVote} from '@contracts/_external/IVote.sol';
import {TestConstants} from '@test/utils/TestConstants.sol';

// solhint-disable-next-line max-states-count
contract CommonE2EBase is DSTestPlus, TestConstants {
  uint256 public constant FORK_BLOCK = 15452788;

  // AMPH token
  AmphoraProtocolTokenDelegate public amphToken;
  // USDA token
  USDA public usdaToken;
  // VaultControllers
  VaultController public vaultController;
  // Capped Token
  CappedToken public aaveCappedToken;
  CappedToken public dydxCappedToken;
  // Curve Master and ThreeLines0_100 curve
  CurveMaster public curveMaster;
  ThreeLines0_100 public threeLines;
  // Oracle Master
  OracleMaster public oracleMaster;
  // uniswapv3 oracles
  UniswapV3OracleRelay public uniswapRelayEthUsdc;
  UniswapV3OracleRelay public uniswapRelayUniUsdc;
  UniswapV3TokenOracleRelay public uniswapRelayAaveWeth;
  // Chainlink oracles
  ChainlinkOracleRelay public chainLinkUni;
  ChainlinkOracleRelay public chainlinkEth;
  ChainlinkOracleRelay public chainlinkAave;
  // AnchoredView relayers
  AnchoredViewRelay public anchoredViewEth;
  AnchoredViewRelay public anchoredViewUni;
  AnchoredViewRelay public anchoredViewAave;

  IWUSDA public wusda;
  IERC20 public susd = IERC20(label(SUSD_ADDRESS, 'SUSD'));
  IERC20 public weth = IERC20(label(WETH_ADDRESS, 'WETH'));
  IVote public uni = IVote(label(UNI_ADDRESS, 'UNI'));
  IVote public aave = IVote(label(AAVE_ADDRESS, 'AAVE'));
  IVote public dydx = IVote(label(DYDX_ADDRESS, 'DYDX'));

  // frank is the Frank and master of USDA, and symbolizes the power of governance
  address public frank = label(newAddress(), 'frank');
  // andy is a susd holder. He wishes to deposit his sUSD to hold USDA
  address public andy = label(newAddress(), 'andy');
  // bob is an eth holder. He wishes to deposit his eth and borrow USDA
  address public bob = label(newAddress(), 'bob');
  // carol is a uni holder. She wishes to deposit uni and borrow USDA, and still be able to vote
  address public carol = label(newAddress(), 'carol');
  // dave is a liquidator. he enjoys liquidating, so he's going to try to liquidate Bob
  address public dave = label(newAddress(), 'dave');
  // eric only holds ETH and generally does not use AP unless a clean slate is needed
  address public eric = label(newAddress(), 'eric');
  // gus is a wBTC holder. He wishes to deposit wBTC and borrow USDA
  address public gus = label(newAddress(), 'gus');
  // hector is also here
  address public hector = label(newAddress(), 'hector');

  IVault public bobVault;
  uint256 public bobVaultId;

  IVault public carolVault;
  uint256 public carolVaultId;

  IVault public daveVault;
  uint256 public daveVaultId;

  IVault public gusVault;

  uint256 public andySUSDBalance = 100_000_000;
  uint256 public bobSUSDBalance = 1_000_000_000;
  uint256 public bobWETH = 10 ether;
  uint256 public carolUni = 100 ether;
  uint256 public gusWBTC = 1_000_000_000;
  uint256 public daveSUSD = 10_000_000_000_000_000;
  uint256 public bobAAVE = 1000 ether;
  uint256 public carolDYDX = 100 ether;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

    // Transfer some susd, weth and uni to users
    deal(address(susd), andy, andySUSDBalance);
    deal(address(susd), dave, daveSUSD);
    deal(address(susd), bob, bobSUSDBalance);
    deal(address(weth), bob, bobWETH);
    deal(address(uni), carol, carolUni);
    deal(address(aave), bob, bobAAVE);
    deal(address(dydx), carol, carolDYDX);

    vm.startPrank(frank);
    // Deploy VaultController
    vaultController = new VaultController();
    label(address(vaultController), 'VaultController');
    vaultController.initialize();

    // Deploy and initialize USDA
    usdaToken = new USDA();
    label(address(usdaToken), 'USDA');
    usdaToken.initialize(SUSD_ADDRESS);

    // Deploy curve
    threeLines = new ThreeLines0_100(2 ether, 0.05 ether, 0.045 ether, 0.5 ether, 0.55 ether);
    label(address(threeLines), 'ThreeLines0_100');

    // Deploy CurveMaster
    curveMaster = new CurveMaster();
    label(address(curveMaster), 'CurveMaster');

    // Deploy OracleMaster
    oracleMaster = new OracleMaster();
    label(address(oracleMaster), 'OracleMaster');

    // Deploy AAVE capped Token
    aaveCappedToken = new CappedToken();
    label(address(aaveCappedToken), 'aaveCappedToken');
    aaveCappedToken.initialize('CappedAave', 'cAave', AAVE_ADDRESS);

    // Add curveMaster to VaultController
    vaultController.registerCurveMaster(address(curveMaster));

    // Add oracleMaster to VaultController
    vaultController.registerOracleMaster(address(oracleMaster));

    // Set VaultController address for usdatoken
    usdaToken.addVaultController(address(vaultController));

    // Deploy uniswapRelayEthUsdc oracle relay
    uniswapRelayEthUsdc = new UniswapV3OracleRelay(60, USDC_WETH_POOL_ADDRESS, true, 1_000_000_000_000, 1);
    // Deploy uniswapRelayUniUsdc oracle relay
    uniswapRelayUniUsdc = new UniswapV3OracleRelay(60, USDC_UNI_POOL_ADDRESS, true, 1_000_000_000_000, 1);
    // Deploy uniswapRelayUniUsdc oracle relay
    uniswapRelayAaveWeth = new UniswapV3TokenOracleRelay(60, AAVE_WETH_POOL_ADDRESS, false, 1, 1);
    // Deploy chainLinkUni oracle relay
    chainLinkUni = new ChainlinkOracleRelay(CHAINLINK_UNI_FEED_ADDRESS, 10_000_000_000, 1);
    // Deploy chainlinkEth oracle relay
    chainlinkEth = new ChainlinkOracleRelay(CHAINLINK_ETH_FEED_ADDRESS, 10_000_000_000, 1);
    // Deploy chainlinkEth oracle relay
    chainlinkAave = new ChainlinkOracleRelay(CHAINLINK_AAVE_FEED_ADDRESS, 10_000_000_000, 1);
    // Deploy anchoredViewEth relay
    anchoredViewEth = new AnchoredViewRelay(address(uniswapRelayEthUsdc), address(chainlinkEth), 10, 100);
    // Deploy anchoredViewEth relay
    anchoredViewUni = new AnchoredViewRelay(address(uniswapRelayUniUsdc), address(chainLinkUni), 30, 100);
    // Deploy anchoredViewEth relay
    anchoredViewAave = new AnchoredViewRelay(address(uniswapRelayAaveWeth), address(chainlinkAave), 10, 100);

    // Set first relay for oracle master
    oracleMaster.setRelay(UNI_ADDRESS, address(anchoredViewUni));
    // Set second relay for oracle master
    oracleMaster.setRelay(WETH_ADDRESS, address(anchoredViewEth));
    // Set second relay for oracle master
    oracleMaster.setRelay(address(aaveCappedToken), address(anchoredViewAave));

    // Register WETH as acceptable erc20 to vault controller
    vaultController.registerErc20(WETH_ADDRESS, WETH_LTV, WETH_ADDRESS, LIQUIDATION_INCENTIVE);
    // Register UNI as acceptable erc20 to vault controller
    vaultController.registerErc20(UNI_ADDRESS, UNI_LTV, UNI_ADDRESS, LIQUIDATION_INCENTIVE);
    // Register cAAVE as acceptable erc20 to vault controller
    vaultController.registerErc20(address(aaveCappedToken), AAVE_LTV, address(aaveCappedToken), LIQUIDATION_INCENTIVE);
    // Register USDA as acceptable erc20 to vault controller
    vaultController.registerUSDA(address(usdaToken));

    // Set new curve
    curveMaster.setCurve(address(0), address(threeLines));

    // Set pauser
    usdaToken.setPauser(address(frank));

    // TODO: add checks for everything being set
    vm.stopPrank();
  }

  function _mintVault(address _minter) internal returns (uint256 _id) {
    vm.prank(_minter);
    vaultController.mintVault();
    _id = vaultController.vaultsMinted();
  }

  function _borrow(address _account, uint256 _vaultId, uint256 _borrowAmount) internal {
    vm.prank(_account);
    vaultController.borrowUSDA(uint96(_vaultId), uint192(_borrowAmount));
  }

  function _depositSUSD(address _account, uint256 _amountToDeposit) internal {
    vm.startPrank(_account);
    susd.approve(address(usdaToken), _amountToDeposit);
    usdaToken.deposit(_amountToDeposit);
    vm.stopPrank();
  }
}
