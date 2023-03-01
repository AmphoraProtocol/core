// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {USDA} from '@contracts/core/USDA.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IRoles} from '@interfaces/utils/IRoles.sol';
import {IUSDA} from '@interfaces/core/IUSDA.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract USDAForTest is USDA {
  /// Overriding this functions to test that the methods can't be called again afterwards
  function erc20DetailedInitForTest(string memory __name, string memory __symbol, uint8 __decimals) public {
    _erc20DetailedInit(__name, __symbol, __decimals);
  }

  function uFragmentsInitForTest(string memory __name, string memory __symbol) public {
    _UFragments_init(__name, __symbol);
  }
}

abstract contract Base is DSTestPlus {
  uint256 internal constant _DELTA = 100;
  uint256 internal _susdAmount = 500 ether;
  USDAForTest internal _usda;
  IERC20 internal _mockToken = IERC20(mockContract(newAddress(), 'mockToken'));
  address internal _vaultController = mockContract(newAddress(), 'mockVaultController');
  address internal _vaultController2 = mockContract(newAddress(), 'mockVaultController2');

  event Deposit(address indexed _from, uint256 _value);
  event Withdraw(address indexed _from, uint256 _value);

  function setUp() public virtual {
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));

    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    vm.mockCall(
      address(_vaultController),
      abi.encodeWithSelector(IVaultController.calculateInterest.selector),
      abi.encode(1 ether)
    );
    // solhint-disable-next-line reentrancy
    _usda = new USDAForTest();
    _usda.initialize(address(_mockToken));
    _usda.addVaultController(_vaultController);
    _usda.setPauser(address(this));
  }
}

contract UnitUSDAInit is Base {
  function testRevertsWhenInitializingAgain() public {
    vm.expectRevert('Initializable: contract is already initialized');
    _usda.initialize(address(_mockToken));
  }

  function testRevertsWhenInitializingUFragmentsAgain() public {
    vm.expectRevert('Initializable: contract is not initializing');
    _usda.uFragmentsInitForTest('NAME', 'SYMBOL');
  }

  function testRevertsWhenInitializingOwnableAgain() public {
    vm.expectRevert('Initializable: contract is not initializing');
    _usda.erc20DetailedInitForTest('name', 'symbol', 18);
  }
}

contract UnitUSDAGetters is Base {
  function testOwnerReturnsThis() public {
    assertEq(_usda.owner(), address(this));
  }

  function testNameReturnsName() public {
    assertEq(_usda.name(), 'USDA Token');
  }

  function testSymbolReturnsSymbol() public {
    assertEq(_usda.symbol(), 'USDA');
  }

  function testDecimalsReturnsDecimals() public {
    assertEq(_usda.decimals(), 18);
  }

  function testReserveAddressReturnsToken() public {
    assertEq(_usda.reserveAddress(), address(_mockToken));
  }
}

contract UnitUSDADeposit is Base {
  //TODO: This needs to be changed after we modify the decimals amount
  //  The maximum amount of tokens to deposit is 72.057.594.037 sUSD at a time
  function testDepositCallsTransferFrom(uint56 _amount) public {
    vm.assume(_amount > 0);
    vm.expectCall(
      address(_mockToken), abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(_usda), _amount)
    );

    _usda.deposit(_amount);
  }

  function testDepositCallsPaysInterest(uint56 _amount) public {
    vm.assume(_amount > 0);
    vm.expectCall(address(_vaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector));

    _usda.deposit(_amount);
  }

  function testDepositAddsToReserve(uint56 _amount) public {
    vm.assume(_amount > 0);
    _usda.deposit(_amount);
    assertEq(_usda.reserveAmount(), _amount);
  }

  function testRevertsIfDeposit0Amount() public {
    vm.expectRevert(IUSDA.USDA_ZeroAmount.selector);
    _usda.deposit(0);
  }

  function testAddsToTotalSupply(uint56 _amount) public {
    vm.assume(_amount > 0);
    uint256 _totalSupplyBefore = _usda.totalSupply();
    _usda.deposit(_amount);
    assertEq(_usda.totalSupply(), uint256(_amount) + _totalSupplyBefore);
  }

  function testAddsToUserBalance(uint56 _amount) public {
    vm.assume(_amount > 0);
    _usda.deposit(_amount);
    assertEq(_usda.balanceOf(address(this)), uint256(_amount));
  }

  function testDepositRevertsIfPaused(uint56 _amount) public {
    vm.assume(_amount > 0);
    _usda.pause();
    vm.expectRevert('Pausable: paused');
    _usda.deposit(_amount);
  }
}

