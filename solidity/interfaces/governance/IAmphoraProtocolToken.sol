// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import {ITokenEvents} from '@interfaces/governance/ITokenEvents.sol';

/// @title interface to interact with TokenDelgate
interface IAmphoraProtocolToken is ITokenEvents {
  /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when already initialized
  error TokenDelegate_AlreadyInitialized();

  /// @notice Thrown when invalid address
  error TokenDelegate_InvalidAddress();

  /// @notice Thrown when invalid supply
  error TokenDelegate_InvalidSupply();

  /// @notice Thrown when overflow
  error TokenDelegate_Overflow();

  /// @notice Thrown when invalid length
  error TokenDelegate_InvalidLength();

  /// @notice Thrown when invalid signature
  error TokenDelegate_InvalidSignature();

  /// @notice Thrown when signature expired
  error TokenDelegate_SignatureExpired();

  /// @notice Thrown when invalid nonce
  error TokenDelegate_InvalidNonce();

  /// @notice Thrown when votes can't be determined
  error TokenDelegate_CannotDetermineVotes();

  /// @notice Thrown when zero address used
  error TokenDelegate_ZeroAddress();

  /// @notice Thrown when transfer exceeds balance
  error TokenDelegate_TransferExceedsBalance();

  /*///////////////////////////////////////////////////////////////
                            STRUCT
    //////////////////////////////////////////////////////////////*/
  /// @notice A checkpoint for marking number of votes from a given block
  struct Checkpoint {
    uint32 fromBlock;
    uint96 votes;
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/

  function changeName(string calldata _name) external;

  function changeSymbol(string calldata _symbol) external;

  function allowance(address _account, address _spender) external view returns (uint256 _allowance);

  function approve(address _spender, uint256 _rawAmount) external returns (bool _success);

  function balanceOf(address _account) external view returns (uint256 _balance);

  function transfer(address _dst, uint256 _rawAmount) external returns (bool _success);

  function transferFrom(address _src, address _dst, uint256 _rawAmount) external returns (bool _success);

  function mint(address _dst, uint256 _rawAmount) external;

  function permit(
    address _owner,
    address _spender,
    uint256 _rawAmount,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external;

  function delegate(address _delegatee) external;

  function delegateBySig(
    address _delegatee,
    uint256 _nonce,
    uint256 _expiry,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external;

  function getCurrentVotes(address _account) external view returns (uint96 _votes);

  function getPriorVotes(address _account, uint256 _blockNumber) external view returns (uint96 _votes);
}
