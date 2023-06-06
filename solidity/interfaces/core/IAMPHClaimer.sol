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
   * @param _cvxTotalRewards The amount of CVX sent in exchange of AMPH
   * @param _crvTotalRewards The amount of CRV sent in exchange of AMPH
   * @param _amphAmount The amount of AMPH received
   */
  event ClaimedAmph(
    address indexed _vaultClaimer, uint256 _cvxTotalRewards, uint256 _crvTotalRewards, uint256 _amphAmount
  );

  /**
   * @notice Emited when governance changes the vault controller
   * @param _newVaultController The address of the new vault controller
   */
  event ChangedVaultController(address indexed _newVaultController);

  /**
   * @notice Emited when governance recovers a token from the contract
   * @param _token the token recovered
   * @param _receiver the receiver of the tokens
   * @param _amount the amount recovered
   */
  event RecoveredDust(address indexed _token, address _receiver, uint256 _amount);

  /**
   * @notice Emited when governance changes the CVX reward fee
   * @param _newCvxReward the new fee
   */
  event ChangedCvxRewardFee(uint256 _newCvxReward);

  /**
   * @notice Emited when governance changes the CRV reward fee
   * @param _newCrvReward the new fee
   */
  event ChangedCrvRewardFee(uint256 _newCrvReward);

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

  function CVX() external view returns (IERC20 _cvx);

  function CRV() external view returns (IERC20 _crv);

  function AMPH() external view returns (IERC20 _amph);

  function BASE_SUPPLY_PER_CLIFF() external view returns (uint256 _baseSupplyPerCliff);

  function distributedAmph() external view returns (uint256 _distributedAmph);

  function TOTAL_CLIFFS() external view returns (uint256 _totalCliffs);

  function cvxRewardFee() external view returns (uint256 _cvxRewardFee);

  function crvRewardFee() external view returns (uint256 _crvRewardFee);

  function vaultController() external view returns (IVaultController _vaultController);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/

  function claimAmph(
    uint96 _vaultId,
    uint256 _cvxTotalRewards,
    uint256 _crvTotalRewards,
    address _receiver
  ) external returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimedAmph);

  function claimable(
    address _sender,
    uint96 _vaultId,
    uint256 _cvxTotalRewards,
    uint256 _crvTotalRewards
  ) external view returns (uint256 _cvxAmountToSend, uint256 _crvAmountToSend, uint256 _claimableAmph);

  function changeVaultController(address _newVaultController) external;

  function recoverDust(address _token, uint256 _amount) external;

  function changeCvxRewardFee(uint256 _newFee) external;

  function changeCrvRewardFee(uint256 _newFee) external;
}
