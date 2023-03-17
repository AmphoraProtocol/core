// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IBaseRewardPool {
  function stake(uint256 _amount) external returns (bool _staked);
  function stakeFor(address _for, uint256 _amount) external returns (bool _staked);
  function withdraw(uint256 _amount, bool _claim) external returns (bool _success);
  function withdrawAndUnwrap(uint256 _amount, bool _claim) external returns (bool _success);
  function getReward(address _account, bool _claimExtras) external returns (bool _success);
}
