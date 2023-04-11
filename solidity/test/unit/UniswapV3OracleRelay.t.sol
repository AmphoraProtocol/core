// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestPlus, console} from 'solidity-utils/test/DSTestPlus.sol';
import {UniswapV3OracleRelay} from '@contracts/periphery/oracles/UniswapV3OracleRelay.sol';

import {IUniswapV3PoolDerivedState} from '@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

abstract contract Base is DSTestPlus {
  UniswapV3OracleRelay public uniswapV3OracleRelay;
  IUniswapV3PoolDerivedState internal _mockPool = IUniswapV3PoolDerivedState(mockContract(newAddress(), 'mockPool'));

  uint32 public lookback = 60;
  bool public quoteTokenIsToken0 = true;
  uint256 public mul = 1;
  uint256 public div = 1;

  int56[] public tickCumulatives;
  uint160[] public secondsPerLiquidityCumulativeX128s;

  IOracleRelay.OracleType public oracleType = IOracleRelay.OracleType(1); // 1 == Uniswap

  function setUp() public virtual {
    // Deploy contract
    uniswapV3OracleRelay = new UniswapV3OracleRelay(lookback, address(_mockPool), quoteTokenIsToken0, mul, div);

    secondsPerLiquidityCumulativeX128s = new uint160[](0);
    tickCumulatives = new int56[](2);
  }
}

contract UnitTestUniswapV3OracleRelayOracleType is Base {
  function testOracleType() public {
    assertEq(uint256(oracleType), uint256(uniswapV3OracleRelay.oracleType()));
  }
}

contract UnitTestUniswapV3OracleRelayCurrentValue is Base {
  function testUniswapV3OracleRelayCurrentValueRevertWithTickTimeDiffTooLarge() public {
    tickCumulatives[0] = 106_472_640;
    tickCumulatives[1] = 53_236_320;

    vm.mockCall(
      address(_mockPool),
      abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
      abi.encode(tickCumulatives, secondsPerLiquidityCumulativeX128s)
    );

    vm.expectRevert(UniswapV3OracleRelay.UniswapV3OracleRelay_TickTimeDiffTooLarge.selector);
    uniswapV3OracleRelay.currentValue();
  }

  function testUniswapV3OracleRelayCurrentValue() public {
    tickCumulatives[0] = 106_472_520;
    tickCumulatives[1] = 53_236_260;

    vm.mockCall(
      address(_mockPool),
      abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
      abi.encode(tickCumulatives, secondsPerLiquidityCumulativeX128s)
    );

    uint256 _price = uniswapV3OracleRelay.currentValue();
    assertGt(_price, 0);
  }
}
