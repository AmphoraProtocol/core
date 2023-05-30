// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestPlus, console} from 'solidity-utils/test/DSTestPlus.sol';
import {UniswapV3TokenOracleRelay} from '@contracts/periphery/oracles/UniswapV3TokenOracleRelay.sol';

import {
  IUniswapV3Pool,
  IUniswapV3PoolImmutables,
  IUniswapV3PoolDerivedState
} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {UniswapV3OracleRelay} from '@contracts/periphery/oracles/UniswapV3OracleRelay.sol';

abstract contract Base is DSTestPlus {
  UniswapV3TokenOracleRelay public uniswapV3TokenOracleRelay;
  IUniswapV3Pool internal _mockPool = IUniswapV3Pool(mockContract(newAddress(), 'mockPool'));
  IOracleRelay internal _mockEthPriceFeed;
  address internal _underlying = newAddress();

  uint32 public lookback = 60;
  bool public quoteTokenIsToken0 = true;
  uint256 public mul = 1;
  uint256 public div = 1;

  int56[] public tickCumulatives;
  uint160[] public secondsPerLiquidityCumulativeX128s;

  IOracleRelay.OracleType public oracleType = IOracleRelay.OracleType(1); // 1 == Uniswap

  UniswapV3OracleRelay internal _uniswapRelayEthUsdc = UniswapV3OracleRelay(newAddress());

  function setUp() public virtual {
    vm.mockCall(
      address(_mockPool), abi.encodeWithSelector(IUniswapV3PoolImmutables.token1.selector), abi.encode(_underlying)
    );

    // Deploy contract
    uniswapV3TokenOracleRelay =
      new UniswapV3TokenOracleRelay(_uniswapRelayEthUsdc, lookback, address(_mockPool), quoteTokenIsToken0, mul, div);

    secondsPerLiquidityCumulativeX128s = new uint160[](0);
    tickCumulatives = new int56[](2);

    _mockEthPriceFeed = IOracleRelay(mockContract(address(_uniswapRelayEthUsdc), 'mockEthPriceFeed'));
  }
}

contract UnitTestUniswapV3TokenOracleRelayUnderlyingIsSet is Base {
  function testUnderlyingIsSet() public {
    assertEq(_underlying, uniswapV3TokenOracleRelay.underlying());
  }
}

contract UnitTestUniswapV3TokenOracleRelayOracleType is Base {
  function testOracleType() public {
    assertEq(uint256(oracleType), uint256(uniswapV3TokenOracleRelay.oracleType()));
  }
}

contract UnitTestUniswapV3TokenOracleRelayCurrentValue is Base {
  function testUniswapV3TokenOracleRelayCurrentValueRevertWithTickTimeDiffTooLarge() public {
    tickCumulatives[0] = 106_472_640;
    tickCumulatives[1] = 53_236_320;

    vm.mockCall(
      address(_mockPool),
      abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
      abi.encode(tickCumulatives, secondsPerLiquidityCumulativeX128s)
    );

    vm.expectRevert(UniswapV3TokenOracleRelay.UniswapV3OracleRelay_TickTimeDiffTooLarge.selector);
    uniswapV3TokenOracleRelay.currentValue();
  }

  function testUniswapV3TokenOracleRelayCurrentValue(uint256 _ethPrice) public {
    vm.assume(_ethPrice > 0);
    vm.assume(_ethPrice < 1e5);

    tickCumulatives[0] = 106_472_520;
    tickCumulatives[1] = 53_236_260;

    vm.mockCall(
      address(_mockPool),
      abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
      abi.encode(tickCumulatives, secondsPerLiquidityCumulativeX128s)
    );
    vm.mockCall(
      address(_mockEthPriceFeed), abi.encodeWithSelector(IOracleRelay.peekValue.selector), abi.encode(_ethPrice)
    );

    uint256 _price = uniswapV3TokenOracleRelay.currentValue();
    assertGt(_price, 0);
  }
}
