// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IGovernorCharlieEvents} from '@interfaces/governance/IGovernorCharlieEvents.sol';
import {Receipt, ProposalState, Proposal} from '@contracts/utils/GovernanceStructs.sol';

interface IGovernorCharlieDelegate is IGovernorCharlieEvents {
  /*///////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when the contract is already initialized
  error GovernorCharlie_AlreadyInitialized();

  /// @notice Thrown when called by non governor
  error GovernorCharlie_NotGovernor();

  /// @notice Thrown when charlie is not active
  error GovernorCharlie_NotActive();

  /// @notice Thrown when votes are below the threshold
  error GovernorCharlie_VotesBelowThreshold();

  /// @notice Thrown when actions where not provided
  error GovernorCharlie_NoActions();

  /// @notice Thrown when too many actions
  error GovernorCharlie_TooManyActions();

  /// @notice Thrown when trying to create more than one active proposal per proposal
  error GovernorCharlie_MultipleActiveProposals();

  /// @notice Thrown when there is more than one pending proposal per proposer
  error GovernorCharlie_MultiplePendingProposals();

  /// @notice Thrown when there is information arity mismatch
  error GovernorCharlie_ArityMismatch();

  /// @notice Thrown when trying to queue a proposal that is not in the Succeeded state
  error GovernorCharlie_ProposalNotSucceeded();

  /// @notice Thrown when trying to queue an already queued proposal
  error GovernorCharlie_ProposalAlreadyQueued();

  /// @notice Thrown when delay has not been reached yet
  error GovernorCharlie_DelayNotReached();

  /// @notice Thrown when trying to execute a proposal that was not queued
  error GovernorCharlie_ProposalNotQueued();

  /// @notice Thrown when trying to execute a proposal that hasn't reached its timelock
  error GovernorCharlie_TimelockNotReached();

  /// @notice Thrown when trying to execute a transaction that is stale
  error GovernorCharlie_TransactionStale();

  /// @notice Thrown when transaction execution reverted
  error GovernorCharlie_TransactionReverted();

  /// @notice Thrown when trying to cancel a proposal that was already execute
  error GovernorCharlie_ProposalAlreadyExecuted();

  /// @notice Thrown when trying to cancel a whitelisted proposer's proposal
  error GovernorCharlie_WhitelistedProposer();

  /// @notice Thrown when proposal is above threshold
  error GovernorCharlie_ProposalAboveThreshold();

  /// @notice Thrown when received an invalid proposal id
  error GovernorCharlie_InvalidProposalId();

  /// @notice Thrown when trying to cast a vote with an invalid signature
  error GovernorCharlie_InvalidSignature();

  /// @notice Thrown when voting is closed
  error GovernorCharlie_VotingClosed();

  /// @notice Thrown when invalid vote type
  error GovernorCharlie_InvalidVoteType();

  /// @notice Thrown when voter already voted
  error GovernorCharlie_AlreadyVoted();

  /// @notice Thrown when expiration exceeds max
  error GovernorCharlie_ExpirationExceedsMax();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
    //////////////////////////////////////////////////////////////*/

  function initialize(address _amph) external;

  function propose(
    address[] memory _targets,
    uint256[] memory _values,
    string[] memory _signatures,
    bytes[] memory _calldatas,
    string memory _description,
    bool _emergency
  ) external returns (uint256 _proposalId);

  function queue(uint256 _proposalId) external;

  function execute(uint256 _proposalId) external payable;

  function executeTransaction(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external payable;

  function cancel(uint256 _proposalId) external;

  function getActions(
    uint256 _proposalId
  ) external view returns (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas);

  function getReceipt(uint256 _proposalId, address _voter) external view returns (Receipt memory _receipt);

  function state(uint256 _proposalId) external view returns (ProposalState _proposalState);

  function castVote(uint256 _proposalId, uint8 _support) external;

  function castVoteWithReason(uint256 _proposalId, uint8 _support, string calldata _reason) external;

  function castVoteBySig(uint256 _proposalId, uint8 _support, uint8 _v, bytes32 _r, bytes32 _s) external;

  function isWhitelisted(address _account) external view returns (bool _isWhitelisted);

  function setDelay(uint256 _proposalTimelockDelay) external;

  function setEmergencyDelay(uint256 _emergencyTimelockDelay) external;

  function setVotingDelay(uint256 _newVotingDelay) external;

  function setVotingPeriod(uint256 _newVotingPeriod) external;

  function setEmergencyVotingPeriod(uint256 _newEmergencyVotingPeriod) external;

  function setProposalThreshold(uint256 _newProposalThreshold) external;

  function setQuorumVotes(uint256 _newQuorumVotes) external;

  function setEmergencyQuorumVotes(uint256 _newEmergencyQuorumVotes) external;

  function setWhitelistAccountExpiration(address _account, uint256 _expiration) external;

  function setWhitelistGuardian(address _account) external;

  function setOptimisticDelay(uint256 _newOptimisticVotingDelay) external;

  function setOptimisticQuorumVotes(uint256 _newOptimisticQuorumVotes) external;
}
