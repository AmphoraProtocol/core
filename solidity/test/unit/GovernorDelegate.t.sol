// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {GovernorCharlieDelegate} from '@contracts/governance/GovernorDelegate.sol';
import {IGovernorCharlieDelegate} from '@interfaces/governance/IGovernorCharlieDelegate.sol';
import {IAMPH} from '@interfaces/governance/IAMPH.sol';
import {Proposal} from '@contracts/utils/GovernanceStructs.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';

abstract contract Base is DSTestPlus {
  GovernorCharlieDelegate public governor;
  address public implementation = label(newAddress(), 'implementation');
  address public otherImplementation = label(newAddress(), 'otherImplementation');
  address public amph = label(newAddress(), 'amph');

  event Deposit(address indexed _from, uint256 _value);
  event Withdraw(address indexed _from, uint256 _value);

  function setUp() public virtual {
    governor = new GovernorCharlieDelegate();
    vm.mockCall(amph, abi.encodeWithSelector(IAMPH.getPriorVotes.selector), abi.encode(1_000_000 ether));
  }

  function _getProposalData(uint256 _actions)
    internal
    returns (
      address[] memory _targets,
      uint256[] memory _values,
      string[] memory _signatures,
      bytes[] memory _calldatas
    )
  {
    _targets = new address[](_actions);
    _values = new uint256[](_actions);
    _signatures = new string[](_actions);
    _calldatas = new bytes[](_actions);

    for (uint256 _i; _i < _actions; _i++) {
      _targets[_i] = address(uint160(_i));
      _values[_i] = 0;
      _signatures[_i] = 'deposit(uint256)';
      _calldatas[_i] = abi.encode(_i * 1 ether);
      vm.mockCall(address(uint160(_i)), abi.encodeWithSignature('deposit(uint256)'), abi.encode(true));
    }
  }
}

contract UnitGovernorDelegateInitialize is Base {
  function testRevertsWhenTryingToInitializeAgain() public {
    governor.initialize(amph);
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_AlreadyInitialized.selector);
    governor.initialize(newAddress());
  }
}

contract UnitGovernorDelegatePropose is Base {
  function testRevertsWhenProposingWhenNotInitialized() public {
    (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) =
      _getProposalData(2);
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotActive.selector);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
  }

  function testRevertsWhenVotesBelowThreshold() public {
    vm.mockCall(amph, abi.encodeWithSelector(IAMPH.getPriorVotes.selector), abi.encode(1000 ether));
    governor.initialize(amph);
    (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) =
      _getProposalData(2);
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_VotesBelowThreshold.selector);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
  }

  function testRevertsWhenWrongArity() public {
    governor.initialize(amph);
    address[] memory _targets = new address[](3);
    _targets[0] = address(0);
    _targets[1] = address(1);
    _targets[2] = address(2);
    (, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) = _getProposalData(2);
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_ArityMismatch.selector);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
  }

  function testRevertsWhenNoActions() public {
    governor.initialize(amph);
    address[] memory _targets;
    uint256[] memory _values;
    string[] memory _signatures;
    bytes[] memory _calldatas;
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NoActions.selector);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
  }

  function testRevertsWhenTooManyActions() public {
    governor.initialize(amph);
    (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) =
      _getProposalData(11);
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_TooManyActions.selector);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
  }

  function testRevertsMultiplePendingProposals() public {
    governor.initialize(amph);
    (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) =
      _getProposalData(2);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_MultiplePendingProposals.selector);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
  }

  function testRevertsMultipleActiveProposals() public {
    governor.initialize(amph);
    (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) =
      _getProposalData(2);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);

    vm.roll(block.number + 13_141);
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_MultipleActiveProposals.selector);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
  }

  function testCreateProposal() public {
    governor.initialize(amph);
    (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) =
      _getProposalData(2);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);

    (address[] memory __targets, uint256[] memory __values, string[] memory __signatures, bytes[] memory __calldatas) =
      governor.getActions(1);

    assertEq(__targets[0], _targets[0]);
    assertEq(__targets[1], _targets[1]);
    assertEq(__values[0], _values[0]);
    assertEq(__values[1], _values[1]);
    assertEq(__signatures[0], _signatures[0]);
    assertEq(__signatures[1], _signatures[1]);
    assertEq(__calldatas[0], _calldatas[0]);
    assertEq(__calldatas[1], _calldatas[1]);
  }
}

