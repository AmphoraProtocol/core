// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IConvexProxyVoter {
  function owner() external view returns (address _owner);
  function operator() external view returns (address _operator);
  function setOperator(address _operator) external;
}
