// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

abstract contract OracleRelay is IOracleRelay {
  OracleType public oracleType;

  constructor(OracleType _oracleType) {
    oracleType = _oracleType;
  }

  function currentValue() external view virtual returns (uint256 _currentValue);
}