contract UnitUSDADepositTo is Base {
  address internal _otherUser = newAddress();

  function testDepositCallsTransferFrom(uint56 _amount) public {
    vm.assume(_amount > 0);
    vm.expectCall(
      address(_mockToken), abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(_usda), _amount)
    );

    _usda.depositTo(_amount, _otherUser);
  }

  function testDepositCallsPaysInterest(uint56 _amount) public {
    vm.assume(_amount > 0);
    vm.expectCall(address(_vaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector));

    _usda.depositTo(_amount, _otherUser);
  }

  function testDepositAddsToReserve(uint56 _amount) public {
    vm.assume(_amount > 0);
    _usda.depositTo(_amount, _otherUser);
    assertEq(_usda.reserveAmount(), _amount);
  }

  function testRevertsIfDeposit0Amount() public {
    vm.expectRevert(IUSDA.USDA_ZeroAmount.selector);
    _usda.depositTo(0, _otherUser);
  }

  function testAddsToTotalSupply(uint56 _amount) public {
    vm.assume(_amount > 0);
    uint256 _totalSupplyBefore = _usda.totalSupply();
    _usda.depositTo(_amount, _otherUser);
    assertEq(_usda.totalSupply(), uint256(_amount) + _totalSupplyBefore);
  }

  function testAddsToUserBalance(uint56 _amount) public {
    vm.assume(_amount > 0);
    _usda.depositTo(_amount, _otherUser);
    assertEq(_usda.balanceOf(_otherUser), uint256(_amount));
  }
}

contract UnitUSDAWithdraw is Base {
  uint256 internal _depositAmount = 100 * 1e6;

  function setUp() public virtual override {
    super.setUp();
    _usda.deposit(_depositAmount);
  }

  function testWithdrawRevertsIfAmountIsZero() public {
    vm.expectRevert(IUSDA.USDA_ZeroAmount.selector);
    _usda.withdraw(0);
  }

  function testWithdrawRevertsIfAmountIsGreaterThanBalance() public {
    vm.expectRevert(IUSDA.USDA_InsufficientFunds.selector);
    _usda.withdraw(_depositAmount + 1);
  }

  function testWithdrawRevertsIfPaused() public {
    _usda.pause();
    vm.expectRevert('Pausable: paused');
    _usda.withdraw(_depositAmount);
  }

  function testWithdrawSubstractsFromReserveAmount(uint256 _amount) public {
    vm.assume(_amount <= _depositAmount);
    vm.assume(_amount > 0);
    uint256 _reserveBefore = _usda.reserveAmount();
    _usda.withdraw(_amount);
    uint256 _reserveAfter = _usda.reserveAmount();
    assertEq(_reserveBefore - _amount, _reserveAfter);
  }

  function testWithdrawCallsTransferOnToken(uint256 _amount) public {
    vm.assume(_amount <= _depositAmount);
    vm.assume(_amount > 0);
    vm.expectCall(address(_mockToken), abi.encodeWithSelector(_mockToken.transfer.selector, address(this), _amount));
    _usda.withdraw(_amount);
  }

  function testWithdrawSubstractsFromTotalSupply(uint256 _amount) public {
    vm.assume(_amount <= _depositAmount);
    vm.assume(_amount > 0);
    uint256 _totalSupplyBefore = _usda.totalSupply();
    _usda.withdraw(_amount);
    uint256 _totalSupplyAfter = _usda.totalSupply();
    assertEq(_totalSupplyBefore - _amount, _totalSupplyAfter);
  }

  function testWithdrawSubstractsFromUserBalance(uint256 _amount) public {
    vm.assume(_amount <= _depositAmount);
    vm.assume(_amount > 0);
    uint256 _balanceBefore = _usda.balanceOf(address(this));
    _usda.withdraw(_amount);
    uint256 _balanceAfter = _usda.balanceOf(address(this));
    assertEq(_balanceBefore - _amount, _balanceAfter);
  }

  function testWithdrawCallsPayInterest() public {
    vm.expectCall(address(_vaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector));
    _usda.withdraw(_depositAmount);
  }
}

