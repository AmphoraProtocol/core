// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';

/// @title implementation of compounds' AnchoredView
/// @notice using a main relay and an anchor relay, the AnchoredView
/// ensures that the main relay's price is within some amount of the anchor relay price
/// if not, the call reverts, effectively disabling the oracle & any actions which require it
contract AnchoredViewRelay is OracleRelay {
  address public anchorAddress;
  IOracleRelay public anchorRelay;

  address public mainAddress;
  IOracleRelay public mainRelay;

  uint256 public widthNumerator;
  uint256 public widthDenominator;

  /// @notice all values set at construction time
  /// @param _anchorAddress address of OracleRelay to use as anchor
  /// @param _mainAddress address of OracleRelay to use as main
  /// @param _widthNumerator numerator of the allowable deviation width
  /// @param _widthDenominator denominator of the allowable deviation width
  constructor(
    address _anchorAddress,
    address _mainAddress,
    uint256 _widthNumerator,
    uint256 _widthDenominator
  ) OracleRelay(IOracleRelay(_mainAddress).oracleType()) {
    anchorAddress = _anchorAddress;
    anchorRelay = IOracleRelay(_anchorAddress);

    mainAddress = _mainAddress;
    mainRelay = IOracleRelay(_mainAddress);

    widthNumerator = _widthNumerator;
    widthDenominator = _widthDenominator;
  }

  /// @notice returns current value of oracle
  /// @return _value current value of oracle
  /// @dev implementation in getLastSecond
  function currentValue() external view override returns (uint256 _value) {
    return _getLastSecond();
  }

  /// @notice compares the main value (chainlink) to the anchor value (uniswap v3)
  /// @notice the two prices must closely match +-buffer, or it will revert
  /// @return _mainValue current value of oracle
  function _getLastSecond() private view returns (uint256 _mainValue) {
    // get the main price
    _mainValue = mainRelay.currentValue();
    require(_mainValue > 0, 'invalid oracle value');

    uint256 _anchorPrice = anchorRelay.currentValue();
    require(_anchorPrice > 0, 'invalid anchor value');

    // calculate buffer
    uint256 _buffer = (widthNumerator * _anchorPrice) / widthDenominator;

    // create upper and lower bounds
    uint256 _upperBounds = _anchorPrice + _buffer;
    uint256 _lowerBounds = _anchorPrice - _buffer;

    // ensure the anchor price is within bounds
    require(_mainValue < _upperBounds, 'anchor too low');
    require(_mainValue > _lowerBounds, 'anchor too high');
  }
}
