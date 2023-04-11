// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestPlus, console} from 'solidity-utils/test/DSTestPlus.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/oracles/ChainlinkOracleRelay.sol';

import {AggregatorInterface} from '@chainlink/interfaces/AggregatorInterface.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

abstract contract Base is DSTestPlus {
  ChainlinkOracleRelay public chainlinkOracleRelay;
  AggregatorInterface internal _mockAggregator = AggregatorInterface(mockContract(newAddress(), 'mockAggregator'));

  uint256 public mul = 10_000_000_000;
  uint256 public div = 1;

  IOracleRelay.OracleType public oracleType = IOracleRelay.OracleType(0); // 0 == Chainlink

  function setUp() public virtual {
    // Deploy contract
    chainlinkOracleRelay = new ChainlinkOracleRelay(address(_mockAggregator), mul, div);
  }
}

contract UnitTestChainlinkOracleRelayOracleType is Base {
  function testOracleType() public {
    assertEq(uint256(oracleType), uint256(chainlinkOracleRelay.oracleType()));
  }
}

contract UnitTestChainlinkOracleRelayCurrentValue is Base {
  function testChainlinkOracleRelayRevertWithPriceLessThanZero(int256 _latestAnswer) public {
    vm.assume(_latestAnswer < 0);

    vm.mockCall(
      address(_mockAggregator),
      abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector),
      abi.encode(_latestAnswer)
    );

    vm.expectRevert(ChainlinkOracleRelay.ChainlinkOracle_PriceLessThanZero.selector);
    chainlinkOracleRelay.currentValue();
  }

  function testChainlinkOracleRelay(int256 _latestAnswer) public {
    vm.assume(_latestAnswer > 0);

    vm.assume(uint256(_latestAnswer) < type(uint256).max / mul);
    vm.mockCall(
      address(_mockAggregator),
      abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector),
      abi.encode(_latestAnswer)
    );

    uint256 _response = chainlinkOracleRelay.currentValue();
    assertEq(_response, (uint256(_latestAnswer) * mul) / div);
  }
}
