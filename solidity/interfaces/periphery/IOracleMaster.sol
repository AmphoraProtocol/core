// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title OracleMaster Interface
/// @notice Interface for interacting with OracleMaster
interface IOracleMaster {
  /// @notice Get the live price of a token
  /// @param _tokenAddress the address of the token
  /// @return _livePrice the live price of the token
  function getLivePrice(address _tokenAddress) external view returns (uint256 _livePrice);

  /// @notice Sets the relay address
  /// @param _tokenAddress the address of the token
  /// @param _relayAddress the address of the relay
  function setRelay(address _tokenAddress, address _relayAddress) external;
}
