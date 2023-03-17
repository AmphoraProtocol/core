// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IVault} from '@interfaces/core/IVault.sol';

import {AMPHClaimer} from '@contracts/core/AMPHClaimer.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';

contract AMPHMath is AMPHClaimer {
  constructor() AMPHClaimer(address(0), address(0), address(0), address(0), 0, 0) {}

  function tokenAmountToAmph(uint256 _tokenAmount, uint256 _tokenRate) public pure returns (uint256 _amph) {
    return _tokenAmountToAmph(_tokenAmount, _tokenRate);
  }
}

abstract contract Base is DSTestPlus {
  IERC20 internal _mockCVX = IERC20(mockContract(newAddress(), 'mockCVX'));
  IERC20 internal _mockCRV = IERC20(mockContract(newAddress(), 'mockCRV'));
  IERC20 internal _mockAMPH = IERC20(mockContract(newAddress(), 'mockAMPH'));
  IVaultController internal _mockVaultController = IVaultController(mockContract(newAddress(), 'mockVaultController'));

  address public deployer = newAddress();
  address public bobVault = newAddress();
  address public bob = newAddress();

  AMPHClaimer public amphClaimer;
  AMPHMath public amphMath;
  uint256 public amphPerCvx = 10e18;
  uint256 public amphPerCrv = 0.5e18;

  function setUp() public virtual {
    // Deploy contract
    vm.prank(deployer);
    amphClaimer =
    new AMPHClaimer(address(_mockVaultController), address(_mockAMPH), address(_mockCVX), address(_mockCRV), amphPerCvx, amphPerCrv);

    amphMath = new AMPHMath();

    vm.mockCall(
      address(_mockVaultController),
      abi.encodeWithSelector(IVaultController.vaultAddress.selector),
      abi.encode(bobVault)
    );
    vm.mockCall(address(_mockCVX), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(_mockCRV), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
  }
}

contract UnitAMPHClaimerConstructor is Base {
  function testDeploy(
    address _vaultController,
    address _amph,
    address _cvx,
    address _crv,
    uint256 _amphPerCvx,
    uint256 _amphPerCrv
  ) public {
    vm.prank(deployer);
    amphClaimer = new AMPHClaimer(_vaultController, _amph,  _cvx,  _crv,  _amphPerCvx,  _amphPerCrv);

    assert(address(amphClaimer.vaultController()) == _vaultController);
    assert(address(amphClaimer.AMPH()) == _amph);
    assert(address(amphClaimer.CVX()) == _cvx);
    assert(address(amphClaimer.CRV()) == _crv);
    assert(amphClaimer.amphPerCvx() == _amphPerCvx);
    assert(amphClaimer.amphPerCrv() == _amphPerCrv);
    assert(amphClaimer.owner() == deployer);
  }
}

contract UnitAMPHClaimerClaimAMPH is Base {
  event ClaimedAmph(address _vaultClaimer, uint256 _cvxAmount, uint256 _crvAmount, uint256 _amphAmount);

  function testClaimAMPHWithInvalidVault(address _caller) public {
    vm.assume(_caller != bobVault);
    vm.prank(_caller);
    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimedAmph) =
      amphClaimer.claimAmph(1, 100 ether, 100 ether, _caller);
    assert(_cvxAmountToSend == 0);
    assert(_crvAmountToSend == 0);
    assert(_claimedAmph == 0);
  }

  function testClaimAMPHEmitEvent(uint256 _cvxAmount, uint256 _crvAmount) public {
    vm.assume(_cvxAmount <= type(uint256).max / amphPerCvx);
    vm.assume(_crvAmount <= type(uint256).max / amphPerCrv);

    vm.mockCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(type(uint256).max));
    vm.mockCall(bobVault, abi.encodeWithSelector(IVault.minter.selector), abi.encode(bob));

    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) =
      amphClaimer.claimable(_cvxAmount, _crvAmount);

    vm.expectEmit(true, true, true, true);
    emit ClaimedAmph(bobVault, _cvxAmountToSend, _crvAmountToSend, _claimableAmph);
    vm.prank(bobVault);
    amphClaimer.claimAmph(1, _cvxAmount, _crvAmount, bob);
  }

  function testClaimAMPH(uint256 _cvxAmount, uint256 _crvAmount) public {
    vm.assume(_cvxAmount <= type(uint256).max / amphPerCvx);
    vm.assume(_crvAmount <= type(uint256).max / amphPerCrv);

    vm.mockCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(type(uint256).max));
    vm.mockCall(bobVault, abi.encodeWithSelector(IVault.minter.selector), abi.encode(bob));

    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) =
      amphClaimer.claimable(_cvxAmount, _crvAmount);

    vm.expectCall(
      address(_mockCVX), abi.encodeWithSelector(IERC20.transferFrom.selector, bobVault, deployer, _cvxAmountToSend)
    );
    vm.expectCall(
      address(_mockCRV), abi.encodeWithSelector(IERC20.transferFrom.selector, bobVault, deployer, _crvAmountToSend)
    );
    vm.expectCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.transfer.selector, bob, _claimableAmph));

    vm.prank(bobVault);
    amphClaimer.claimAmph(1, _cvxAmount, _crvAmount, bob);
  }
}

