// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Vault, IVault} from '@contracts/core/Vault.sol';
import {IVaultDeployer} from '@interfaces/core/IVaultDeployer.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

/// @notice The VaultDeployer contract, used to deploy new Vaults
contract VaultDeployer is IVaultDeployer {
  /// @notice The VaultController
  IVaultController public immutable VAULT_CONTROLLER;

  constructor(IVaultController _vaultController) payable {
    VAULT_CONTROLLER = _vaultController;
  }

  /// @notice Deploys a new Vault
  /// @param _id The id of the vault
  /// @param _minter The address of the minter of the vault
  /// @return _vault The vault that was created
  function deployVault(uint96 _id, address _minter) external returns (IVault _vault) {
    if (msg.sender != address(VAULT_CONTROLLER)) revert VaultDeployer_OnlyVaultController();
    _vault = IVault(new Vault{salt: keccak256(abi.encode(_id))}(_id, _minter, address(VAULT_CONTROLLER)));
  }
}
