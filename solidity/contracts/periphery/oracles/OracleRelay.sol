// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

abstract contract OracleRelay is IOracleRelay {
  OracleType public oracleType;

  constructor(OracleType _oracleType) {
    oracleType = _oracleType;
  }

  /// @dev Most oracles don't require a state change for pricing, for those who do, override this function
  function currentValue() external virtual returns (uint256 _currentValue) {
    _currentValue = peekValue();
  }

  function peekValue() public view virtual override returns (uint256 _price);
}
