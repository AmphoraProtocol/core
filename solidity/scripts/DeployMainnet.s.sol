// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {
  Deploy,
  DeployVars,
  AmphoraProtocolToken,
  VaultController,
  VaultDeployer,
  AMPHClaimer,
  USDA,
  CurveMaster,
  IOwnable,
  IAnchoredViewRelay,
  console
} from '@scripts/Deploy.s.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {UniswapV3OracleRelay} from '@contracts/periphery/oracles/UniswapV3OracleRelay.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/oracles/ChainlinkOracleRelay.sol';
import {CTokenOracle} from '@contracts/periphery/oracles/CTokenOracle.sol';
import {GovernorCharlie} from '@contracts/governance/GovernorCharlie.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {ChainlinkTokenOracleRelay} from '@contracts/periphery/oracles/ChainlinkTokenOracleRelay.sol';

contract DeployMainnet is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_MAINNNET_PRIVATE_KEY'));
  IOwnable[] internal _oracles;

  function run() external {
    vm.startBroadcast(deployer);
    UniswapV3OracleRelay _uniswapRelayEthUsdc = UniswapV3OracleRelay(_createEthUsdcTokenOracleRelay());
    ChainlinkOracleRelay _chainlinkEth = ChainlinkOracleRelay(_createEthUsdChainlinkOracleRelay());
    // Deploy weth oracle first, can be removed if the user defines a valid oracle address
    address _wethOracle = _createWethOracle(_uniswapRelayEthUsdc, _chainlinkEth);

    DeployVars memory _deployVars = DeployVars(
      deployer,
      IERC20(CVX_ADDRESS),
      IERC20(CRV_ADDRESS),
      IERC20(SUSD_V3_ADDRESS),
      IERC20(WETH_ADDRESS),
      BOOSTER,
      _wethOracle,
      false
    );

    // Deploy protocol
    (
      AmphoraProtocolToken _amphToken,
      GovernorCharlie _governor,
      VaultController _vaultController,
      ,
      AMPHClaimer _amphClaimer,
      USDA _usda,
      CurveMaster _curveMaster
    ) = _deploy(_deployVars);

    // Deploy simple oracles
    IOracleRelay _daiAnchorOracle = IOracleRelay(_createDaiOracle());
    IOracleRelay _usdtAnchorOracle = IOracleRelay(_createUsdtOracle());
    IOracleRelay _usdcAnchorOracle = IOracleRelay(_createUsdcOracle());
    _oracles.push(IOwnable(address(IAnchoredViewRelay(address(_wethOracle)).mainRelay())));
    _oracles.push(IOwnable(address(IAnchoredViewRelay(address(_daiAnchorOracle)).mainRelay())));
    _oracles.push(IOwnable(address(IAnchoredViewRelay(address(_usdtAnchorOracle)).mainRelay())));
    _oracles.push(IOwnable(address(IAnchoredViewRelay(address(_usdcAnchorOracle)).mainRelay())));

    {
      // Add 3pool
      address _3poolOracle =
        _create3CrvOracle(THREE_CRV_POOL_ADDRESS, _daiAnchorOracle, _usdtAnchorOracle, _usdcAnchorOracle);
      _vaultController.registerErc20(
        THREE_CRV_LP_ADDRESS, LTV_60, _3poolOracle, LIQUIDATION_INCENTIVE, type(uint256).max, 9
      );
    }

    {
      // Add tricrypto2
      IOracleRelay _wbtcAnchorOracle = IOracleRelay(_createWbtcOracle(_uniswapRelayEthUsdc));
      ChainlinkTokenOracleRelay _chainlinkWbtc =
        ChainlinkTokenOracleRelay(address(IAnchoredViewRelay(address(_wbtcAnchorOracle)).mainRelay()));
      _oracles.push(IOwnable(address(_chainlinkWbtc.AGGREGATOR())));
      _oracles.push(IOwnable(address(_chainlinkWbtc.BASE_AGGREGATOR())));
      address _triCrypto2Oracle =
        _createTriCrypto2Oracle(IOracleRelay(_wethOracle), _usdtAnchorOracle, _wbtcAnchorOracle);
      _vaultController.registerErc20(
        TRI_CRYPTO_LP_TOKEN, LTV_40, _triCrypto2Oracle, LIQUIDATION_INCENTIVE, type(uint256).max, 38
      );
    }

    // {
    //   // Add cbeth/eth
    //   IOracleRelay _cbEthAnchorOracle = IOracleRelay(_createCbEthOracle(_uniswapRelayEthUsdc, _chainlinkEth));
    //   ChainlinkTokenOracleRelay _chainlinkCbeth =
    //     ChainlinkTokenOracleRelay(address(IAnchoredViewRelay(address(_cbEthAnchorOracle)).mainRelay()));
    //   _oracles.push(IOwnable(address(_chainlinkCbeth.AGGREGATOR())));
    //   address _cbethEthOracle = _createCbEthEthOracle(_cbEthAnchorOracle, IOracleRelay(_wethOracle));
    //   _vaultController.registerErc20(
    //     CBETH_ETH_LP_TOKEN, LTV_30, _cbethEthOracle, LIQUIDATION_INCENTIVE, type(uint256).max, 127
    //   );
    // }

    {
      // Add 4pool
      IOracleRelay _susdAnchorOracle = IOracleRelay(_createSusdOracle());
      _oracles.push(IOwnable(address(IAnchoredViewRelay(address(_susdAnchorOracle)).mainRelay())));
      address _4poolOracle = _createSusdDaiUsdcUsdtOracle(
        SUSD_DAI_USDT_USDC_CRV_POOL_ADDRESS, _susdAnchorOracle, _daiAnchorOracle, _usdtAnchorOracle, _usdcAnchorOracle
      );
      _vaultController.registerErc20(
        SUSD_USDT_USDC_DAI_LP_TOKEN, LTV_20, _4poolOracle, LIQUIDATION_INCENTIVE, type(uint256).max, 4
      );
    }

    _changeOwnership(
      _deployVars.deployer, address(_governor), _amphToken, _vaultController, _amphClaimer, _usda, _curveMaster
    );

    _changeOwnershipOracles(address(_governor), _oracles);

    vm.stopBroadcast();
  }
}
