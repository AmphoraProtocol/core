// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, IVault} from '@test/e2e/Common.sol';

contract E2EUSDA is CommonE2EBase {
  uint256 public susdAmount = 500 ether;

  function setUp() public override {
    super.setUp();
  }

  function testAccountsForUSDARewards() public {
    uint256 _amountToDeposit = 100 ether;

    // Andy deposits SUSD
    _depositSUSD(andy, _amountToDeposit);
    uint256 _andyUSDABalance = usdaToken.balanceOf(andy);

    // Bob Deposits SUSD
    _depositSUSD(bob, _amountToDeposit);
    uint256 _bobUSDABalance = usdaToken.balanceOf(bob);

    // Bob deposits usda to wusda
    vm.startPrank(bob);
    usdaToken.approve(address(wusda), _bobUSDABalance);
    wusda.wrap(_bobUSDABalance);
    // He will get slightly less because of being the first depositor)
    uint256 _bobWUSDABalance = wusda.balanceOf(bob);
    vm.stopPrank();

    // Check that bob's wusda balance is correct
    assertEq(_bobWUSDABalance, _bobUSDABalance - wusda.BOOTSTRAP_MINT());

    // Andy deposits usda to wusda
    vm.startPrank(andy);
    usdaToken.approve(address(wusda), _andyUSDABalance);
    wusda.wrap(_andyUSDABalance);
    uint256 _andyWUSDABalance = wusda.balanceOf(andy);
    vm.stopPrank();

    // Check that andy's wusda balance is correct
    assertEq(_andyWUSDABalance, _andyUSDABalance);

    // Someone donates to the USDA pool
    uint256 _donationAmount = 1000 ether;
    vm.startPrank(dave);
    susd.approve(address(usdaToken), _donationAmount);
    usdaToken.donate(_donationAmount);
    vm.stopPrank();

    // Both should have the same amount if we take in account the interest accumulated in the burned shares
    uint256 _interestAccountedForBurnedShares = wusda.getUsdaByWUsda(wusda.BOOTSTRAP_MINT());
    assertEq(
      wusda.getUsdaByWUsda(wusda.balanceOf(andy)),
      wusda.getUsdaByWUsda(wusda.balanceOf(bob)) + _interestAccountedForBurnedShares
    );

    // Bob's wusda balance should remain the same
    assertEq(wusda.balanceOf(bob), _bobWUSDABalance);

    // Bob's underlying usda balance should increase
    uint256 _bobUsdaBalanceAccountingForDonations =
      _bobUSDABalance + (_donationAmount / 2) - _interestAccountedForBurnedShares;
    assertGt(wusda.getUsdaByWUsda(wusda.balanceOf(bob)), _bobUSDABalance);
    assertApproxEqRel(wusda.getUsdaByWUsda(wusda.balanceOf(bob)), _bobUsdaBalanceAccountingForDonations, 2.5 ether);

    // Andy's wusda balance should remain the same
    assertEq(wusda.balanceOf(andy), _andyWUSDABalance);

    // Andy's underlying usda balance should increase
    uint256 _andyUsdaBalanceAccountingForDonations = _andyUSDABalance + (_donationAmount / 2);
    assertGt(wusda.getUsdaByWUsda(wusda.balanceOf(andy)), _andyUSDABalance);
    assertApproxEqRel(wusda.getUsdaByWUsda(wusda.balanceOf(andy)), _andyUsdaBalanceAccountingForDonations, 2.5 ether);

    // Bob can now withdraw all usda and it will be the correct amount
    vm.startPrank(bob);
    uint256 _bobUsdaExpectedBalance = wusda.getUsdaByWUsda(_bobWUSDABalance);
    wusda.approve(address(wusda), _bobWUSDABalance);
    wusda.unwrap(_bobWUSDABalance);
    vm.stopPrank();
    assertEq(usdaToken.balanceOf(bob), _bobUsdaExpectedBalance);

    // Andy can now withdraw all usda and it will be the correct amount
    vm.startPrank(andy);
    uint256 _andyUsdaExpectedBalance = wusda.getUsdaByWUsda(_andyWUSDABalance);
    wusda.approve(address(wusda), _andyWUSDABalance);
    wusda.unwrap(_andyWUSDABalance);
    vm.stopPrank();
    assertEq(usdaToken.balanceOf(andy), _andyUsdaExpectedBalance);
  }
}