contract UnitAMPHClaimerClaimable is Base {
  function testClaimableWithAmountsInZero(uint256 _amphAmount) public {
    vm.assume(_amphAmount > 0);
    vm.mockCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(_amphAmount));

    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) = amphClaimer.claimable(0, 0);

    assert(_cvxAmountToSend == 0);
    assert(_crvAmountToSend == 0);
    assert(_claimableAmph == 0);
  }

  function testClaimableWithAMPHBalanceInZero(uint256 _cvxAmount, uint256 _crvAmount) public {
    vm.assume(_cvxAmount > 0);
    vm.assume(_crvAmount > 0);
    vm.mockCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) =
      amphClaimer.claimable(_cvxAmount, _crvAmount);

    assert(_cvxAmountToSend == 0);
    assert(_crvAmountToSend == 0);
    assert(_claimableAmph == 0);
  }

  function testClaimableWithMoreAMPHThanNeeded(uint256 _cvxAmount, uint256 _crvAmount) public {
    vm.assume(_cvxAmount > 0);
    vm.assume(_crvAmount > 0);
    vm.assume(_cvxAmount <= type(uint256).max / amphPerCvx);
    vm.assume(_crvAmount <= type(uint256).max / amphPerCrv);

    vm.mockCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(type(uint256).max));

    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) =
      amphClaimer.claimable(_cvxAmount, _crvAmount);

    assert(_cvxAmountToSend == _cvxAmount);
    assert(_crvAmountToSend == _crvAmount);
    assert(
      _claimableAmph
        == (amphMath.tokenAmountToAmph(_cvxAmount, amphPerCvx) + amphMath.tokenAmountToAmph(_crvAmount, amphPerCrv))
    );
  }

  function testClaimableWithMoreAMPHThanNeededAndSendingZeroCRV(uint256 _cvxAmount) public {
    vm.assume(_cvxAmount > 0);
    vm.assume(_cvxAmount <= type(uint256).max / amphPerCvx);
    vm.assume(_cvxAmount * amphPerCvx >= 1 ether);

    uint256 _amphBalance = amphMath.tokenAmountToAmph(_cvxAmount, amphPerCvx);

    vm.mockCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(_amphBalance));

    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) = amphClaimer.claimable(_cvxAmount, 0);

    assert(_cvxAmountToSend == _cvxAmount);
    assert(_crvAmountToSend == 0);
    assert(_claimableAmph == _amphBalance);
  }

  function testClaimableWithMoreAMPHThanNeededAndSendingZeroCVX(uint256 _crvAmount) public {
    vm.assume(_crvAmount > 0);
    vm.assume(_crvAmount <= type(uint256).max / amphPerCrv);
    vm.assume(_crvAmount * amphPerCrv >= 1 ether);

    uint256 _amphBalance = amphMath.tokenAmountToAmph(_crvAmount, amphPerCrv);

    vm.mockCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(_amphBalance));

    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) = amphClaimer.claimable(0, _crvAmount);

    assert(_cvxAmountToSend == 0);
    assert(_crvAmountToSend == _crvAmount);
    assert(_claimableAmph == _amphBalance);
  }

  function testClaimableWithLessAMPHThanNeeded(uint256 _cvxAmount, uint256 _crvAmount) public {
    vm.assume(_crvAmount > 0);
    vm.assume(_cvxAmount > 0);
    vm.assume(_cvxAmount <= type(uint256).max / amphPerCvx);
    vm.assume(_crvAmount <= type(uint256).max / amphPerCrv);

    uint256 _amphBalance =
      (amphMath.tokenAmountToAmph(_crvAmount, amphPerCrv) + amphMath.tokenAmountToAmph(_cvxAmount, amphPerCvx) - 1);

    vm.mockCall(address(_mockAMPH), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(_amphBalance));

    (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) =
      amphClaimer.claimable(_cvxAmount, _crvAmount);

    assert(_cvxAmountToSend == 0);
    assert(_crvAmountToSend == 0);
    assert(_claimableAmph == 0);
  }
}

