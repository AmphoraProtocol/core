// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase} from '@test/e2e/Common.sol';

import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IVault} from '@interfaces/core/IVault.sol';

contract E2EVaultController is CommonE2EBase {
  uint256 public borrowAmount = 500 ether;

  event BorrowUSDA(uint256 _vaultId, address _vaultAddress, uint256 _borrowAmount);

  function setUp() public override {
    super.setUp();

    // Bob mints vault
    _mintVault(bob);
    // Since we only have 1 vault the id: 1 is gonna be Bob's vault
    bobVault = IVault(vaultController.vaultAddress(1));

    vm.startPrank(bob);
    weth.approve(address(bobVault), bobWETH);
    bobVault.depositERC20(address(weth), bobWETH);
    vm.stopPrank();

    // Carol mints vault
    _mintVault(carol);
    // Since we only have 2 vaults the id: 2 is gonna be Carol's vault
    carolVault = IVault(vaultController.vaultAddress(2));

    vm.startPrank(carol);
    uni.approve(address(carolVault), carolUni);
    carolVault.depositERC20(address(uni), carolUni);
    vm.stopPrank();

    _mintVault(dave);
    daveVault = IVault(vaultController.vaultAddress(3));
  }

  /**
   * ----------------------- Internal Functions -----------------------
   */
  /**
   * @notice Takes interest factor and returns new interest factor - pulls block time from network and latestInterestTime from contract
   * @param _interestFactor Current interest factor read from contract
   * @return _newInterestFactor New interest factor based on time elapsed and reserve ratio
   */
  function _payInterestMath(uint192 _interestFactor) internal view returns (uint192 _newInterestFactor) {
    uint192 _latestInterestTime = vaultController.lastInterestTime();
    // vm.warp(block.timestamp + 1);

    uint256 _timeDiff = block.timestamp - _latestInterestTime;

    uint192 _reserveRatio = usdaToken.reserveRatio();
    int256 _curveValue = curveMaster.getValueAt(address(0), int192(_reserveRatio));

    uint192 _calculation = uint192(int192(int256(_timeDiff)) * int192(_curveValue)); //correct step 1
    _calculation = _calculation / (365 days + 6 hours); //correct step 2 - divide by OneYear
    _calculation = _calculation * _interestFactor;
    _calculation = _calculation / 1 ether;

    _newInterestFactor = _interestFactor + _calculation;
  }

  function _calculateAccountLiability(
    uint256 _borrowAmount,
    uint256 _currentInterestFactor,
    uint256 _initialInterestFactor
  ) internal pure returns (uint256 _liability) {
    uint256 _baseAmount = _borrowAmount / _initialInterestFactor;
    _liability = _baseAmount * _currentInterestFactor;
  }

  /**
   * @notice Proper procedure: read interest factor from contract -> elapse time -> call this to predict balance -> pay_interest() -> compare
   * @param _interestFactor CURRENT interest factor read from contract before any time has elapsed
   * @param _user Whose balance to calculate interest on
   * @return _balance Expected after pay_interest()
   */
  function _calculateBalance(uint192 _interestFactor, address _user) internal view returns (uint256 _balance) {
    uint192 _totalBaseLiability = vaultController.totalBaseLiability();
    uint192 _protocolFee = vaultController.protocolFee();

    uint192 _valueBefore = (_totalBaseLiability * _interestFactor) / 1 ether;
    uint192 _calculatedInterestFactor = _payInterestMath(_interestFactor);

    uint192 _valueAfter = (_totalBaseLiability * _calculatedInterestFactor) / 1 ether;
    uint192 _protocolAmount = ((_valueAfter - _valueBefore) * _protocolFee) / 1 ether;

    uint192 _donationAmount = _valueAfter - _valueBefore - _protocolAmount; // wrong
    uint256 _currentSupply = usdaToken.totalSupply();

    uint256 _newSupply = _currentSupply + _donationAmount;

    uint256 _totalGons = usdaToken._totalGons();

    uint256 _gpf = _totalGons / _newSupply;

    uint256 _gonBalance = usdaToken.scaledBalanceOf(_user);

    _balance = _gonBalance / _gpf;
  }

  /**
   * ----------------------- Public Function Tests -----------------------
   */

  function testMintVault() public {
    assertEq(bobVault.minter(), bob);
    assertEq(carolVault.minter(), carol);
  }

  function testVaultDeposits() public {
    assertEq(bobVault.tokenBalance(WETH_ADDRESS), bobWETH);

    assertEq(carolVault.tokenBalance(UNI_ADDRESS), carolUni);
  }

  function testRevertVaultDepositETH() public {
    vm.expectRevert();
    vm.prank(bob);
    address(bobVault).call{value: 1 ether}('');
  }

  function testRevertBorrowIfVaultInsolvent() public {
    vm.expectRevert(IVaultController.VaultController_VaultInsolvent.selector);
    vm.prank(bob);
    vaultController.borrowUSDA(1, uint192(bobWETH * 1 ether * 1_000_000));
  }

  function testBorrow() public {
    uint256 _usdaBalance = usdaToken.balanceOf(bob);
    assertEq(0, _usdaBalance);

    /// Get initial interest factFtestWithdrawUnderlyingr
    uint192 _interestFactor = vaultController.interestFactor();
    uint256 _expectedInterestFactor = _payInterestMath(_interestFactor);

    uint256 _liability = _calculateAccountLiability(borrowAmount, _interestFactor, _interestFactor);

    vm.expectEmit(false, false, false, true);
    emit BorrowUSDA(1, address(bobVault), borrowAmount);

    vm.prank(bob);
    vaultController.borrowUSDA(1, uint192(borrowAmount));

    uint256 _newInterestFactor = vaultController.interestFactor();
    assertEq(_newInterestFactor, _expectedInterestFactor);

    vaultController.calculateInterest();
    vm.prank(bob);
    uint256 _trueLiability = vaultController.vaultLiability(1);
    assertEq(_trueLiability, _liability);

    uint256 _usdaBalanceAfter = usdaToken.balanceOf(bob);
    assertEq(_usdaBalanceAfter, borrowAmount);
  }

  function testLiabilityAfterAWeek() public {
    uint192 _initInterestFactor = vaultController.interestFactor();

    _borrow(bob, 1, borrowAmount);

    vm.warp(block.timestamp + 1 weeks);

    uint192 _interestFactor = vaultController.interestFactor();
    uint256 _expectedInterestFactor = _payInterestMath(_interestFactor);

    vm.prank(frank);
    vaultController.calculateInterest();
    vm.warp(block.timestamp + 1);

    _interestFactor = vaultController.interestFactor();
    uint256 _liability = _calculateAccountLiability(borrowAmount, _interestFactor, _initInterestFactor);

    _interestFactor = vaultController.interestFactor();
    assertEq(_interestFactor, _expectedInterestFactor);

    vm.prank(bob);
    uint192 _realLiability = vaultController.vaultLiability(1);
    assertGt(_realLiability, borrowAmount);
    assertEq(_realLiability, _liability);
  }

  function testInterestGeneration() public {
    _depositSUSD(dave, daveSUSD);
    uint256 _balance = usdaToken.balanceOf(dave);

    _borrow(bob, 1, borrowAmount);

    /// pass 1 year
    vm.warp(block.timestamp + 365 days + 6 hours);

    uint192 _interestFactor = vaultController.interestFactor();

    uint256 _expectedBalance = _calculateBalance(_interestFactor, dave);

    uint256 _newBalance = usdaToken.balanceOf(dave);

    /// No yield before calculateInterest
    assertEq(_newBalance, _balance);

    /// Calculate and pay interest on the contract
    vm.prank(frank);
    vaultController.calculateInterest();
    advanceTime(60);

    _newBalance = usdaToken.balanceOf(dave);
    assertEq(_newBalance, _expectedBalance);
    assertGt(_newBalance, _balance);
  }

  function testPartialRepay() public {
    uint256 _borrowAmount = 10 ether;
    _borrow(bob, 1, _borrowAmount);

    vm.prank(bob);
    uint256 _liability = bobVault.baseLiability();
    uint256 _partialLiability = _liability / 2; // half

    vm.prank(frank);
    vaultController.pause();
    vm.warp(block.timestamp + 1);
    vm.expectRevert('Pausable: paused');
    vm.prank(bob);
    vaultController.repayUSDA(1, uint192(_liability / 2));
    vm.prank(frank);
    vaultController.unpause();
    vm.warp(block.timestamp + 1);

    //need to get liability again, 2 seconds have passed when checking pausable
    vm.prank(bob);
    _liability = bobVault.baseLiability();
    _partialLiability = _liability / 2;

    uint192 _interestFactor = vaultController.interestFactor();
    uint256 _expectedBalance = _calculateBalance(_interestFactor, bob);

    uint256 _expectedInterestFactor = _payInterestMath(_interestFactor);

    uint256 _baseAmount = (_partialLiability * 1 ether) / _expectedInterestFactor;
    uint256 _expectedBaseLiability = _liability - _baseAmount;

    vm.prank(bob);
    vaultController.repayUSDA(1, uint192(_partialLiability));
    vm.warp(block.timestamp + 1);

    _interestFactor = vaultController.interestFactor();
    assertEq(_interestFactor, _expectedInterestFactor);

    vm.prank(bob);
    uint256 _newLiability = bobVault.baseLiability();
    uint256 _usdaBalance = usdaToken.balanceOf(bob);

    assertEq(_expectedBaseLiability, _newLiability);
    assertEq(_usdaBalance, _expectedBalance - _partialLiability);
  }

  function testCompletelyRepayVault() public {
    uint256 _borrowAmount = 10 ether;
    _borrow(bob, 1, _borrowAmount);

    uint192 _interestFactor = vaultController.interestFactor();
    vm.prank(bob);
    uint256 _liability = bobVault.baseLiability();
    uint192 _expectedInterestFactor = _payInterestMath(_interestFactor);
    uint256 _expectedUSDALiability = (_expectedInterestFactor * _liability) / 1 ether;
    uint256 _expectedBalanceWithInterest = _calculateBalance(_expectedInterestFactor, bob);

    uint256 _neededUSDA = _expectedUSDALiability - _expectedBalanceWithInterest;
    _expectedBalanceWithInterest = _expectedBalanceWithInterest + _neededUSDA;

    vm.startPrank(bob);
    susd.approve(address(usdaToken), (_neededUSDA / 1e12) + 1);
    usdaToken.deposit((_neededUSDA / 1e12) + 1);
    vaultController.repayAllUSDA(1);
    vm.stopPrank();
    vm.warp(block.timestamp + 1);

    // const args = await getArgs(repayResult)
    // assert.equal(args.repayAmount.toString(), expectedUSDAliability.toString(), "Expected USDA amount repayed and burned")
    // assert.equal(expectedBalanceWithInterest.toString(), args.repayAmount.toString(), "Expected balance at the time of repay is correct")

    vm.prank(bob);
    uint256 _newLiability = bobVault.baseLiability();
    assertEq(0, _newLiability);
  }
}
