// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {ChainlinkStalePriceLib} from '@contracts/periphery/oracles/ChainlinkStalePriceLib.sol';
import {AggregatorV2V3Interface} from '@chainlink/interfaces/AggregatorV2V3Interface.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

/// @notice Oracle that wraps a chainlink oracle.
///         The oracle returns (chainlinkPrice) * mul / div
contract ChainlinkOracleRelay is OracleRelay, Ownable {
  /// @notice Emitted when the amount is zero
  error ChainlinkOracle_ZeroAmount();

  AggregatorV2V3Interface private immutable _AGGREGATOR;

  uint256 public immutable MULTIPLY;
  uint256 public immutable DIVIDE;

  uint256 public stalePriceDelay;

  /// @notice All values set at construction time
  /// @param  _feedAddress The address of chainlink feed
  /// @param _mul The numerator of scalar
  /// @param _div The denominator of scalar
  constructor(
    address _feedAddress,
    uint256 _mul,
    uint256 _div,
    uint256 _stalePriceDelay
  ) OracleRelay(OracleType.Chainlink) {
    _AGGREGATOR = AggregatorV2V3Interface(_feedAddress);
    MULTIPLY = _mul;
    DIVIDE = _div;
    stalePriceDelay = _stalePriceDelay;
  }

  /// @notice The current reported value of the oracle
  /// @dev Implementation in getLastSecond
  /// @return _value The current value
  function currentValue() external view override returns (uint256 _value) {
    return _getLastSecond();
  }

  /// @notice Sets the stale price delay
  /// @param _stalePriceDelay The new stale price delay
  /// @dev Only the owner can call this function
  function setStalePriceDelay(uint256 _stalePriceDelay) external onlyOwner {
    if (_stalePriceDelay == 0) revert ChainlinkOracle_ZeroAmount();
    stalePriceDelay = _stalePriceDelay;
  }

  /// @notice Returns last second value of the oracle
  /// @return _value The last second value of the oracle
  function _getLastSecond() private view returns (uint256 _value) {
    uint256 _latest = ChainlinkStalePriceLib.getCurrentPrice(_AGGREGATOR, stalePriceDelay);
    _value = (uint256(_latest) * MULTIPLY) / DIVIDE;
  }
}
