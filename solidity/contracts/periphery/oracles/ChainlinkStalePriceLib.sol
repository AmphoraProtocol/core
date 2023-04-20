// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import {AggregatorV2V3Interface} from '@chainlink/interfaces/AggregatorV2V3Interface.sol';

library ChainlinkStalePriceLib {
  // @notice Thrown when the price received is negative
  error Chainlink_NegativePrice();

  // @notice Thrown when the last updated price is stale
  error Chainlink_StalePrice();

  function getCurrentPrice(
    AggregatorV2V3Interface _aggregator,
    uint256 _stalePriceDelay
  ) internal view returns (uint256 _price) {
    (, int256 _answer,, uint256 _updatedAt,) = _aggregator.latestRoundData();
    if (_answer <= 0) revert Chainlink_NegativePrice();
    if (block.timestamp > _updatedAt + _stalePriceDelay) revert Chainlink_StalePrice();
    _price = uint256(_answer);
  }
}
