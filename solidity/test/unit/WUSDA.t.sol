// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {WUSDA} from '@contracts/core/WUSDA.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

abstract contract Base is DSTestPlus {
  uint256 internal constant _DELTA = 100;

  address public usdaToken = newAddress();
  string public name = 'USDA Token';
  string public symbol = 'USDA';
  uint256 public usdaTotalSupply = 1_000_000 ether;
  WUSDA public wusda;
  uint256 public wusdaMaxSupply;

  function setUp() public virtual {
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(usdaTotalSupply));

    wusda = new WUSDA(usdaToken, name, symbol);
    wusdaMaxSupply = wusda.MAX_wUSDA_SUPPLY();
  }
}

contract UnitWUSDAMint is Base {
  function testMintAddsToTotalSupply(uint256 _amount) public {
    vm.assume(_amount <= wusdaMaxSupply);
    wusda.mint(_amount);
    assertEq(wusda.totalSupply(), _amount);
  }

  function testMintAddsToUserBalance(uint256 _amount) public {
    vm.assume(_amount <= wusdaMaxSupply);
    wusda.mint(_amount);
    assertEq(wusda.balanceOf(address(this)), _amount);
  }

  function testMintCallsTransferFromOnUser(uint256 _amount, uint128 _usdaTotalSupply) public {
    vm.assume(_amount <= wusdaMaxSupply);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _expectedAmount = (_amount * _usdaTotalSupply) / wusdaMaxSupply;
    vm.expectCall(
      usdaToken, abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(wusda), _expectedAmount)
    );
    wusda.mint(_amount);
  }
}

contract UnitWUSDAMintFor is Base {
  function testMintAddsToTotalSupply(uint256 _amount) public {
    vm.assume(_amount <= wusdaMaxSupply);
    address _receiver = newAddress();
    wusda.mintFor(_receiver, _amount);
    assertEq(wusda.totalSupply(), _amount);
  }

  function testMintAddsToUserBalance(uint256 _amount) public {
    vm.assume(_amount <= wusdaMaxSupply);
    address _receiver = newAddress();
    wusda.mintFor(_receiver, _amount);
    assertEq(wusda.balanceOf(_receiver), _amount);
  }

  function testMintCallsTransferFromOnUser(uint256 _amount, uint128 _usdaTotalSupply) public {
    vm.assume(_amount <= wusdaMaxSupply);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _expectedAmount = (_amount * _usdaTotalSupply) / wusdaMaxSupply;
    address _receiver = newAddress();
    vm.expectCall(
      usdaToken, abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(wusda), _expectedAmount)
    );
    wusda.mintFor(_receiver, _amount);
  }
}

contract UnitWUSDABurn is Base {
  uint256 public wusdaMinted = 100_000 ether;

  function setUp() public override {
    super.setUp();
    wusda.mint(wusdaMinted);
  }

  function testBurnSubtractsFromTotalSupply(uint256 _amount) public {
    vm.assume(_amount <= wusdaMinted);
    wusda.burn(_amount);
    assertEq(wusda.totalSupply(), wusdaMinted - _amount);
  }

  function testBurnSubtractsFromUserBalance(uint256 _amount) public {
    vm.assume(_amount <= wusdaMinted);
    wusda.burn(_amount);
    assertEq(wusda.balanceOf(address(this)), wusdaMinted - _amount);
  }

  function testBurnCallsTransferToUser(uint256 _amount, uint128 _usdaTotalSupply) public {
    vm.assume(_amount <= wusdaMinted);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _expectedAmount = (_amount * _usdaTotalSupply) / wusdaMaxSupply;
    vm.expectCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector, address(this), _expectedAmount));
    wusda.burn(_amount);
  }
}

contract UnitWUSDABurnTo is Base {
  uint256 public wusdaMinted = 100_000 ether;

  function setUp() public override {
    super.setUp();
    wusda.mint(wusdaMinted);
  }

  function testBurnSubtractsFromTotalSupply(uint256 _amount) public {
    vm.assume(_amount <= wusdaMinted);
    address _receiver = newAddress();
    wusda.burnTo(_receiver, _amount);
    assertEq(wusda.totalSupply(), wusdaMinted - _amount);
  }

  function testBurnSubtractsFromUserBalance(uint256 _amount) public {
    vm.assume(_amount <= wusdaMinted);
    address _receiver = newAddress();
    wusda.burnTo(_receiver, _amount);
    assertEq(wusda.balanceOf(address(this)), wusdaMinted - _amount);
  }

  function testBurnCallsTransferToUser(uint256 _amount, uint128 _usdaTotalSupply) public {
    vm.assume(_amount <= wusdaMinted);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    address _receiver = newAddress();
    uint256 _expectedAmount = (_amount * _usdaTotalSupply) / wusdaMaxSupply;
    vm.expectCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector, _receiver, _expectedAmount));
    wusda.burnTo(_receiver, _amount);
  }
}

