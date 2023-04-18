// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Vault, IVault} from '@contracts/core/Vault.sol';
import {IVaultDeployer} from '@interfaces/core/IVaultDeployer.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @notice The VaultDeployer contract, used to deploy new Vaults
contract VaultDeployer is IVaultDeployer {
  /// @notice The VaultController
  IVaultController public immutable VAULT_CONTROLLER;
  /// @notice The CVX token
  IERC20 public immutable CVX;
  /// @notice The CRV token
  IERC20 public immutable CRV;

  /// @param _vaultController The address of the VaultController
  /// @param _cvx The address of the CVX token
  /// @param _crv The address of the CRV token
  constructor(IVaultController _vaultController, IERC20 _cvx, IERC20 _crv) payable {
    VAULT_CONTROLLER = _vaultController;
    CVX = _cvx;
    CRV = _crv;
  }

  /// @notice Deploys a new Vault
  /// @param _id The id of the vault
  /// @param _minter The address of the minter of the vault
  /// @return _vault The vault that was created
  function deployVault(uint96 _id, address _minter) external returns (IVault _vault) {
    if (msg.sender != address(VAULT_CONTROLLER)) revert VaultDeployer_OnlyVaultController();
    _vault = IVault(new Vault{salt: keccak256(abi.encode(_id))}(_id, _minter, address(VAULT_CONTROLLER), CVX, CRV));
  }
}
