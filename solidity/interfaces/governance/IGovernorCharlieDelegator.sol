// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ProposalState, Receipt} from '@contracts/utils/GovernanceStructs.sol';

import {IGovernorCharlieEvents} from '@interfaces/governance/IGovernorCharlieEvents.sol';

/// @title interface to interact with TokenDelgator
interface IGovernorCharlieDelegator is IGovernorCharlieEvents {
  /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when called by non governance
  error GovernorCharlieDelegator_OnlyGovernance();

  /// @notice Thrown when invalid implementation address
  error GovernorCharlieDelegator_InvalidImplementation();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/

  function setImplementation(address _implementation) external;

  fallback() external payable;

  receive() external payable;
}
