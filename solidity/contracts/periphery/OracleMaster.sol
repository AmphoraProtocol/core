// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleMaster} from '@interfaces/periphery/IOracleMaster.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

/// @title An addressbook for oracle relays
/// @notice the oraclemaster is simply an addressbook of address->relay
/// this is so that contracts may use the OracleMaster to call any registered relays.
contract OracleMaster is IOracleMaster, Ownable {
  // mapping of token to address
  mapping(address => address) public relays;

  /// @notice empty constructor
  constructor() Ownable() {}

  /// @notice gets the current price of the oracle registered for a token
  /// @param _tokenAddress address of the token to get value for
  /// @return _value the value of the token
  function getLivePrice(address _tokenAddress) external view override returns (uint256 _value) {
    require(relays[_tokenAddress] != address(0), 'token not enabled');
    IOracleRelay _relay = IOracleRelay(relays[_tokenAddress]);
    uint256 _value = _relay.currentValue();
    return _value;
  }

  /// @notice admin only, sets relay for a token address to the relay addres
  /// @param _tokenAddress address of the token
  /// @param _relayAddress address of the relay
  function setRelay(address _tokenAddress, address _relayAddress) public override onlyOwner {
    relays[_tokenAddress] = _relayAddress;
  }
}
