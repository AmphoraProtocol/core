// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

/// @title interface which contains all events emitted by delegator & delegate
interface ITokenEvents {
  /// @notice An event thats emitted when an account changes its delegate
  event DelegateChanged(address indexed _delegator, address indexed _fromDelegate, address indexed _toDelegate);

  /// @notice An event thats emitted when a delegate account's vote balance changes
  event DelegateVotesChanged(address indexed _delegate, uint256 _previousBalance, uint256 _newBalance);

  /// @notice An event thats emitted when the minter changes
  event MinterChanged(address indexed _oldMinter, address indexed _newMinter);

  /// @notice The standard EIP-20 transfer event
  event Transfer(address indexed _from, address indexed _to, uint256 _amount);

  /// @notice The standard EIP-20 approval event
  event Approval(address indexed _owner, address indexed _spender, uint256 _amount);

  /// @notice Emitted when implementation is changed
  event NewImplementation(address _oldImplementation, address _newImplementation);

  /// @notice An event thats emitted when the token symbol is changed
  event ChangedSymbol(string _oldSybmol, string _newSybmol);

  /// @notice An event thats emitted when the token name is changed
  event ChangedName(string _oldName, string _newName);
}
