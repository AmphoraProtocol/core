// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IChainlinkOracleRelay {
  /// @notice An event emitted when the stale price delay is set
  event StalePriceDelaySet(uint256 _oldStalePriceDelay, uint256 _newStalePriceDelay);

  /// @notice Returns True if the oracle is stale
  function isStale() external view returns (bool _stale);

  /// @notice Sets the stale price delay
  /// @param _stalePriceDelay The new stale price delay
  /// @dev Only the owner can call this function
  function setStalePriceDelay(uint256 _stalePriceDelay) external;
}
