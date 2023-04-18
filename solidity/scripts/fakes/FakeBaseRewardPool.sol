// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IBaseRewardPool} from '@interfaces/utils/IBaseRewardPool.sol';
import {IBooster} from '@interfaces/utils/IBooster.sol';
import {IVirtualBalanceRewardPool} from '@interfaces/utils/IVirtualBalanceRewardPool.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';

import {FakeVirtualRewardsPool} from './FakeVirtualRewardsPool.sol';

struct Rewards {
  uint256 lastClaimTime;
  uint256 rewardsToPay;
}

contract FakeBaseRewardPool is IBaseRewardPool {
  address public booster;
  mapping(address => uint256) public balances;
  IERC20 public rewardToken;
  mapping(address => Rewards) public rewards;
  uint256 public rewardsPerSecondPerToken; //1e18 = 1 token
  IVirtualBalanceRewardPool[] public extraRewards;
  address public owner;
  IERC20 public lptoken;

  constructor(address _booster, IERC20 _rewardToken, uint256 _rewardsPerSecondPerToken, address _lptoken) {
    booster = _booster;
    rewardToken = _rewardToken;
    rewardsPerSecondPerToken = _rewardsPerSecondPerToken;
    owner = msg.sender;
    lptoken = IERC20(_lptoken);
  }

  function withdraw(uint256, bool) external pure override returns (bool _success) {
    return true;
  }

  function queueNewRewards(uint256) external pure override returns (bool _success) {
    return true;
  }

  function stakeFor(address, uint256) external pure override returns (bool _staked) {
    return true;
  }

  function stake(uint256) external pure override returns (bool _staked) {
    return true;
  }

  ////////////////////////

  function stakeForUser(uint256 _amount, address _user) external {
    require(msg.sender == booster, 'only booster');
    rewards[_user].rewardsToPay = rewards[_user].rewardsToPay + _newAccumulatedRewards(_user);
    rewards[_user].lastClaimTime = block.timestamp;
    balances[_user] += _amount;

    for (uint256 i = 0; i < extraRewards.length; i++) {
      FakeVirtualRewardsPool(address(extraRewards[i])).stake(_user, _amount);
    }
  }

  function earned(address _ad) external view override returns (uint256 _reward) {
    _reward = rewards[_ad].rewardsToPay + _newAccumulatedRewards(_ad);
  }

  function extraRewardsLength() external view override returns (uint256 _extraRewardsLength) {
    return extraRewards.length;
  }

  function withdrawAndUnwrap(uint256 _amount, bool) external override returns (bool _success) {
    rewards[msg.sender].rewardsToPay = rewards[msg.sender].rewardsToPay + _newAccumulatedRewards(msg.sender);
    rewards[msg.sender].lastClaimTime = block.timestamp;
    balances[msg.sender] -= _amount;

    for (uint256 i = 0; i < extraRewards.length; i++) {
      FakeVirtualRewardsPool(address(extraRewards[i])).unstake(msg.sender, _amount);
    }

    lptoken.transfer(msg.sender, _amount);
    return true;
  }

  function getReward(address _account, bool) external override returns (bool _success) {
    uint256 _earned = rewards[_account].rewardsToPay + _newAccumulatedRewards(_account);
    rewardToken.transfer(_account, _earned);

    rewards[_account].lastClaimTime = block.timestamp;
    rewards[_account].rewardsToPay = 0;
    return true;
  }

  function addExtraReward(IVirtualBalanceRewardPool _extraReward) external {
    require(msg.sender == owner, 'only owner');
    extraRewards.push(_extraReward);
  }

  function _newAccumulatedRewards(address _user) internal view returns (uint256 _rewards) {
    uint256 _secondsSinceLastDeposit = (block.timestamp - rewards[_user].lastClaimTime);
    _rewards = ((rewardsPerSecondPerToken * _secondsSinceLastDeposit * balances[_user]) / 1 ether);
  }
}
