// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {console} from 'forge-std/console.sol';

import {UniswapV3OracleRelay} from '@contracts/periphery/oracles/UniswapV3OracleRelay.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/oracles/ChainlinkOracleRelay.sol';
import {AnchoredViewRelay} from '@contracts/periphery/oracles/AnchoredViewRelay.sol';
import {CTokenOracle} from '@contracts/periphery/oracles/CTokenOracle.sol';
import {TestConstants} from '@test/utils/TestConstants.sol';

abstract contract CreateOracles is TestConstants {
  uint32 public constant TWO_HOURS = 2 hours;
  uint32 public constant ONE_HOUR = 1 hours;
  uint32 public constant ONE_DAY = 24 hours;
  uint256 public constant SIX_DECIMALS_MUL_DIV = 1e12;
  uint256 public constant EIGHT_DECIMALS_MUL_DIV = 1e10;

  function _createWethOracle() internal returns (address _wethOracle) {
    // Deploy uniswapRelayEthUsdc oracle relay
    UniswapV3OracleRelay _uniswapRelayEthUsdc =
      new UniswapV3OracleRelay(TWO_HOURS, USDC_WETH_POOL_ADDRESS, true, SIX_DECIMALS_MUL_DIV, 1);
    console.log('UNISWAP_ETH_USDC_ORACLE: ', address(_uniswapRelayEthUsdc));
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

  function _createCETHOracle(address _anchoredViewEth) internal returns (address _cETHOracleAddress) {
    CTokenOracle _cETHOracle = new CTokenOracle(cETH_ADDRESS, _anchoredViewEth);
    console.log('CTOKEN_ORACLE_ETH: ', address(_cETHOracle));
    _cETHOracleAddress = address(_cETHOracle);
  }

  function _createCUSDCOracle(address _anchoredViewUsdc) internal returns (address _cUSDCOracleAddress) {
    CTokenOracle _cUSDCOracle = new CTokenOracle(cUSDC_ADDRESS, _anchoredViewUsdc);
    console.log('CTOKEN_ORACLE_USDC: ', address(_cUSDCOracle));
    _cUSDCOracleAddress = address(_cUSDCOracle);
  }

  function _createCDAIOracle(address _anchoredViewDai) internal returns (address _cDAIOracleAddress) {
    CTokenOracle _cDAIOracle = new CTokenOracle(cDAI_ADDRESS, _anchoredViewDai);
    console.log('CTOKEN_ORACLE_DAI: ', address(_cDAIOracle));
    _cDAIOracleAddress = address(_cDAIOracle);
  }

  function _createCUSDTOracle(address _anchoredViewUsdt) internal returns (address _cUSDTOracleAddress) {
    CTokenOracle _cUSDTOracle = new CTokenOracle(cUSDT_ADDRESS, _anchoredViewUsdt);
    console.log('CTOKEN_ORACLE_USDT: ', address(_cUSDTOracle));
    _cUSDTOracleAddress = address(_cUSDTOracle);
  }
}
