// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {AmphoraProtocolToken} from '@contracts/governance/AmphoraProtocolToken.sol';
import {IAmphoraProtocolToken} from '@interfaces/governance/IAmphoraProtocolToken.sol';

import {DSTestPlus, console} from 'solidity-utils/test/DSTestPlus.sol';

abstract contract Base is DSTestPlus {
  AmphoraProtocolToken public amphoraToken;
  address public owner = label(newAddress(), 'owner');
  uint256 public initSupply = 1_000_000 ether;

  function setUp() public virtual {
    vm.prank(owner);
    amphoraToken = new AmphoraProtocolToken(owner, initSupply);
  }
}

contract UnitAmphoraProtocolTokenConstructor is Base {
  AmphoraProtocolToken public mockAmphoraToken;

  function testRevertIfInvalidAddress() public {
    vm.expectRevert(IAmphoraProtocolToken.AmphoraProtocolToken_InvalidAddress.selector);
    vm.prank(owner);
    mockAmphoraToken = new AmphoraProtocolToken(address(0), initSupply);
  }

  function testRevertIfInvalidSupply() public {
    vm.expectRevert(IAmphoraProtocolToken.AmphoraProtocolToken_InvalidSupply.selector);
    vm.prank(owner);
    mockAmphoraToken = new AmphoraProtocolToken(owner, 0);
  }

  function testRevertIfSupplyOverflows() public {
    vm.expectRevert(IAmphoraProtocolToken.AmphoraProtocolToken_Overflow.selector);
    vm.prank(owner);
    mockAmphoraToken = new AmphoraProtocolToken(owner, type(uint192).max);
  }

  function testConstructorValuesSet() public {
    assertEq(amphoraToken.totalSupply(), initSupply);
    assertEq(amphoraToken.balanceOf(owner), initSupply);
  }
}

contract UnitAmphoraProtocolTokenChangeName is Base {
  event ChangedName(string _oldName, string _newName);

  string public tokenName = 'Amphora Protocol';

  function testRevertIfNotOwner(string calldata _name) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    amphoraToken.changeName(_name);
  }

  function testRevertIfLengthIsZero() public {
    vm.expectRevert(IAmphoraProtocolToken.AmphoraProtocolToken_InvalidLength.selector);
    vm.prank(owner);
    amphoraToken.changeName('');
  }

  function testChangeName() public {
    string memory _newTokenName = 'Amphora Protocol V2';
    vm.expectEmit(true, true, true, true);
    emit ChangedName(tokenName, _newTokenName);

    vm.prank(owner);
    amphoraToken.changeName(_newTokenName);
    assertEq(amphoraToken.name(), _newTokenName);
  }
}

contract UnitAmphoraProtocolTokenChangeSymbol is Base {
  event ChangedSymbol(string _oldSybmol, string _newSybmol);

  string public tokenSymbol = 'AMPH';

  function testRevertIfNotOwner(string calldata _symbol) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    amphoraToken.changeSymbol(_symbol);
  }

  function testRevertIfLengthIsZero() public {
    vm.expectRevert(IAmphoraProtocolToken.AmphoraProtocolToken_InvalidLength.selector);
    vm.prank(owner);
    amphoraToken.changeSymbol('');
  }

  function testChangeSymbol() public {
    string memory _newTokenSymbol = 'AMPH_V2';
    vm.expectEmit(true, true, true, true);
    emit ChangedSymbol(tokenSymbol, _newTokenSymbol);

    vm.prank(owner);
    amphoraToken.changeSymbol(_newTokenSymbol);
    assertEq(amphoraToken.symbol(), _newTokenSymbol);
  }
}

contract UnitAmphoraProtocolTokenAllowance is Base {
  function testZeroAllowance(address _spender) public {
    assertEq(amphoraToken.allowance(owner, _spender), 0);
  }

  function testAllowance(address _spender) public {
    vm.prank(owner);
    amphoraToken.approve(_spender, 1 ether);

    assertEq(amphoraToken.allowance(owner, _spender), 1 ether);
  }
}