contract UnitUSDAWithdrawAll is Base {
  uint256 internal _depositAmount = 100 * 1e6;

  function setUp() public virtual override {
    super.setUp();
    _usda.deposit(_depositAmount);
  }

  function testWithdrawRevertsIfPaused() public {
    _usda.pause();
    vm.expectRevert('Pausable: paused');
    _usda.withdrawAll();
  }

  function testWithdrawSubstractsFromReserveAmount() public {
    uint256 _reserveBefore = _usda.reserveAmount();
    _usda.withdrawAll();
    uint256 _reserveAfter = _usda.reserveAmount();
    assertEq(_reserveBefore - _depositAmount, _reserveAfter);
  }

  function testWithdrawCallsTransferOnToken() public {
    vm.expectCall(
      address(_mockToken), abi.encodeWithSelector(_mockToken.transfer.selector, address(this), _depositAmount)
    );
    _usda.withdrawAll();
  }

  function testWithdrawSubstractsFromTotalSupply() public {
    uint256 _totalSupplyBefore = _usda.totalSupply();
    _usda.withdrawAll();
    uint256 _totalSupplyAfter = _usda.totalSupply();
    assertEq(_totalSupplyBefore - _depositAmount, _totalSupplyAfter);
  }

  function testWithdrawSubstractsFromUserBalance() public {
    uint256 _balanceBefore = _usda.balanceOf(address(this));
    _usda.withdrawAll();
    uint256 _balanceAfter = _usda.balanceOf(address(this));
    assertEq(_balanceBefore - _depositAmount, _balanceAfter);
  }

  function testWithdrawCallsPayInterest() public {
    vm.expectCall(address(_vaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector));
    _usda.withdrawAll();
  }

  function testWithdrawAllWhenAmountIsMoreThanReserve() public {
    vm.prank(_vaultController);
    // Remove half the reserve
    _usda.vaultControllerTransfer(newAddress(), _depositAmount / 2);
    vm.expectCall(
      address(_mockToken), abi.encodeWithSelector(_mockToken.transfer.selector, address(this), _depositAmount / 2)
    );
    _usda.withdrawAll();
  }
}

contract UnitUSDAMint is Base {
  uint256 internal _mintAmount = 100 * 1e6;

  function testRevertsIfCalledByNonOwner() public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    _usda.mint(_mintAmount);
  }

  function testRevertsIfAmountIsZero() public {
    vm.expectRevert(IUSDA.USDA_ZeroAmount.selector);
    _usda.mint(0);
  }

  function testAddsToTotalSupply(uint56 _amount) public {
    vm.assume(_amount > 0);
    uint256 _totalSupplyBefore = _usda.totalSupply();
    _usda.mint(_amount);
    uint256 _totalSupplyAfter = _usda.totalSupply();
    assertEq(_totalSupplyBefore + uint256(_amount), _totalSupplyAfter);
  }

  function testAddsToAdminBalance(uint56 _amount) public {
    vm.assume(_amount > 0);
    uint256 _balanceBefore = _usda.balanceOf(address(this));
    _usda.mint(_amount);
    uint256 _balanceAfter = _usda.balanceOf(address(this));
    assertEq(_balanceBefore + uint256(_amount), _balanceAfter);
  }
}

contract UnitUSDABurn is Base {
  uint256 internal _burnAmount = 100 * 1e6;

  function setUp() public virtual override {
    super.setUp();
    _usda.mint(_burnAmount);
  }

  function testRevertsIfCalledByNonOwner() public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    _usda.burn(_burnAmount);
  }

  function testRevertsIfAmountIsZero() public {
    vm.expectRevert(IUSDA.USDA_ZeroAmount.selector);
    _usda.burn(0);
  }

  function testSubsToTotalSupply(uint56 _amount) public {
    vm.assume(_amount > 0);
    vm.assume(_amount <= _burnAmount);
    uint256 _totalSupplyBefore = _usda.totalSupply();
    _usda.burn(_amount);
    uint256 _totalSupplyAfter = _usda.totalSupply();
    assertEq(_totalSupplyBefore - uint256(_amount), _totalSupplyAfter);
  }

  function testSubsToAdminBalance(uint56 _amount) public {
    vm.assume(_amount > 0);
    vm.assume(_amount <= _burnAmount);
    uint256 _balanceBefore = _usda.balanceOf(address(this));
    _usda.burn(_amount);
    uint256 _balanceAfter = _usda.balanceOf(address(this));
    assertEq(_balanceBefore - uint256(_amount), _balanceAfter);
  }
}

