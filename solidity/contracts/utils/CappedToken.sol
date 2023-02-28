// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {ICappedToken} from '@interfaces/utils/ICappedToken.sol';

/// @title CappedToken
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract CappedToken is ICappedToken, Initializable, OwnableUpgradeable, ERC20Upgradeable {
  IERC20Metadata public underlying;
  uint8 private _underlyingDecimals;

  /// @notice CAP is in units of the CAP token,so 18 decimals.
  ///         not the underlying!!!!!!!!!
  uint256 public cap;

  /// @notice initializer for contract
  /// @param _name name of capped token
  /// @param _symbol symbol of capped token
  /// @param _underlying the address of underlying
  function initialize(string memory _name, string memory _symbol, address _underlying) public initializer {
    __Ownable_init();
    __ERC20_init(_name, _symbol);
    underlying = IERC20Metadata(_underlying);
    _underlyingDecimals = underlying.decimals();
  }

  /// @notice 18 decimal erc20 spec should have been written into the fucking standard
  /// @return _decimals decimals of token
  function decimals() public pure override returns (uint8 _decimals) {
    return 18;
  }

  /// @notice set the Cap
  function setCap(uint256 _cap) external onlyOwner {
    cap = _cap;
  }

  function _checkCap(uint256 _amount) internal view {
    if (ERC20Upgradeable.totalSupply() + _amount > cap) revert CappedToken_CapReached();
  }

  function underlyingScalar() public view returns (uint256 _underlyingScalar) {
    return (10 ** (18 - _underlyingDecimals));
  }

  /// @notice get underlying ratio
  /// @return _amount amount of this CappedToken
  function _underlyingToCappedAmount(uint256 _underlyingAmount) internal view returns (uint256 _amount) {
    _amount = _underlyingAmount * underlyingScalar();
  }

  function _cappedAmountToUnderlying(uint256 _underlyingAmount) internal view returns (uint256 _amount) {
    _amount = _underlyingAmount / underlyingScalar();
  }

  /// @notice deposit underlying to mint CappedToken
  /// @param _underlyingAmount amount of underlying to deposit
  /// @param _target recipient of tokens
  function deposit(uint256 _underlyingAmount, address _target) public {
    // scale the decimals to THIS token decimals, or 1e18. see _underlyingToCappedAmount
    uint256 _amount = _underlyingToCappedAmount(_underlyingAmount);
    if (_amount == 0) revert CappedToken_ZeroAmount();
    // check cap
    _checkCap(_amount);
    // mint the scaled amount of tokens to the TARGET
    ERC20Upgradeable._mint(_target, _amount);
    // transfer underlying from SENDER to THIS
    if (!underlying.transferFrom(_msgSender(), address(this), _underlyingAmount)) revert CappedToken_TransferFailed();
  }

  /// @notice withdraw underlying by burning THIS token
  /// caller should obtain 1 underlying for every underlyingScalar() THIS token
  /// @param _underlyingAmount amount of underlying to withdraw
  function withdraw(uint256 _underlyingAmount, address _target) public {
    // scale the _underlyingAmount to the THIS token decimal amount, aka 1e18
    uint256 _amount = _underlyingToCappedAmount(_underlyingAmount);
    if (_amount == 0) revert CappedToken_ZeroAmount();
    // burn the scaled amount of tokens from the SENDER
    ERC20Upgradeable._burn(_msgSender(), _amount);
    // transfer underlying to the TARGET
    if (!underlying.transfer(_target, _underlyingAmount)) revert CappedToken_TransferFailed();
  }

  // EIP-4626 compliance, sorry it's not the most gas efficient.

  function underlyingAddress() external view returns (address _underlying) {
    return address(underlying);
  }

  function totalUnderlying() public view returns (uint256 _totalUnderlying) {
    return underlying.balanceOf(address(this));
  }

  function convertToShares(uint256 _assets) external view returns (uint256 _shares) {
    return _underlyingToCappedAmount(_assets);
  }

  function convertToAssets(uint256 _shares) external view returns (uint256 _assets) {
    return _cappedAmountToUnderlying(_shares);
  }

  function maxDeposit(address _receiver) public view returns (uint256 _maxDeposit) {
    uint256 _remaining = (cap - _underlyingToCappedAmount(totalUnderlying()));
    uint256 _receiverBalance = _underlyingToCappedAmount(underlying.balanceOf(_receiver));
    if (_remaining > _receiverBalance) return _receiverBalance;
    return _remaining;
  }

  function previewDeposit(uint256 _assets) public view returns (uint256 _shares) {
    return _underlyingToCappedAmount(_assets);
  }

  function maxMint(address _receiver) external view returns (uint256 _assets) {
    return _cappedAmountToUnderlying(maxDeposit(_receiver));
  }

  function previewMint(uint256 _shares) external view returns (uint256 _assets) {
    return _cappedAmountToUnderlying(_shares);
  }

  function mint(uint256 _shares, address _receiver) external {
    return deposit(_cappedAmountToUnderlying(_shares), _receiver);
  }

  function maxWithdraw(address _receiver) public view returns (uint256 _maxWithdraw) {
    _maxWithdraw = _cappedAmountToUnderlying(ERC20Upgradeable.balanceOf(_receiver));
    if (_maxWithdraw > underlying.balanceOf(address(this))) return underlying.balanceOf(address(this));
  }

  function previewWithdraw(uint256 _assets) public view returns (uint256 _shares) {
    return _underlyingToCappedAmount(_assets);
  }

  function maxRedeem(address _receiver) external view returns (uint256 _assets) {
    return _underlyingToCappedAmount(maxWithdraw(_receiver));
  }

  function previewRedeem(uint256 _shares) external view returns (uint256 _assets) {
    return _cappedAmountToUnderlying(_shares);
  }

  function redeem(uint256 _shares, address _receiver) external {
    return withdraw(_cappedAmountToUnderlying(_shares), _receiver);
  }
}