contract UnitWUSDABurnAll is Base {
  uint256 public wusdaMinted = 100_000 ether;

  function setUp() public override {
    super.setUp();
    wusda.mint(wusdaMinted);
  }

  function testBurnSubtractsFromTotalSupply() public {
    wusda.burnAll();
    assertEq(wusda.totalSupply(), 0);
  }

  function testBurnSubtractsFromUserBalance() public {
    wusda.burnAll();
    assertEq(wusda.balanceOf(address(this)), 0);
  }

  function testBurnCallsTransferToUser(uint128 _usdaTotalSupply) public {
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _expectedAmount = (wusdaMinted * _usdaTotalSupply) / wusdaMaxSupply;
    vm.expectCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector, address(this), _expectedAmount));
    wusda.burnAll();
  }
}

contract UnitWUSDABurnAllTo is Base {
  uint256 public wusdaMinted = 100_000 ether;

  function setUp() public override {
    super.setUp();
    wusda.mint(wusdaMinted);
  }

  function testBurnSubtractsFromTotalSupply() public {
    address _receiver = newAddress();
    wusda.burnAllTo(_receiver);
    assertEq(wusda.totalSupply(), 0);
  }

  function testBurnSubtractsFromUserBalance() public {
    address _receiver = newAddress();
    wusda.burnAllTo(_receiver);
    assertEq(wusda.balanceOf(address(this)), 0);
  }

  function testBurnCallsTransferToUser(uint128 _usdaTotalSupply) public {
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _expectedAmount = (wusdaMinted * _usdaTotalSupply) / wusdaMaxSupply;
    address _receiver = newAddress();
    vm.expectCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector, _receiver, _expectedAmount));
    wusda.burnAllTo(_receiver);
  }
}

contract UnitWUSDADeposit is Base {
  function testDepositAddsToTotalSupply(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _maxUSDAAmount = (_usdaTotalSupply * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(_usdaAmount <= _maxUSDAAmount);
    uint256 _expectedAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    wusda.deposit(_usdaAmount);
    assertEq(wusda.totalSupply(), _expectedAmount);
  }

  function testDepositAddsToUserBalance(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _maxUSDAAmount = (_usdaTotalSupply * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(_usdaAmount <= _maxUSDAAmount);
    uint256 _expectedAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    wusda.deposit(_usdaAmount);
    assertEq(wusda.balanceOf(address(this)), _expectedAmount);
  }

  function testDepositCallsTransferFromOnUser(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _maxUSDAAmount = (_usdaTotalSupply * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(_usdaAmount <= _maxUSDAAmount);
    uint256 _expectedAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    vm.expectCall(
      usdaToken, abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(wusda), _usdaAmount)
    );
    wusda.deposit(_usdaAmount);
  }
}

contract UnitWUSDADepositFor is Base {
  address internal _receiver = newAddress();

  function testDepositAddsToTotalSupply(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _maxUSDAAmount = (_usdaTotalSupply * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(_usdaAmount <= _maxUSDAAmount);
    uint256 _expectedAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    wusda.depositFor(_receiver, _usdaAmount);
    assertEq(wusda.totalSupply(), _expectedAmount);
  }

  function testDepositAddsToUserBalance(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _maxUSDAAmount = (_usdaTotalSupply * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(_usdaAmount <= _maxUSDAAmount);
    uint256 _expectedAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    wusda.depositFor(_receiver, _usdaAmount);
    assertEq(wusda.balanceOf(_receiver), _expectedAmount);
  }

  function testDepositCallsTransferFromOnUser(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _maxUSDAAmount = (_usdaTotalSupply * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(_usdaAmount <= _maxUSDAAmount);
    uint256 _expectedAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    vm.expectCall(
      usdaToken, abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(wusda), _usdaAmount)
    );
    wusda.depositFor(_receiver, _usdaAmount);
  }
}

contract UnitWUSDAWithdraw is Base {
  uint256 public usdaDeposited = 100_000 ether;
  uint256 public wusdaSupply;

  function setUp() public override {
    super.setUp();
    wusda.deposit(usdaDeposited);
    wusdaSupply = wusda.totalSupply();
  }

  function testWithdrawSubstractsFromTotalSupply(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaAmount <= usdaDeposited);
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    wusda.withdraw(_usdaAmount);
    uint256 _newTotalSupply = wusdaSupply - _withdrawAmount;
    assertEq(wusda.totalSupply(), _newTotalSupply);
  }

  function testWithdrawSubstractsFromUserBalance(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaAmount <= usdaDeposited);
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    wusda.withdraw(_usdaAmount);
    uint256 _newUserBalance = wusdaSupply - _withdrawAmount;
    assertEq(wusda.balanceOf(address(this)), _newUserBalance);
  }

  function testWithdrawCallsTransferFromUser(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaAmount <= usdaDeposited);
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    vm.expectCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector, address(this), _usdaAmount));
    wusda.withdraw(_usdaAmount);
  }
}

