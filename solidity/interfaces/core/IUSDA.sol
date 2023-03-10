// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IRoles} from '@interfaces/utils/IRoles.sol';

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

/// @title USDA Interface
/// @notice extends IERC20Metadata
interface IUSDA is IERC20Metadata, IRoles {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
  /// @notice Emitted when a deposit is made
  event Deposit(address indexed _from, uint256 _value);

  /// @notice Emitted when a withdraw is made
  event Withdraw(address indexed _from, uint256 _value);

  /// @notice Emitted when a mint is made
  event Mint(address _to, uint256 _value);

  /// @notice Emitted when a burn is made
  event Burn(address _from, uint256 _value);

  /// @notice Emitted when a donation is made
  event Donation(address indexed _from, uint256 _value, uint256 _totalSupply);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when trying to deposit zero amount
  error USDA_ZeroAmount();

  /// @notice Thrown when a transfer fails
  error USDA_TransferFailed();

  /// @notice Thrown when trying to withdraw more than the balance
  error USDA_InsufficientFunds();

  /// @notice Thrown when trying to withdraw all but the reserve amount is 0
  error USDA_EmptyReserve();

  /// @notice Thrown when _msgSender is not the pauser of the contract
  error USDA_OnlyPauser();

  /// @notice Thrown when vault controller is trying to burn more than the balance
  error USDA_NotEnoughBalance();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

  /// @notice Returns the reserve ratio
  /// @return _reserveRatio The reserve ratio
  function reserveRatio() external view returns (uint192 _reserveRatio);

  /// @notice Returns the reserve address
  /// @return _reserveAddress The reserve address
  function reserveAddress() external view returns (address _reserveAddress);

  /// @notice Returns the reserve amount
  /// @return _reserveAmount The reserve amount
  function reserveAmount() external view returns (uint256 _reserveAmount);

  /// @notice Return the owner
  /// @return _owner The owner
  function owner() external view returns (address _owner);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @notice initializer specifies the reserveAddress
  function initialize(address _reserveAddress) external;

  function deposit(uint256 _susdAmount) external;

  function depositTo(uint256 _susdAmount, address _target) external;

  function withdraw(uint256 _susdAmount) external;

  function withdrawTo(uint256 _susdAmount, address _target) external;

  function withdrawAll() external;

  function withdrawAllTo(address _target) external;

  function donate(uint256 _susdAmount) external;

  function recoverDust(address _to) external;

  // admin functions

  function setPauser(address _pauser) external;

  function pauser() external view returns (address _pauser);

  function pause() external;

  function unpause() external;

  function mint(uint256 _susdAmount) external;

  function burn(uint256 _susdAmount) external;

  // functions for the vault controller to call
  function vaultControllerBurn(address _target, uint256 _amount) external;

  function vaultControllerMint(address _target, uint256 _amount) external;

  function vaultControllerTransfer(address _target, uint256 _susdAmount) external;

  function vaultControllerDonate(uint256 _amount) external;

  /// @notice Adds a new vault controller
  /// @param _vaultController The new vault controller to add
  function addVaultController(address _vaultController) external;

  /// @notice Removes a vault controller
  /// @param _vaultController The vault controller to remove
  function removeVaultController(address _vaultController) external;

  /// @notice Removes a vault controller from the loop list
  /// @param _vaultController The vault controller to remove
  function removeVaultControllerFromList(address _vaultController) external;
}
