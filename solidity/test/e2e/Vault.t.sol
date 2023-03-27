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

    // fill with AMPH tokens
    vm.prank(amphToken.owner());
    amphToken.mint(address(amphClaimer), 100 ether);
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

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);

    vm.warp(block.timestamp + 5 days);

    IVault.Reward[] memory _rewards = bobVault.claimableRewards(address(usdtStableLP));
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(usdtStableLP);
    vm.prank(bob);
    bobVault.claimRewards(_tokens);

    assertTrue(_rewards[0].amount != 0);
    assertTrue(_rewards[1].amount != 0);

    // _rewards[0] should be CRV and _rewards[1] AMPH in this case
    assertEq(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards[0].amount);
    assertEq(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards[1].amount);
  }

  function testClaimMultipleCurveLPWithExtraRewards() public {
    uint256 _depositAmount = 0.1 ether;

    // deposit and stake
    vm.startPrank(bob);
    boringDaoLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(boringDaoLP), _depositAmount);

    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceVirtualBefore = IERC20(BOR_DAO_ADDRESS).balanceOf(bob);
    uint256 _balanceOtherVirtualBefore = IERC20(BORING_DAO_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);

    vm.prank(BOOSTER);
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(BOOSTER);
    IBaseRewardPool(BORING_DAO_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(BORING_DAO_VIRTUAL_REWARDS_OPERATOR_CONTRACT);
    IVirtualBalanceRewardPool(BORING_DAO_LP_VIRTUAL_REWARDS_CONTRACT).queueNewRewards(_depositAmount);

    // pass time
    vm.warp(block.timestamp + 5 days);

    IVault.Reward[] memory _rewards = bobVault.claimableRewards(address(usdtStableLP));
    IVault.Reward[] memory _rewards2 = bobVault.claimableRewards(address(boringDaoLP));

    address[] memory _tokensToClaim = new address[](2);
    _tokensToClaim[0] = address(boringDaoLP);
    _tokensToClaim[1] = address(usdtStableLP);

    // claim
    vm.startPrank(bob);
    bobVault.claimRewards(_tokensToClaim);
    vm.stopPrank();

    assertTrue(_rewards[0].amount != 0); // _rewards[0] = CRV rewards
    assertTrue(_rewards[1].amount != 0); // _rewards[1] = AMPH rewards
    assertTrue(_rewards2[0].amount != 0); // _rewards2[0] = CRV rewards
    assertTrue(_rewards2[1].amount != 0); // _rewards2[1] = extra rewards
    assertTrue(_rewards2[2].amount != 0); // _rewards2[2] = other extra rewards
    assertTrue(_rewards2[3].amount != 0); // _rewards2[2] = AMPH rewards

    assertEq(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards[0].amount + _rewards2[0].amount);
    assertEq(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards[1].amount + _rewards2[3].amount);
    assertEq(IERC20(BOR_DAO_ADDRESS).balanceOf(bob), _balanceVirtualBefore + _rewards2[1].amount);
    assertEq(IERC20(BORING_DAO_ADDRESS).balanceOf(bob), _balanceOtherVirtualBefore + _rewards2[2].amount);
  }
}