contract UnitWUSDAWithdrawTo is Base {
  uint256 public usdaDeposited = 100_000 ether;
  uint256 public wusdaSupply;
  address public receiver = newAddress();

  function setUp() public override {
    super.setUp();
    wusda.deposit(usdaDeposited);
    wusdaSupply = wusda.totalSupply();
  }

  function testWithdrawToSubstractsFromTotalSupply(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaAmount <= usdaDeposited);
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    wusda.withdrawTo(receiver, _usdaAmount);
    uint256 _newTotalSupply = wusdaSupply - _withdrawAmount;
    assertEq(wusda.totalSupply(), _newTotalSupply);
  }

  function testWithdrawToSubstractsFromUserBalance(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaAmount <= usdaDeposited);
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    wusda.withdrawTo(receiver, _usdaAmount);
    uint256 _newUserBalance = wusdaSupply - _withdrawAmount;
    assertEq(wusda.balanceOf(address(this)), _newUserBalance);
  }

  function testWithdrawToCallsTransferFromUser(uint256 _usdaAmount, uint128 _usdaTotalSupply) public {
    vm.assume(_usdaAmount <= usdaDeposited);
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (_usdaAmount * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    vm.expectCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector, receiver, _usdaAmount));
    wusda.withdrawTo(receiver, _usdaAmount);
  }
}

contract UnitWUSDAWithdrawAll is Base {
  uint256 public usdaDeposited = 100_000 ether;
  uint256 public wusdaSupply;

  function setUp() public override {
    super.setUp();
    wusda.deposit(usdaDeposited);
    wusdaSupply = wusda.totalSupply();
  }

  function testWithdrawAllSubstractsFromTotalSupply(uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (usdaDeposited * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    wusda.withdrawAll();
    assertEq(wusda.totalSupply(), 0);
  }

  function testWithdrawAllSubstractsFromUserBalance(uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (usdaDeposited * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    wusda.withdrawAll();
    assertEq(wusda.balanceOf(address(this)), 0);
  }

  function testWithdrawAllCallsTransferFromUser() public {
    uint256 _withdrawAmount = (usdaDeposited * wusdaMaxSupply) / usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    vm.expectCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector, address(this), usdaDeposited));
    wusda.withdrawAll();
  }
}

contract UnitWUSDAWithdrawAllTo is Base {
  uint256 public usdaDeposited = 100_000 ether;
  uint256 public wusdaSupply;
  address public receiver = newAddress();

  function setUp() public override {
    super.setUp();
    wusda.deposit(usdaDeposited);
    wusdaSupply = wusda.totalSupply();
  }

  function testWithdrawAllToSubstractsFromTotalSupply(uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (usdaDeposited * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    wusda.withdrawAllTo(receiver);
    assertEq(wusda.totalSupply(), 0);
  }

  function testWithdrawAllToSubstractsFromUserBalance(uint128 _usdaTotalSupply) public {
    vm.assume(_usdaTotalSupply > 0);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_usdaTotalSupply));
    uint256 _withdrawAmount = (usdaDeposited * wusdaMaxSupply) / _usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    wusda.withdrawAllTo(receiver);
    assertEq(wusda.balanceOf(address(this)), 0);
  }

  function testWithdrawAllToCallsTransferFromUser() public {
    uint256 _withdrawAmount = (usdaDeposited * wusdaMaxSupply) / usdaTotalSupply;
    vm.assume(wusdaSupply >= _withdrawAmount);
    vm.expectCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector, receiver, usdaDeposited));
    wusda.withdrawAllTo(receiver);
  }
}
