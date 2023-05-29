// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {console} from 'forge-std/console.sol';

import {UniswapV3OracleRelay} from '@contracts/periphery/oracles/UniswapV3OracleRelay.sol';
import {UniswapV3TokenOracleRelay} from '@contracts/periphery/oracles/UniswapV3TokenOracleRelay.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/oracles/ChainlinkOracleRelay.sol';
import {AnchoredViewRelay} from '@contracts/periphery/oracles/AnchoredViewRelay.sol';
import {StableCurveLpOracle} from '@contracts/periphery/oracles/StableCurveLpOracle.sol';
import {EthSafeStableCurveOracle} from '@contracts/periphery/oracles/EthSafeStableCurveOracle.sol';

import {CTokenOracle} from '@contracts/periphery/oracles/CTokenOracle.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

import {TestConstants} from '@test/utils/TestConstants.sol';

abstract contract CreateOracles is TestConstants {
  uint32 public constant TWO_HOURS = 2 hours;
  uint32 public constant ONE_HOUR = 1 hours;
  uint32 public constant ONE_DAY = 24 hours;
  uint256 public constant SIX_DECIMALS_MUL_DIV = 1e12;
  uint256 public constant EIGHT_DECIMALS_MUL_DIV = 1e10;

  function _createEthUsdcTokenOracleRelay() internal returns (address _ethUsdcTokenOracleRelay) {
    // Deploy uniswapRelayEthUsdc oracle relay
    UniswapV3OracleRelay _uniswapRelayEthUsdc =
      new UniswapV3OracleRelay(TWO_HOURS, USDC_WETH_POOL_ADDRESS, true, SIX_DECIMALS_MUL_DIV, 1);
    console.log('UNISWAP_ETH_USDC_ORACLE: ', address(_uniswapRelayEthUsdc));
    _ethUsdcTokenOracleRelay = address(_uniswapRelayEthUsdc);
  }

  function _createWethOracle(UniswapV3OracleRelay _uniswapRelayEthUsdc) internal returns (address _wethOracle) {
    // Deploy chainlinkEth oracle relay
    ChainlinkOracleRelay _chainlinkEth =
      new ChainlinkOracleRelay(CHAINLINK_ETH_FEED_ADDRESS, EIGHT_DECIMALS_MUL_DIV, 1, ONE_HOUR);
    console.log('CHAINLINK_ETH_FEED: ', address(_chainlinkEth));
    // Deploy anchoredViewEth relay
    AnchoredViewRelay _anchoredViewEth =
      new AnchoredViewRelay(address(_uniswapRelayEthUsdc), address(_chainlinkEth), 20, 100, 10, 100);
    console.log('ANCHORED_VIEW_RELAY: ', address(_anchoredViewEth));
    _wethOracle = address(_anchoredViewEth);
  }

  function _createUsdtOracle() internal returns (address _usdtOracle) {
    // Deploy uniswapRelayUsdtUsdc oracle relay
    UniswapV3OracleRelay _uniswapRelayUsdtUsdc = new UniswapV3OracleRelay(TWO_HOURS, USDT_USDC_POOL_ADDRESS, true, 1, 1);
    console.log('UNISWAP_USDT_USDC_ORACLE: ', address(_uniswapRelayUsdtUsdc));
    // Deploy chainlinkUsdt oracle relay
    ChainlinkOracleRelay _chainlinkUsdt =
      new ChainlinkOracleRelay(CHAINLINK_USDT_FEED_ADDRESS, EIGHT_DECIMALS_MUL_DIV, 1, ONE_DAY);
    console.log('CHAINLINK_USDT_FEED: ', address(_chainlinkUsdt));
    // Deploy anchoredViewUsdt relay
    AnchoredViewRelay _anchoredViewUsdt =
      new AnchoredViewRelay(address(_uniswapRelayUsdtUsdc), address(_chainlinkUsdt), 20, 100, 10, 100);
    console.log('ANCHORED_VIEW_RELAY: ', address(_anchoredViewUsdt));
    _usdtOracle = address(_anchoredViewUsdt);
  }

  function _createUsdcOracle() internal returns (address _usdcOracle) {
    // Deploy uniswapRelayUsdcUsdt oracle relay
    UniswapV3OracleRelay _uniswapRelayUsdcUsdt =
      new UniswapV3OracleRelay(TWO_HOURS, USDC_USDT_POOL_ADDRESS, false, 1, 1);
    console.log('UNISWAP_USDC_USDT_ORACLE: ', address(_uniswapRelayUsdcUsdt));
    // Deploy chainlinkUsdc oracle relay
    ChainlinkOracleRelay _chainlinkUsdc =
      new ChainlinkOracleRelay(CHAINLINK_USDC_FEED_ADDRESS, EIGHT_DECIMALS_MUL_DIV, 1, ONE_DAY);
    console.log('CHAINLINK_USDC_FEED: ', address(_chainlinkUsdc));
    // Deploy anchoredViewUsdc relay
    AnchoredViewRelay _anchoredViewUsdt =
      new AnchoredViewRelay(address(_uniswapRelayUsdcUsdt), address(_chainlinkUsdc), 20, 100, 10, 100);
    console.log('ANCHORED_VIEW_RELAY: ', address(_anchoredViewUsdt));
    _usdcOracle = address(_anchoredViewUsdt);
  }

  function _createDaiOracle() internal returns (address _daiOracle) {
    // Deploy uniswapRelayDaiUsdc oracle relay
    UniswapV3OracleRelay _uniswapRelayDaiUsdc =
      new UniswapV3OracleRelay(TWO_HOURS, DAI_USDC_POOL_ADDRESS, false, SIX_DECIMALS_MUL_DIV, 1);
    console.log('UNISWAP_DAI_USDC_ORACLE: ', address(_uniswapRelayDaiUsdc));
    // Deploy _chainlinkDai oracle relay
    ChainlinkOracleRelay _chainlinkDai =
      new ChainlinkOracleRelay(CHAINLINK_DAI_FEED_ADDRESS, EIGHT_DECIMALS_MUL_DIV, 1, ONE_HOUR);
    console.log('CHAINLINK_DAI_FEED: ', address(_chainlinkDai));
    // Deploy anchoredViewDai relay
    AnchoredViewRelay _anchoredViewDai =
      new AnchoredViewRelay(address(_uniswapRelayDaiUsdc), address(_chainlinkDai), 20, 100, 10, 100);
    console.log('ANCHORED_VIEW_RELAY: ', address(_anchoredViewDai));
    _daiOracle = address(_anchoredViewDai);
  }

  function _createCETHOracle(IOracleRelay _anchoredViewEth) internal returns (address _cETHOracleAddress) {
    CTokenOracle _cETHOracle = new CTokenOracle(cETH_ADDRESS, _anchoredViewEth);
    console.log('CTOKEN_ORACLE_ETH: ', address(_cETHOracle));
    _cETHOracleAddress = address(_cETHOracle);
  }

  function _createCUSDCOracle(IOracleRelay _anchoredViewUsdc) internal returns (address _cUSDCOracleAddress) {
    CTokenOracle _cUSDCOracle = new CTokenOracle(cUSDC_ADDRESS, _anchoredViewUsdc);
    console.log('CTOKEN_ORACLE_USDC: ', address(_cUSDCOracle));
    _cUSDCOracleAddress = address(_cUSDCOracle);
  }

  function _createCDAIOracle(IOracleRelay _anchoredViewDai) internal returns (address _cDAIOracleAddress) {
    CTokenOracle _cDAIOracle = new CTokenOracle(cDAI_ADDRESS, _anchoredViewDai);
    console.log('CTOKEN_ORACLE_DAI: ', address(_cDAIOracle));
    _cDAIOracleAddress = address(_cDAIOracle);
  }

  function _createCUSDTOracle(IOracleRelay _anchoredViewUsdt) internal returns (address _cUSDTOracleAddress) {
    CTokenOracle _cUSDTOracle = new CTokenOracle(cUSDT_ADDRESS, _anchoredViewUsdt);
    console.log('CTOKEN_ORACLE_USDT: ', address(_cUSDTOracle));
    _cUSDTOracleAddress = address(_cUSDTOracle);
  }

  function _createStEthOracle(UniswapV3OracleRelay _uniswapRelayEthUsdc) internal returns (address _stEthOracle) {
    // Deploy uniswapRelayWstEthWEth oracle relay
    UniswapV3TokenOracleRelay _uniswapRelayWstEthWEth =
      new UniswapV3TokenOracleRelay(_uniswapRelayEthUsdc, TWO_HOURS, WSTETH_WETH_POOL_ADDRESS, false, 1, 1);
    console.log('UNISWAP_WSTETH_WETH_ORACLE: ', address(_uniswapRelayWstEthWEth));
    // Deploy _chainlinkStETH oracle relay
    ChainlinkOracleRelay _chainlinkStETH =
      new ChainlinkOracleRelay(CHAINLINK_STETH_USD_FEED_ADDRESS, EIGHT_DECIMALS_MUL_DIV, 1, ONE_HOUR);
    console.log('CHAINLINK_STETH_FEED: ', address(_chainlinkStETH));
    // Deploy anchoredViewStEth relay
    AnchoredViewRelay _anchoredViewStETH =
      new AnchoredViewRelay(address(_uniswapRelayWstEthWEth), address(_chainlinkStETH), 20, 100, 10, 100);
    console.log('ANCHORED_VIEW_RELAY: ', address(_anchoredViewStETH));
    _stEthOracle = address(_anchoredViewStETH);
  }

  function _createFraxOracle() internal returns (address _fraxOracle) {
    // Deploy uniswapRelayFraxUsdc oracle relay
    UniswapV3OracleRelay _uniswapRelayFraxUsdc =
      new UniswapV3OracleRelay(TWO_HOURS, FRAX_USDC_POOL_ADDRESS, false, SIX_DECIMALS_MUL_DIV, 1);
    console.log('UNISWAP_FRAX_USDC_ORACLE: ', address(_uniswapRelayFraxUsdc));
    // Deploy _chainlinkFrax oracle relay
    ChainlinkOracleRelay _chainlinkFrax =
      new ChainlinkOracleRelay(CHAINLINK_FRAX_FEED_ADDRESS, EIGHT_DECIMALS_MUL_DIV, 1, ONE_HOUR);
    console.log('CHAINLINK_FRAX_FEED: ', address(_chainlinkFrax));
    // Deploy anchoredViewFrax relay
    AnchoredViewRelay _anchoredViewFrax =
      new AnchoredViewRelay(address(_uniswapRelayFraxUsdc), address(_chainlinkFrax), 20, 100, 10, 100);
    console.log('ANCHORED_VIEW_RELAY: ', address(_anchoredViewFrax));
    _fraxOracle = address(_anchoredViewFrax);
  }

  function _createSteCrvOracle(
    address _crvPool,
    IOracleRelay _stEthAnchorOracle,
    IOracleRelay _wethAnchorOracle
  ) internal returns (address _steCrvLpOracleAddress) {
    IOracleRelay[] memory _anchoredUnderlyingTokens = new IOracleRelay[](2);
    _anchoredUnderlyingTokens[0] = _stEthAnchorOracle;
    _anchoredUnderlyingTokens[1] = _wethAnchorOracle;

    EthSafeStableCurveOracle _steCrvLpOracle = new EthSafeStableCurveOracle(_crvPool, _anchoredUnderlyingTokens);
    _steCrvLpOracleAddress = address(_steCrvLpOracle);
    console.log('STE_CRV_ORACLE: ', _steCrvLpOracleAddress);
  }

  function _createFraxCrvOracle(
    address _crvPool,
    IOracleRelay _fraxAnchorOracle,
    IOracleRelay _usdcAnchorOracle
  ) internal returns (address _fraxCrvLpOracleAddress) {
    IOracleRelay[] memory _anchoredUnderlyingTokens = new IOracleRelay[](2);
    _anchoredUnderlyingTokens[0] = _fraxAnchorOracle;
    _anchoredUnderlyingTokens[1] = _usdcAnchorOracle;

    StableCurveLpOracle _fraxCrvLpOracle = new StableCurveLpOracle(_crvPool, _anchoredUnderlyingTokens);
    _fraxCrvLpOracleAddress = address(_fraxCrvLpOracle);
    console.log('CRV_FRAX_ORACLE: ', _fraxCrvLpOracleAddress);
  }

  function _create3CrvOracle(
    address _crvPool,
    IOracleRelay _daiAnchorOracle,
    IOracleRelay _usdtAnchorOracle,
    IOracleRelay _usdcAnchorOracle
  ) internal returns (address _3CrvOracleAddress) {
    IOracleRelay[] memory _anchoredUnderlyingTokens = new IOracleRelay[](3);
    _anchoredUnderlyingTokens[0] = _daiAnchorOracle;
    _anchoredUnderlyingTokens[1] = _usdtAnchorOracle;
    _anchoredUnderlyingTokens[2] = _usdcAnchorOracle;

    StableCurveLpOracle _3CrvOracle = new StableCurveLpOracle(_crvPool, _anchoredUnderlyingTokens);
    _3CrvOracleAddress = address(_3CrvOracle);
    console.log('3_CRV_ORACLE: ', _3CrvOracleAddress);
  }

  function _createFrax3CrvOracle(
    address _crvPool,
    IOracleRelay _fraxAnchorOracle,
    IOracleRelay _daiAnchorOracle,
    IOracleRelay _usdtAnchorOracle,
    IOracleRelay _usdcAnchorOracle
  ) internal returns (address _frax3CrvOracleAddress) {
    IOracleRelay[] memory _anchoredUnderlyingTokens = new IOracleRelay[](4);
    _anchoredUnderlyingTokens[0] = _fraxAnchorOracle;
    _anchoredUnderlyingTokens[1] = _daiAnchorOracle;
    _anchoredUnderlyingTokens[2] = _usdtAnchorOracle;
    _anchoredUnderlyingTokens[3] = _usdcAnchorOracle;

    StableCurveLpOracle _frax3CrvOracle = new StableCurveLpOracle(_crvPool, _anchoredUnderlyingTokens);
    _frax3CrvOracleAddress = address(_frax3CrvOracle);
    console.log('FRAX_3_CRV_ORACLE: ', _frax3CrvOracleAddress);
  }
}
