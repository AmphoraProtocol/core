// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

/// @title AnchoredViewRelay Interface
interface IAnchoredViewRelay {
  /// @notice returns the price with 18 decimals
  /// @return _currentValue the current price
  function currentValue() external view returns (uint256 _currentValue);

  /// @notice The interface of the anchor relay
  /// @return _anchorRelay the address of the anchor relay
  function anchorRelay() external view returns (IOracleRelay _anchorRelay);

  /// @notice The interface of the main relay
  /// @return _mainRelay the address of the main relay
  function mainRelay() external view returns (IOracleRelay _mainRelay);
}
