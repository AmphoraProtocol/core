// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4 <0.9.0;

import {IVault} from '@interfaces/core/IVault.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

/**
 * @notice Deployer of Vaults
 * @dev    This contract is needed to reduce the size of the VaultController contract
 */
interface IVaultDeployer {
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when someone other than the vault controller tries to call the method
   */
  error VaultDeployer_OnlyVaultController();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @notice Deploys a new Vault
  /// @param _id The id of the vault
  /// @param _minter The address of the minter of the vault
  /// @return _vault The vault that was created
  function deployVault(uint96 _id, address _minter) external returns (IVault _vault);
}
