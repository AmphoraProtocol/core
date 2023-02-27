//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {CustomInitializable} from '@contracts/_external/CustomInitializable.sol';

/**
 * @title ERC20Detailed token
 * @dev The decimals are only for visualization purposes.
 * All the operations are done using the smallest and indivisible token unit,
 * just as on Ethereum all the operations are done in wei.
 */
abstract contract ERC20Detailed is CustomInitializable, IERC20 {
  string private _name;
  string private _symbol;
  uint8 private _decimals;

  /**
   * constructor(string memory _name, string memory _symbol, uint8 decimals_){
   *     _name = _name;
   *     _symbol = _symbol;
   *     _decimals = decimals_;
   * }
   */

  function erc20DetailedInit(string memory __name, string memory __symbol, uint8 __decimals) public initializer2 {
    _name = __name;
    _symbol = __symbol;
    _decimals = __decimals;
  }

  /**
   * @return __name the name of the token.
   */
  function name() public view virtual returns (string memory __name) {
    return _name;
  }

  /**
   * @return __symbol the symbol of the token.
   */
  function symbol() public view virtual returns (string memory __symbol) {
    return _symbol;
  }

  /**
   * @return __decimals the number of decimals of the token.
   */
  function decimals() public view virtual returns (uint8 __decimals) {
    return _decimals;
  }

  uint256[50] private ______gap;
}
