// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IWUSDA is IERC20 {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a wrap is made
   * @param _from The address which made the wrap
   * @param _usdaAmount The amount sent, denominated in the underlying
   * @param _wusdaAmount The amount sent, denominated in the wrapped
   */
  event Wrapped(address indexed _from, uint256 _usdaAmount, uint256 _wusdaAmount);

  /**
   * @notice Emitted when a unwrap is made
   * @param _from The address which made the unwrap
   * @param _usdaAmount The amount sent, denominated in the underlying
   * @param _wusdaAmount The amount sent, denominated in the wrapped
   */
  event Unwrapped(address indexed _from, uint256 _usdaAmount, uint256 _wusdaAmount);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when trying to wrap or unwrap 0 amount
   */
  error WUsda_ZeroAmount();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

  /// @notice The reference to the usda token.
  function USDA() external view returns (address _usda);

  /// @notice The amount to substract from the first depositor to prevent 'first depositor attack'
  function BOOTSTRAP_MINT() external view returns (uint256 _bootstrapMint);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Exchanges USDA to wUSDA
   * @param _usdaAmount amount of USDA to wrap in exchange for wUSDA
   * @dev Requirements:
   *  - `_usdaAmount` must be non-zero
   *  - msg.sender must approve at least `_usdaAmount` USDA to this
   *    contract.
   *  - msg.sender must have at least `_usdaAmount` of USDA.
   * User should first approve _usdaAmount to the WstETH contract
   * @return _wusdaAmount Amount of wUSDA user receives after wrap
   */
  function wrap(uint256 _usdaAmount) external returns (uint256 _wusdaAmount);

  /**
   * @notice Exchanges wUSDA to USDA
   * @param _wusdaAmount amount of wUSDA to uwrap in exchange for USDA
   * @dev Requirements:
   *  - `_wusdaAmount` must be non-zero
   *  - msg.sender must have at least `_wusdaAmount` wUSDA.
   * @return _usdaAmount Amount of USDA user receives after unwrap
   */
  function unwrap(uint256 _wusdaAmount) external returns (uint256 _usdaAmount);

  /**
   * @notice Get amount of wUSDA for a given amount of USDA
   * @param _usdaAmount amount of USDA
   * @return _wusdaAmount Amount of wUSDA for a given USDA amount
   */
  function getWUsdaByUsda(uint256 _usdaAmount) external view returns (uint256 _wusdaAmount);

  /**
   * @notice Get amount of USDA for a given amount of wUSDA
   * @param _wusdaAmount amount of wUSDA
   * @return _usdaAmount Amount of USDA for a given wUSDA amount
   */
  function getUsdaByWUsda(uint256 _wusdaAmount) external view returns (uint256 _usdaAmount);

  /**
   * @notice Get amount of USDA for a one wUSDA
   * @return _usdaPerToken Amount of USDA for 1 wUSDA
   */
  function usdaPerToken() external view returns (uint256 _usdaPerToken);

  /**
   * @notice Get amount of wUSDA for a one USDA
   * @return _tokensPerUsda Amount of wUSDA for a 1 USDA
   */
  function tokensPerUsda() external view returns (uint256 _tokensPerUsda);
}
