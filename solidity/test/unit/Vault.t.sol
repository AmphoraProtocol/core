// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Vault} from '@contracts/core/Vault.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';

abstract contract Base is DSTestPlus {
  IERC20 internal _mockToken = IERC20(mockContract(newAddress(), 'mockToken'));
  IVaultController public mockVaultController = IVaultController(mockContract(newAddress(), 'mockVaultController'));

  Vault public vault;
  address public vaultOwner = label(newAddress(), 'vaultOwner');

  function setUp() public virtual {
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    // solhint-disable-next-line reentrancy
    vault = new Vault(1, vaultOwner, address(mockVaultController));
  }
}

contract UnitVaultGetters is Base {
  function testConstructor() public {
    assertEq(vault.minter(), vaultOwner);
    assertEq(vault.id(), 1);
    assertEq(address(vault.CONTROLLER()), address(mockVaultController));
  }

  function testTokenBalance(uint256 _amount) public {
    vm.assume(_amount > 0);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);

    assertEq(vault.tokenBalance(address(_mockToken)), _amount);
  }
}

contract UnitVaultDepositERC20 is Base {
  event Deposit(address _token, uint256 _amount);

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );
  }

  function testRevertIfNotVaultOwner(address _token, uint256 _amount) public {
    vm.expectRevert(IVault.Vault_NotMinter.selector);
    vm.prank(newAddress());
    vault.depositERC20(_token, _amount);
  }

  function testRevertIfTokenNotRegistered(address _token, uint256 _amount) public {
    vm.expectRevert(IVault.Vault_TokenNotRegistered.selector);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_token)),
      abi.encode(0)
    );
    vm.prank(vaultOwner);
    vault.depositERC20(_token, _amount);
  }

  function testRevertIfAmountZero() public {
    vm.expectRevert(IVault.Vault_AmountZero.selector);
    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), 0);
  }

  function testDepositERC20(uint256 _amount) public {
    vm.assume(_amount > 0);
    vm.expectEmit(false, false, false, true);
    emit Deposit(address(_mockToken), _amount);
    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);
  }
}

contract UnitVaultWithdrawERC20 is Base {
  event Withdraw(address _token, uint256 _amount);

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), 1 ether);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.checkVault.selector, 1), abi.encode(true)
    );
  }

  function testRevertIfNotVaultOwner(address _token, uint256 _amount) public {
    vm.expectRevert(IVault.Vault_NotMinter.selector);
    vm.prank(newAddress());
    vault.withdrawERC20(_token, _amount);
  }

  function testRevertIfTokenNotRegistered(address _token, uint256 _amount) public {
    vm.expectRevert(IVault.Vault_TokenNotRegistered.selector);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_token)),
      abi.encode(0)
    );
    vm.prank(vaultOwner);
    vault.withdrawERC20(_token, _amount);
  }

  function testRevertIfOverWithdrawal(uint256 _amount) public {
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.checkVault.selector, 1), abi.encode(false)
    );
    vm.expectRevert(IVault.Vault_OverWithdrawal.selector);
    vm.prank(vaultOwner);
    vault.withdrawERC20(address(_mockToken), _amount);
  }

  function testWithdrawERC20() public {
    vm.expectEmit(false, false, false, true);
    emit Withdraw(address(_mockToken), 1 ether);
    vm.prank(vaultOwner);
    vault.withdrawERC20(address(_mockToken), 1 ether);
  }
}

contract UnitVaultRecoverDust is Base {
  event Recover(address _token, uint256 _amount);

  uint256 internal _dust = 10 ether;
  uint256 internal _deposit = 5 ether;

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _deposit);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.checkVault.selector, 1), abi.encode(true)
    );

    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(_dust + _deposit));
  }

  function testRevertIfNotVaultOwner(address _token) public {
    vm.expectRevert(IVault.Vault_NotMinter.selector);
    vm.prank(newAddress());
    vault.recoverDust(_token);
  }

  function testRevertIfTokenNotRegistered(address _token) public {
    vm.expectRevert(IVault.Vault_TokenNotRegistered.selector);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_token)),
      abi.encode(0)
    );
    vm.prank(vaultOwner);
    vault.recoverDust(_token);
  }

  function testRevertIfOverWithdrawal() public {
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.checkVault.selector, 1), abi.encode(false)
    );
    vm.expectRevert(IVault.Vault_OverWithdrawal.selector);
    vm.prank(vaultOwner);
    vault.recoverDust(address(_mockToken));
  }

  function testRevertIfZeroDust() public {
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(_deposit));
    vm.expectRevert(IVault.Vault_AmountZero.selector);
    vm.prank(vaultOwner);
    vault.recoverDust(address(_mockToken));
  }

  function testRecoverDust() public {
    vm.expectEmit(false, false, false, true);
    emit Recover(address(_mockToken), _dust);
    vm.prank(vaultOwner);
    vault.recoverDust(address(_mockToken));
  }
}
