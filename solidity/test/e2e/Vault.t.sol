// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase} from '@test/e2e/Common.sol';

import {VaultController} from '@contracts/core/VaultController.sol';
import {IVault} from '@interfaces/core/IVault.sol';

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
}