contract UnitUSDADonate is Base {
  uint256 internal _donateAmount = 10_000 * 1e6;
  address internal _otherUser = newAddress();

  function setUp() public virtual override {
    super.setUp();
    _usda.deposit(_donateAmount);
    vm.prank(_otherUser);
    _usda.deposit(_donateAmount);
  }

  function testRevertsIfAmountIsZero() public {
    vm.expectRevert(IUSDA.USDA_ZeroAmount.selector);
    _usda.donate(0);
  }

  function testCallsPaysInterest() public {
    vm.expectCall(address(_vaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector));
    _usda.donate(_donateAmount);
  }

  function testCallsTransferFromOnToken(uint256 _amount) public {
    vm.assume(_amount <= _donateAmount);
    vm.assume(_amount > 0);
    vm.expectCall(
      address(_mockToken),
      abi.encodeWithSelector(_mockToken.transferFrom.selector, address(this), address(_usda), _amount)
    );
    _usda.donate(_amount);
  }

  function testAddsToReserveAmount(uint256 _amount) public {
    vm.assume(_amount <= _donateAmount);
    vm.assume(_amount > 0);
    uint256 _reserveBefore = _usda.reserveAmount();
    _usda.donate(_amount);
    uint256 _reserveAfter = _usda.reserveAmount();
    assertEq(_reserveBefore + _amount, _reserveAfter);
  }

  function testAddsToTotalSupply(uint256 _amount) public {
    vm.assume(_amount <= _donateAmount);
    vm.assume(_amount > 0);
    uint256 _totalSupplyBefore = _usda.totalSupply();
    _usda.donate(_amount);
    uint256 _totalSupplyAfter = _usda.totalSupply();
    assertEq(_totalSupplyBefore + _amount, _totalSupplyAfter);
  }

  // A part of the supply is assigned to the zero address on initialization
  // that's why we need to substract the amount that is going to the zero address
  function testAddsToUserBalances(uint256 _amount) public {
    vm.assume(_amount <= _donateAmount);
    vm.assume(_amount > 0);
    _amount = _donateAmount;
    uint256 _totalSupplyBefore = _usda.totalSupply();

    uint256 _balanceZeroBefore = _usda.balanceOf(address(0));
    uint256 _amountToZeroAddress = (_amount * _balanceZeroBefore) / (_totalSupplyBefore);

    uint256 _balanceOtherUserBefore = _usda.balanceOf(_otherUser);
    uint256 _balanceAdminBefore = _usda.balanceOf(address(this));
    _usda.donate(_amount);
    uint256 _balanceOtherUserAfter = _usda.balanceOf(_otherUser);
    uint256 _balanceAdminAfter = _usda.balanceOf(address(this));

    assertApproxEqAbs(_balanceOtherUserBefore + (_amount - _amountToZeroAddress) / 2, _balanceOtherUserAfter, _DELTA);

    assertApproxEqAbs(_balanceAdminBefore + (_amount - _amountToZeroAddress) / 2, _balanceAdminAfter, _DELTA);
  }
}

contract UnitUSDARecoverDust is Base {
  uint256 internal _amountToRecover = 100 ether;
  uint256 internal _depositAmount = 100_000 ether;

  function setUp() public virtual override {
    super.setUp();
    _usda.deposit(_depositAmount);
    // Add some balance to the USDA contract to recover via mocking balance of in the mockToken
    vm.mockCall(
      address(_mockToken),
      abi.encodeWithSelector(_mockToken.balanceOf.selector, address(_usda)),
      abi.encode(_amountToRecover + _depositAmount)
    );
  }

  function testRevertsIfCalledByNonOwner() public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    _usda.recoverDust(address(_mockToken));
  }

  function testCallsTransferOnToken() public {
    vm.expectCall(
      address(_mockToken), abi.encodeWithSelector(_mockToken.transfer.selector, address(this), _amountToRecover)
    );
    _usda.recoverDust(address(this));
  }

  function testRevertsIfPaused() public {
    _usda.pause();
    vm.expectRevert('Pausable: paused');
    _usda.recoverDust(address(this));
  }
}

