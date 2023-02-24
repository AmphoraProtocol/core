// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, IERC20, IVault, CappedToken} from '@test/e2e/Common.sol';
import {ICappedToken} from '@interfaces/utils/ICappedToken.sol';

contract E2ECap is CommonE2EBase {
    uint256 aaveDepositAmount = 500 ether;
    uint256 dydxDepositAmount = 5 ether;
    uint256 borrowAmount = 500 ether;

    function setUp() public override {
        super.setUp();

        // Bob mints vault
        bobVaultId = _mintVault(bob);
        bobVault = IVault(vaultController.vaultAddress(uint96(bobVaultId)));

        // Carol mints vault
        carolVaultId = _mintVault(carol);
        carolVault = IVault(vaultController.vaultAddress(uint96(carolVaultId)));
    }

    function _createCappedToken(
        address _owner,
        string memory _label,
        string memory _name,
        string memory _symbol,
        address _underlyingTokenAddress
    ) internal returns (CappedToken _cappedToken) {
        vm.startPrank(_owner);
        _cappedToken = new CappedToken();
        label(address(_cappedToken), _label);
        _cappedToken.initialize(_name, _symbol, _underlyingTokenAddress);
        vm.stopPrank();
    }

    function _setCap(CappedToken _cappedToken, uint256 _cap) internal {
        vm.prank(frank);
        _cappedToken.setCap(_cap);
    }

    function _depositCapped(
        address _account,
        address _underlying,
        address _capped,
        uint256 _amountToDeposit,
        address _vaultAddress
    ) internal {
        vm.startPrank(_account);
        IERC20(_underlying).approve(_capped, _amountToDeposit);
        ICappedToken(_capped).deposit(_amountToDeposit, _vaultAddress);
        vm.stopPrank();
    }

    function _withdrawERC20(address _account, address _vaultAddress, address _cappedToken, uint256 _amountToWithdraw)
        internal
    {
        vm.prank(_account);
        IVault(_vaultAddress).withdrawErc20(_cappedToken, _amountToWithdraw);
        vm.stopPrank();
    }

    function testSetCap() public {
        _setCap(aaveCappedToken, AAVE_CAP);
        assert(aaveCappedToken.getCap() == AAVE_CAP);
    }

    function testDepositUnderlying() public {
        // set cap
        _setCap(aaveCappedToken, AAVE_CAP);

        // deposit
        _depositCapped(bob, AAVE_ADDRESS, address(aaveCappedToken), aaveDepositAmount, address(bobVault));

        assert(aaveCappedToken.balanceOf(address(bobVault)) == aaveDepositAmount);
        assert(aave.balanceOf(address(aaveCappedToken)) == aaveDepositAmount);
    }

    function testRevertTryToExceedCap() public {
        // set cap
        _setCap(aaveCappedToken, AAVE_CAP);

        // deposit
        vm.startPrank(bob);
        IERC20(AAVE_ADDRESS).approve(address(aaveCappedToken), AAVE_CAP + 1);
        vm.expectRevert(ICappedToken.CappedToken_CapReached.selector);
        aaveCappedToken.deposit(AAVE_CAP + 1, address(bobVault));
        vm.stopPrank();
    }

    function testRevertExceedBurn() public {
        // try to withdraw
        vm.expectRevert('ERC20: transfer amount exceeds balance');
        _withdrawERC20(bob, address(bobVault), address(aaveCappedToken), 1 ether);
    }

    function testRevertTryToWithdrawFromAnotherUser() public {
        // try to withdraw
        vm.expectRevert('sender not minter');
        _withdrawERC20(carol, address(bobVault), address(aaveCappedToken), 1 ether);
    }

    function testWithdrawUnderlying() public {
        // set cap
        _setCap(aaveCappedToken, AAVE_CAP);

        // deposit
        _depositCapped(bob, AAVE_ADDRESS, address(aaveCappedToken), aaveDepositAmount, address(bobVault));

        // withdraw
        _withdrawERC20(bob, address(bobVault), address(aaveCappedToken), aaveDepositAmount);
        assert(aaveCappedToken.balanceOf(address(bobVault)) == 0);
        assert(aave.balanceOf(address(aaveCappedToken)) == aaveDepositAmount);
    }

    function testDepositSecondToken() public {
        // deploy DYDX capped Token
        dydxCappedToken = _createCappedToken(frank, 'dydxCappedToken', 'CappedDydx', 'cDydx', DYDX_ADDRESS);

        // set cap
        _setCap(dydxCappedToken, DYDX_CAP);

        // deposit
        _depositCapped(carol, DYDX_ADDRESS, address(dydxCappedToken), dydxDepositAmount, address(carolVault));
        assert(dydxCappedToken.balanceOf(address(carolVault)) == dydxDepositAmount);
        assert(dydx.balanceOf(address(dydxCappedToken)) == dydxDepositAmount);
    }

    function testWithdrawSecondToken() public {
        // Deploy DYDX capped Token
        dydxCappedToken = _createCappedToken(frank, 'dydxCappedToken', 'CappedDydx', 'cDydx', DYDX_ADDRESS);

        // set cap
        _setCap(dydxCappedToken, DYDX_CAP);

        // deposit
        _depositCapped(carol, DYDX_ADDRESS, address(dydxCappedToken), dydxDepositAmount, address(carolVault));

        // Withdraw
        _withdrawERC20(carol, address(carolVault), address(dydxCappedToken), dydxDepositAmount);
        assert(dydxCappedToken.balanceOf(address(carolVault)) == 0);
        assert(dydx.balanceOf(address(dydxCappedToken)) == dydxDepositAmount);
    }

    function testCheckBorrowPower() public {
        // set cap
        _setCap(aaveCappedToken, AAVE_CAP);

        // deposit
        _depositCapped(bob, AAVE_ADDRESS, address(aaveCappedToken), aaveDepositAmount, address(bobVault));

        // check borrow power
        uint256 _borrowPower = vaultController.vaultBorrowingPower(uint96(bobVaultId));
        uint256 _balance = aaveCappedToken.balanceOf(address(bobVault));
        uint256 _price = oracleMaster.getLivePrice(address(aaveCappedToken));
        uint256 _totalValue = (_balance * _price) / 1e18;
        uint256 _expectedBorrowPower = (_totalValue * AAVE_LTV) / 1e18;
        assert(_borrowPower == _expectedBorrowPower);
        assert(_borrowPower > 0);
    }

    function testBorrow() public {
        // set cap
        _setCap(aaveCappedToken, AAVE_CAP);

        // deposit
        _depositCapped(bob, AAVE_ADDRESS, address(aaveCappedToken), aaveDepositAmount, address(bobVault));

        // borrow
        _borrow(bob, bobVaultId, borrowAmount);
        assert(usdaToken.balanceOf(bob) == borrowAmount);
        assert(vaultController.vaultLiability(uint96(bobVaultId)) == borrowAmount);
    }

    function testRepayLoan() public {
        // set cap
        _setCap(aaveCappedToken, AAVE_CAP);

        // deposit
        _depositCapped(bob, AAVE_ADDRESS, address(aaveCappedToken), aaveDepositAmount, address(bobVault));

        // borrow
        _borrow(bob, bobVaultId, borrowAmount);

        // deposit 1 gwei of susd
        vm.startPrank(bob);
        susd.approve(address(usdaToken), 1);
        usdaToken.deposit(1);
        vm.stopPrank();

        // repay
        vm.startPrank(bob);
        vaultController.repayAllUSDA(uint96(bobVaultId));
        assert(vaultController.vaultLiability(uint96(bobVaultId)) == 0);
        vm.stopPrank();
    }

    function testTryToWithdrawWithVaultUnderwater() public {
        // set cap
        _setCap(aaveCappedToken, AAVE_CAP);

        // deposit
        _depositCapped(bob, AAVE_ADDRESS, address(aaveCappedToken), aaveDepositAmount, address(bobVault));

        // borrow to insolvency
        _borrow(bob, bobVaultId, vaultController.vaultBorrowingPower(uint96(bobVaultId)));

        // advance time
        advanceTime(365 * 24 * 60 * 60);
        vaultController.calculateInterest();

        // try to withdraw
        assert(vaultController.checkVault(uint96(bobVaultId)) == false);
        vm.expectRevert('over-withdrawal');
        _withdrawERC20(bob, address(bobVault), address(aaveCappedToken), 1);
    }

    function testLiquidate() public {
        // set cap
        _setCap(aaveCappedToken, AAVE_CAP);

        // deposit
        _depositCapped(bob, AAVE_ADDRESS, address(aaveCappedToken), aaveDepositAmount, address(bobVault));

        // borrow to insolvency
        _borrow(bob, bobVaultId, vaultController.vaultBorrowingPower(uint96(bobVaultId)));

        // advance time
        advanceTime(365 * 24 * 60 * 60);
        vaultController.calculateInterest();

        // dave deposit funds to liquidate
        vm.startPrank(dave);
        susd.approve(address(usdaToken), type(uint256).max);
        usdaToken.deposit(susd.balanceOf(dave));
        vm.stopPrank();

        // liquidate
        vm.startPrank(dave);
        uint256 _USDADaveBalanceBefore = usdaToken.balanceOf(dave);
        uint256 _cappedAaveDaveBalanceBefore = aave.balanceOf(dave);
        uint256 _tokensToLiquidate = vaultController.tokensToLiquidate(uint96(bobVaultId), address(aaveCappedToken));
        uint256 _tokensLiquidated =
            vaultController.liquidateVault(uint96(bobVaultId), address(aaveCappedToken), _tokensToLiquidate);
        uint256 _USDADaveBalanceAfter = usdaToken.balanceOf(dave);
        uint256 _cappedAaveDaveBalanceAfter = aaveCappedToken.balanceOf(dave);
        assert(_cappedAaveDaveBalanceAfter == _cappedAaveDaveBalanceBefore + _tokensLiquidated);
        assert(_USDADaveBalanceBefore > _USDADaveBalanceAfter);
        vm.stopPrank();
    }
}
