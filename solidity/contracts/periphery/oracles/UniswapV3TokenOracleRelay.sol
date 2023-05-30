// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import {OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {IUniswapV3PoolDerivedState} from '@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol';
import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {UniswapV3OracleRelay} from '@contracts/periphery/oracles/UniswapV3OracleRelay.sol';

/// @notice Oracle that wraps a univ3 pool
/// @dev This oracle is for tokens that do not have a stable Uniswap V3 pair against sUSD
///      If QUOTE_TOKEN_IS_TOKEN0 == true, then the reciprocal is returned
///      quote_token refers to the token we are comparing to, so for an Aave price in ETH, Aave is the target and Eth is the quote
contract UniswapV3TokenOracleRelay is OracleRelay {
  /// @notice Thrown when the tick time diff fails
  error UniswapV3OracleRelay_TickTimeDiffTooLarge();

  UniswapV3OracleRelay public immutable ETH_ORACLE;

  bool public immutable QUOTE_TOKEN_IS_TOKEN0;

  IUniswapV3PoolDerivedState public immutable POOL;

  uint32 public immutable LOOKBACK;
  uint256 public immutable MUL;
  uint256 public immutable DIV;

  /// @notice All values set at construction time
  /// @param _ethOracle The uniswap oracle for ethusdc
  /// @param _lookback How many seconds to twap for
  /// @param _poolAddress The address of uniswap feed
  /// @param _quoteTokenIsToken0 Boolean, true if eth is token 0, or false if eth is token 1
  /// @param _mul The numerator of scalar
  /// @param _div The denominator of scalar
  constructor(
    UniswapV3OracleRelay _ethOracle,
    uint32 _lookback,
    address _poolAddress,
    bool _quoteTokenIsToken0,
    uint256 _mul,
    uint256 _div
  ) OracleRelay(OracleType.Uniswap) {
    ETH_ORACLE = _ethOracle;
    LOOKBACK = _lookback;
    MUL = _mul;
    DIV = _div;
    QUOTE_TOKEN_IS_TOKEN0 = _quoteTokenIsToken0;
    POOL = IUniswapV3PoolDerivedState(_poolAddress);

    _setUnderlying(_quoteTokenIsToken0 ? IUniswapV3Pool(_poolAddress).token1() : IUniswapV3Pool(_poolAddress).token0());
  }

  function peekValue() public view virtual override returns (uint256 _price) {
    _price = _get();
  }

  /// @notice Returns the current reported value of the oracle
  /// @dev Implementation in _getLastSeconds
  /// @return _usdPrice The price in USD terms
  function _get() internal view returns (uint256 _usdPrice) {
    uint256 _priceInEth = _getLastSeconds(LOOKBACK);

    //get price of eth to convert _priceInEth to USD terms
    uint256 _ethPrice = ETH_ORACLE.peekValue();

    _usdPrice = (_ethPrice * _priceInEth) / 1e18;
  }

  /// @notice Returns last second value of the oracle
  /// @param _tickTimeDifference How many seconds to twap for
  /// @return _price The last second value of the oracle
  function _getLastSeconds(uint32 _tickTimeDifference) private view returns (uint256 _price) {
    int56[] memory _tickCumulatives;
    uint32[] memory _input = new uint32[](2);
    _input[0] = _tickTimeDifference;
    _input[1] = 0;

    (_tickCumulatives,) = POOL.observe(_input);

    int56 _tickCumulativeDifference = _tickCumulatives[0] - _tickCumulatives[1];
    bool _tickNegative = _tickCumulativeDifference < 0;

    uint56 _tickAbs;

    if (_tickNegative) _tickAbs = uint56(-_tickCumulativeDifference);
    else _tickAbs = uint56(_tickCumulativeDifference);

    uint56 _bigTick = _tickAbs / _tickTimeDifference;
    if (_bigTick >= 887_272) revert UniswapV3OracleRelay_TickTimeDiffTooLarge();
    int24 _tick;
    if (_tickNegative) _tick = -int24(int56(_bigTick));
    else _tick = int24(int56(_bigTick));

    // we use 1e18 bc this is what we're going to use in exp
    // basically, you need the '_price' amount of the quote in order to buy 1 base
    // or, 1 base is worth this much quote;

    _price = (1e9 * ((uint256(TickMath.getSqrtRatioAtTick(_tick))))) / (2 ** (2 * 48));

    _price = _price * _price;

    if (!QUOTE_TOKEN_IS_TOKEN0) _price = (1e18 * 1e18) / _price;

    _price = (_price * MUL) / DIV;
  }
}
