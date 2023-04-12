// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {AggregatorInterface} from '@chainlink/interfaces/AggregatorInterface.sol';

/// @notice Oracle that wraps a chainlink oracle.
///         The oracle returns (chainlinkPrice) * mul / div
contract ChainlinkOracleRelay is OracleRelay {
  /// @notice emitted when the oracle price is less than zero
  error ChainlinkOracle_PriceLessThanZero();

  AggregatorInterface private immutable _AGGREGATOR;

  uint256 public immutable MULTIPLY;
  uint256 public immutable DIVIDE;

  /// @notice All values set at construction time
  /// @param  _feedAddress The address of chainlink feed
  /// @param _mul The numerator of scalar
  /// @param _div The denominator of scalar
  constructor(address _feedAddress, uint256 _mul, uint256 _div) OracleRelay(OracleType.Chainlink) {
    _AGGREGATOR = AggregatorInterface(_feedAddress);
    MULTIPLY = _mul;
    DIVIDE = _div;
  }

  /// @notice The current reported value of the oracle
  /// @dev Implementation in getLastSecond
  /// @return _value The current value
  function currentValue() external view override returns (uint256 _value) {
    return _getLastSecond();
  }

  /// @notice Returns last second value of the oracle
  /// @return _value The last second value of the oracle
  function _getLastSecond() private view returns (uint256 _value) {
    int256 _latest = _AGGREGATOR.latestAnswer();
    if (_latest <= 0) revert ChainlinkOracle_PriceLessThanZero();
    _value = (uint256(_latest) * MULTIPLY) / DIVIDE;
  }
}
