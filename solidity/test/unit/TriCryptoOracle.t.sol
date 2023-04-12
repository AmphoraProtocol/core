// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {WUSDA} from '@contracts/core/WUSDA.sol';
import {TriCryptoOracle} from '@contracts/periphery/oracles/TriCryptoOracle.sol';

import {ICurvePool} from '@interfaces/utils/ICurvePool.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {AggregatorInterface} from '@chainlink/interfaces/AggregatorInterface.sol';
import {FixedPointMathLib} from 'solady/utils/FixedPointMathLib.sol';

abstract contract Base is DSTestPlus {
  uint256 public constant POINT_ONE_PERCENT = 0.001e18;

  TriCryptoOracle public triCryptoOracle;
  ICurvePool public curvePool;
  AggregatorInterface public btcFeed;
  AggregatorInterface public ethFeed;
  AggregatorInterface public usdtFeed;
  AggregatorInterface public wbtcFeed;

  function setUp() public virtual {
    triCryptoOracle = new TriCryptoOracle();
    curvePool = ICurvePool(mockContract(address(triCryptoOracle.TRI_CRYPTO()), 'triCryptoPool'));
    btcFeed = AggregatorInterface(mockContract(address(triCryptoOracle.BTC_FEED()), 'btcFeed'));
    ethFeed = AggregatorInterface(mockContract(address(triCryptoOracle.ETH_FEED()), 'ethFeed'));
    usdtFeed = AggregatorInterface(mockContract(address(triCryptoOracle.USDT_FEED()), 'usdtFeed'));
    wbtcFeed = AggregatorInterface(mockContract(address(triCryptoOracle.WBTC_FEED()), 'wbtcFeed'));
  }
}

contract UnitRoot is Base {
  function testCubicRoot(uint80 _x) public {
    assertEq(FixedPointMathLib.cbrt(uint256(_x) * _x * _x), _x);
  }

  function testSqrt(uint128 _x) public {
    assertEq(FixedPointMathLib.sqrt(uint256(_x) * _x), _x);
  }

  // Calculated outside and chose a random number that is not round
  function testCubicRootHardcoded() public {
    assertApproxEqRel(FixedPointMathLib.cbrt(46_617_561_682_349_991_266_580_000), 359_901_207, POINT_ONE_PERCENT);
  }

  // Calculated outside and chose a random number that is not round
  function testSqrtHardcoded() public {
    assertApproxEqRel(FixedPointMathLib.sqrt(4_661_756_168_234_999_126_658), 68_277_082_538, POINT_ONE_PERCENT);
  }
}

contract UnitCurrentValue is Base {
  function testCurrentValueWbtc1(uint32 _btcPrice, uint32 _ethPrice, uint32 _usdtPrice) public {
    vm.assume(_btcPrice > 0.1e8);
    vm.assume(_ethPrice > 0.1e8);
    vm.assume(_usdtPrice > 0.1e8);
    uint256 _vp = 1.1e18;

    // mockCall to get_virtual_price
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_vp));
    vm.mockCall(
      address(curvePool), abi.encodeWithSelector(ICurvePool.gamma.selector), abi.encode(triCryptoOracle.GAMMA0())
    );
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.A.selector), abi.encode(triCryptoOracle.A0()));

    // mockCall to feed latestAnswers
    vm.mockCall(
      address(btcFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_btcPrice)
    );
    vm.mockCall(
      address(ethFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_ethPrice)
    );
    vm.mockCall(
      address(usdtFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_usdtPrice)
    );
    vm.mockCall(address(wbtcFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(1e8));

    uint256 _basePrices = (uint256(_btcPrice) * 1e10 * _ethPrice * 1e10 * _usdtPrice * 1e10);

    uint256 _maxPrice = (3 * _vp * FixedPointMathLib.cbrt(_basePrices)) / 1 ether;

    assertEq(triCryptoOracle.currentValue(), _maxPrice);
  }

  function testCurrentValueWbtcDepegDown(uint32 _btcPrice, uint32 _wbtcPrice) public {
    vm.assume(_wbtcPrice > 0.01e8 && _wbtcPrice < 1e8);
    vm.assume(_btcPrice > 0.1e8);
    uint256 _usdtPrice = 1e8;
    uint256 _ethPrice = 1000e8;
    uint256 _vp = 1.1e18;

    // mockCall to get_virtual_price
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_vp));
    vm.mockCall(
      address(curvePool), abi.encodeWithSelector(ICurvePool.gamma.selector), abi.encode(triCryptoOracle.GAMMA0())
    );
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.A.selector), abi.encode(triCryptoOracle.A0()));

    // mockCall to feed latestAnswers
    vm.mockCall(
      address(btcFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_btcPrice)
    );
    vm.mockCall(
      address(ethFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_ethPrice)
    );
    vm.mockCall(
      address(usdtFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_usdtPrice)
    );
    vm.mockCall(
      address(wbtcFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_wbtcPrice)
    );

    uint256 _minWbtc = (uint256(_btcPrice) * 1e10 * _wbtcPrice * 1e10) / 1e18;

    uint256 _basePrices = (_minWbtc * _ethPrice * 1e10 * _usdtPrice * 1e10);

    uint256 _maxPrice = (3 * _vp * FixedPointMathLib.cbrt(_basePrices)) / 1 ether;

    assertEq(triCryptoOracle.currentValue(), _maxPrice);
  }

  function testCurrentValueWbtcDepegUp(uint32 _btcPrice, uint32 _wbtcPrice) public {
    vm.assume(_wbtcPrice > 1e8);
    vm.assume(_btcPrice > 0.1e8);
    uint256 _usdtPrice = 1e8;
    uint256 _ethPrice = 1000e8;
    uint256 _vp = 1.1e18;

    // mockCall to get_virtual_price
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_vp));
    vm.mockCall(
      address(curvePool), abi.encodeWithSelector(ICurvePool.gamma.selector), abi.encode(triCryptoOracle.GAMMA0())
    );
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.A.selector), abi.encode(triCryptoOracle.A0()));

    // mockCall to feed latestAnswers
    vm.mockCall(
      address(btcFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_btcPrice)
    );
    vm.mockCall(
      address(ethFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_ethPrice)
    );
    vm.mockCall(
      address(usdtFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_usdtPrice)
    );
    vm.mockCall(
      address(wbtcFeed), abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector), abi.encode(_wbtcPrice)
    );
    uint256 _basePrices = (uint256(_btcPrice) * 1e10 * _ethPrice * 1e10 * _usdtPrice * 1e10);

    uint256 _maxPrice = (3 * _vp * FixedPointMathLib.cbrt(_basePrices)) / 1 ether;

    assertEq(triCryptoOracle.currentValue(), _maxPrice);
  }
}