contract UnitAMPHClaimerGovernanceFunctions is Base {
  event ChangedVaultController(address _newVaultController);
  event ChangedCvxRate(uint256 _newCvxRate);
  event ChangedCrvRate(uint256 _newCrvRate);
  event RecoveredDust(address _token, address _receiver, uint256 _amount);

  function testChangeVaultController(address _vaultController) public {
    vm.assume(_vaultController != address(amphClaimer.vaultController()));

    vm.expectEmit(true, true, true, true);
    emit ChangedVaultController(_vaultController);

    vm.prank(deployer);
    amphClaimer.changeVaultController(_vaultController);

    assert(address(amphClaimer.vaultController()) == _vaultController);
  }

  function testChangeVaultControllerRevertOnlyOwner(address _caller) public {
    vm.assume(_caller != deployer);

    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(_caller);
    amphClaimer.changeVaultController(address(0));
  }

  function testChangeCvxRate(uint256 _newRate) public {
    vm.assume(_newRate != amphClaimer.amphPerCvx());

    vm.expectEmit(true, true, true, true);
    emit ChangedCvxRate(_newRate);

    vm.prank(deployer);
    amphClaimer.changeCvxRate(_newRate);

    assert(amphClaimer.amphPerCvx() == _newRate);
  }

  function testChangeCvxRateRevertOnlyOwner(address _caller) public {
    vm.assume(_caller != deployer);

    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(_caller);
    amphClaimer.changeCvxRate(0);
  }

  function testChangeCrvRate(uint256 _newRate) public {
    vm.assume(_newRate != amphClaimer.amphPerCrv());

    vm.expectEmit(true, true, true, true);
    emit ChangedCrvRate(_newRate);

    vm.prank(deployer);
    amphClaimer.changeCrvRate(_newRate);

    assert(amphClaimer.amphPerCrv() == _newRate);
  }

  function testChangeCrvRateRevertOnlyOwner(address _caller) public {
    vm.assume(_caller != deployer);

    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(_caller);
    amphClaimer.changeCrvRate(0);
  }

  function testRecoverDust(address _token, uint256 _amount) public {
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    vm.expectEmit(true, true, true, true);
    emit RecoveredDust(_token, deployer, _amount);

    vm.prank(deployer);
    vm.expectCall(_token, abi.encodeWithSelector(IERC20.transfer.selector, deployer, _amount));
    amphClaimer.recoverDust(_token, _amount);
  }

  function testRecoverDustRevertOnlyOwner(address _caller) public {
    vm.assume(_caller != deployer);

    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(_caller);
    amphClaimer.recoverDust(address(0), 0);
  }
}

contract UnitAMPHClaimerConvertFunctions is Base {
  function testTokenAmountToAmph(uint256 _tokenAmount, uint256 _tokenRate) public {
    vm.assume(_tokenAmount >= 1); // NOTE: I had to do this to prevent an error: "Division or modulo by 0" in some of the assumes below (but you can send a zero amount in production)

    vm.assume(_tokenRate >= 1); // minimum rate
    vm.assume(_tokenRate <= type(uint256).max / _tokenAmount); // max rate
    vm.assume(_tokenAmount * _tokenRate >= 1 ether); // minimum token amount
    vm.assume(_tokenAmount <= type(uint256).max / _tokenRate); // max token amount

    // simply calling the function, if not revert then all good
    amphMath.tokenAmountToAmph(_tokenAmount, _tokenRate);
  }
}
