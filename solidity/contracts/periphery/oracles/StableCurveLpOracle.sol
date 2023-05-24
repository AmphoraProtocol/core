// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {ICurvePool} from '@interfaces/utils/ICurvePool.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

/// @notice Oracle Relay for crv lps
contract StableCurveLpOracle is OracleRelay, Ownable {
  /// @notice Thrown when there are too few anchored oracles
  error StableCurveLpOracle_TooFewAnchoredOracles();

  /// @notice The pool of the crv lp token
  ICurvePool public immutable CRV_POOL;
  /// @notice The anchor oracles of the underlying tokens
  IOracleRelay[] public anchoredUnderlyingTokens;

  constructor(address _crvPool, IOracleRelay[] memory _anchoredUnderlyingTokens) OracleRelay(OracleType.Chainlink) {
    if (_anchoredUnderlyingTokens.length < 2) revert StableCurveLpOracle_TooFewAnchoredOracles();
    CRV_POOL = ICurvePool(_crvPool);
    for (uint256 _i; _i < _anchoredUnderlyingTokens.length;) {
      anchoredUnderlyingTokens.push(_anchoredUnderlyingTokens[_i]);

      unchecked {
        ++_i;
      }
    }
  }

  /// @notice The current reported value of the oracle
  /// @dev Implementation in _get()
  /// @return _value The current value
  function currentValue() external view override returns (uint256 _value) {
    _value = _get();
  }

  /// @notice Calculates the lastest exchange rate
  function _get() internal view returns (uint256 _value) {
    // As the price should never be negative, the unchecked conversion is acceptable
    uint256 _minStable = anchoredUnderlyingTokens[0].currentValue();
    for (uint256 _i = 1; _i < anchoredUnderlyingTokens.length;) {
      _minStable = Math.min(_minStable, anchoredUnderlyingTokens[_i].currentValue());
      unchecked {
        ++_i;
      }
    }

    uint256 _lpPrice = CRV_POOL.get_virtual_price() * _minStable;

    _value = _lpPrice / 1e18;
  }
}
