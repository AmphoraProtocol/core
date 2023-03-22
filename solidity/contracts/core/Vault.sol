// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IUSDA} from '@interfaces/core/IUSDA.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {IBooster} from '@interfaces/utils/IBooster.sol';
import {IBaseRewardPool} from '@interfaces/utils/IBaseRewardPool.sol';
import {IVirtualBalanceRewardPool} from '@interfaces/utils/IVirtualBalanceRewardPool.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Context} from '@openzeppelin/contracts/utils/Context.sol';
import {SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';

/// @title Vault
/// @notice our implentation of maker-vault like vault
/// major differences:
/// 1. multi-collateral
/// 2. generate interest in USDA
contract Vault is IVault, Context {
  using SafeERC20Upgradeable for IERC20;

  IERC20 public constant CVX = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
  IERC20 public constant CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);

  IVaultController public immutable CONTROLLER;

  /// @notice Metadata of vault, aka the id & the minter's address
  VaultInfo public vaultInfo;

  /// @notice this is the unscaled liability of the vault.
  /// the number is meaningless on its own, and must be combined with the factor taken from
  /// the vaultController in order to find the true liabilitiy
  uint256 public baseLiability;

  mapping(address => uint256) public balances;

  /// @notice checks if _msgSender is the controller of the vault
  modifier onlyVaultController() {
    if (_msgSender() != address(CONTROLLER)) revert Vault_NotVaultController();
    _;
  }

  /// @notice checks if _msgSender is the minter of the vault
  modifier onlyMinter() {
    if (_msgSender() != vaultInfo.minter) revert Vault_NotMinter();
    _;
  }

  /// @notice must be called by VaultController, else it will not be registered as a vault in system
  /// @param _id unique id of the vault, ever increasing and tracked by VaultController
  /// @param _minter address of the person who created this vault
  /// @param _controllerAddress address of the VaultController
  constructor(uint96 _id, address _minter, address _controllerAddress) {
    vaultInfo = VaultInfo(_id, _minter);
    CONTROLLER = IVaultController(_controllerAddress);
  }

  /// @notice minter of the vault
  /// @return _minter address of minter
  function minter() external view override returns (address _minter) {
    return vaultInfo.minter;
  }

  /// @notice id of the vault
  /// @return _id address of minter
  function id() external view override returns (uint96 _id) {
    return vaultInfo.id;
  }

  /// @notice get vaults balance of an erc20 token
  /// @param _token address of the erc20 token
  /// @return _balance the token balance
  function tokenBalance(address _token) external view override returns (uint256 _balance) {
    return balances[_token];
  }

  /**
   * @notice Used to deposit a token to the vault
   * @dev    Deposits and stakes on convex if token is of type CurveLP
   *
   * @param _token The address of the token to deposit
   * @param _amount The amount of the token to deposit
   */
  function depositERC20(address _token, uint256 _amount) external override onlyMinter {
    if (CONTROLLER.tokenId(_token) == 0) revert Vault_TokenNotRegistered();
    if (_amount == 0) revert Vault_AmountZero();
    SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_token), _msgSender(), address(this), _amount);
    if (CONTROLLER.tokenCollateralType(_token) == IVaultController.CollateralType.CurveLP) {
      uint256 _poolId = CONTROLLER.tokenPoolId(_token);
      IBooster _booster = CONTROLLER.booster();
      IERC20(_token).approve(address(_booster), _amount);
      if (!_booster.deposit(_poolId, _amount, true)) revert Vault_DepositAndStakeOnConvexFailed();
    }
    balances[_token] += _amount;
    CONTROLLER.modifyTotalDeposited(vaultInfo.id, _amount, _token, true);
    emit Deposit(_token, _amount);
  }

  /// @notice Withdraws an erc20 token from the vault
  /// @dev    This can only be called by the minter
  /// @dev    The withdraw will be denied if ones vault would become insolvent
  /// @dev    If the withdraw token is of CurveLP then unstake and withdraw directly to user
  ///
  /// @param _tokenAddress The address of erc20 token
  /// @param _amount The amount of erc20 token to withdraw
  function withdrawERC20(address _tokenAddress, uint256 _amount) external override onlyMinter {
    if (CONTROLLER.tokenId(_tokenAddress) == 0) revert Vault_TokenNotRegistered();
    if (CONTROLLER.tokenCollateralType(_tokenAddress) == IVaultController.CollateralType.CurveLP) {
      if (!CONTROLLER.tokenCrvRewardsContract(_tokenAddress).withdrawAndUnwrap(_amount, false)) {
        revert Vault_WithdrawAndUnstakeOnConvexFailed();
      }
    }
    // transfer the token to the owner
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_tokenAddress), _msgSender(), _amount);
    //  check if the account is solvent
    if (!CONTROLLER.checkVault(vaultInfo.id)) revert Vault_OverWithdrawal();
    balances[_tokenAddress] -= _amount;
    CONTROLLER.modifyTotalDeposited(vaultInfo.id, _amount, _tokenAddress, false);
    emit Withdraw(_tokenAddress, _amount);
  }

  /// @notice Claims avaiable rewards from convex
  /// @dev    Transfers a percentage of the crv and cvx rewards to claim AMPH tokens
  /// @param _tokenAddress The address of erc20 token
  function claimRewards(address _tokenAddress) external override onlyMinter {
    if (CONTROLLER.tokenId(_tokenAddress) == 0) revert Vault_TokenNotRegistered();
    if (CONTROLLER.tokenCollateralType(_tokenAddress) != IVaultController.CollateralType.CurveLP) {
      revert Vault_TokenNotCurveLP();
    }

    IBaseRewardPool _rewardsContract = CONTROLLER.tokenCrvRewardsContract(_tokenAddress);
    uint256 _crvReward = _rewardsContract.earned(address(this));

    if (_crvReward != 0) {
      // Claim the CRV reward
      _rewardsContract.getReward(address(this), false);
      CRV.transfer(msg.sender, _crvReward);
    }

    // All other rewards
    uint256 _rewardsAmount = _rewardsContract.extraRewardsLength();

    uint256 _cvxReward;

    // Loop and claim all virtual rewards
    for (uint256 _i; _i < _rewardsAmount; _i++) {
      IVirtualBalanceRewardPool _virtualReward = _rewardsContract.extraRewards(_i);
      IERC20 _rewardToken = _virtualReward.rewardToken();
      uint256 _earnedReward = _virtualReward.earned(address(this));
      if (_earnedReward != 0) {
        _virtualReward.getReward();
        if (address(_rewardToken) == address(CVX)) {
          // Save the cvx reward in a variable
          _cvxReward = _earnedReward;
        } else {
          // If it's any other token, transfer to the owner of the vault
          if (_earnedReward > 0) {
            _rewardToken.transfer(msg.sender, _earnedReward);
            emit ClaimedReward(address(_rewardToken), _earnedReward);
          }
        }
      }
    }

    // if(_crvReward > 0 || _cvxReward > 0) {
    //   // Approve amounts for it to be taken
    //   (uint256 _takenCVX, uint256 _takenCRV, ) = _amphClaimer.claimable(_cvxReward, _crvReward);
    //   _crv.approve(address(_amphClaimer), _takenCRV);
    //   _cvx.approve(address(_amphClaimer), _takenCVX);

    //   // Claim AMPH tokens depending on how much CRV and CVX was claimed
    //   _amphClaimer.claimAmph(this.id(), _cvxReward, _crvReward, msg.sender);

    //   // Send the remaining CRV and CVX
    //   _crv.transfer(msg.sender, _crvReward - _takenCRV);
    //   _cvx.transfer(msg.sender, _cvxReward - _takenCVX);

    //   emit ClaimedReward(address(_crv), _crvReward - _takenCRV);
    //   emit ClaimedReward(address(_cvx), _cvxReward - _takenCVX);
    // }
  }

  function claimableRewards(address _tokenAddress) external view override returns (Reward[] memory _rewards) {
    if (CONTROLLER.tokenId(_tokenAddress) == 0) revert Vault_TokenNotRegistered();
    if (CONTROLLER.tokenCollateralType(_tokenAddress) != IVaultController.CollateralType.CurveLP) {
      revert Vault_TokenNotCurveLP();
    }

    IBaseRewardPool _rewardsContract = CONTROLLER.tokenCrvRewardsContract(_tokenAddress);

    uint256 _rewardsAmount = _rewardsContract.extraRewardsLength();

    uint256 _crvReward = _rewardsContract.earned(address(this));

    _rewards = new Reward[](_rewardsAmount+1);
    _rewards[0] = Reward(CRV, _crvReward);

    // TODO: we need to account for the amount the protocol keeps
    for (uint256 _i = 0; _i < _rewardsAmount; _i++) {
      IVirtualBalanceRewardPool _virtualReward = _rewardsContract.extraRewards(_i);
      IERC20 _rewardToken = _virtualReward.rewardToken();
      uint256 _earnedReward = _virtualReward.earned(address(this));
      _rewards[_i + 1] = Reward(_rewardToken, _earnedReward);
    }
  }

  /// @notice Recovers dust from vault
  /// this can only be called by the minter
  /// @param _tokenAddress address of erc20 token
  function recoverDust(address _tokenAddress) external override onlyMinter {
    if (CONTROLLER.tokenId(_tokenAddress) == 0) revert Vault_TokenNotRegistered();
    IERC20Upgradeable _token = IERC20Upgradeable(_tokenAddress);
    uint256 _dust = _token.balanceOf(address(this)) - balances[_tokenAddress];
    if (_dust == 0) revert Vault_AmountZero();
    // transfer the token to the owner
    SafeERC20Upgradeable.safeTransfer(_token, _msgSender(), _dust);
    //  check if the account is solvent just in case of any attacks
    if (!CONTROLLER.checkVault(vaultInfo.id)) revert Vault_OverWithdrawal();
    emit Recover(_tokenAddress, _dust);
  }

  /// @notice function used by the VaultController to transfer tokens
  /// callable by the VaultController only
  /// @param _token token to transfer
  /// @param _to person to send the coins to
  /// @param _amount amount of coins to move
  function controllerTransfer(address _token, address _to, uint256 _amount) external override onlyVaultController {
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _to, _amount);
    balances[_token] -= _amount;
  }

  /// @notice function used by the VaultController to reduce a vault's liability
  /// callable by the VaultController only
  /// @param _increase true to increase, false to decrease
  /// @param _baseAmount change in base liability
  /// @return _newLiability the new liability
  function modifyLiability(
    bool _increase,
    uint256 _baseAmount
  ) external override onlyVaultController returns (uint256 _newLiability) {
    if (_increase) {
      baseLiability = baseLiability + _baseAmount;
    } else {
      // require statement only valid for repayment
      if (baseLiability < _baseAmount) revert Vault_RepayTooMuch();
      baseLiability = baseLiability - _baseAmount;
    }
    return baseLiability;
  }
}
