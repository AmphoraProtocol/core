// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, IERC20, IVault} from '@test/e2e/Common.sol';

contract E2EAMPHClaimer is CommonE2EBase {
  IERC20 public cvx = IERC20(CVX_ADDRESS);
  IERC20 public crv = IERC20(CRV_ADDRESS);

  function setUp() public override {
    super.setUp();

    // fill with AMPH tokens
    vm.prank(amphToken.owner());
    amphToken.mint(address(amphClaimer), 100 ether);

    // create a vault for bob
    bobVaultId = _mintVault(bob);
    bobVault = IVault(vaultController.vaultAddress(bobVaultId));

    // deal some tokens to bob
    deal(CVX_ADDRESS, address(bobVault), 1 ether);
    deal(CRV_ADDRESS, address(bobVault), 1 ether);
  }

  function testAMPHClaimer() public {
    // change rates
    vm.startPrank(address(governor));
    amphClaimer.changeCvxRate(1);
    amphClaimer.changeCrvRate(1);
    assert(amphClaimer.amphPerCvx() == 1);
    assert(amphClaimer.amphPerCrv() == 1);
    amphClaimer.changeCvxRate(cvxRate);
    amphClaimer.changeCrvRate(crvRate);
    vm.stopPrank();

    // change vault controller
    vm.startPrank(address(governor));
    amphClaimer.changeVaultController(address(2));
    assert(address(amphClaimer.vaultController()) == address(2));
    amphClaimer.changeVaultController(address(vaultController));
    vm.stopPrank();

    // try to claim sending 0 tokens
    vm.prank(address(bobVault));
    (uint256 _cvx0, uint256 _crv0, uint256 _amph0) = amphClaimer.claimable(0, 0);
    assert(_cvx0 == 0);
    assert(_crv0 == 0);
    assert(_amph0 == 0);
    amphClaimer.claimAmph(bobVaultId, 0, 0, bob);
    assert(amphToken.balanceOf(bob) == 0);
    assert(cvx.balanceOf(address(bobVault)) == 1 ether);
    assert(crv.balanceOf(address(bobVault)) == 1 ether);

    // try to claim sending more than 0 tokens
    vm.startPrank(address(bobVault));
    cvx.approve(address(amphClaimer), type(uint256).max);
    crv.approve(address(amphClaimer), type(uint256).max);
    (uint256 _cvx1, uint256 _crv1, uint256 _amph1) = amphClaimer.claimable(1 ether, 1 ether);
    assert(_cvx1 == 1 ether);
    assert(_crv1 == 1 ether);
    assert(_amph1 == 10.5 ether);
    amphClaimer.claimAmph(bobVaultId, 1 ether, 1 ether, bob);
    assert(amphToken.balanceOf(bob) == 10.5 ether);
    assert(cvx.balanceOf(address(bobVault)) == 0);
    assert(crv.balanceOf(address(bobVault)) == 0);
    vm.stopPrank();

    // recover dust (empty the pool)
    uint256 _poolAmphBalance = amphToken.balanceOf(address(amphClaimer));
    vm.prank(address(governor));
    amphClaimer.recoverDust(address(amphToken), _poolAmphBalance);
    assert(amphToken.balanceOf(address(amphClaimer)) == 0);

    // try to claim when no tokens in the pool
    vm.startPrank(address(bobVault));
    uint256 _cvxBalanceBefore = cvx.balanceOf(address(bobVault));
    uint256 _crvBalanceBefore = crv.balanceOf(address(bobVault));
    (uint256 _cvx2, uint256 _crv2, uint256 _amph2) = amphClaimer.claimable(1 ether, 1 ether);
    assert(_cvx2 == 0);
    assert(_crv2 == 0);
    assert(_amph2 == 0);
    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimedAmph) =
      amphClaimer.claimAmph(bobVaultId, 1 ether, 1 ether, bob);
    uint256 _cvxBalanceAfter = cvx.balanceOf(address(bobVault));
    uint256 _crvBalanceAfter = crv.balanceOf(address(bobVault));
    assert(_cvxBalanceBefore == _cvxBalanceAfter);
    assert(_crvBalanceBefore == _crvBalanceAfter);
    assert(_cvxAmountToSend == 0);
    assert(_crvAmountToSend == 0);
    assert(_claimedAmph == 0);
    vm.stopPrank();
  }
}
