// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ICurvePool {
  function calc_token_amount(uint256[] memory _amounts, bool _deposit) external view returns (uint256 _amount);
}
