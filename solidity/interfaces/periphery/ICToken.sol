// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ICToken {
  function exchangeRateStored() external view returns (uint256 _exchangeRate);
  function decimals() external view returns (uint8 _decimals);
  function symbol() external view returns (string memory _symbol);
  function underlying() external view returns (address _underlying);
}
