// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ICurvePool {
  function get_virtual_price() external view returns (uint256 _price);
  function gamma() external view returns (uint256 _gamma);
  // solhint-disable-next-line defi-wonderland/wonder-var-name-mixedcase
  function A() external view returns (uint256 _A);
  function remove_liquidity(
    uint256 _amount,
    uint256[2] memory _minAmounts
  ) external returns (uint256[2] memory _amounts);
  function lp_token() external view returns (IERC20 _lpToken);
  function calc_token_amount(uint256[] memory _amounts, bool _deposit) external view returns (uint256 _amount);
}
