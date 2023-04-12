// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IVault} from '@interfaces/core/IVault.sol';

/// @notice AMPHClaimer contract, used to exchange CVX and CRV at a fixed rate for AMPH
contract AMPHClaimer is IAMPHClaimer, Ownable {
  using SafeERC20 for IERC20;

  /// @dev The CVX token
  IERC20 public immutable CVX;

  /// @dev The CRV token
  IERC20 public immutable CRV;

  /// @dev The AMPH token
  IERC20 public immutable AMPH;

  /// @dev How much AMPH you will receive per 1 CVX (1e18)
  uint256 public amphPerCvx;

  /// @dev How much AMPH you will receive per 1 CRV (1e18)
  uint256 public amphPerCrv;

  /// @dev Percentage of rewards taken in CVX (1e18 == 100%)
  uint256 public cvxRewardFee;

  /// @dev Percentage of rewards taken in CRV (1e18 == 100%)
  uint256 public crvRewardFee;

  /// @dev The vault controller
  IVaultController public vaultController;

  constructor(
    address _vaultController,
    address _amph,
    address _cvx,
    address _crv,
    uint256 _amphPerCvx,
    uint256 _amphPerCrv,
    uint256 _cvxRewardFee,
    uint256 _crvRewardFee
  ) {
    vaultController = IVaultController(_vaultController);
    CVX = IERC20(_cvx);
    CRV = IERC20(_crv);
    AMPH = IERC20(_amph);

    amphPerCvx = _amphPerCvx;
    amphPerCrv = _amphPerCrv;

    cvxRewardFee = _cvxRewardFee;
    crvRewardFee = _crvRewardFee;
  }

  /// @notice Claims an amount of AMPH given a CVX and CRV quantity
  /// @param _vaultId The vault id that is claiming
  /// @param _cvxTotalRewards The max CVX amount to exchange
  /// @param _crvTotalRewards The max CVR amount to exchange
  /// @param _receiver The receiver of the AMPH
  /// @return _cvxAmountToSend The amount of CVX the contract extracted
  /// @return _crvAmountToSend The amount of CRV the contract extracted
  /// @return _claimedAmph The amount of AMPH received
  function claimAmph(
    uint96 _vaultId,
    uint256 _cvxTotalRewards,
    uint256 _crvTotalRewards,
    address _receiver
  ) external override returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimedAmph) {
    (_cvxAmountToSend, _crvAmountToSend, _claimedAmph) =
      _claimable(msg.sender, _vaultId, _cvxTotalRewards, _crvTotalRewards);
    CVX.safeTransferFrom(msg.sender, owner(), _cvxAmountToSend);
    CRV.safeTransferFrom(msg.sender, owner(), _crvAmountToSend);

    // transfer AMPH token to minter
    AMPH.safeTransfer(_receiver, _claimedAmph);

    emit ClaimedAmph(msg.sender, _cvxAmountToSend, _crvAmountToSend, _claimedAmph);
  }

  /// @notice Returns the claimable amount of AMPH given a CVX and CRV quantity
  /// @param _sender The address of the account claiming
  /// @param _vaultId The vault id that is claiming
  /// @param _cvxTotalRewards The max CVX amount to exchange
  /// @param _crvTotalRewards The max CVR amount to exchange
  /// @return _cvxAmountToSend The amount of CVX the contract will extract
  /// @return _crvAmountToSend The amount of CRV the contract will extract
  /// @return _claimableAmph The amount of AMPH receivable
  function claimable(
    address _sender,
    uint96 _vaultId,
    uint256 _cvxTotalRewards,
    uint256 _crvTotalRewards
  ) external view override returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) {
    (_cvxAmountToSend, _crvAmountToSend, _claimableAmph) =
      _claimable(_sender, _vaultId, _cvxTotalRewards, _crvTotalRewards);
  }

  /// @notice Used by governance to change the vault controller
  /// @param _newVaultController The new vault controller
  function changeVaultController(address _newVaultController) external override onlyOwner {
    vaultController = IVaultController(_newVaultController);

    emit ChangedVaultController(_newVaultController);
  }

  /// @notice Used by governance to change the CVX per AMPH rate
  /// @param _newRate The new rate
  function changeCvxRate(uint256 _newRate) external override onlyOwner {
    amphPerCvx = _newRate;

    emit ChangedCvxRate(_newRate);
  }

  /// @notice Used by governance to change the CRV per AMPH rate
  /// @param _newRate The new rate
  function changeCrvRate(uint256 _newRate) external override onlyOwner {
    amphPerCrv = _newRate;

    emit ChangedCrvRate(_newRate);
  }

  /// @notice Used by governance to recover tokens from the contract
  /// @param _token The token to recover
  /// @param _amount The amount to recover
  function recoverDust(address _token, uint256 _amount) external override onlyOwner {
    IERC20(_token).transfer(owner(), _amount);

    emit RecoveredDust(_token, owner(), _amount);
  }

  /// @notice Used by governance to change the fee taken from the CVX reward
  /// @param _newFee The new reward fee
  function changeCvxRewardFee(uint256 _newFee) external override onlyOwner {
    cvxRewardFee = _newFee;

    emit ChangedCvxRewardFee(_newFee);
  }

  /// @notice Used by governance to change the fee taken from the CRV reward
  /// @param _newFee The new reward fee
  function changeCrvRewardFee(uint256 _newFee) external override onlyOwner {
    crvRewardFee = _newFee;

    emit ChangedCrvRewardFee(_newFee);
  }

  /// @dev Returns the AMPH given some token amount and rate
  function _tokenAmountToAmph(uint256 _tokenAmount, uint256 _tokenRate) internal pure returns (uint256 _amph) {
    if (_tokenAmount == 0) return 0;
    _amph = (_tokenAmount * _tokenRate) / 1 ether;
  }

  /// @dev Receives a total and a percentage, returns the amount equivalent of the percentage
  function _totalToFraction(uint256 _total, uint256 _fraction) internal pure returns (uint256 _amount) {
    if (_total == 0) return 0;
    _amount = (_total * _fraction) / 1 ether;
  }

  /// @dev Returns the claimable amount of AMPH, also the CVX and CRV the contract needs to extract
  function _claimable(
    address _sender,
    uint96 _vaultId,
    uint256 _cvxTotalRewards,
    uint256 _crvTotalRewards
  ) internal view returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph) {
    if (_sender != vaultController.vaultAddress(_vaultId)) return (0, 0, 0);

    uint256 _amphBalance = AMPH.balanceOf(address(this));

    // if both amounts are zero, or AMPH balance is zero simply return all zeros
    if ((_cvxTotalRewards == 0 && _crvTotalRewards == 0) || _amphBalance == 0) return (0, 0, 0);

    uint256 _cvxRewardsFeeToExchange = _totalToFraction(_cvxTotalRewards, cvxRewardFee);
    uint256 _crvRewardsFeeToExchange = _totalToFraction(_crvTotalRewards, crvRewardFee);

    uint256 _amphByCvx = _tokenAmountToAmph(_cvxRewardsFeeToExchange, amphPerCvx);
    uint256 _amphByCrv = _tokenAmountToAmph(_crvRewardsFeeToExchange, amphPerCrv);

    uint256 _totalAmount = _amphByCvx + _amphByCrv;

    // check for rounding errors
    if (_totalAmount == 0) return (0, 0, 0);

    if (_amphBalance >= _totalAmount) {
      // contract has the full amount
      _cvxAmountToSend = _cvxRewardsFeeToExchange;
      _crvAmountToSend = _crvRewardsFeeToExchange;
      _claimableAmph = _totalAmount;
    } else {
      // contract doesnt have the full amount
      return (0, 0, 0);
    }
  }
}
