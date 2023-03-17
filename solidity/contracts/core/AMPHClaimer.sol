// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IVault} from '@interfaces/core/IVault.sol';

/// @title AMPHClaimer contract, used to exchange CVX and CRV at a fixed rate for AMPH
contract AMPHClaimer is IAMPHClaimer, Ownable {
  using SafeERC20 for IERC20;

  IERC20 public immutable CVX;
  IERC20 public immutable CRV;
  IERC20 public immutable AMPH;

  /// @dev how much AMPH you will receive per 1 CVX (1e6)
  uint256 public amphPerCvx;

  /// @dev how much AMPH you will receive per 1 CRV (1e6)
  uint256 public amphPerCrv;

  IVaultController public vaultController;

  constructor(
    address _vaultController,
    address _amph,
    address _cvx,
    address _crv,
    uint256 _amphPerCvx,
    uint256 _amphPerCrv
  ) {
    vaultController = IVaultController(_vaultController);
    CVX = IERC20(_cvx);
    CRV = IERC20(_crv);
    AMPH = IERC20(_amph);

    amphPerCvx = _amphPerCvx;
    amphPerCrv = _amphPerCrv;
  }

  /// @notice Claims an amount of AMPH given a CVX and CRV quantity
  /// @param _vaultId the vault id that is claiming
  /// @param _cvxAmount the max CVX amount to exchange
  /// @param _crvAmount the max CVR amount to exchange
  /// @param _receiver the receiver of the AMPH
  /// @return _cvxAmountToSend the amount of CVX the contract extracted
  /// @return _crvAmountToSend the amount of CRV the contract extracted
  /// @return _claimedAmph the amount of AMPH received
  function claimAmph(
    uint96 _vaultId,
    uint256 _cvxAmount,
    uint256 _crvAmount,
    address _receiver
  ) external override returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimedAmph) {
    if (msg.sender != vaultController.vaultAddress(_vaultId)) {
      emit ClaimedAmph(msg.sender, _cvxAmountToSend, _crvAmountToSend, _claimedAmph);
      return (0, 0, 0);
    }

    (_cvxAmountToSend, _crvAmountToSend, _claimedAmph) = _claimable(_cvxAmount, _crvAmount);
    CVX.safeTransferFrom(msg.sender, owner(), _cvxAmountToSend);
    CRV.safeTransferFrom(msg.sender, owner(), _crvAmountToSend);

    // transfer AMPH token to minter
    AMPH.safeTransfer(_receiver, _claimedAmph);

    emit ClaimedAmph(msg.sender, _cvxAmountToSend, _crvAmountToSend, _claimedAmph);
  }

  /// @notice Returns the claimable amount of AMPH given a CVX and CRV quantity
  /// @param _cvxAmount the max CVX amount to exchange
  /// @param _crvAmount the max CVR amount to exchange
  /// @return _cvxAmountToSend the amount of CVX the contract will extract
  /// @return _crvAmountToSend the amount of CRV the contract will extract
  /// @return _claimableAmph the amount of AMPH receivable
  function claimable(
    uint256 _cvxAmount,
    uint256 _crvAmount
  ) external view override returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) {
    (_cvxAmountToSend, _crvAmountToSend, _claimableAmph) = _claimable(_cvxAmount, _crvAmount);
  }

  /// @notice Used by governance to change the vault controller
  /// @param _newVaultController the new vault controller
  function changeVaultController(address _newVaultController) external override onlyOwner {
    vaultController = IVaultController(_newVaultController);

    emit ChangedVaultController(_newVaultController);
  }

  /// @notice Used by governance to change the CVX per AMPH rate
  /// @param _newRate the new rate
  function changeCvxRate(uint256 _newRate) external override onlyOwner {
    amphPerCvx = _newRate;

    emit ChangedCvxRate(_newRate);
  }

  /// @notice Used by governance to change the CRV per AMPH rate
  /// @param _newRate the new rate
  function changeCrvRate(uint256 _newRate) external override onlyOwner {
    amphPerCrv = _newRate;

    emit ChangedCrvRate(_newRate);
  }

  /// @notice Used by governance to recover tokens from the contract
  /// @param _token token to recover
  /// @param _amount amount to recover
  function recoverDust(address _token, uint256 _amount) external override onlyOwner {
    IERC20(_token).transfer(owner(), _amount);

    emit RecoveredDust(_token, owner(), _amount);
  }

  /// @dev Returns the AMPH given some token amount and rate
  function _tokenAmountToAmph(uint256 _tokenAmount, uint256 _tokenRate) internal pure returns (uint256 _amph) {
    if (_tokenAmount == 0) return 0;
    _amph = (_tokenAmount * _tokenRate) / 1 ether;
  }

  /// @dev Returns the claimable amount of AMPH, also the CVX and CRV the contract needs to extract
  function _claimable(
    uint256 _cvxAmount,
    uint256 _crvAmount
  ) internal view returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) {
    uint256 _amphBalance = AMPH.balanceOf(address(this));

    // if both amounts are zero, or AMPH balance is zero simply return all zeros
    if ((_cvxAmount == 0 && _crvAmount == 0) || _amphBalance == 0) return (0, 0, 0);

    uint256 _amphByCvx = _tokenAmountToAmph(_cvxAmount, amphPerCvx);
    uint256 _amphByCrv = _tokenAmountToAmph(_crvAmount, amphPerCrv);
    uint256 _totalAmount = _amphByCvx + _amphByCrv;

    if (_amphBalance >= _totalAmount) {
      // contract has the full amount
      _cvxAmountToSend = _cvxAmount;
      _crvAmountToSend = _crvAmount;
      _claimableAmph = _totalAmount;
    } else {
      // contract doesnt have the full amount
      return (0, 0, 0);
    }

    // check for rounding errors
    if (_claimableAmph == 0) return (0, 0, 0);
  }
}
