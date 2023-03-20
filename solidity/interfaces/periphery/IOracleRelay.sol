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
  function currentValue() external view returns (uint256 _currentValue);

  /// @notice returns the type of the oracle
  /// @return _type the type (Chainlink/Uniswap/Price)
  function oracleType() external view returns (OracleType _type);
}
