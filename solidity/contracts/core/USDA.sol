// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20Detailed} from '@contracts/utils/ERC20Detailed.sol';
import {ExponentialNoError} from '@contracts/utils/ExponentialNoError.sol';
import {Roles} from '@contracts/utils/Roles.sol';
import {UFragments} from '@contracts/utils/UFragments.sol';

import {IUSDA} from '@interfaces/core/IUSDA.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {ContextUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol';
import {Context} from '@openzeppelin/contracts/utils/Context.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/// @title USDA token contract
/// @notice handles all minting/burning of usda
/// @dev extends UFragments
contract USDA is Initializable, PausableUpgradeable, UFragments, IUSDA, ExponentialNoError, Roles {
  using EnumerableSet for EnumerableSet.AddressSet;

  bytes32 public constant VAULT_CONTROLLER_ROLE = keccak256('VAULT_CONTROLLER');

  EnumerableSet.AddressSet internal _vaultControllers;

  IERC20 public reserve;

  address public pauser;

  uint256 public reserveAmount;

  /// @notice checks if _msgSender() is a valid VaultController
  modifier onlyVaultController() {
    _checkRole(VAULT_CONTROLLER_ROLE, _msgSender());
    _;
  }

  /// @notice checks if _msgSender() is pauser
  modifier onlyPauser() {
    if (_msgSender() != address(pauser)) revert USDA_OnlyPauser();
    _;
  }

  /// @notice any function with this modifier will call the pay_interest() function before any function logic is called
  modifier paysInterest() {
    for (uint256 _i; _i < _vaultControllers.length();) {
      IVaultController(_vaultControllers.at(_i)).calculateInterest();
      unchecked {
        _i++;
      }
    }
    _;
  }

  /// @notice initializer for contract
  /// @param _reserveAddr the address of sUSD
  /// @dev consider adding decimals?
  function initialize(address _reserveAddr) public override initializer {
    _UFragments_init('USDA Token', 'USDA');
    __Pausable_init();
    reserve = IERC20(_reserveAddr);
  }

  ///@notice sets the pauser for both USDA and VaultController
  ///@notice the pauser is a separate role from the owner
  function setPauser(address _pauser) external override onlyOwner {
    pauser = _pauser;
  }

  /// @notice pause contract, pauser only
  function pause() external override onlyPauser {
    _pause();
  }

  /// @notice unpause contract, pauser only
  function unpause() external override onlyPauser {
    _unpause();
  }

  ///@notice gets the owner of the USDA contract
  ///@return _ownerAddress address of owner
  function owner() public view override(IUSDA, OwnableUpgradeable) returns (address _ownerAddress) {
    return super.owner();
  }

  /// @notice getter for name
  /// @return _name name of token
  function name() public view override(IERC20Metadata, ERC20Detailed) returns (string memory _name) {
    return super.name();
  }

  /// @notice getter for symbol
  /// @return _symbol symbol for token
  function symbol() public view override(IERC20Metadata, ERC20Detailed) returns (string memory _symbol) {
    return super.symbol();
  }

  /// @notice getter for decimals
  /// @return _decimals decimals for token
  function decimals() public view override(IERC20Metadata, ERC20Detailed) returns (uint8 _decimals) {
    return super.decimals();
  }

  /// @notice getter for address of the reserve currency, or susd
  /// @return _reserveAddress the reserve address
  function reserveAddress() public view override returns (address _reserveAddress) {
    return address(reserve);
  }

  /// @notice deposit sUSD to mint USDA
  /// @dev caller should obtain 1 USDA for each sUSD
  /// the calculations for deposit mimic the calculations done by mint in the ampleforth contract, simply with the susd transfer
  /// 'fragments' are the units that we see, so 1000 fragments == 1000 USDA
  /// 'gons' are the internal accounting unit, used to keep scale.
  /// we use the variable _gonsPerFragment in order to convert between the two
  /// try dimensional analysis when doing the math in order to verify units are correct
  /// @param _susdAmount amount of sUSD to deposit
  function deposit(uint256 _susdAmount) external override {
    _deposit(_susdAmount, _msgSender());
  }

  function depositTo(uint256 _susdAmount, address _target) external override {
    _deposit(_susdAmount, _target);
  }

  function _deposit(uint256 _susdAmount, address _target) internal paysInterest whenNotPaused {
    if (_susdAmount == 0) revert USDA_ZeroAmount();
    // Account for the susd received
    reserveAmount += _susdAmount;
    if (!reserve.transferFrom(_msgSender(), address(this), _susdAmount)) revert USDA_TransferFailed();
    // the gonbalances of the sender is in gons, therefore we must multiply the deposit amount, which is in fragments, by gonsperfragment
    _gonBalances[_target] = _gonBalances[_target] + _susdAmount * _gonsPerFragment;
    // total supply is in fragments, and so we add amount
    _totalSupply = _totalSupply + _susdAmount;
    // and totalgons of course is in gons, and so we multiply amount by gonsperfragment to get the amount of gons we must add to totalGons
    _totalGons = _totalGons + _susdAmount * _gonsPerFragment;

    emit Transfer(address(0), _target, _susdAmount);
    emit Deposit(_target, _susdAmount);
  }

  /// @notice withdraw sUSD by burning USDA
  /// caller should obtain 1 sUSD for every 1 USDA
  /// @param _susdAmount amount of sUSD to withdraw
  function withdraw(uint256 _susdAmount) external override {
    _withdraw(_susdAmount, _msgSender());
  }

  ///@notice withdraw sUSD to a specific address by burning USDA from the caller
  /// _target should obtain 1 sUSD for every 1 USDA burned from the caller
  /// @param _susdAmount amount of sUSD to withdraw
  /// @param _target address to receive the sUSD
  function withdrawTo(uint256 _susdAmount, address _target) external override {
    _withdraw(_susdAmount, _target);
  }

  ///@notice business logic to withdraw sUSD and burn USDA from the caller
  function _withdraw(uint256 _susdAmount, address _target) internal paysInterest whenNotPaused {
    // check balances all around
    if (_susdAmount == 0) revert USDA_ZeroAmount();
    if (_susdAmount > this.balanceOf(_msgSender())) revert USDA_InsufficientFunds();
    // Account for the susd withdrawn
    reserveAmount -= _susdAmount;
    // ensure transfer success
    if (!reserve.transfer(_target, _susdAmount)) revert USDA_TransferFailed();
    // modify the gonbalances of the sender, subtracting the amount of gons, therefore amount*gonsperfragment
    _gonBalances[_msgSender()] = _gonBalances[_msgSender()] - _susdAmount * _gonsPerFragment;
    // modify totalSupply and totalGons
    _totalSupply = _totalSupply - _susdAmount;
    _totalGons = _totalGons - _susdAmount * _gonsPerFragment;
    // emit both a Withdraw and transfer event
    emit Transfer(_msgSender(), address(0), _susdAmount);
    emit Withdraw(_target, _susdAmount);
  }

  /// @notice withdraw sUSD by burning USDA
  /// caller should obtain 1 sUSD for every 1 USDA
  /// this function is effectively just withdraw, but we calculate the amount for the sender
  function withdrawAll() external override {
    _withdrawAll(_msgSender());
  }

  /// @notice withdraw sUSD by burning USDA
  /// @param _target should obtain 1 sUSD for every 1 USDA burned from caller
  /// this function is effectively just withdraw, but we calculate the amount for the _target
  function withdrawAllTo(address _target) external override {
    _withdrawAll(_target);
  }

  /// @notice business logic for withdrawAll
  /// @param _target should obtain 1 sUSD for every 1 USDA burned from caller
  /// this function is effectively just withdraw, but we calculate the amount for the _target
  function _withdrawAll(address _target) internal paysInterest whenNotPaused {
    if (reserveAmount == 0) revert USDA_EmptyReserve();
    uint256 _susdAmount = this.balanceOf(_msgSender());
    //user's USDA value is more than reserve
    if (_susdAmount > reserveAmount) _susdAmount = reserveAmount;
    // Account for the susd withdrawn
    reserveAmount -= _susdAmount;
    if (!reserve.transfer(_target, _susdAmount)) revert USDA_TransferFailed();
    // see comments in the withdraw function for an explaination of this math
    _gonBalances[_msgSender()] = _gonBalances[_msgSender()] - (_susdAmount * _gonsPerFragment);
    _totalSupply = _totalSupply - _susdAmount;
    _totalGons = _totalGons - (_susdAmount * _gonsPerFragment);
    // emit both a Withdraw and transfer event
    emit Transfer(_msgSender(), address(0), _susdAmount);
    emit Withdraw(_target, _susdAmount);
  }

  /// @notice admin function to mint USDA
  /// @param _susdAmount the amount of USDA to mint, denominated in sUSD
  function mint(uint256 _susdAmount) external override paysInterest onlyOwner {
    if (_susdAmount == 0) revert USDA_ZeroAmount();
    // see comments in the deposit function for an explaination of this math
    _gonBalances[_msgSender()] = _gonBalances[_msgSender()] + _susdAmount * _gonsPerFragment;
    _totalSupply = _totalSupply + _susdAmount;
    _totalGons = _totalGons + _susdAmount * _gonsPerFragment;
    // emit both a mint and transfer event
    emit Transfer(address(0), _msgSender(), _susdAmount);
    emit Mint(_msgSender(), _susdAmount);
  }

  /// @notice admin function to burn USDA
  /// @param _susdAmount the amount of USDA to burn, denominated in sUSD
  function burn(uint256 _susdAmount) external override paysInterest onlyOwner {
    if (_susdAmount == 0) revert USDA_ZeroAmount();
    // see comments in the deposit function for an explaination of this math
    _gonBalances[_msgSender()] = _gonBalances[_msgSender()] - _susdAmount * _gonsPerFragment;
    _totalSupply = _totalSupply - _susdAmount;
    _totalGons = _totalGons - _susdAmount * _gonsPerFragment;
    // emit both a mint and transfer event
    emit Transfer(_msgSender(), address(0), _susdAmount);
    emit Burn(_msgSender(), _susdAmount);
  }

  /// @notice donates susd to the protocol reserve
  /// @param _susdAmount the amount of sUSD to donate
  function donate(uint256 _susdAmount) external override paysInterest whenNotPaused {
    if (_susdAmount == 0) revert USDA_ZeroAmount();
    // Account for the susd received
    reserveAmount += _susdAmount;
    if (!reserve.transferFrom(_msgSender(), address(this), _susdAmount)) revert USDA_TransferFailed();
    _donation(_susdAmount);
  }

  /// @notice Recovers accidentally sent sUSD to this contract
  /// @param _to The receiver of the dust
  function recoverDust(address _to) external onlyOwner {
    // All sUSD sent directly to the contract is not accounted into the reserveAmount
    // This function allows governance to recover it
    uint256 _amount = reserve.balanceOf(address(this)) - reserveAmount;
    reserve.transfer(_to, _amount);
  }

  /// @notice function for the vaultController to mint
  /// @param _target whom to mint the USDA to
  /// @param _amount the amount of USDA to mint
  function vaultControllerMint(address _target, uint256 _amount) external override onlyVaultController whenNotPaused {
    // see comments in the deposit function for an explaination of this math
    _gonBalances[_target] = _gonBalances[_target] + _amount * _gonsPerFragment;
    _totalSupply = _totalSupply + _amount;
    _totalGons = _totalGons + _amount * _gonsPerFragment;
    emit Transfer(address(0), _target, _amount);
    emit Mint(_target, _amount);
  }

  /// @notice function for the vaultController to burn
  /// @param _target whom to burn the USDA from
  /// @param _amount the amount of USDA to burn
  function vaultControllerBurn(address _target, uint256 _amount) external override onlyVaultController {
    if (_gonBalances[_target] < (_amount * _gonsPerFragment)) revert USDA_NotEnoughBalance();
    // see comments in the withdraw function for an explaination of this math
    _gonBalances[_target] = _gonBalances[_target] - _amount * _gonsPerFragment;
    _totalSupply = _totalSupply - _amount;
    _totalGons = _totalGons - _amount * _gonsPerFragment;
    emit Transfer(_target, address(0), _amount);
    emit Burn(_target, _amount);
  }

  /// @notice Allows VaultController to send sUSD from the reserve
  /// @param _target whom to receive the sUSD from reserve
  /// @param _susdAmount the amount of sUSD to send
  function vaultControllerTransfer(
    address _target,
    uint256 _susdAmount
  ) external override onlyVaultController whenNotPaused {
    // Account for the susd withdrawn
    reserveAmount -= _susdAmount;
    // ensure transfer success
    if (!reserve.transfer(_target, _susdAmount)) revert USDA_TransferFailed();
  }

  /// @notice function for the vaultController to scale all USDA balances
  /// @param _amount amount of USDA (e18) to donate
  function vaultControllerDonate(uint256 _amount) external override onlyVaultController {
    _donation(_amount);
  }

  /// @notice function for distributing the donation to all USDA holders
  /// @param _amount amount of USDA to donate
  function _donation(uint256 _amount) internal {
    _totalSupply = _totalSupply + _amount;
    if (_totalSupply > MAX_SUPPLY) _totalSupply = MAX_SUPPLY;
    _gonsPerFragment = _totalGons / _totalSupply;
    emit Donation(_msgSender(), _amount, _totalSupply);
  }

  /// @notice get reserve ratio
  /// @return _e18reserveRatio USDA reserve ratio
  function reserveRatio() external view override returns (uint192 _e18reserveRatio) {
    _e18reserveRatio = _safeu192((reserveAmount * EXP_SCALE) / _totalSupply);
  }

  /*///////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

  /// @notice Adds a new vault controller
  /// @param _vaultController The new vault controller to add
  function addVaultController(address _vaultController) external onlyOwner {
    _vaultControllers.add(_vaultController);
    _grantRole(VAULT_CONTROLLER_ROLE, _vaultController);
  }

  /// @notice Removes a vault controller
  /// @param _vaultController The vault controller to remove
  function removeVaultController(address _vaultController) external onlyOwner {
    _vaultControllers.remove(_vaultController);
    _revokeRole(VAULT_CONTROLLER_ROLE, _vaultController);
  }

  /// @notice Removes a vault controller from the list
  /// @param _vaultController The vault controller to remove
  /// @dev the vault controller is removed from the list but keeps the role as to not brick it
  function removeVaultControllerFromList(address _vaultController) external onlyOwner {
    _vaultControllers.remove(_vaultController);
  }

  /*///////////////////////////////////////////////////////////////
                        OPENZEPPELIN OVERRIDES
    //////////////////////////////////////////////////////////////*/

  /// @notice Returns the msg sender
  /// @return _sender The message sender
  function _msgSender() internal view virtual override(Context, ContextUpgradeable) returns (address _sender) {
    return msg.sender;
  }

  /// @notice Returns the msg data
  /// @return _data The message data
  function _msgData() internal view virtual override(Context, ContextUpgradeable) returns (bytes calldata _data) {
    return msg.data;
  }
}
