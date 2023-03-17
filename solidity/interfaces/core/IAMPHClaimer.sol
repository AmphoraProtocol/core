// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

/// @title AMPHClaimer Interface
interface IAMPHClaimer {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emited when a vault claims AMPH
   * @param _vaultClaimer The address of the vault that claimed
   * @param _cvxAmount The amount of CVX sent in exchange of AMPH
   * @param _crvAmount The amount of CRV sent in exchange of AMPH
   * @param _amphAmount The amount of AMPH received
   */
  event ClaimedAmph(address _vaultClaimer, uint256 _cvxAmount, uint256 _crvAmount, uint256 _amphAmount);

  /**
   * @notice Emited when governance changes the vault controller
   * @param _newVaultController The address of the new vault controller
   */
  event ChangedVaultController(address _newVaultController);

  /**
   * @notice Emited when governance changes the CVX rate
   * @param _newCvxRate The new rate
   */
  event ChangedCvxRate(uint256 _newCvxRate);

  /**
   * @notice Emited when governance changes the CRV rate
   * @param _newCrvRate he new rate
   */
  event ChangedCrvRate(uint256 _newCrvRate);

  /**
   * @notice Emited when governance recovers a token from the contract
   * @param _token the token recovered
   * @param _receiver the receiver of the tokens
   * @param _amount the amount recovered
   */
  event RecoveredDust(address _token, address _receiver, uint256 _amount);

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

  function vaultController() external view returns (IVaultController _vaultController);

  function CVX() external view returns (IERC20 _CVX);

  function CRV() external view returns (IERC20 _CVX);

  function AMPH() external view returns (IERC20 _AMPH);

  function amphPerCvx() external view returns (uint256 _amphPerCvx);

  function amphPerCrv() external view returns (uint256 _amphPerCrv);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/

  function claimAmph(
    uint96 _vaultId,
    uint256 _cvxAmount,
    uint256 _crvAmount,
    address _receiver
  ) external returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimedAmph);

  function claimable(
    uint256 _cvxAmount,
    uint256 _crvAmount
  ) external view returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph);

  function changeVaultController(address _newVaultController) external;

  function changeCvxRate(uint256 _newRate) external;

  function changeCrvRate(uint256 _newRate) external;

  function recoverDust(address _token, uint256 _amount) external;
}