contract UnitUSDAVaultControllerMint is Base {
  uint256 internal _amountToMint = 100 ether;

  function testRevertsIfCalledByNonVault() public {
    vm.expectRevert(
      abi.encodeWithSelector(IRoles.Roles_Unauthorized.selector, address(this), _usda.VAULT_CONTROLLER_ROLE())
    );
    _usda.vaultControllerMint(address(this), _amountToMint);
  }

  function testAddsToTotalSupply(uint56 _amount) public {
    vm.assume(_amount > 0);
    uint256 _totalSupplyBefore = _usda.totalSupply();
    vm.prank(_vaultController);
    _usda.vaultControllerMint(_vaultController, _amount);
    uint256 _totalSupplyAfter = _usda.totalSupply();
    assertEq(_totalSupplyBefore + _amount, _totalSupplyAfter);
  }

  function testAddsToUserBalance(uint56 _amount) public {
    vm.assume(_amount > 0);
    uint256 _balanceBefore = _usda.balanceOf(_vaultController);
    vm.prank(_vaultController);
    _usda.vaultControllerMint(_vaultController, _amount);
    uint256 _balanceAfter = _usda.balanceOf(_vaultController);
    assertEq(_balanceBefore + _amount, _balanceAfter);
  }
}

contract UnitUSDAVaultControllerTransfer is Base {
  uint256 internal _amountToTransfer = 100 ether;

  function testRevertsIfCalledByNonVault() public {
    vm.expectRevert(
      abi.encodeWithSelector(IRoles.Roles_Unauthorized.selector, address(this), _usda.VAULT_CONTROLLER_ROLE())
    );
    _usda.vaultControllerTransfer(address(this), _amountToTransfer);
  }

  function testSubstractFromReserveAmount(uint56 _amount) public {
    vm.assume(_amount > 0);
    _usda.deposit(_amount);
    uint256 _reserveBefore = _usda.reserveAmount();
    vm.prank(_vaultController);
    _usda.vaultControllerTransfer(_vaultController, _amount);
    uint256 _reserveAfter = _usda.reserveAmount();
    assertEq(_reserveBefore - _amount, _reserveAfter);
  }
}

contract UnitUSDAAddVaultController is Base {
  function testRevertsIfCalledByNonOwner() public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    _usda.addVaultController(_vaultController2);
  }

  function testAddsVaultController() public {
    _usda.addVaultController(_vaultController2);
    assert(_usda.hasRole(_usda.VAULT_CONTROLLER_ROLE(), _vaultController2));
  }

  function testCallsPayInterestOnAllVaultControllers() public {
    vm.mockCall(
      address(_vaultController2),
      abi.encodeWithSelector(IVaultController.calculateInterest.selector),
      abi.encode(1 ether)
    );

    _usda.addVaultController(_vaultController2);
    vm.expectCall(address(_vaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector));
    vm.expectCall(address(_vaultController2), abi.encodeWithSelector(IVaultController.calculateInterest.selector));
    _usda.mint(1);
  }
}

contract UnitUSDARemoveVaultController is Base {
  function setUp() public virtual override {
    super.setUp();
    _usda.addVaultController(_vaultController2);
  }

  function testRevertsIfCalledByNonOwner() public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    _usda.removeVaultController(_vaultController2);
  }

  function testRemovesVaultController() public {
    _usda.removeVaultController(_vaultController);
    assert(!_usda.hasRole(_usda.VAULT_CONTROLLER_ROLE(), _vaultController));
  }

  function testDoesNotCallPayInterestOnRemovedVaultControllers() public {
    _usda.removeVaultController(_vaultController2);
    vm.expectCall(address(_vaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector));
    _usda.mint(1);
  }
}

contract UnitUSDARemoveVaultControllerFromList is Base {
  function setUp() public virtual override {
    super.setUp();
    _usda.addVaultController(_vaultController2);
  }

  function testRevertsIfCalledByNonOwner() public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    _usda.removeVaultControllerFromList(_vaultController2);
  }

  function testKeepsRoleVaultController() public {
    _usda.removeVaultControllerFromList(_vaultController2);
    assert(_usda.hasRole(_usda.VAULT_CONTROLLER_ROLE(), _vaultController2));
  }

  function testDoesNotCallPayInterestOnRemovedVaultControllers() public {
    _usda.removeVaultControllerFromList(_vaultController2);
    vm.expectCall(address(_vaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector));
    _usda.mint(1);
  }
}
