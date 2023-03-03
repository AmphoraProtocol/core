// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {GovernorCharlieDelegator} from '@contracts/governance/GovernorDelegator.sol';
import {IGovernorCharlieDelegator} from '@interfaces/governance/IGovernorCharlieDelegator.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';

abstract contract Base is DSTestPlus {
  GovernorCharlieDelegator public governor;
  address public implementation = label(newAddress(), 'implementation');
  address public otherImplementation = label(newAddress(), 'otherImplementation');
  address public amph;

  event Deposit(address indexed _from, uint256 _value);
  event Withdraw(address indexed _from, uint256 _value);

  function setUp() public virtual {
    vm.mockCall(
      address(implementation), abi.encodeWithSignature('randomMethod(string)', 'random'), abi.encode('randomResponse')
    );
    vm.mockCall(
      address(otherImplementation),
      abi.encodeWithSignature('randomMethod(string)', 'random'),
      abi.encode('otherRandomResponse')
    );
    governor = new GovernorCharlieDelegator(amph, implementation);
  }
}

contract UnitGovernorDelegator is Base {
  function testCallsCorrectImplementation() public {
    vm.expectCall(address(implementation), abi.encodeWithSignature('randomMethod(string)', 'random'));
    address(governor).call(abi.encodeWithSignature('randomMethod(string)', 'random'));
  }

  function testCallsOtherImplementationWhenSettedd() public {
    vm.prank(address(governor));
    governor.setImplementation(otherImplementation);
    vm.expectCall(address(otherImplementation), abi.encodeWithSignature('randomMethod(string)', 'random'));
    address(governor).call(abi.encodeWithSignature('randomMethod(string)', 'random'));
  }

  function testRevertsIfNonAdminSetImplementation() public {
    vm.expectRevert(IGovernorCharlieDelegator.GovernorCharlieDelegator_OnlyGovernance.selector);
    governor.setImplementation(otherImplementation);
  }
}
