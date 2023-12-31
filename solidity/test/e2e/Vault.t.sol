// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, console} from '@test/e2e/Common.sol';

import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {VaultController} from '@contracts/core/VaultController.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IBaseRewardPool} from '@interfaces/utils/IBaseRewardPool.sol';
import {IVirtualBalanceRewardPool} from '@interfaces/utils/IVirtualBalanceRewardPool.sol';
import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {ICVX} from '@interfaces/utils/ICVX.sol';
import {IConvexProxyVoter} from '@interfaces/utils/IConvexProxyVoter.sol';
import {IBooster} from '@interfaces/utils/IBooster.sol';

contract E2EVault is CommonE2EBase {
  uint256 public bobDeposit = 5 ether;

  function setUp() public override {
    super.setUp();

    // Bob mints vault
    bobVaultId = _mintVault(bob);
    // Since we only have 1 vault the id: 1 is gonna be Bob's vault
    bobVault = IVault(vaultController.vaultIdVaultAddress(bobVaultId));

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

    uint192 _accountBorrowingPower = vaultController.vaultBorrowingPower(bobVaultId);

    // Borrow the maximum amount
    vm.prank(bob);
    vaultController.borrowUSDA(bobVaultId, _accountBorrowingPower);

    // Advance 1 week and add interest
    vm.warp(block.timestamp + 1 weeks);
    vaultController.calculateInterest();

    // should revert when the ltv is not enough
    vm.expectRevert(IVault.Vault_OverWithdrawal.selector);
    vm.prank(bob);
    bobVault.withdrawERC20(address(weth), 1 ether);
  }

  function testStakeAndWithdrawCurveLP() public {
    uint256 _depositAmount = 10 ether;
    uint256 _stakedBalance = usdtStableLP.balanceOf(USDT_LP_STAKED_CONTRACT);

    // Deposit and stake
    vm.startPrank(bob);
    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    uint256 _balanceAfterDeposit = usdtStableLP.balanceOf(bob);
    assertEq(bobVault.balances(address(usdtStableLP)), _depositAmount);
    assertEq(_balanceAfterDeposit, bobWETH - _depositAmount);
    assertEq(usdtStableLP.balanceOf(USDT_LP_STAKED_CONTRACT), _stakedBalance + _depositAmount);

    // Withdraw and unstake
    vm.prank(bob);
    bobVault.withdrawERC20(address(usdtStableLP), _depositAmount);
    assertEq(bobVault.balances(address(usdtStableLP)), 0);
    assertEq(_balanceAfterDeposit + _depositAmount, bobWETH);
    assertEq(usdtStableLP.balanceOf(USDT_LP_STAKED_CONTRACT), _stakedBalance);
  }

  function testDepositMultipleCurveLPAndBorrow() public {
    uint256 _depositAmount = 1 ether;

    // deposit and stake
    vm.startPrank(bob);
    gearLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(gearLP), _depositAmount);

    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    assertEq(usdaToken.balanceOf(bob), 0);

    // get max borrowing power and borrow
    uint192 _maxBorrow = vaultController.vaultBorrowingPower(bobVaultId);
    assertGt(_maxBorrow, 0);
    vaultController.borrowUSDA(bobVaultId, _maxBorrow);
    vm.stopPrank();
    assertEq(usdaToken.balanceOf(bob), _maxBorrow);
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
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);
    assertEq(IERC20(CRV_ADDRESS).balanceOf(address(governor)), 0);

    vm.warp(block.timestamp + 5 days);

    IVault.Reward[] memory _rewards = bobVault.claimableRewards(address(usdtStableLP), true);
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(usdtStableLP);
    vm.prank(bob);
    bobVault.claimRewards(_tokens, true);

    assertTrue(_rewards[0].amount != 0);
    assertTrue(_rewards[1].amount != 0);

    // _rewards[0] should be CRV and _rewards[1] AMPH in this case
    assertEq(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards[0].amount);
    assertEq(IERC20(CVX_ADDRESS).balanceOf(bob), _balanceBeforeCVX + _rewards[1].amount);
    assertEq(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards[2].amount);
    assertGt(IERC20(CRV_ADDRESS).balanceOf(address(governor)), 0);
    assertGt(IERC20(CVX_ADDRESS).balanceOf(address(governor)), 0);
    assertEq(IERC20(CRV_ADDRESS).balanceOf(address(bobVault)), 0);
    assertEq(IERC20(CVX_ADDRESS).balanceOf(address(bobVault)), 0);
  }

  function testClaimableCurveLPRewardsAfterThirdPartyClaimed() public {
    uint256 _bobCRV = 1000 ether;
    deal(address(crv), bob, _bobCRV);

    uint256 _depositAmount = 10 ether;

    vm.startPrank(bob);
    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);

    crv.approve(address(bobVault), _bobCRV);
    bobVault.depositERC20(address(crv), _bobCRV);
    vm.stopPrank();

    vm.prank(BOOSTER);
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);
    assertEq(IERC20(CRV_ADDRESS).balanceOf(address(governor)), 0);

    vm.warp(block.timestamp + 5 days);

    IVault.Reward[] memory _rewards = bobVault.claimableRewards(address(usdtStableLP), true);
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(usdtStableLP);

    // Here we force claim the rewards of the vault
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).getReward(address(bobVault), true);

    IVault.Reward[] memory _rewards2 = bobVault.claimableRewards(address(usdtStableLP), true);
    assertEq(_rewards.length, _rewards2.length);
    assertEq(address(_rewards[0].token), address(_rewards2[0].token));
    assertEq(_rewards[0].amount, _rewards2[0].amount);
    assertEq(address(_rewards[1].token), address(_rewards2[1].token));
    assertEq(_rewards[1].amount, _rewards2[1].amount);
    assertEq(address(_rewards[2].token), address(_rewards2[2].token));
    assertEq(_rewards[2].amount, _rewards2[2].amount);

    vm.prank(bob);
    bobVault.claimRewards(_tokens, true);

    // _rewards[0] should be CRV and _rewards[1] AMPH in this case
    assertEq(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards[0].amount);
    assertEq(IERC20(CVX_ADDRESS).balanceOf(bob), _balanceBeforeCVX + _rewards[1].amount);
    assertEq(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards[2].amount);
    assertGt(IERC20(CRV_ADDRESS).balanceOf(address(governor)), 0);
    assertGt(IERC20(CVX_ADDRESS).balanceOf(address(governor)), 0);
    assertEq(IERC20(CRV_ADDRESS).balanceOf(address(bobVault)), _bobCRV);
    assertEq(IERC20(CVX_ADDRESS).balanceOf(address(bobVault)), 0);
  }

  function testClaimCurveLPRewardsWithClaimerAsZeroAddress() public {
    uint256 _depositAmount = 10 ether;

    vm.startPrank(bob);
    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    vm.prank(BOOSTER);
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.warp(block.timestamp + 5 days);

    address[] memory _tokens = new address[](1);
    _tokens[0] = address(usdtStableLP);

    // change claimer to 0x0
    vm.prank(address(governor));
    vaultController.changeClaimerContract(IAMPHClaimer(address(0)));

    // check that amph was not claimed
    IVault.Reward[] memory _rewardsInZero = bobVault.claimableRewards(address(usdtStableLP), true);
    for (uint256 _i; _i < _rewardsInZero.length; _i++) {
      if (address(_rewardsInZero[_i].token) == address(amphToken)) revert('fail: amph was claimed'); // if finds amph rewards trigger a revert
    }

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _amphBalanceBeforeClaimingInZero = amphToken.balanceOf(bob);

    vm.prank(bob);
    bobVault.claimRewards(_tokens, true);

    uint256 _balanceAfterCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceAfterCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _amphBalanceAfterClaimingInZero = amphToken.balanceOf(bob);

    assertGt(_balanceAfterCVX, _balanceBeforeCVX);
    assertGt(_balanceAfterCRV, _balanceBeforeCRV);
    assertEq(_amphBalanceBeforeClaimingInZero, _amphBalanceAfterClaimingInZero);
  }

  function testClaimCurveLPRewardsOverAndOverShouldTransferAllCVXBalance() public {
    // change claimer to 0x0
    vm.prank(address(governor));
    vaultController.changeClaimerContract(IAMPHClaimer(address(0)));

    uint256 _depositAmount = 10 ether;

    vm.startPrank(bob);
    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    vm.prank(BOOSTER);
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    address[] memory _tokens = new address[](1);
    _tokens[0] = address(usdtStableLP);

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);

    uint256 _totalCRVClaimed;
    uint256 _totalCVXClaimed;

    for (uint256 _i; _i < 10; ++_i) {
      vm.warp(block.timestamp + 5 days);
      IVault.Reward[] memory _rewards = bobVault.claimableRewards(address(usdtStableLP), true);
      _totalCRVClaimed += _rewards[0].amount;
      _totalCVXClaimed += _rewards[1].amount;

      vm.prank(bob);
      bobVault.claimRewards(_tokens, true);
    }

    uint256 _balanceAfterCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceAfterCVX = IERC20(CVX_ADDRESS).balanceOf(bob);

    assertEq(_balanceBeforeCRV, _balanceAfterCRV - _totalCRVClaimed);
    assertEq(_balanceBeforeCVX, _balanceAfterCVX - _totalCVXClaimed);
    assertEq(IERC20(CVX_ADDRESS).balanceOf(address(bobVault)), 0);
  }

  function testClaimMultipleCurveLPWithExtraRewards() public {
    uint256 _depositAmount = 0.1 ether;

    // deposit and stake
    vm.startPrank(bob);
    gearLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(gearLP), _depositAmount);

    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    assertEq(usdtStableLP.balanceOf(bob), bobCurveLPBalance - _depositAmount);

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _balanceVirtualBefore = IERC20(GEAR_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);

    vm.prank(BOOSTER);
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(BOOSTER);
    IBaseRewardPool(GEAR_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(GEAR_VIRTUAL_REWARDS_OPERATOR_CONTRACT);
    IVirtualBalanceRewardPool(GEAR_LP_VIRTUAL_REWARDS_CONTRACT).queueNewRewards(_depositAmount);

    // pass time
    vm.warp(block.timestamp + 5 days);

    // Withdraw and unstake usdtCurveLP
    vm.prank(bob);
    bobVault.withdrawERC20(address(usdtStableLP), _depositAmount);
    assertEq(bobVault.balances(address(usdtStableLP)), 0);
    assertEq(usdtStableLP.balanceOf(bob), bobCurveLPBalance);

    IVault.Reward[] memory _rewards = bobVault.claimableRewards(address(usdtStableLP), true);
    IVault.Reward[] memory _rewards2 = bobVault.claimableRewards(address(gearLP), true);

    address[] memory _tokensToClaim = new address[](2);
    _tokensToClaim[0] = address(gearLP);
    _tokensToClaim[1] = address(usdtStableLP);

    uint256 _balanceCrvGovBefore = IERC20(CRV_ADDRESS).balanceOf(address(governor));
    uint256 _balanceCvxGovBefore = IERC20(CVX_ADDRESS).balanceOf(address(governor));

    // claim
    vm.startPrank(bob);
    bobVault.claimRewards(_tokensToClaim, true);
    vm.stopPrank();

    // governance should have received the tokens
    assertGt(IERC20(CRV_ADDRESS).balanceOf(address(governor)), _balanceCrvGovBefore);
    assertGt(IERC20(CVX_ADDRESS).balanceOf(address(governor)), _balanceCvxGovBefore);

    assertEq(_rewards.length, 3);
    assertEq(_rewards2.length, 4);

    assertTrue(_rewards[0].amount != 0); // _rewards[0] = CRV rewards
    assertTrue(_rewards[1].amount != 0); // _rewards[1] = CVX rewards
    assertTrue(_rewards[2].amount != 0); // _rewards[2] = AMPH rewards
    assertTrue(_rewards2[0].amount != 0); // _rewards2[0] = CRV rewards
    assertTrue(_rewards2[1].amount != 0); // _rewards2[1] = CVX rewards
    assertTrue(_rewards2[2].amount != 0); // _rewards2[2] = GEAR rewards
    assertTrue(_rewards2[3].amount != 0); // _rewards2[3] = AMPH rewards
    assertApproxEqAbs(
      IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards[0].amount + _rewards2[0].amount, 1
    );
    assertApproxEqAbs(
      IERC20(CVX_ADDRESS).balanceOf(bob), _balanceBeforeCVX + _rewards[1].amount + _rewards2[1].amount, 1
    );
    // This 10 wei difference is because of the claiming order or the rewards and is an acceptable difference.
    // When calling the view method claimable it doesn't affect the CVX supply so the rewards don't change between claims
    assertApproxEqAbs(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards[2].amount + _rewards2[3].amount, 10);
    assertEq(IERC20(GEAR_ADDRESS).balanceOf(bob), _balanceVirtualBefore + _rewards2[2].amount);
  }

  function testClaimMultipleCurveLPWithoutExtraRewards() public {
    uint256 _depositAmount = 0.1 ether;

    // deposit and stake
    vm.startPrank(bob);
    gearLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(gearLP), _depositAmount);

    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    assertEq(usdtStableLP.balanceOf(bob), bobCurveLPBalance - _depositAmount);

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _balanceVirtualBefore = IERC20(GEAR_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);

    vm.prank(BOOSTER);
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(BOOSTER);
    IBaseRewardPool(GEAR_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(GEAR_VIRTUAL_REWARDS_OPERATOR_CONTRACT);
    IVirtualBalanceRewardPool(GEAR_LP_VIRTUAL_REWARDS_CONTRACT).queueNewRewards(_depositAmount);

    // pass time
    vm.warp(block.timestamp + 5 days);

    // Withdraw and unstake usdtCurveLP
    vm.prank(bob);
    bobVault.withdrawERC20(address(usdtStableLP), _depositAmount);
    assertEq(bobVault.balances(address(usdtStableLP)), 0);
    assertEq(usdtStableLP.balanceOf(bob), bobCurveLPBalance);

    IVault.Reward[] memory _rewards = bobVault.claimableRewards(address(usdtStableLP), false);
    IVault.Reward[] memory _rewards2 = bobVault.claimableRewards(address(gearLP), false);

    address[] memory _tokensToClaim = new address[](2);
    _tokensToClaim[0] = address(gearLP);
    _tokensToClaim[1] = address(usdtStableLP);

    uint256 _balanceCrvGovBefore = IERC20(CRV_ADDRESS).balanceOf(address(governor));
    uint256 _balanceCvxGovBefore = IERC20(CVX_ADDRESS).balanceOf(address(governor));

    // claim
    vm.startPrank(bob);
    bobVault.claimRewards(_tokensToClaim, false);
    vm.stopPrank();

    // governance should have received the tokens
    assertGt(IERC20(CRV_ADDRESS).balanceOf(address(governor)), _balanceCrvGovBefore);
    assertGt(IERC20(CVX_ADDRESS).balanceOf(address(governor)), _balanceCvxGovBefore);

    assertEq(_rewards.length, 3);
    assertEq(_rewards2.length, 3);
    assertTrue(_rewards[0].amount != 0); // _rewards[0] = CRV rewards
    assertTrue(_rewards[1].amount != 0); // _rewards[1] = CVX rewards
    assertTrue(_rewards[2].amount != 0); // _rewards[2] = AMPH rewards
    assertTrue(_rewards2[0].amount != 0); // _rewards2[0] = CRV rewards
    assertTrue(_rewards2[1].amount != 0); // _rewards2[1] = CVX rewards
    assertTrue(_rewards2[2].amount != 0); // _rewards2[2] = AMPH rewards
    assertApproxEqAbs(
      IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards[0].amount + _rewards2[0].amount, 1
    );
    assertApproxEqAbs(
      IERC20(CVX_ADDRESS).balanceOf(bob), _balanceBeforeCVX + _rewards[1].amount + _rewards2[1].amount, 1
    );
    // This 10 wei difference is because of the claiming order or the rewards and is an acceptable difference.
    // When calling the view method claimable it doesn't affect the CVX supply so the rewards don't change between claims
    assertApproxEqAbs(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards[2].amount + _rewards2[2].amount, 10);
    assertEq(IERC20(GEAR_ADDRESS).balanceOf(bob), _balanceVirtualBefore);
  }

  function testClaimWhenOperatorChanged() public {
    uint256 _depositAmount = 0.1 ether;

    vm.prank(BOOSTER);
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(BOOSTER);
    IBaseRewardPool(GEAR_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(GEAR_VIRTUAL_REWARDS_OPERATOR_CONTRACT);
    IVirtualBalanceRewardPool(GEAR_LP_VIRTUAL_REWARDS_CONTRACT).queueNewRewards(_depositAmount);

    // deposit and stake
    vm.startPrank(bob);
    gearLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(gearLP), _depositAmount);

    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    assertEq(usdtStableLP.balanceOf(bob), bobCurveLPBalance - _depositAmount);

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _balanceVirtualBefore = IERC20(GEAR_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);

    // pass time
    vm.warp(block.timestamp + 5 days);

    // Withdraw and unstake usdtCurveLP
    vm.prank(bob);
    bobVault.withdrawERC20(address(usdtStableLP), _depositAmount);
    assertEq(bobVault.balances(address(usdtStableLP)), 0);
    assertEq(usdtStableLP.balanceOf(bob), bobCurveLPBalance);

    {
      address _newOperator = mockContract(newAddress(), 'newOperator');
      vm.mockCall(_newOperator, abi.encodeWithSignature('rewardClaimed(uint256,address,uint256)'), abi.encode(true));

      // Get the proxy voter for convex
      IConvexProxyVoter _veCrvProxy = IConvexProxyVoter((ICVX(CVX_ADDRESS).vecrvProxy()));
      address _veCrvProxyOwner = _veCrvProxy.owner();

      // Shutdown the current operator
      IBooster _booster = IBooster(_veCrvProxy.operator());
      vm.prank(_booster.owner());
      _booster.shutdownSystem();

      // Change the operator for CVX
      vm.prank(_veCrvProxyOwner);
      _veCrvProxy.setOperator(_newOperator);
      ICVX(CVX_ADDRESS).updateOperator();
    }

    IVault.Reward[] memory _rewards = bobVault.claimableRewards(address(usdtStableLP), true);
    IVault.Reward[] memory _rewards2 = bobVault.claimableRewards(address(gearLP), true);

    address[] memory _tokensToClaim = new address[](2);
    _tokensToClaim[0] = address(gearLP);
    _tokensToClaim[1] = address(usdtStableLP);

    uint256 _balanceCrvGovBefore = IERC20(CRV_ADDRESS).balanceOf(address(governor));
    uint256 _balanceCvxGovBefore = IERC20(CVX_ADDRESS).balanceOf(address(governor));

    // claim
    vm.startPrank(bob);
    bobVault.claimRewards(_tokensToClaim, true);
    vm.stopPrank();

    // governance should have received the tokens
    assertGt(IERC20(CRV_ADDRESS).balanceOf(address(governor)), _balanceCrvGovBefore);
    assertEq(IERC20(CVX_ADDRESS).balanceOf(address(governor)), _balanceCvxGovBefore);

    assertTrue(_rewards[0].amount != 0); // _rewards[0] = CRV rewards
    assertTrue(_rewards[1].amount == 0); // _rewards[1] = CVX rewards
    assertTrue(_rewards[2].amount != 0); // _rewards[2] = AMPH rewards
    assertTrue(_rewards2[0].amount != 0); // _rewards2[0] = CRV rewards
    assertTrue(_rewards2[1].amount == 0); // _rewards2[1] = CVX rewards
    assertTrue(_rewards2[2].amount != 0); // _rewards2[2] = GEAR rewards
    assertTrue(_rewards2[3].amount != 0); // _rewards2[3] = AMPH rewards
    assertApproxEqAbs(
      IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards[0].amount + _rewards2[0].amount, 1
    );
    assertApproxEqAbs(IERC20(CVX_ADDRESS).balanceOf(bob), _balanceBeforeCVX, 1);
    // This 10 wei difference is because of the claiming order or the rewards and is an acceptable difference.
    // When calling the view method claimable it doesn't affect the CVX supply so the rewards don't change between claims
    assertApproxEqAbs(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards[2].amount + _rewards2[3].amount, 10);
    assertEq(IERC20(GEAR_ADDRESS).balanceOf(bob), _balanceVirtualBefore + _rewards2[2].amount);
  }

  function testDepositCrvLpAfterPoolIdUpdateFromStakedToOtherStake() public {
    // Create a new pool for three crv lp
    IBooster _booster = IBooster(BOOSTER);

    uint256 _newPoolId = _booster.poolLength();

    (uint96 _id,) = bobVault.vaultInfo();

    vm.prank(_booster.poolManager());
    _booster.addPool(THREE_CRV_LP_ADDRESS, 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A, 0);

    (,,, address _crvRewards,,) = _booster.poolInfo(_newPoolId);

    uint256 _depositAmount = 0.1 ether;

    vm.prank(address(governor));
    // make pool id back to normal
    vaultController.registerErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 9
    );

    IERC20 _previousStakingToken = IERC20(IBaseRewardPool(THREE_CRV_LP_REWARDS_ADDRESS).stakingToken());
    uint256 _stakingBalanceBeforeInPrevRewards =
      _previousStakingToken.balanceOf(address(IBaseRewardPool(THREE_CRV_LP_REWARDS_ADDRESS)));

    uint256 _initialBorrowingPower = vaultController.vaultBorrowingPower(_id);
    uint256 _initialBobBalance = threeCrvLP.balanceOf(bob);

    // deposite should stake all balance
    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    uint256 _depositDiffBorrow = (vaultController.vaultBorrowingPower(_id) - _initialBorrowingPower);

    assertEq(threeCrvLP.balanceOf(address(bobVault)), 0);
    assertEq(
      _previousStakingToken.balanceOf(address(THREE_CRV_LP_REWARDS_ADDRESS)),
      _stakingBalanceBeforeInPrevRewards + _depositAmount
    );

    vm.prank(address(governor));
    vaultController.updateRegisteredErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, _newPoolId
    );

    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    assertApproxEqAbs(vaultController.vaultBorrowingPower(_id), _initialBorrowingPower + _depositDiffBorrow * 2, 1);
    assertEq(threeCrvLP.balanceOf(address(bobVault)), 0);
    assertEq(bobVault.balances(THREE_CRV_LP_ADDRESS), _depositAmount * 2);
    assertEq(_previousStakingToken.balanceOf(address(THREE_CRV_LP_REWARDS_ADDRESS)), _stakingBalanceBeforeInPrevRewards);

    {
      IERC20 _newStakeToken = IERC20(IBaseRewardPool(_crvRewards).stakingToken());
      assertEq(_newStakeToken.balanceOf(_crvRewards), _depositAmount * 2);
    }

    vm.prank(bob);
    bobVault.withdrawERC20(address(threeCrvLP), _depositAmount * 2);
    assertApproxEqAbs(threeCrvLP.balanceOf(bob), _initialBobBalance, 1);
    assertApproxEqAbs(vaultController.vaultBorrowingPower(_id), _initialBorrowingPower, 1);
  }

  function testDepositCrvLpAfterPoolIdUpdateFromStakedToNotStaked() public {
    uint256 _depositAmount = 0.1 ether;

    vm.prank(address(governor));
    // make pool id back to normal
    vaultController.registerErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 9
    );

    uint256 _bobBalanceBefore = threeCrvLP.balanceOf(bob);
    uint256 _stakedAmountInContract = threeCrvLP.balanceOf(THREE_CRV_LP_STAKED_CONTRACT);
    // deposite should stake all balance
    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    assertEq(threeCrvLP.balanceOf(THREE_CRV_LP_STAKED_CONTRACT), _stakedAmountInContract + _depositAmount);
    assertEq(threeCrvLP.balanceOf(address(bobVault)), 0);

    vm.prank(address(governor));
    // make pool id of a crvlp 0
    vaultController.updateRegisteredErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );

    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    assertEq(threeCrvLP.balanceOf(address(bobVault)), _depositAmount * 2);
    assertEq(bobVault.balances(THREE_CRV_LP_ADDRESS), _depositAmount * 2);
    assertEq(threeCrvLP.balanceOf(THREE_CRV_LP_STAKED_CONTRACT), _stakedAmountInContract);

    vm.prank(bob);
    bobVault.withdrawERC20(address(threeCrvLP), _depositAmount * 2);
    assertEq(threeCrvLP.balanceOf(bob), _bobBalanceBefore);
  }

  function testDepositCrvLpAfterPoolIdUpdateFromNotStakedToStaked() public {
    uint256 _depositAmount = 0.1 ether;

    vm.prank(address(governor));
    // make pool id of a crvlp 0
    vaultController.registerErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );
    uint256 _bobBalanceBefore = threeCrvLP.balanceOf(bob);
    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    assertEq(threeCrvLP.balanceOf(address(bobVault)), _depositAmount);

    vm.prank(address(governor));
    // make pool id back to normal
    vaultController.updateRegisteredErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 9
    );

    uint256 _stakedAmountInContract = threeCrvLP.balanceOf(THREE_CRV_LP_STAKED_CONTRACT);
    // deposite should stake all balance
    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    assertEq(threeCrvLP.balanceOf(address(bobVault)), 0);
    assertEq(bobVault.balances(THREE_CRV_LP_ADDRESS), _depositAmount * 2);
    assertEq(threeCrvLP.balanceOf(THREE_CRV_LP_STAKED_CONTRACT), _stakedAmountInContract + _depositAmount * 2);

    vm.prank(bob);
    bobVault.withdrawERC20(address(threeCrvLP), _depositAmount * 2);
    assertEq(threeCrvLP.balanceOf(bob), _bobBalanceBefore);
  }

  function testDepositCrvLpAfterPoolIdUpdateFromStakedToNotStakedAlreadyADepositor() public {
    uint256 _depositAmount = 0.1 ether;
    uint256 _bobInitialBalance = threeCrvLP.balanceOf(bob);

    vm.prank(address(governor));
    // make pool id back to normal
    vaultController.registerErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 9
    );

    // deposite should stake all balance
    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    vm.prank(bob);
    bobVault.withdrawERC20(address(threeCrvLP), _depositAmount);
    assertEq(threeCrvLP.balanceOf(bob), _bobInitialBalance);

    vm.prank(address(governor));
    // make pool id of a crvlp 0
    vaultController.updateRegisteredErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );

    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    assertEq(threeCrvLP.balanceOf(address(bobVault)), _depositAmount);
    assertEq(bobVault.balances(THREE_CRV_LP_ADDRESS), _depositAmount);

    vm.prank(bob);
    bobVault.withdrawERC20(address(threeCrvLP), _depositAmount);
    assertEq(threeCrvLP.balanceOf(bob), _bobInitialBalance);
  }

  function testDepositCrvLpAfterPoolIdUpdateFromStakedToOtherStakeAlreadyADepositor() public {
    // Create a new pool for three crv lp
    IBooster _booster = IBooster(BOOSTER);

    uint256 _newPoolId = _booster.poolLength();

    (uint96 _id,) = bobVault.vaultInfo();

    vm.prank(_booster.poolManager());
    _booster.addPool(THREE_CRV_LP_ADDRESS, 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A, 0);

    (,,, address _crvRewards,,) = _booster.poolInfo(_newPoolId);

    uint256 _depositAmount = 0.1 ether;

    vm.prank(address(governor));
    // make pool id back to normal
    vaultController.registerErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 9
    );

    IERC20 _previousStakingToken = IERC20(IBaseRewardPool(THREE_CRV_LP_REWARDS_ADDRESS).stakingToken());
    uint256 _stakingBalanceBeforeInPrevRewards =
      _previousStakingToken.balanceOf(address(IBaseRewardPool(THREE_CRV_LP_REWARDS_ADDRESS)));

    uint256 _initialBorrowingPower = vaultController.vaultBorrowingPower(_id);
    uint256 _initialBobBalance = threeCrvLP.balanceOf(bob);

    // deposite should stake all balance
    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    uint256 _depositDiffBorrow = (vaultController.vaultBorrowingPower(_id) - _initialBorrowingPower);

    vm.prank(bob);
    bobVault.withdrawERC20(address(threeCrvLP), _depositAmount);

    vm.prank(address(governor));
    vaultController.updateRegisteredErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, _newPoolId
    );

    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    assertApproxEqAbs(vaultController.vaultBorrowingPower(_id), _initialBorrowingPower + _depositDiffBorrow, 1);
    assertEq(threeCrvLP.balanceOf(address(bobVault)), 0);
    assertEq(bobVault.balances(THREE_CRV_LP_ADDRESS), _depositAmount);
    assertEq(_previousStakingToken.balanceOf(address(THREE_CRV_LP_REWARDS_ADDRESS)), _stakingBalanceBeforeInPrevRewards);

    {
      IERC20 _newStakeToken = IERC20(IBaseRewardPool(_crvRewards).stakingToken());
      assertEq(_newStakeToken.balanceOf(_crvRewards), _depositAmount);
    }

    vm.prank(bob);
    bobVault.withdrawERC20(address(threeCrvLP), _depositAmount);
    assertApproxEqAbs(threeCrvLP.balanceOf(bob), _initialBobBalance, 1);
  }

  function testDepositCrvLpAfterPoolIdUpdateFromStakedToOtherStakeRewards() public {
    // Create a new pool for three crv lp
    IBooster _booster = IBooster(BOOSTER);

    uint256 _newPoolId = _booster.poolLength();

    vm.prank(_booster.poolManager());
    _booster.addPool(THREE_CRV_LP_ADDRESS, 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A, 0);

    (,,, address _crvRewards,,) = _booster.poolInfo(_newPoolId);
    (,,, address _crvRewardsOld,,) = _booster.poolInfo(9);

    uint256 _depositAmount = 0.1 ether;

    vm.prank(address(governor));
    // make pool id back to normal
    vaultController.registerErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 9
    );

    // deposite should stake all balance
    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    // We add rewards
    vm.prank(BOOSTER);
    IBaseRewardPool(_crvRewardsOld).queueNewRewards(_depositAmount);
    vm.warp(block.timestamp + 5 days);

    vm.prank(address(governor));
    vaultController.updateRegisteredErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, _newPoolId
    );

    IVault.Reward[] memory _rewards = bobVault.claimableRewards(THREE_CRV_LP_ADDRESS, true);
    assertTrue(_rewards[0].amount != 0);
    assertTrue(_rewards[1].amount != 0);

    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    // Now rewards are 0
    _rewards = bobVault.claimableRewards(THREE_CRV_LP_ADDRESS, true);
    assertTrue(_rewards[0].amount == 0);
    assertTrue(_rewards[1].amount == 0);

    // We add rewards to the new rewards contract
    vm.prank(BOOSTER);
    IBaseRewardPool(_crvRewards).queueNewRewards(_depositAmount);
    vm.warp(block.timestamp + 5 days);

    _rewards = bobVault.claimableRewards(THREE_CRV_LP_ADDRESS, true);
    assertTrue(_rewards[0].amount != 0);
    assertTrue(_rewards[1].amount != 0);
  }

  function testStakeCrvLpAfterPoolIdUpdate() public {
    uint256 _depositAmount = 0.1 ether;

    vm.prank(address(governor));
    // make pool id of a crvlp 0
    vaultController.registerErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );

    vm.startPrank(bob);
    threeCrvLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(threeCrvLP), _depositAmount);
    vm.stopPrank();

    assertEq(threeCrvLP.balanceOf(address(bobVault)), _depositAmount);

    vm.prank(address(governor));
    // make pool id back to normal
    vaultController.updateRegisteredErc20(
      THREE_CRV_LP_ADDRESS, OTHER_LTV, address(threeCrvOracle), LIQUIDATION_INCENTIVE, type(uint256).max, 9
    );

    uint256 _stakedAmountInContract = threeCrvLP.balanceOf(THREE_CRV_LP_STAKED_CONTRACT);
    // deposite should stake all balance
    vm.startPrank(bob);
    bobVault.migrateCrvLPCollateral(address(threeCrvLP));
    vm.stopPrank();

    assertEq(threeCrvLP.balanceOf(address(bobVault)), 0);
    assertEq(bobVault.balances(THREE_CRV_LP_ADDRESS), _depositAmount);
    assertEq(threeCrvLP.balanceOf(THREE_CRV_LP_STAKED_CONTRACT), _stakedAmountInContract + _depositAmount);
  }

  function testClaimPreviousCurveLPRewards() public {
    uint256 _depositAmount = 10 ether;

    vm.startPrank(bob);
    usdtStableLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(usdtStableLP), _depositAmount);
    vm.stopPrank();

    vm.prank(BOOSTER);
    IBaseRewardPool(USDT_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);
    assertEq(IERC20(CRV_ADDRESS).balanceOf(address(governor)), 0);

    vm.warp(block.timestamp + 5 days);

    IVault.Reward[] memory _rewards = bobVault.claimableRewards(address(usdtStableLP), true);
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(usdtStableLP);

    uint256[] memory _indexes;

    vm.prank(bob);
    bobVault.claimPreviousRewards(IBaseRewardPool(USDT_LP_REWARDS_ADDRESS), true, _indexes);

    assertTrue(_rewards[0].amount != 0);
    assertTrue(_rewards[1].amount != 0);

    // _rewards[0] should be CRV and _rewards[1] AMPH in this case
    assertEq(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards[0].amount);
    assertEq(IERC20(CVX_ADDRESS).balanceOf(bob), _balanceBeforeCVX + _rewards[1].amount);
    assertEq(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards[2].amount);
    assertGt(IERC20(CRV_ADDRESS).balanceOf(address(governor)), 0);
    assertGt(IERC20(CVX_ADDRESS).balanceOf(address(governor)), 0);
    assertEq(IERC20(CRV_ADDRESS).balanceOf(address(bobVault)), 0);
    assertEq(IERC20(CVX_ADDRESS).balanceOf(address(bobVault)), 0);
  }

  function testClaimPreviousCurveLPWithExtraRewards() public {
    uint256 _depositAmount = 0.1 ether;

    // deposit and stake
    vm.startPrank(bob);
    gearLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(gearLP), _depositAmount);
    vm.stopPrank();

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _balanceVirtualBefore = IERC20(GEAR_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);

    vm.prank(BOOSTER);
    IBaseRewardPool(GEAR_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(GEAR_VIRTUAL_REWARDS_OPERATOR_CONTRACT);
    IVirtualBalanceRewardPool(GEAR_LP_VIRTUAL_REWARDS_CONTRACT).queueNewRewards(_depositAmount);

    // pass time
    vm.warp(block.timestamp + 5 days);

    IVault.Reward[] memory _rewards2 = bobVault.claimableRewards(address(gearLP), true);

    uint256 _balanceCrvGovBefore = IERC20(CRV_ADDRESS).balanceOf(address(governor));
    uint256 _balanceCvxGovBefore = IERC20(CVX_ADDRESS).balanceOf(address(governor));

    // claim
    vm.startPrank(bob);
    uint256[] memory _indexes = new uint256[](1);
    _indexes[0] = 0;
    bobVault.claimPreviousRewards(IBaseRewardPool(GEAR_LP_REWARDS_ADDRESS), true, _indexes);
    vm.stopPrank();

    // governance should have received the tokens
    assertGt(IERC20(CRV_ADDRESS).balanceOf(address(governor)), _balanceCrvGovBefore);
    assertGt(IERC20(CVX_ADDRESS).balanceOf(address(governor)), _balanceCvxGovBefore);

    assertEq(_rewards2.length, 4);

    assertTrue(_rewards2[0].amount != 0); // _rewards2[0] = CRV rewards
    assertTrue(_rewards2[1].amount != 0); // _rewards2[1] = CVX rewards
    assertTrue(_rewards2[2].amount != 0); // _rewards2[2] = GEAR rewards
    assertTrue(_rewards2[3].amount != 0); // _rewards2[3] = AMPH rewards
    assertApproxEqAbs(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards2[0].amount, 1);
    assertApproxEqAbs(IERC20(CVX_ADDRESS).balanceOf(bob), _balanceBeforeCVX + _rewards2[1].amount, 1);
    // This 10 wei difference is because of the claiming order or the rewards and is an acceptable difference.
    // When calling the view method claimable it doesn't affect the CVX supply so the rewards don't change between claims
    assertApproxEqAbs(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards2[3].amount, 10);
    assertEq(IERC20(GEAR_ADDRESS).balanceOf(bob), _balanceVirtualBefore + _rewards2[2].amount);
  }

  function testClaimPreviousCurveLPWithoutExtraRewards() public {
    uint256 _depositAmount = 0.1 ether;

    // deposit and stake
    vm.startPrank(bob);
    gearLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(gearLP), _depositAmount);
    vm.stopPrank();

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _balanceVirtualBefore = IERC20(GEAR_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);

    vm.prank(BOOSTER);
    IBaseRewardPool(GEAR_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(GEAR_VIRTUAL_REWARDS_OPERATOR_CONTRACT);
    IVirtualBalanceRewardPool(GEAR_LP_VIRTUAL_REWARDS_CONTRACT).queueNewRewards(_depositAmount);

    // pass time
    vm.warp(block.timestamp + 5 days);

    IVault.Reward[] memory _rewards2 = bobVault.claimableRewards(address(gearLP), true);

    uint256 _balanceCrvGovBefore = IERC20(CRV_ADDRESS).balanceOf(address(governor));
    uint256 _balanceCvxGovBefore = IERC20(CVX_ADDRESS).balanceOf(address(governor));

    // claim
    vm.startPrank(bob);
    uint256[] memory _indexes;
    bobVault.claimPreviousRewards(IBaseRewardPool(GEAR_LP_REWARDS_ADDRESS), true, _indexes);
    vm.stopPrank();

    // governance should have received the tokens
    assertGt(IERC20(CRV_ADDRESS).balanceOf(address(governor)), _balanceCrvGovBefore);
    assertGt(IERC20(CVX_ADDRESS).balanceOf(address(governor)), _balanceCvxGovBefore);

    assertEq(_rewards2.length, 4);

    assertTrue(_rewards2[0].amount != 0); // _rewards2[0] = CRV rewards
    assertTrue(_rewards2[1].amount != 0); // _rewards2[1] = CVX rewards
    assertTrue(_rewards2[2].amount != 0); // _rewards2[2] = GEAR rewards
    assertTrue(_rewards2[3].amount != 0); // _rewards2[3] = AMPH rewards
    assertApproxEqAbs(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV + _rewards2[0].amount, 1);
    assertApproxEqAbs(IERC20(CVX_ADDRESS).balanceOf(bob), _balanceBeforeCVX + _rewards2[1].amount, 1);
    // This 10 wei difference is because of the claiming order or the rewards and is an acceptable difference.
    // When calling the view method claimable it doesn't affect the CVX supply so the rewards don't change between claims
    assertApproxEqAbs(amphToken.balanceOf(bob), _balanceBeforeAMPH + _rewards2[3].amount, 10);
    assertEq(IERC20(GEAR_ADDRESS).balanceOf(bob), _balanceVirtualBefore);

    _rewards2 = bobVault.claimableRewards(address(gearLP), true);
    assertTrue(_rewards2[0].amount == 0); // _rewards2[0] = CRV rewards
    assertTrue(_rewards2[1].amount == 0); // _rewards2[1] = CVX rewards
    assertTrue(_rewards2[2].amount != 0); // _rewards2[2] = GEAR rewards
    assertTrue(_rewards2[3].amount == 0); // _rewards2[3] = AMPH rewards
  }

  function testClaimPreviousCurveLPNoMainRewardWithExtraRewards() public {
    uint256 _depositAmount = 0.1 ether;

    // deposit and stake
    vm.startPrank(bob);
    gearLP.approve(address(bobVault), _depositAmount);
    bobVault.depositERC20(address(gearLP), _depositAmount);
    vm.stopPrank();

    uint256 _balanceBeforeCRV = IERC20(CRV_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeCVX = IERC20(CVX_ADDRESS).balanceOf(bob);
    uint256 _balanceVirtualBefore = IERC20(GEAR_ADDRESS).balanceOf(bob);
    uint256 _balanceBeforeAMPH = amphToken.balanceOf(bob);

    vm.prank(BOOSTER);
    IBaseRewardPool(GEAR_LP_REWARDS_ADDRESS).queueNewRewards(_depositAmount);

    vm.prank(GEAR_VIRTUAL_REWARDS_OPERATOR_CONTRACT);
    IVirtualBalanceRewardPool(GEAR_LP_VIRTUAL_REWARDS_CONTRACT).queueNewRewards(_depositAmount);

    // pass time
    vm.warp(block.timestamp + 5 days);

    IVault.Reward[] memory _rewards2 = bobVault.claimableRewards(address(gearLP), true);

    uint256 _balanceCrvGovBefore = IERC20(CRV_ADDRESS).balanceOf(address(governor));
    uint256 _balanceCvxGovBefore = IERC20(CVX_ADDRESS).balanceOf(address(governor));

    // claim
    vm.startPrank(bob);
    uint256[] memory _indexes = new uint256[](1);
    _indexes[0] = 0;
    bobVault.claimPreviousRewards(IBaseRewardPool(GEAR_LP_REWARDS_ADDRESS), false, _indexes);
    vm.stopPrank();

    // governance should have received the tokens
    assertEq(IERC20(CRV_ADDRESS).balanceOf(address(governor)), _balanceCrvGovBefore);
    assertEq(IERC20(CVX_ADDRESS).balanceOf(address(governor)), _balanceCvxGovBefore);

    assertEq(_rewards2.length, 4);

    assertTrue(_rewards2[0].amount != 0); // _rewards2[0] = CRV rewards
    assertTrue(_rewards2[1].amount != 0); // _rewards2[1] = CVX rewards
    assertTrue(_rewards2[2].amount != 0); // _rewards2[2] = GEAR rewards
    assertTrue(_rewards2[3].amount != 0); // _rewards2[3] = AMPH rewards
    assertApproxEqAbs(IERC20(CRV_ADDRESS).balanceOf(bob), _balanceBeforeCRV, 1);
    assertApproxEqAbs(IERC20(CVX_ADDRESS).balanceOf(bob), _balanceBeforeCVX, 1);
    // This 10 wei difference is because of the claiming order or the rewards and is an acceptable difference.
    // When calling the view method claimable it doesn't affect the CVX supply so the rewards don't change between claims
    assertApproxEqAbs(amphToken.balanceOf(bob), _balanceBeforeAMPH, 10);
    assertEq(IERC20(GEAR_ADDRESS).balanceOf(bob), _balanceVirtualBefore + _rewards2[2].amount);
  }
}