contract UnitGovernorDelegateCancel is Base {
  function setUp() public virtual override {
    super.setUp();
    governor.initialize(amph);
    (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) =
      _getProposalData(2);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
  }

  function testRevertsIfProposalIsAboveThreshold() public {
    vm.mockCall(amph, abi.encodeWithSelector(IAMPH.getPriorVotes.selector), abi.encode(100_000_000 ether));
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_ProposalAboveThreshold.selector);
    vm.prank(newAddress());
    governor.cancel(1);
  }

  function testRevertsIfProposalAlreadyExecuted() public {
    vm.mockCall(amph, abi.encodeWithSelector(IAMPH.getPriorVotes.selector), abi.encode(100_000_000 ether));
    /// cast yes vote on the proposal
    vm.roll(block.number + governor.votingDelay() + 1);
    governor.castVote(1, 1);
    vm.prank(newAddress());
    governor.castVote(1, 1);
    vm.roll(block.number + governor.votingPeriod() + 1);
    governor.queue(1);
    vm.warp(block.timestamp + governor.proposalTimelockDelay() + 1);
    governor.execute(1);
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_ProposalAlreadyExecuted.selector);
    governor.cancel(1);
  }

  function testCancelProposal() public {
    governor.cancel(1);
    Proposal memory _proposal = governor.getProposal(1);
    assertTrue(_proposal.canceled);
  }
}

contract UnitGovernorDelegateQueue is Base {
  function setUp() public virtual override {
    super.setUp();
    governor.initialize(amph);
    (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) =
      _getProposalData(2);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
    vm.prank(newAddress());
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
  }

  function testRevertsIfProposalNotSucceded() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_ProposalNotSucceeded.selector);
    vm.prank(newAddress());
    governor.queue(1);
  }

  function testRevertsIfProposalAlreadyQueued() public {
    vm.mockCall(amph, abi.encodeWithSelector(IAMPH.getPriorVotes.selector), abi.encode(100_000_000 ether));
    vm.roll(block.number + governor.votingDelay() + 1);
    governor.castVote(1, 1);
    governor.castVote(2, 1);
    vm.prank(newAddress());
    governor.castVote(1, 1);
    vm.prank(newAddress());
    governor.castVote(2, 1);
    vm.roll(block.number + governor.votingPeriod() + 1);
    governor.queue(1);
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_ProposalAlreadyQueued.selector);
    governor.queue(2);
  }

  function testQueueProposal() public {
    vm.mockCall(amph, abi.encodeWithSelector(IAMPH.getPriorVotes.selector), abi.encode(100_000_000 ether));
    vm.roll(block.number + governor.votingDelay() + 1);
    governor.castVote(1, 1);
    vm.prank(newAddress());
    governor.castVote(1, 1);
    vm.prank(newAddress());
    vm.roll(block.number + governor.votingPeriod() + 1);
    governor.queue(1);
    Proposal memory _proposal = governor.getProposal(1);
    assertTrue(_proposal.eta != 0);
    bytes32 _proposalHash1 = keccak256(
      abi.encode(
        _proposal.targets[0], _proposal.values[0], _proposal.signatures[0], _proposal.calldatas[0], _proposal.eta
      )
    );
    assertTrue(governor.queuedTransactions(_proposalHash1));
    bytes32 _proposalHash2 = keccak256(
      abi.encode(
        _proposal.targets[1], _proposal.values[1], _proposal.signatures[1], _proposal.calldatas[1], _proposal.eta
      )
    );
    assertTrue(governor.queuedTransactions(_proposalHash2));
  }
}

contract UnitGovernorDelegateExecute is Base {
  function setUp() public virtual override {
    super.setUp();
    governor.initialize(amph);
    vm.mockCall(amph, abi.encodeWithSelector(IAMPH.getPriorVotes.selector), abi.encode(100_000_000 ether));

    (address[] memory _targets, uint256[] memory _values, string[] memory _signatures, bytes[] memory _calldatas) =
      _getProposalData(2);
    governor.propose(_targets, _values, _signatures, _calldatas, 'description', false);
    vm.roll(block.number + governor.votingDelay() + 1);
    vm.prank(newAddress());
    governor.castVote(1, 1);
    vm.prank(newAddress());
    governor.castVote(1, 1);
    vm.roll(block.number + governor.votingPeriod() + 1);
  }

  function testRevertsIfProposalNotQueued() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_ProposalNotQueued.selector);
    governor.execute(1);
  }

  function testExecuteProposalMarksItAsExecuted() public {
    governor.queue(1);
    vm.warp(block.timestamp + governor.proposalTimelockDelay() + 1);
    governor.execute(1);
    Proposal memory _proposal = governor.getProposal(1);
    assertTrue(_proposal.executed);
  }

  function testExecuteProposalCallsCorrectContracts() public {
    governor.queue(1);
    vm.warp(block.timestamp + governor.proposalTimelockDelay() + 1);
    Proposal memory _proposal = governor.getProposal(1);
    vm.expectCall(_proposal.targets[0], abi.encodeWithSignature(_proposal.signatures[0]));
    governor.execute(1);
  }
}

