// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {AggregatorV2V3Interface} from '@chainlink/interfaces/AggregatorV2V3Interface.sol';
import {ICurvePool} from '@interfaces/utils/ICurvePool.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {FixedPointMathLib} from 'solady/utils/FixedPointMathLib.sol';
import {ChainlinkStalePriceLib} from '@contracts/periphery/oracles/ChainlinkStalePriceLib.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

/// @notice Oracle Relay for the TriCrypto pool (USDT/WBTC/WETH)
contract TriCryptoOracle is OracleRelay, Ownable {
  /// @notice Emitted when the amount is zero
  error TriCryptoOracle_ZeroAmount();

  address public constant POOL = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46;
  AggregatorV2V3Interface public constant BTC_FEED = AggregatorV2V3Interface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);

  AggregatorV2V3Interface public constant ETH_FEED = AggregatorV2V3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
  AggregatorV2V3Interface public constant USDT_FEED =
    AggregatorV2V3Interface(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
  AggregatorV2V3Interface public constant WBTC_FEED =
    AggregatorV2V3Interface(0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23);

  uint256 public constant GAMMA0 = 28_000_000_000_000; // 2.8e-5
  uint256 public constant A0 = 2 * 3 ** 3 * 10_000;
  uint256 public constant DISCOUNT0 = 1_087_460_000_000_000; // 0.00108..

  ICurvePool public constant TRI_CRYPTO = ICurvePool(POOL);

  uint256 public btcStaleDelay = 1 hours;
  uint256 public ethStaleDelay = 1 hours;
  uint256 public usdtStaleDelay = 1 days;
  uint256 public wbtcStaleDelay = 1 days;

  constructor() OracleRelay(OracleType.Chainlink) {}

  /// @notice The current reported value of the oracle
  /// @dev Implementation in _get
  /// @return _value The current value
  function currentValue() external view override returns (uint256 _value) {
    _value = _get();
  }

  /// @notice Sets the stale delay for the BTC feed
  /// @param _delay The new delay
  function setBtcStaleDelay(uint256 _delay) external onlyOwner {
    if (_delay == 0) revert TriCryptoOracle_ZeroAmount();
    btcStaleDelay = _delay;
  }

  /// @notice Sets the stale delay for the ETH feed
  /// @param _delay The new delay
  function setEthStaleDelay(uint256 _delay) external onlyOwner {
    if (_delay == 0) revert TriCryptoOracle_ZeroAmount();
    ethStaleDelay = _delay;
  }

  /// @notice Sets the stale delay for the USDT feed
  /// @param _delay The new delay
  function setUsdtStaleDelay(uint256 _delay) external onlyOwner {
    if (_delay == 0) revert TriCryptoOracle_ZeroAmount();
    usdtStaleDelay = _delay;
  }

  /// @notice Sets the stale delay for the WBTC feed
  /// @param _delay The new delay
  function setWbtcStaleDelay(uint256 _delay) external onlyOwner {
    if (_delay == 0) revert TriCryptoOracle_ZeroAmount();
    wbtcStaleDelay = _delay;
  }

  /// @notice Calculated the price of 1 LP token
  /// @dev This function comes from the implementation in vyper that is on the bottom
  /// @return _maxPrice The current value
  function _get() internal view returns (uint256 _maxPrice) {
    uint256 _vp = TRI_CRYPTO.get_virtual_price();

    // Get the prices from chainlink and add 10 decimals
    // TODO: need to be added as anchor oracler, stale delay is set in ChainlinkOracleRelay
    uint256 _btcPrice = (ChainlinkStalePriceLib.getCurrentPrice(BTC_FEED)) * 1e10;
    uint256 _wbtcPrice = (ChainlinkStalePriceLib.getCurrentPrice(WBTC_FEED)) * 1e10;
    uint256 _ethPrice = (ChainlinkStalePriceLib.getCurrentPrice(ETH_FEED)) * 1e10;
    uint256 _usdtPrice = (ChainlinkStalePriceLib.getCurrentPrice(USDT_FEED)) * 1e10;

    uint256 _minWbtcPrice = (_wbtcPrice < 1e18) ? (_wbtcPrice * _btcPrice) / 1e18 : _btcPrice;

    uint256 _basePrices = (_minWbtcPrice * _ethPrice * _usdtPrice);

    _maxPrice = (3 * _vp * FixedPointMathLib.cbrt(_basePrices)) / 1 ether;
    // removed discount since the % is so small that it doesn't make a difference
  }

  /*///////////////////////////////////////////////////////////////
                            VYPER IMPLEMENTATION
  //////////////////////////////////////////////////////////////*/

  // @external
  // @view
  // def lp_price() -> uint256:
  //     vp: uint256 = Tricrypto(POOL).virtual_price()
  //     p1: uint256 = convert(Chainlink(BTC_FEED).latestAnswer() * 10**10, uint256)
  //     p2: uint256 = convert(Chainlink(ETH_FEED).latestAnswer() * 10**10, uint256)
  //     max_price: uint256 = 3 * vp * self.cubic_root(p1 * p2) / 10**18
  //     # ((A/A0) * (gamma/gamma0)**2) ** (1/3)
  //     g: uint256 = Tricrypto(POOL).gamma() * 10**18 / GAMMA0
  //     a: uint256 = Tricrypto(POOL).A() * 10**18 / A0
  //     discount: uint256 = max(g**2 / 10**18 * a, 10**34)  # handle qbrt nonconvergence
  //     # if discount is small, we take an upper bound
  //     discount = self.cubic_root(discount) * DISCOUNT0 / 10**18
  //     max_price -= max_price * discount / 10**18
  //     return max_price
}
