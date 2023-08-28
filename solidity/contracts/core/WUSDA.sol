// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import {IWUSDA} from '@interfaces/core/IWUSDA.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC20Permit, IERC20, ERC20} from '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';

/// @title wUSDA (Wrapped usda).
/// @notice this contract is modified implementation of xSUSHI https://etherscan.io/token/0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272#code. Also it keeps the same interface as wstETH https://etherscan.io/token/0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0#code.
/// @dev It's an ERC20 token that represents the account's share of the total
/// supply of USDA tokens. wUSDA token's balance only changes on transfers,
/// unlike USDA that is also changed when the protocol accumulates interest.
/// It's a 'power user' token for DeFi protocols which don't support rebasable tokens.
///
/// The contract is also a trustless wrapper that accepts USDA tokens and mints
/// wUSDA in return. Then the user unwraps, the contract burns user's wUSDA
/// and sends user locked USDA in return.
contract WUSDA is IWUSDA, ERC20Permit {
  using SafeERC20 for IERC20;

  /// @notice The amount to substract from the first depositor to prevent 'first depositor attack'
  uint256 public constant BOOTSTRAP_MINT = 10_000;

  /// @notice The reference to the usda token.
  address public immutable USDA;

  /// @param _usdaToken The usda ERC20 token address.
  /// @param _name The wUSDA ERC20 name.
  /// @param _symbol The wUSDA ERC20 symbol.
  constructor(address _usdaToken, string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC20Permit(_name) {
    USDA = _usdaToken;
  }

  /// @notice Exchanges USDA to wUSDA
  /// @param _usdaAmount amount of USDA to wrap in exchange for wUSDA
  /// @dev Requirements:
  ///  - `_usdaAmount` must be non-zero
  ///  - msg.sender must approve at least `_usdaAmount` USDA to this
  ///    contract.
  ///  - msg.sender must have at least `_usdaAmount` of USDA.
  /// User should first approve _usdaAmount to the WstETH contract
  /// @return _wusdaAmount Amount of wUSDA user receives after wrap
  function wrap(uint256 _usdaAmount) external returns (uint256 _wusdaAmount) {
    if (_usdaAmount == 0) revert WUsda_ZeroAmount();

    _wusdaAmount = _getWUsdaByUsda(_usdaAmount);

    // NOTE: prevent 'first depositor attack' burning some shares from the first depositor
    if (totalSupply() == 0) {
      _mint(0x000000000000000000000000000000000000dEaD, BOOTSTRAP_MINT);
      _wusdaAmount -= BOOTSTRAP_MINT;
    }

    _mint(msg.sender, _wusdaAmount);

    IERC20(USDA).transferFrom(msg.sender, address(this), _usdaAmount);

    emit Wrapped(msg.sender, _usdaAmount, _wusdaAmount);
  }

  /// @notice Exchanges wUSDA to USDA
  /// @param _wusdaAmount amount of wUSDA to uwrap in exchange for USDA
  /// @dev Requirements:
  ///  - `_wusdaAmount` must be non-zero
  ///  - msg.sender must have at least `_wusdaAmount` wUSDA.
  /// @return _usdaAmount Amount of USDA user receives after unwrap
  function unwrap(uint256 _wusdaAmount) external returns (uint256 _usdaAmount) {
    if (_wusdaAmount == 0) revert WUsda_ZeroAmount();

    _usdaAmount = _getUsdaByWUsda(_wusdaAmount);
    _burn(msg.sender, _wusdaAmount);

    IERC20(USDA).transfer(msg.sender, _usdaAmount);

    emit Unwrapped(msg.sender, _usdaAmount, _wusdaAmount);
  }

  /// @notice Get amount of wUSDA for a given amount of USDA
  /// @param _usdaAmount amount of USDA
  /// @return _wusdaAmount Amount of wUSDA for a given USDA amount
  function getWUsdaByUsda(uint256 _usdaAmount) external view returns (uint256 _wusdaAmount) {
    _wusdaAmount = _getWUsdaByUsda(_usdaAmount);
  }

  /// @notice Get amount of USDA for a given amount of wUSDA
  /// @param _wusdaAmount amount of wUSDA
  /// @return _usdaAmount Amount of USDA for a given wUSDA amount
  function getUsdaByWUsda(uint256 _wusdaAmount) external view returns (uint256 _usdaAmount) {
    _usdaAmount = _getUsdaByWUsda(_wusdaAmount);
  }

  /// @notice Get amount of USDA for a one wUSDA
  /// @return _usdaPerToken Amount of USDA for 1 wUSDA
  function usdaPerToken() external view returns (uint256 _usdaPerToken) {
    _usdaPerToken = _getUsdaByWUsda(1 ether);
  }

  /// @notice Get amount of wUSDA for a one USDA
  /// @return _tokensPerUsda Amount of wUSDA for a 1 USDA
  function tokensPerUsda() external view returns (uint256 _tokensPerUsda) {
    _tokensPerUsda = _getWUsdaByUsda(1 ether);
  }

  /// @notice Get total amount of USDA held by the contract and wUSDA in circulation
  /// @return _totalUSDA Total amount of USDA held by the contract
  /// @return _totalWUSDA Total amount of wUSDA in circulation
  function _getSupplies() internal view returns (uint256 _totalUSDA, uint256 _totalWUSDA) {
    _totalUSDA = IERC20(USDA).balanceOf(address(this));
    _totalWUSDA = totalSupply();
  }

  /// @notice Internal function to get amount of wUSDA for a given amount of USDA
  /// @param _usdaAmount amount of USDA
  /// @return _wusdaAmount Amount of wUSDA for a given USDA amount
  function _getWUsdaByUsda(uint256 _usdaAmount) internal view returns (uint256 _wusdaAmount) {
    // USDA -> wUSDA
    (uint256 _totalUSDA, uint256 _totalWUSDA) = _getSupplies();

    // if there are no wUSDA in circulation, mint 1:1
    // if there are no USDA in the contract, mint 1:1
    if (_totalWUSDA == 0 || _totalUSDA == 0) _wusdaAmount = _usdaAmount;
    else _wusdaAmount = (_usdaAmount * _totalWUSDA) / _totalUSDA;
  }

  /// @notice Internal function to get amount of USDA for a given amount of wUSDA
  /// @param _wusdaAmount amount of wUSDA
  /// @return _usdaAmount Amount of USDA for a given wUSDA amount
  function _getUsdaByWUsda(uint256 _wusdaAmount) internal view returns (uint256 _usdaAmount) {
    // wUSDA -> USDA
    (uint256 _totalUSDA, uint256 _totalWUSDA) = _getSupplies();

    // if there are no wUSDA in circulation, return zero USDA
    // if there are no USDA in the contract, return zero USDA
    if (_totalWUSDA == 0 || _totalUSDA == 0) return 0;
    _usdaAmount = (_wusdaAmount * _totalUSDA) / _totalWUSDA;
  }
}
