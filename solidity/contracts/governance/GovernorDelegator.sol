// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import {IGovernorCharlieDelegator} from '@interfaces/governance/IGovernorCharlieDelegator.sol';
import {GovernorCharlieDelegatorStorage} from '@contracts/governance/GovernorStorage.sol';

contract GovernorCharlieDelegator is GovernorCharlieDelegatorStorage, IGovernorCharlieDelegator {
  constructor(address _amph, address _implementation) {
    _delegateTo(_implementation, abi.encodeWithSignature('initialize(address)', _amph));
    address _oldImplementation = implementation;
    implementation = _implementation;
    emit NewImplementation(_oldImplementation, _implementation);
  }

  /**
   * @notice Called by itself via governance to update the implementation of the delegator
   * @param _implementation The address of the new implementation for delegation
   */
  function setImplementation(address _implementation) public override {
    if (msg.sender != address(this)) revert GovernorCharlieDelegator_OnlyGovernance();
    if (_implementation == address(0)) revert GovernorCharlieDelegator_InvalidImplementation();

    address _oldImplementation = implementation;
    implementation = _implementation;

    emit NewImplementation(_oldImplementation, _implementation);
  }

  /**
   * @notice Internal method to delegate execution to another contract
   * @dev It returns to the external caller whatever the implementation returns or forwards reverts
   * @param _callee The contract to delegatecall
   * @param _data The raw data to delegatecall
   */
  function _delegateTo(address _callee, bytes memory _data) internal {
    //solhint-disable-next-line avoid-low-level-calls
    (bool _success, bytes memory _returnData) = _callee.delegatecall(_data);
    //solhint-disable-next-line no-inline-assembly
    assembly {
      if eq(_success, 0) {
        revert(add(_returnData, 0x20), returndatasize())
      }
    }
  }

  /**
   * @dev Delegates execution to an implementation contract.
   * It returns to the external caller whatever the implementation returns
   * or forwards reverts.
   */
  // solhint-disable-next-line no-complex-fallback
  fallback() external payable override {
    // delegate all other functions to current implementation
    //solhint-disable-next-line avoid-low-level-calls
    (bool _success, ) = implementation.delegatecall(msg.data);

    //solhint-disable-next-line no-inline-assembly
    assembly {
      let _free_mem_ptr := mload(0x40)
      returndatacopy(_free_mem_ptr, 0, returndatasize())

      switch _success
      case 0 {
        revert(_free_mem_ptr, returndatasize())
      }
      default {
        return(_free_mem_ptr, returndatasize())
      }
    }
  }

  receive() external payable override {}
}
