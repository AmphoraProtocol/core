// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IGovernorCharlieEvents} from '@interfaces/governance/IGovernorCharlieEvents.sol';
import {IAMPH} from '@interfaces/governance/IAMPH.sol';

import {Receipt, ProposalState, Proposal} from '@contracts/utils/GovernanceStructs.sol';

interface IGovernorCharlie is IGovernorCharlieEvents {
  /*///////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when called by non governor
  error GovernorCharlie_NotGovernorCharlie();

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
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

  function quorumVotes() external view returns (uint256 _quorumVotes);

  function emergencyQuorumVotes() external view returns (uint256 _emergencyQuorumVotes);

  function votingDelay() external view returns (uint256 _votingDelay);

  function votingPeriod() external view returns (uint256 _votingPeriod);

  function proposalThreshold() external view returns (uint256 _proposalThreshold);

  function initialProposalId() external view returns (uint256 _initialProposalId);

  function proposalCount() external view returns (uint256 _proposalCount);

  function amph() external view returns (IAMPH _amph);

  function latestProposalIds(address _proposer) external returns (uint256 _proposerId);

  function queuedTransactions(bytes32 _transaction) external returns (bool _isQueued);

  function proposalTimelockDelay() external view returns (uint256 _proposalTimelockDelay);

  function whitelistAccountExpirations(address _account) external returns (uint256 _expiration);

  function whitelistGuardian() external view returns (address _guardian);

  function emergencyVotingPeriod() external view returns (uint256 _emergencyVotingPeriod);

  function emergencyTimelockDelay() external view returns (uint256 _emergencyTimelockDelay);

  function optimisticQuorumVotes() external view returns (uint256 _optimisticQuorumVotes);

  function optimisticVotingDelay() external view returns (uint256 _optimisticVotingDelay);

  function maxWhitelistPeriod() external view returns (uint256 _maxWhitelistPeriod);

  function timelock() external view returns (address _timelock);

  function delay() external view returns (uint256 _delay);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
    //////////////////////////////////////////////////////////////*/

  function propose(
    address[] memory _targets,
    uint256[] memory _values,
    string[] memory _signatures,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _proposalId);

  function proposeEmergency(
    address[] memory _targets,
    uint256[] memory _values,
    string[] memory _signatures,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _proposalId);

  function queue(uint256 _proposalId) external;

  function execute(uint256 _proposalId) external payable;

  function executeTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external payable;

  function cancel(uint256 _proposalId) external;

  function getActions(uint256 _proposalId)
    external
    view
    returns (
      address[] memory _targets,
      uint256[] memory _values,
      string[] memory _signatures,
      bytes[] memory _calldatas
    );

  function getProposal(uint256 _proposalId) external view returns (Proposal memory _proposal);

  function getReceipt(uint256 _proposalId, address _voter) external view returns (Receipt memory _receipt);

  function state(uint256 _proposalId) external view returns (ProposalState _proposalState);

  function castVote(uint256 _proposalId, uint8 _support) external;

  function castVoteWithReason(uint256 _proposalId, uint8 _support, string calldata _reason) external;

  function castVoteBySig(uint256 _proposalId, uint8 _support, uint8 _v, bytes32 _r, bytes32 _s) external;

  function isWhitelisted(address _account) external view returns (bool _isWhitelisted);

  function setDelay(uint256 _delay) external;

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
