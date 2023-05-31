// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {ICToken} from '@interfaces/periphery/ICToken.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IWStETH} from '@interfaces/utils/IWStETH.sol';

/// @notice Oracle Relay for WstEth
contract WstEthOracle is OracleRelay {
  /// @notice The WstEth contract
  IWStETH public constant WSTETH = IWStETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
  /// @notice The oracle of the underlying asset
  IOracleRelay public stEthAnchoredViewUnderlying;

  constructor(IOracleRelay _stEthAnchoredViewUnderlying) OracleRelay(OracleType.Chainlink) {
    stEthAnchoredViewUnderlying = _stEthAnchoredViewUnderlying;
    _setUnderlying(address(WSTETH));
  }

  /// @notice returns the price with 18 decimals without any state changes
  /// @dev some oracles require a state change to get the exact current price.
  ///      This is updated when calling other state changing functions that query the price
  /// @return _price the current price
  function peekValue() public view override returns (uint256 _price) {
    _price = _get();
  }

  /// @notice The current reported value of the oracle
  /// @return _value The current value
  function _get() internal view returns (uint256 _value) {
    uint256 _stETHPrice = stEthAnchoredViewUnderlying.peekValue();
    uint256 _stETHPerWstEth = WSTETH.stEthPerToken();
    _value = (_stETHPrice * _stETHPerWstEth) / 1e18;
  }
}