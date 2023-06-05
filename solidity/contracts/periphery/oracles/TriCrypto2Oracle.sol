// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {IV2Pool} from '@interfaces/utils/ICurvePool.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {FixedPointMathLib} from 'solady/utils/FixedPointMathLib.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {CurveRegistryUtils} from '@contracts/periphery/oracles/CurveRegistryUtils.sol';

/// @notice Oracle Relay for the TriCrypto pool (USDT/WBTC/WETH)
contract TriCrypto2Oracle is OracleRelay, CurveRegistryUtils, Ownable {
  /// @notice Emitted when the amount is zero
  error TriCryptoOracle_ZeroAmount();

  IV2Pool public immutable TRI_CRYPTO;
  IOracleRelay public immutable WBTC_ORACLE_RELAY;
  IOracleRelay public immutable ETH_ORACLE_RELAY;
  IOracleRelay public immutable USDT_ORACLE_RELAY;

  constructor(
    address _triCryptoPool,
    IOracleRelay _ethOracleRelay,
    IOracleRelay _usdtOracleRelay,
    IOracleRelay _wbtcOracleRelay
  ) OracleRelay(OracleType.Chainlink) {
    TRI_CRYPTO = IV2Pool(_triCryptoPool);
    WBTC_ORACLE_RELAY = _wbtcOracleRelay;
    ETH_ORACLE_RELAY = _ethOracleRelay;
    USDT_ORACLE_RELAY = _usdtOracleRelay;

    _setUnderlying(_getLpAddress(_triCryptoPool));
  }

  /// @notice The current reported value of the oracle
  /// @dev Implementation in _get
  /// @return _value The current value
  function peekValue() public view override returns (uint256 _value) {
    _value = _get();
  }

  /// @notice Calculated the price of 1 LP token
  /// @dev This function comes from the implementation in vyper that is on the bottom
  /// @return _maxPrice The current value
  function _get() internal view returns (uint256 _maxPrice) {
    uint256 _vp = TRI_CRYPTO.get_virtual_price();

    // Get the prices from chainlink and add 10 decimals
    // TODO: need to be added as anchor oracler, stale delay is set in ChainlinkOracleRelay
    uint256 _wbtcPrice = (WBTC_ORACLE_RELAY.peekValue());
    uint256 _ethPrice = (ETH_ORACLE_RELAY.peekValue());
    uint256 _usdtPrice = (USDT_ORACLE_RELAY.peekValue());

    uint256 _basePrices = (_wbtcPrice * _ethPrice * _usdtPrice);

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
