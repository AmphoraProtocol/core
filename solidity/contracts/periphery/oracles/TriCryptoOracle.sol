// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {AggregatorInterface} from '@chainlink/interfaces/AggregatorInterface.sol';
import {ICurvePool} from '@interfaces/utils/ICurvePool.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {FixedPointMathLib} from 'solady/utils/FixedPointMathLib.sol';

/// @notice Oracle Relay for the TriCrypto pool (USDT/WBTC/WETH)
contract TriCryptoOracle is OracleRelay {
  address public constant POOL = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46;
  AggregatorInterface public constant BTC_FEED = AggregatorInterface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
  AggregatorInterface public constant ETH_FEED = AggregatorInterface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
  AggregatorInterface public constant USDT_FEED = AggregatorInterface(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
  AggregatorInterface public constant WBTC_FEED = AggregatorInterface(0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23);

  uint256 public constant GAMMA0 = 28_000_000_000_000; // 2.8e-5
  uint256 public constant A0 = 2 * 3 ** 3 * 10_000;
  uint256 public constant DISCOUNT0 = 1_087_460_000_000_000; // 0.00108..

  ICurvePool public constant TRI_CRYPTO = ICurvePool(POOL);

  constructor() OracleRelay(OracleType.Chainlink) {}

  /// @notice The current reported value of the oracle
  /// @dev Implementation in _get
  /// @return _value The current value
  function currentValue() external view override returns (uint256 _value) {
    _value = _get();
  }

  /// @notice Calculated the price of 1 LP token
  /// @dev This function comes from the implementation in vyper that is on the bottom
  /// @return _maxPrice The current value
  function _get() internal view returns (uint256 _maxPrice) {
    uint256 _vp = TRI_CRYPTO.get_virtual_price();

    // Get the prices from chainlink and add 10 decimals
    uint256 _btcPrice = uint256(BTC_FEED.latestAnswer()) * 1e10;
    uint256 _wbtcPrice = uint256(WBTC_FEED.latestAnswer()) * 1e10;
    uint256 _ethPrice = uint256(ETH_FEED.latestAnswer()) * 1e10;
    uint256 _usdtPrice = uint256(USDT_FEED.latestAnswer()) * 1e10;

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
