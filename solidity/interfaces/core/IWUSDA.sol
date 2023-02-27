// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IWUSDA is IERC20 {
  /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/
  function underlying() external view returns (address _underlying);

  function totalUnderlying() external view returns (uint256 _totalUnderlying);

  function balanceOfUnderlying(address _owner) external view returns (uint256 _balanceOfUnderlying);

  function underlyingToWrapper(uint256 _usdaAmount) external view returns (uint256 _wusdaAmount);

  function wrapperToUnderlying(uint256 _wusdaAmount) external view returns (uint256 _usdaAmount);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/
  function mint(uint256 _wusdaAmount) external returns (uint256 _usdaAmount);

  function mintFor(address _to, uint256 _wusdaAmount) external returns (uint256 _usdaAmount);

  function burn(uint256 _wusdaAmount) external returns (uint256 _usdaAmount);

  function burnTo(address _to, uint256 _wusdaAmount) external returns (uint256 _usdaAmount);

  function burnAll() external returns (uint256 _usdaAmount);

  function burnAllTo(address _to) external returns (uint256 _usdaAmount);

  function deposit(uint256 _usdaAmount) external returns (uint256 _wusdaAmount);

  function depositFor(address _to, uint256 _usdaAmount) external returns (uint256 _wusdaAmount);

  function withdraw(uint256 _usdaAmount) external returns (uint256 _wusdaAmount);

  function withdrawTo(address _to, uint256 _usdaAmount) external returns (uint256 _wusdaAmount);

  function withdrawAll() external returns (uint256 _usdaAmount);

  function withdrawAllTo(address _to) external returns (uint256 _usdaAmount);
}
