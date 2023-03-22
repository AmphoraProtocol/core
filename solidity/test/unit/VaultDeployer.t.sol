// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {VaultDeployer} from '@contracts/core/VaultDeployer.sol';
import {IVaultDeployer} from '@interfaces/core/IVaultDeployer.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';

abstract contract Base is DSTestPlus {
  IVaultController public mockVaultController = IVaultController(mockContract('mockVaultController'));
  VaultDeployer public vaultDeployer;

  function setUp() public virtual {
    vm.prank(address(mockVaultController));
    vaultDeployer = new VaultDeployer(mockVaultController);
  }
}

contract UnitVaultDeployerConstructor is Base {
  function testVaultControllerAddress() external {
    assertEq(address(vaultDeployer.VAULT_CONTROLLER()), address(mockVaultController));
  }
}

contract UnitVaultDeployerDeployVault is Base {
  function testRevertsIfInvalidVaultController(uint96 _id, address _owner) public {
    vm.expectRevert(IVaultDeployer.VaultDeployer_OnlyVaultController.selector);

    vm.prank(newAddress());
    vaultDeployer.deployVault(_id, _owner);
  }

  function testDeployVault(uint96 _id, address _owner) public {
    vm.assume(_id > 1);
    vm.prank(address(mockVaultController));
    IVault _vault = vaultDeployer.deployVault(_id, _owner);

    assertEq(address(_vault.CONTROLLER()), address(mockVaultController));
    assertEq(_vault.id(), _id);
    assertEq(_vault.minter(), _owner);
  }
}
