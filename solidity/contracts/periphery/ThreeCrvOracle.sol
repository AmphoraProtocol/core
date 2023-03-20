// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/OracleRelay.sol';
import {AggregatorInterface} from '@chainlink/interfaces/AggregatorInterface.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

interface ICurvePool {
  function get_virtual_price() external view returns (uint256 _price);
}

contract ThreeCrvOracle is OracleRelay {
  ICurvePool public constant THREE_CRV = ICurvePool(0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C);
  AggregatorInterface public constant DAI = AggregatorInterface(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);
  AggregatorInterface public constant USDC = AggregatorInterface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
  AggregatorInterface public constant USDT = AggregatorInterface(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);

  constructor() OracleRelay(OracleType.Chainlink) {}

  /// @notice the current reported value of the oracle
  /// @return _value the current value
  /// @dev implementation in getLastSecond
  function currentValue() external view override returns (uint256 _value) {
    _value = _get();
  }

  // Calculates the lastest exchange rate
  // Uses both divide and multiply only for tokens not supported directly by Chainlink, for example MKR/USD
  function _get() internal view returns (uint256 _value) {
    // As the price should never be negative, the unchecked conversion is acceptable
    uint256 _minStable =
      Math.min(uint256(DAI.latestAnswer()), Math.min(uint256(USDC.latestAnswer()), uint256(USDT.latestAnswer())));

    uint256 _lpPrice = THREE_CRV.get_virtual_price() * _minStable;

    // Chainlink price has 8 decimals
    _value = _lpPrice / 1e8;
  }
}
