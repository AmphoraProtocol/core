// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase} from '@test/e2e/Common.sol';
import {IUSDA} from '@interfaces/core/IUSDA.sol';

contract E2EUSDA is CommonE2EBase {
  uint256 public susdAmount = 500_000_000;

  event Deposit(address indexed _from, uint256 _value);
  event Withdraw(address indexed _from, uint256 _value);

  function setUp() public override {
    super.setUp();
  }

  function testDepositSUSD() public {
    _depositSUSD(andy, andySUSDBalance);
    assertEq(usdaToken.balanceOf(andy), andySUSDBalance * 1e12);
  }

  function testRevertIfBurnByNonAdmin() public {
    vm.expectRevert();
    vm.prank(bob);
    usdaToken.burn(100);
  }

  function testDepositAndInterestWithStartingBalance() public {
    assertEq(susd.balanceOf(dave), daveSUSD);

    vm.prank(dave);
    susd.approve(address(usdaToken), susdAmount);

    uint256 _daveUSDABalance = usdaToken.balanceOf(dave);

    /// Test pause/unpause
    vm.prank(frank);
    usdaToken.pause();

    vm.expectRevert('Pausable: paused');
    vm.prank(dave);
    usdaToken.deposit(susdAmount);

    vm.prank(frank);
    usdaToken.unpause();

    /// Test deposit
    vm.expectEmit(false, false, false, true);
    emit Deposit(address(dave), susdAmount * 1e12);

    vm.prank(dave);
    usdaToken.deposit(susdAmount);

    assertEq(susd.balanceOf(dave), daveSUSD - susdAmount);
    // some interest has accrued, USDA balance should be slightly higher than existingUSDA balance + sUSD amount deposited
    vaultController.calculateInterest();
    assertGt(usdaToken.balanceOf(dave), _daveUSDABalance + susdAmount);
  }

  function testRevertIfDepositingMoreThanBalance() public {
    assertEq(0, susd.balanceOf(eric));

    vm.startPrank(eric);
    susd.approve(address(usdaToken), susdAmount);

    vm.expectRevert('ERC20: transfer amount exceeds balance');
    usdaToken.deposit(susdAmount);
    vm.stopPrank();
  }

  function testRevertIfDepositIsZero() public {
    vm.startPrank(dave);
    susd.approve(address(usdaToken), susdAmount);

    vm.expectRevert(IUSDA.USDA_ZeroAmount.selector);
    usdaToken.deposit(0);
    vm.stopPrank();
  }

  function testWithdrawSUSD() public {
    /// Deposit
    _depositSUSD(dave, susdAmount);

    vm.warp(block.timestamp + 1 days);

    /// Test pause/unpause
    vm.prank(frank);
    usdaToken.pause();

    vm.expectRevert('Pausable: paused');
    vm.prank(dave);
    usdaToken.withdraw(susdAmount);

    vm.prank(frank);
    usdaToken.unpause();

    /// SUSD balance before
    uint256 _susdBefore = susd.balanceOf(dave);
    assertEq(_susdBefore, daveSUSD - susdAmount);

    /// Withdraw
    vm.prank(dave);
    usdaToken.withdraw(susdAmount);
    assertEq(susd.balanceOf(dave), daveSUSD);

    /// TODO: FAILS
    /// Should end up with slightly more USDA than original due to interest
    // assertGt(usdaToken.balanceOf(dave), _usdaBefore);
  }

  function testRevertIfWithdrawMoreThanBalance() public {
    /// Deposit
    _depositSUSD(andy, andySUSDBalance);

    uint256 _usdaBalanceBefore = usdaToken.balanceOf(eric);
    assertEq(0, _usdaBalanceBefore);

    vm.prank(andy);
    usdaToken.transfer(eric, 1 ether);

    assertEq(1 ether, usdaToken.balanceOf(eric));

    vm.expectRevert(IUSDA.USDA_InsufficientFunds.selector);
    vm.prank(eric);
    usdaToken.withdraw(5 ether);
  }

  function testWithdrawAllReserve() public {
    /// Deposit
    _depositSUSD(bob, bobSUSDBalance);

    uint256 _reserve = susd.balanceOf(address(usdaToken));
    assertEq(_reserve * 1e12, usdaToken.balanceOf(bob));

    vm.prank(bob);
    usdaToken.transfer(dave, _reserve * 1e12);

    uint256 _susdBalance = susd.balanceOf(dave);

    vm.expectEmit(false, false, false, true);
    emit Withdraw(address(dave), _reserve * 1e12);

    /// Withdraw
    vm.prank(dave);
    usdaToken.withdrawAll();

    uint256 _susdBalanceAfter = susd.balanceOf(dave);
    uint256 _reserveAfter = susd.balanceOf(address(usdaToken));

    assertEq(_susdBalanceAfter, _susdBalance + _reserve);
    assertEq(0, _reserveAfter);

    vm.startPrank(dave);
    vm.expectRevert();
    usdaToken.withdraw(1);

    vm.expectRevert('Reserve is empty');
    usdaToken.withdrawAll();
    vm.stopPrank();
  }

  function testDonateSUSD() public {
    uint256 _daveSUSDBalance = susd.balanceOf(dave);
    uint256 _reserve = susd.balanceOf(address(usdaToken));
    assertEq(0, _reserve);

    /// Donate
    vm.startPrank(dave);
    susd.approve(address(usdaToken), _daveSUSDBalance / 2);
    usdaToken.donate(_daveSUSDBalance / 2);
    vm.stopPrank();

    uint256 _reserveAfter = susd.balanceOf(address(usdaToken));
    assertGt(_reserveAfter, 0);
  }

  function testRevertIfDepositETH() public {
    vm.expectRevert();
    vm.prank(dave);
    address(usdaToken).call{value: 1 ether}('');
  }

  function testTransferSUSDtoUSDA() public {
    uint256 _reserve = susd.balanceOf(address(usdaToken));
    uint256 _reserveRatio = usdaToken.reserveRatio();
    uint256 _usdaSupply = usdaToken.totalSupply();

    vm.prank(dave);
    susd.transfer(address(usdaToken), 1_000_000);

    uint256 _reserveAfter = susd.balanceOf(address(usdaToken));
    uint256 _reserveRatioAfter = usdaToken.reserveRatio();
    uint256 _usdaSupplyAfter = usdaToken.totalSupply();

    assertEq(_usdaSupply, _usdaSupplyAfter);
    assertGt(_reserveAfter, _reserve);
    assertGt(_reserveRatioAfter, _reserveRatio);
  }
}
