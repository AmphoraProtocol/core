// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title OracleRelay Interface
/// @notice Interface for interacting with OracleRelay
interface IOracleRelay {
  /// @notice returns the price with 18 decimals
  /// @return _currentValue the current price
  function currentValue() external view returns (uint256 _currentValue);
}
