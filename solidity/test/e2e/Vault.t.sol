// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase} from '@test/e2e/Common.sol';

import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {VaultController} from '@contracts/core/VaultController.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IBaseRewardPool} from '@interfaces/utils/IBaseRewardPool.sol';
import {IVirtualBalanceRewardPool} from '@interfaces/utils/IVirtualBalanceRewardPool.sol';

contract E2EVault is CommonE2EBase {
  uint96 public bobsVaultId = 1;
  uint256 public bobDeposit = 5 ether;

  function setUp() public override {
    super.setUp();

    // Bob mints vault
    _mintVault(bob);
    // Since we only have 1 vault the id: 1 is gonna be Bob's vault
    bobVault = IVault(vaultController.vaultAddress(bobsVaultId));

    vm.startPrank(bob);
    weth.approve(address(bobVault), bobDeposit);
    bobVault.depositERC20(address(weth), bobDeposit);
    vm.stopPrank();
  }

  function testWithdrawWhileLTVisEnough() public {
    // bob should be able to withdraw since there is no liability
    vm.startPrank(bob);
    bobVault.withdrawERC20(address(weth), 1 ether);
    weth.approve(address(bobVault), 1 ether);
    bobVault.depositERC20(address(weth), 1 ether);
    vm.stopPrank();

    uint192 _accountBorrowingPower = vaultController.vaultBorrowingPower(bobsVaultId);

    // Borrow the maximum amount
    vm.prank(bob);
    vaultController.borrowUSDA(bobsVaultId, _accountBorrowingPower);

    // Advance 1 week and add interest
    vm.warp(block.timestamp + 1 weeks);
    vaultController.calculateInterest();

    // should revert when the ltv is not enough
    vm.expectRevert(IVault.Vault_OverWithdrawal.selector);
    vm.prank(bob);
    bobVault.withdrawERC20(address(weth), 1 ether);
  }

  function testRecoverDust() public {
    vm.prank(bob);
    weth.transfer(address(bobVault), 1 ether);

    uint256 _vaultBalance = weth.balanceOf(address(bobVault));
    uint256 _bobBalance = weth.balanceOf(bob);
    assertEq(_vaultBalance, bobDeposit + 1 ether);

    vm.prank(bob);
    bobVault.recoverDust(WETH_ADDRESS);

    assertEq(weth.balanceOf(address(bobVault)), bobDeposit);
    assertEq(weth.balanceOf(bob), _bobBalance + 1 ether);
  }

  function testStakeAndWithdrawCurveLP() public {
    uint256 _depositAmount = 10 ether;
    uint256 _stakedBalance = usdtStableLP.balanceOf(USDT_LP_STAKED_CONTRACT);

    vm.startPrank(bob);
    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    uint256 _balanceAfterDeposit = usdtStableLP.balanceOf(bob);
    assertEq(bobVault.tokenBalance(address(usdtStableLP)), _depositAmount);
    assertEq(_balanceAfterDeposit, bobWETH - _depositAmount);
    assertEq(usdtStableLP.balanceOf(USDT_LP_STAKED_CONTRACT), _stakedBalance + _depositAmount);

    vm.prank(bob);
    bobVault.withdrawERC20(address(usdtStableLP), _depositAmount);
    assertEq(bobVault.tokenBalance(address(usdtStableLP)), 0);
    assertEq(_balanceAfterDeposit + _depositAmount, bobWETH);
    assertEq(usdtStableLP.balanceOf(USDT_LP_STAKED_CONTRACT), _stakedBalance);
  }

  function testClaimCurveLPRewards() public {
    uint256 _depositAmount = 10 ether;

    vm.startPrank(bob);
    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    vm.prank(BOOSTER);
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    uint256 _balanceBefore = IERC20(CRV_ADDRESS).balanceOf(bob);

    vm.warp(block.timestamp + 5 days);
    uint256 _crvEarned = IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).earned(address(bobVault));
    assertTrue(_crvEarned != 0);

    vm.prank(bob);
    bobVault.claimRewards(address(usdtStableLP));

    assertEq(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBefore + _crvEarned);
  }

  function testClaimCurveLPWithExtraRewards() public {
    uint256 _depositAmount = 0.1 ether;

    // deposit and stake
    vm.startPrank(bob);
    boringDaoLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(boringDaoLP), _depositAmount);
    vm.stopPrank();

    uint256 _balanceBefore = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceVirtualBefore = IERC20(BORING_DAO_ADDRESS).balanceOf(bob);

    vm.prank(BOOSTER);
    IBaseRewardPool(BORING_DAO_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(BORING_DAO_VIRTUAL_REWARDS_OPERATOR_CONTRACT);
    IVirtualBalanceRewardPool(BORING_DAO_LP_VIRTUAL_REWARDS_CONTRACT).queueNewRewards(_depositAmount);

    // pass time
    vm.warp(block.timestamp + 5 days);

    uint256 _crvEarnner = IBaseRewardPool(BORING_DAO_LP_REWARDS_ADDRESS).earned(address(bobVault));
    uint256 _virtualEarner = IVirtualBalanceRewardPool(BORING_DAO_LP_VIRTUAL_REWARDS_CONTRACT).earned(address(bobVault));

    assertTrue(_crvEarnner != 0);
    assertTrue(_virtualEarner != 0);

    // claim
    vm.prank(bob);
    bobVault.claimRewards(address(boringDaoLP));

    assertEq(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBefore + _crvEarnner);
    assertEq(IERC20(BORING_DAO_ADDRESS).balanceOf(bob), _balanceVirtualBefore + _virtualEarner);
  }
}