contract UnitGovernorDelegateSetters is Base {
  function testRevertsWhenSetNotTokenNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setNewToken(newAddress());
  }

  function testSetNewToken() public {
    vm.prank(address(governor));
    address _newToken = newAddress();
    governor.setNewToken(_newToken);
    assertEq(address(governor.amph()), _newToken);
  }

  function testRevertsWhenSetMaxWhitelistPeriodNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setMaxWhitelistPeriod(1);
  }

  function testSetMaxWhitelistPeriod() public {
    vm.prank(address(governor));
    governor.setMaxWhitelistPeriod(1);
    assertEq(governor.maxWhitelistPeriod(), 1);
  }

  function testRevertsWhenSetDelayNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setDelay(1);
  }

  function testSetDelay() public {
    vm.prank(address(governor));
    governor.setDelay(1);
    assertEq(governor.proposalTimelockDelay(), 1);
  }

  function testRevertsWhenSetEmergencyDelayNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setEmergencyDelay(1);
  }

  function testSetEmergencyDelay() public {
    vm.prank(address(governor));
    governor.setEmergencyDelay(1);
    assertEq(governor.emergencyTimelockDelay(), 1);
  }

  function testRevertsWhenSetVotingPeriodNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setVotingPeriod(1);
  }

  function testSetVotingPeriod() public {
    vm.prank(address(governor));
    governor.setVotingPeriod(1);
    assertEq(governor.votingPeriod(), 1);
  }

  function testRevertsWhenSetVotingDelayNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setVotingDelay(1);
  }

  function testSetVotingDelay() public {
    vm.prank(address(governor));
    governor.setVotingDelay(1);
    assertEq(governor.votingDelay(), 1);
  }

  function testRevertsWhenSetEmergencyVotingPeriodNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setEmergencyVotingPeriod(1);
  }

  function testSetEmergencyVotingPeriod() public {
    vm.prank(address(governor));
    governor.setEmergencyVotingPeriod(1);
    assertEq(governor.emergencyVotingPeriod(), 1);
  }

  function testRevertsWhenSetProposalThresholdNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setProposalThreshold(1);
  }

  function testSetProposalThreshold() public {
    vm.prank(address(governor));
    governor.setProposalThreshold(1);
    assertEq(governor.proposalThreshold(), 1);
  }

  function testRevertsWhenSetQuorumVotesNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setQuorumVotes(1);
  }

  function testSetQuorumVotes() public {
    vm.prank(address(governor));
    governor.setQuorumVotes(1);
    assertEq(governor.quorumVotes(), 1);
  }

  function testRevertsWhenSetEmergencyQuorumVotesNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setEmergencyQuorumVotes(1);
  }

  function testSetEmergencyQuorumVotes() public {
    vm.prank(address(governor));
    governor.setEmergencyQuorumVotes(1);
    assertEq(governor.emergencyQuorumVotes(), 1);
  }

  function testRevertsWhenSetWhitelistAccountExpirationNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setWhitelistAccountExpiration(newAddress(), 1);
  }

  function testRevertsSetWhitelistAccountExpirationExceedsMax() public {
    address _account = newAddress();
    vm.startPrank(address(governor));
    uint256 _expiration = block.timestamp + governor.maxWhitelistPeriod() + 1;
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_ExpirationExceedsMax.selector);
    governor.setWhitelistAccountExpiration(_account, _expiration);
  }

  function testSetWhitelistAccountExpiration() public {
    address _account = newAddress();
    vm.prank(address(governor));
    governor.setWhitelistAccountExpiration(_account, 0);
    assertEq(governor.whitelistAccountExpirations(_account), 0);
  }

  function testRevertsWhenSetWhitelistGuardianNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setWhitelistGuardian(newAddress());
  }

  function testSetWhitelistGuardian() public {
    address _guardian = newAddress();
    vm.prank(address(governor));
    governor.setWhitelistGuardian(_guardian);
    assertEq(governor.whitelistGuardian(), _guardian);
  }

  function testRevertsWhenSetOptimisticDelayNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setOptimisticDelay(1);
  }

  function testSetOptimisticDelay() public {
    vm.prank(address(governor));
    governor.setOptimisticDelay(1);
    assertEq(governor.optimisticVotingDelay(), 1);
  }

  function testRevertsWhenSetOptimisticQuorumVotesNotGovernor() public {
    vm.expectRevert(IGovernorCharlieDelegate.GovernorCharlie_NotGovernor.selector);
    governor.setOptimisticQuorumVotes(1);
  }

  function testSetOptimisticQuorumVotes() public {
    vm.prank(address(governor));
    governor.setOptimisticQuorumVotes(1);
    assertEq(governor.optimisticQuorumVotes(), 1);
  }
}
