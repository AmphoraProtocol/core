// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ICurvePool {
  function get_virtual_price() external view returns (uint256 _price);
  function gamma() external view returns (uint256 _gamma);
  // solhint-disable-next-line defi-wonderland/wonder-var-name-mixedcase
  function A() external view returns (uint256 _A);
}
