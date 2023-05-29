// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestPlus, console} from 'solidity-utils/test/DSTestPlus.sol';
import {ChainlinkTokenOracleRelay} from '@contracts/periphery/oracles/ChainlinkTokenOracleRelay.sol';

import {AggregatorInterface} from '@chainlink/interfaces/AggregatorInterface.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

abstract contract Base is DSTestPlus {
  ChainlinkTokenOracleRelay public chainlinkTokenOracleRelay;
  AggregatorInterface internal _mockAggregator = AggregatorInterface(mockContract(newAddress(), 'mockAggregator'));
  IOracleRelay internal _mockEthPriceFeed;

  uint256 public mul = 10_000_000_000;
  uint256 public div = 1;

  IOracleRelay.OracleType public oracleType = IOracleRelay.OracleType(0); // 0 == Chainlink

  function setUp() public virtual {
    // Deploy contract
    chainlinkTokenOracleRelay = new ChainlinkTokenOracleRelay(address(_mockAggregator), mul, div);
    _mockEthPriceFeed =
      IOracleRelay(mockContract(address(chainlinkTokenOracleRelay.ETH_PRICE_FEED()), 'mockEthPriceFeed'));
  }
}

contract UnitTestChainlinkTokenOracleRelayOracleType is Base {
  function testOracleType() public {
    assertEq(uint256(oracleType), uint256(chainlinkTokenOracleRelay.oracleType()));
  }
}

contract UnitTestChainlinkTokenOracleRelayCurrentValue is Base {
  function testChainlinkTokenOracleRelayRevertWithPriceLessThanZero(int256 _latestAnswer) public {
    vm.assume(_latestAnswer < 0);

    vm.mockCall(
      address(_mockAggregator),
      abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector),
      abi.encode(_latestAnswer)
    );

    vm.expectRevert(ChainlinkTokenOracleRelay.ChainlinkOracle_PriceLessThanZero.selector);
    chainlinkTokenOracleRelay.currentValue();
  }

  function testChainlinkTokenOracleRelay(int256 _latestAnswer, uint256 _ethPrice) public {
    vm.assume(_latestAnswer > 0);
    vm.assume(_ethPrice > 0);
    vm.assume(uint256(_latestAnswer) < type(uint256).max / mul);

    uint256 _priceInEth = (uint256(_latestAnswer) * mul) / div;

    vm.assume(_ethPrice < type(uint256).max / _priceInEth);
    vm.assume(_ethPrice * _priceInEth >= 1e18);

    vm.mockCall(
      address(_mockAggregator),
      abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector),
      abi.encode(_latestAnswer)
    );
    vm.mockCall(
      address(_mockEthPriceFeed), abi.encodeWithSelector(IOracleRelay.peekValue.selector), abi.encode(_ethPrice)
    );

    uint256 _response = chainlinkTokenOracleRelay.currentValue();
    assertEq(_response, (_ethPrice * _priceInEth) / 1e18);
  }
}