contract UnitAmphoraProtocolTokenApprove is Base {
  event Approval(address indexed _owner, address indexed _spender, uint256 _amount);

  function testRevertIfAmountTooHigh(address _spender) public {
    vm.expectRevert('approve: amount exceeds 96 bits');
    amphoraToken.approve(_spender, type(uint192).max);
  }

  function testApproveWithUnit256Max(address _spender) public {
    vm.prank(owner);
    assertTrue(amphoraToken.approve(_spender, type(uint256).max));
    assertEq(amphoraToken.allowance(owner, _spender), type(uint96).max);
  }

  function testApprove(address _spender) public {
    vm.expectEmit(true, true, true, true);
    emit Approval(owner, _spender, 10 ether);

    vm.prank(owner);
    assertTrue(amphoraToken.approve(_spender, 10 ether));
    assertEq(amphoraToken.allowance(owner, _spender), 10 ether);
  }
}

contract UnitAmphoraProtocolTokenBalanceOf is Base {
  function testBalanceOfUserWithZeroTokens(address _wallet) public {
    vm.assume(_wallet != owner);
    assertEq(amphoraToken.balanceOf(_wallet), 0);
  }

  function testBalanceOfUserWithTokens() public {
    assertEq(amphoraToken.balanceOf(owner), initSupply);
  }
}

contract UnitAmphoraProtocolTokenTransfer is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _amount);

  function testRevertIfAmountTooHigh(address _receiver) public {
    vm.expectRevert('transfer: amount exceeds 96 bits');
    vm.prank(owner);
    amphoraToken.transfer(_receiver, type(uint192).max);
  }

  function testRevertIfSenderIsZeroAddress(address _receiver, uint96 _amount) public {
    vm.assume(_amount <= type(uint96).max);

    vm.expectRevert(IAmphoraProtocolToken.AmphoraProtocolToken_ZeroAddress.selector);
    vm.prank(address(0));
    amphoraToken.transfer(_receiver, _amount);
  }

  function testRevertIfReceiverIsZeroAddress(uint96 _amount) public {
    vm.assume(_amount <= type(uint96).max);

    vm.expectRevert(IAmphoraProtocolToken.AmphoraProtocolToken_ZeroAddress.selector);
    vm.prank(owner);
    amphoraToken.transfer(address(0), _amount);
  }

  function testRevertIfAmountHigherThanBalance(address _receiver) public {
    vm.assume(_receiver != address(0));
    vm.expectRevert('_transferTokens: transfer amount exceeds balance');
    vm.prank(owner);
    amphoraToken.transfer(_receiver, initSupply + 1);
  }

  function testTransfer(address _receiver) public {
    vm.assume(_receiver != address(0) && _receiver != owner);

    uint256 _amount = 10 ether;
    vm.expectEmit(true, true, true, true);
    emit Transfer(owner, _receiver, _amount);

    vm.prank(owner);
    assertTrue(amphoraToken.transfer(_receiver, _amount));
    assertEq(amphoraToken.balanceOf(_receiver), _amount);
    assertEq(amphoraToken.balanceOf(owner), initSupply - _amount);
  }
}

contract UnitAmphoraProtocolTokenTransferFrom is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _amount);
  event Approval(address indexed _owner, address indexed _spender, uint256 _amount);

  uint256 public amount = 10 ether;

  function testRevertIfAmountTooHigh(address _receiver) public {
    vm.expectRevert('transferFrom: amount exceeds 96 bits');
    vm.prank(owner);
    amphoraToken.transferFrom(owner, _receiver, type(uint192).max);
  }

  function testRevertIfAmountExceedsSpenderAllowance(address _receiver) public {
    vm.assume(_receiver != owner);

    vm.expectRevert('transferFrom: transfer amount exceeds spender allowance');
    vm.prank(_receiver);
    amphoraToken.transferFrom(owner, _receiver, amount * 2);
  }

  function testTransferFrom(address _receiver) public {
    vm.assume(_receiver != address(0) && _receiver != owner);

    vm.prank(owner);
    amphoraToken.approve(_receiver, amount);

    vm.expectEmit(true, true, true, true);
    emit Approval(owner, _receiver, 0);

    vm.expectEmit(true, true, true, true);
    emit Transfer(owner, _receiver, amount);

    vm.prank(_receiver);
    assertTrue(amphoraToken.transferFrom(owner, _receiver, amount));
    assertEq(amphoraToken.balanceOf(_receiver), amount);
    assertEq(amphoraToken.balanceOf(owner), initSupply - amount);
  }
}

