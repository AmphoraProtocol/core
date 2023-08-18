// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ICTokenOracle {
  /// @notice An event emitted when the underlying oracle is changed
  event AnchoredViewChanged(address indexed _oldAnchoredView, address indexed _newAnchoredView);

  /// @notice Change the underlying oracle
  /// @param _anchoredViewUnderlying The new underlying oracle
  function changeAnchoredView(address _anchoredViewUnderlying) external;
}
