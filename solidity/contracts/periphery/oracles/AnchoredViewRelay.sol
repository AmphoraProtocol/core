// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {IChainlinkOracleRelay} from '@interfaces/periphery/IChainlinkOracleRelay.sol';

/// @notice Implementation of compounds' AnchoredView, using a main relay and an anchor relay, the AnchoredView
/// ensures that the main relay's price is within some amount of the anchor relay price
/// if not, the call reverts, effectively disabling the oracle & any actions which require it
contract AnchoredViewRelay is OracleRelay {
  address public anchorAddress;
  IOracleRelay public anchorRelay;

  address public mainAddress;
  IOracleRelay public mainRelay;

  uint256 public widthNumerator;
  uint256 public widthDenominator;

  uint256 public staleWidthNumerator;
  uint256 public staleWidthDenominator;

  /// @notice All values set at construction time
  /// @param _anchorAddress The address of OracleRelay to use as anchor
  /// @param _mainAddress The address of OracleRelay to use as main
  /// @param _widthNumerator The numerator of the allowable deviation width
  /// @param _widthDenominator The denominator of the allowable deviation width
  /// @param _widthNumerator The numerator of the allowable deviation width for the stale price
  /// @param _widthDenominator The denominator of the allowable deviation width for the stale price
  constructor(
    address _anchorAddress,
    address _mainAddress,
    uint256 _widthNumerator,
    uint256 _widthDenominator,
    uint256 _staleWidthNumerator,
    uint256 _staleWidthDenominator
  ) OracleRelay(IOracleRelay(_mainAddress).oracleType()) {
    anchorAddress = _anchorAddress;
    anchorRelay = IOracleRelay(_anchorAddress);

    mainAddress = _mainAddress;
    mainRelay = IOracleRelay(_mainAddress);

    widthNumerator = _widthNumerator;
    widthDenominator = _widthDenominator;

    staleWidthNumerator = _staleWidthNumerator;
    staleWidthDenominator = _staleWidthDenominator;
  }

  /// @notice Returns current value of oracle
  /// @dev Implementation in getLastSecond
  /// @return _value The current value of oracle
  function currentValue() external view override returns (uint256 _value) {
    _value = _getLastSecond();
  }

  /// @notice Compares the main value (chainlink) to the anchor value (uniswap v3)
  /// @dev The two prices must closely match +-buffer, or it will revert
  /// @return _mainValue The current value of oracle
  function _getLastSecond() private view returns (uint256 _mainValue) {
    // get the main price
    _mainValue = mainRelay.currentValue();
    require(_mainValue > 0, 'invalid oracle value');

    uint256 _anchorPrice = anchorRelay.currentValue();
    require(_anchorPrice > 0, 'invalid anchor value');

    uint256 _buffer;
    if (IChainlinkOracleRelay(mainAddress).isStale()) {
      /// If the price is stale the range percentage is smaller
      _buffer = (staleWidthNumerator * _anchorPrice) / staleWidthDenominator;
    } else {
      _buffer = (widthNumerator * _anchorPrice) / widthDenominator;
    }

    // create upper and lower bounds
    uint256 _upperBounds = _anchorPrice + _buffer;
    uint256 _lowerBounds = _anchorPrice - _buffer;

    // ensure the anchor price is within bounds
    require(_mainValue < _upperBounds, 'anchor too low');
    require(_mainValue > _lowerBounds, 'anchor too high');
  }
}