contract UnitAmphoraProtocolTokenMint is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _amount);

  function testRevertIfNotOwner(address _receiver, uint256 _amount) public {
    vm.assume(_receiver != address(0));
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    amphoraToken.mint(_receiver, _amount);
  }

  function testRevertIfReceiverIsZeroAddress(uint96 _amount) public {
    vm.expectRevert('mint: cant transfer to 0 address');
    vm.prank(owner);
    amphoraToken.mint(address(0), _amount);
  }

  function testRevertIfAmountTooHigh(address _receiver) public {
    vm.assume(_receiver != address(0));
    vm.expectRevert('mint: amount exceeds 96 bits');
    vm.prank(owner);
    amphoraToken.mint(_receiver, type(uint192).max);
  }

  function testRevertIfTotalSupplyTooHigh(address _receiver) public {
    vm.assume(_receiver != address(0));
    vm.expectRevert('mint: totalSupply exceeds 96 bits');
    vm.prank(owner);
    amphoraToken.mint(_receiver, type(uint96).max);
  }

  function testMint(address _receiver, uint96 _amount) public {
    vm.assume(_amount > 0 && _amount < type(uint96).max - initSupply);
    vm.assume(_receiver != address(0));

    vm.expectEmit(true, true, true, true);
    emit Transfer(address(0), _receiver, _amount);

    vm.prank(owner);
    amphoraToken.mint(_receiver, _amount);
    assertEq(amphoraToken.totalSupply(), initSupply + _amount);
    assertEq(amphoraToken.balanceOf(_receiver), _amount);
  }
}

contract UnitAmphoraProtocolTokenDelegate is Base {
  event DelegateChanged(address indexed _delegator, address indexed _fromDelegate, address indexed _toDelegate);

  function testDelegate(address _delegatee) public {
    vm.assume(_delegatee != address(0) && _delegatee != owner);

    vm.expectEmit(true, true, true, true);
    emit DelegateChanged(owner, address(0), _delegatee);

    vm.prank(owner);
    amphoraToken.delegate(_delegatee);

    assertEq(amphoraToken.getCurrentVotes(_delegatee), initSupply);
    assertEq(amphoraToken.getCurrentVotes(owner), 0);
  }
}

contract UnitAmphoraProtocolGetCurrentVotes is Base {
  function testGetCurrentVotesWhenZero(address _account) public {
    vm.assume(_account != owner);
    assertEq(amphoraToken.getCurrentVotes(_account), 0);
  }

  function testGetCurrentVotes(address _account) public {
    vm.assume(_account != owner && _account != address(0));

    vm.prank(owner);
    amphoraToken.delegate(_account);
    assertEq(amphoraToken.getCurrentVotes(_account), initSupply);
  }
}

contract UnitAmphoraProtocolTokenGetPriorVotes is Base {
  function testRevertIfBlockNumberIsInvalid(address _account) public {
    vm.expectRevert(IAmphoraProtocolToken.AmphoraProtocolToken_CannotDetermineVotes.selector);
    amphoraToken.getPriorVotes(_account, block.number + 10);
  }

  function testGetPriorVotesWhenThereAreNoPriorVototes(address _account) public {
    assertEq(amphoraToken.getPriorVotes(_account, block.number - 1), 0);
  }
}
