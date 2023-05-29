// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title OracleRelay Interface
/// @notice Interface for interacting with OracleRelay
interface IOracleRelay {
  enum OracleType {
    Chainlink,
    Uniswap,
    Price
  }

  /// @notice returns the price with 18 decimals
  /// @return _currentValue the current price
  function currentValue() external returns (uint256 _currentValue);

  /// @notice returns the price with 18 decimals without any state changes
  /// @dev some oracles require a state change to get the exact current price.
  ///      This is updated when calling other state changing functions that query the price
  /// @return _price the current price
  function peekValue() external view returns (uint256 _price);

  /// @notice returns the type of the oracle
  /// @return _type the type (Chainlink/Uniswap/Price)
  function oracleType() external view returns (OracleType _type);
}
