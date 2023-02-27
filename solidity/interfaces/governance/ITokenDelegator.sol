// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import {ITokenEvents} from '@interfaces/governance/ITokenEvents.sol';

/// @title interface to interact with TokenDelgator
interface ITokenDelegator is ITokenEvents {
  /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when invalid address
  error TokenDelegator_InvalidAddress();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/
  function setImplementation(address _implementation) external;

  function setOwner(address _owner) external;

  fallback() external payable;

  receive() external payable;
}
