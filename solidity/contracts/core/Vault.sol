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

    /// @title VaultInfo struct
    /// @notice this struct is used to store the vault metadata
    /// this should reduce the cost of minting by ~15,000
    /// by limiting us to max 2**96-1 vaults
    struct VaultInfo {
        uint96 id;
        address minter;
    }
    /// @notice Metadata of vault, aka the id & the minter's address

    VaultInfo public _vaultInfo;
    IVaultController public immutable _controller;

    mapping(address => uint256) public balances;

    /// @notice this is the unscaled liability of the vault.
    /// the number is meaningless on its own, and must be combined with the factor taken from
    /// the vaultController in order to find the true liabilitiy
    uint256 public _baseLiability;

    /// @notice checks if _msgSender is the controller of the vault
    modifier onlyVaultController() {
        require(_msgSender() == address(_controller), 'sender not VaultController');
        _;
    }

    /// @notice checks if _msgSender is the minter of the vault
    modifier onlyMinter() {
        require(_msgSender() == _vaultInfo.minter, 'sender not minter');
        _;
    }

    /// @notice must be called by VaultController, else it will not be registered as a vault in system
    /// @param id_ unique id of the vault, ever increasing and tracked by VaultController
    /// @param minter_ address of the person who created this vault
    /// @param controller_address address of the VaultController
    constructor(uint96 id_, address minter_, address controller_address) {
        _vaultInfo = VaultInfo(id_, minter_);
        _controller = IVaultController(controller_address);
    }

    /**
     * @notice Returns the minter's address of the vault
     * @return _minter The minter's address
     */
    function minter() external view override returns (address _minter) {
        return _vaultInfo.minter;
    }

    /**
     * @notice Returns the id of the vault
     * @return _id The id of the vault
     */
    function id() external view override returns (uint96 _id) {
        return _vaultInfo.id;
    }

    /**
     * @notice Returns the current vault base liability
     * @return _liability The current vault base liability of the vault
     */
    function baseLiability() external view override returns (uint256 _liability) {
        return _baseLiability;
    }

    /**
     * @notice Returns the vault's balance of a token
     * @param _token The address of the token
     * @return _balance The token's balance of the vault
     */
    function tokenBalance(address _token) external view override returns (uint256 _balance) {
        return balances[_token];
    }

    /**
     * @notice Used to deposit a token to the vault
     * @param _token The address of the token to deposit
     * @param _amount The amount of the token to deposit
     */
    function depositERC20(address _token, uint256 _amount) external override onlyMinter {
        if (_controller.tokenId(_token) == 0) revert Vault_TokenNotRegistered();
        if (_amount == 0) revert Vault_AmountZero();
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_token), _msgSender(), address(this), _amount);
        balances[_token] += _amount;
        emit Deposit(_token, _amount);
    }

    /**
     * @notice Used to withdraw a token from the vault. This can only be called by the minter
     * @dev The withdraw will be denied if ones vault would become insolvent
     * @param _token The address of the token
     * @param _amount The amount of the token to withdraw
     */
    function withdrawERC20(address _token, uint256 _amount) external override onlyMinter {
        if (_controller.tokenId(_token) == 0) revert Vault_TokenNotRegistered();
        // transfer the token to the owner
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _msgSender(), _amount);
        //  check if the account is solvent
        require(_controller.checkVault(_vaultInfo.id), 'over-withdrawal');
        balances[_token] -= _amount;
        emit Withdraw(_token, _amount);
    }

    /**
     * @notice Function used by the VaultController to transfer tokens
     * @param _token The address of the token to transfer
     * @param _to The address of the person to send the coins to
     * @param _amount The amount of coins to move
     */
    function controllerTransfer(address _token, address _to, uint256 _amount) external override onlyVaultController {
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _to, _amount);
    }

    /**
     * @notice Modifies a vault's liability. Can only be called by VaultController
     * @param _increase True to increase liability, false to decrease
     * @param _baseAmount The change amount in base liability
     * @return _liability The new base liability
     */
    function modifyLiability(bool _increase, uint256 _baseAmount)
        external
        override
        onlyVaultController
        returns (uint256)
    {
        if (_increase) {
            _baseLiability = _baseLiability + _baseAmount;
        } else {
            // require statement only valid for repayment
            require(_baseLiability >= _baseAmount, 'repay too much');
            _baseLiability = _baseLiability - _baseAmount;
        }
        return _baseLiability;
    }
}
