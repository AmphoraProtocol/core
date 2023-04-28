// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IChainlinkOracleRelay {
  function isStale() external view returns (bool _stale);
}
