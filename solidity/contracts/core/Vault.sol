// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IUSDA} from '@interfaces/core/IUSDA.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

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

  /// @notice Metadata of vault, aka the id & the minter's address

  IVaultController public immutable CONTROLLER;

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
   * @param _token The address of the token to deposit
   * @param _amount The amount of the token to deposit
   */
  function depositERC20(address _token, uint256 _amount) external override onlyMinter {
    if (CONTROLLER.tokenId(_token) == 0) revert Vault_TokenNotRegistered();
    if (_amount == 0) revert Vault_AmountZero();
    SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_token), _msgSender(), address(this), _amount);
    balances[_token] += _amount;
    emit Deposit(_token, _amount);
  }

  /// @notice withdraw an erc20 token from the vault
  /// this can only be called by the minter
  /// the withdraw will be denied if ones vault would become insolvent
  /// @param _tokenAddress address of erc20 token
  /// @param _amount amount of erc20 token to withdraw
  function withdrawERC20(address _tokenAddress, uint256 _amount) external override onlyMinter {
    if (CONTROLLER.tokenId(_tokenAddress) == 0) revert Vault_TokenNotRegistered();
    // transfer the token to the owner
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_tokenAddress), _msgSender(), _amount);
    //  check if the account is solvent
    if (!CONTROLLER.checkVault(vaultInfo.id)) revert Vault_OverWithdrawal();
    balances[_tokenAddress] -= _amount;
    emit Withdraw(_tokenAddress, _amount);
  }

  /// @notice function used by the VaultController to transfer tokens
  /// callable by the VaultController only
  /// @param _token token to transfer
  /// @param _to person to send the coins to
  /// @param _amount amount of coins to move
  function controllerTransfer(address _token, address _to, uint256 _amount) external override onlyVaultController {
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _to, _amount);
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
