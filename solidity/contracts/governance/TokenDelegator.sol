// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import {ITokenDelegator} from '@interfaces/governance/ITokenDelegator.sol';
import {TokenDelegatorStorage} from '@contracts/governance/TokenStorage.sol';

contract AmphoraProtocolToken is TokenDelegatorStorage, ITokenDelegator {
  constructor(address _account, address _owner, address _implementation, uint256 _initialSupply) {
    if (_implementation == address(0)) revert TokenDelegator_InvalidAddress();
    owner = _owner;
    _delegateTo(_implementation, abi.encodeWithSignature('initialize(address,uint256)', _account, _initialSupply));

    implementation = _implementation;

    emit NewImplementation(address(0), implementation);
  }

  /**
   * @notice Called by the admin to update the implementation of the delegator
   * @param _implementation The address of the new implementation for delegation
   */
  function setImplementation(address _implementation) external override onlyOwner {
    if (_implementation == address(0)) revert TokenDelegator_InvalidAddress();

    address _oldImplementation = implementation;
    implementation = _implementation;

    emit NewImplementation(_oldImplementation, implementation);
  }

  /**
   * @notice Called by the admin to update the owner of the delegator
   * @param _owner The address of the new owner
   */
  function setOwner(address _owner) external override onlyOwner {
    owner = _owner;
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
      if eq(_success, 0) { revert(add(_returnData, 0x20), returndatasize()) }
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
    (bool _success,) = implementation.delegatecall(msg.data);
    //solhint-disable-next-line no-inline-assembly
    assembly {
      let _free_mem_ptr := mload(0x40)
      returndatacopy(_free_mem_ptr, 0, returndatasize())
      switch _success
      case 0 { revert(_free_mem_ptr, returndatasize()) }
      default { return(_free_mem_ptr, returndatasize()) }
    }
  }

  receive() external payable override {}
}
