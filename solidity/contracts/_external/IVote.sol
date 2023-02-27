// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IVote is IERC20 {
  enum DelegationType {
    VOTING_POWER,
    PROPOSITION_POWER
  }

  /**
   * @notice Gets the current votes balance for `account`
   * @param _account The address to get votes balance
   * @return _votes The number of current votes for `account`
   */
  function getCurrentVotes(address _account) external view returns (uint96 _votes);

  /**
   * @dev returns the current delegated power of a user. The current power is the
   * power delegated at the time of the last snapshot
   * @param _user the user
   * @param _delegationType the delegation type
   * @return _power the delegated power of the user
   *
   */
  function getPowerCurrent(address _user, DelegationType _delegationType) external view returns (uint256 _power);

  function getVotes(address _account) external view returns (uint256 _votes);

  //aave functions
  function getDelegateeByType(address _delegator, DelegationType _delegationType) external view returns (address _delegatee);
}
