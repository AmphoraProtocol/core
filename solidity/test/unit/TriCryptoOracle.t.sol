// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {WUSDA} from '@contracts/core/WUSDA.sol';
import {TriCryptoOracle} from '@contracts/periphery/oracles/TriCryptoOracle.sol';

import {ICurvePool} from '@interfaces/utils/ICurvePool.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {AggregatorInterface} from '@chainlink/interfaces/AggregatorInterface.sol';
import {FixedPointMathLib} from 'solady/utils/FixedPointMathLib.sol';
import {AggregatorV3Interface} from '@chainlink/interfaces/AggregatorV3Interface.sol';
import {ChainlinkStalePriceLib} from '@contracts/periphery/oracles/ChainlinkStalePriceLib.sol';

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

    vm.warp(block.timestamp + 365 days);
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
      address(btcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _btcPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(ethFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _ethPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _usdtPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(wbtcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 1e8, 0, block.timestamp, 0)
    );

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
      address(btcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _btcPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(ethFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _ethPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _usdtPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(wbtcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _wbtcPrice, 0, block.timestamp, 0)
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
      address(btcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _btcPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(ethFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _ethPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _usdtPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(wbtcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _wbtcPrice, 0, block.timestamp, 0)
    );

    uint256 _basePrices = (uint256(_btcPrice) * 1e10 * _ethPrice * 1e10 * _usdtPrice * 1e10);

    uint256 _maxPrice = (3 * _vp * FixedPointMathLib.cbrt(_basePrices)) / 1 ether;

    assertEq(triCryptoOracle.currentValue(), _maxPrice);
  }

  function testCurrentValueWhenBtcPriceStale(uint32 _btcPrice) public {
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

    uint256 _btcStaleDelay = triCryptoOracle.btcStaleDelay();

    // mockCall to feed latestAnswers
    vm.mockCall(
      address(btcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _btcPrice, 0, block.timestamp - _btcStaleDelay - 1, 0)
    );

    vm.mockCall(
      address(ethFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _ethPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _usdtPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(wbtcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 1e8, 0, block.timestamp, 0)
    );

    uint256 _basePrices = (uint256(_btcPrice) * 1e10 * _ethPrice * 1e10 * _usdtPrice * 1e10);

    uint256 _maxPrice = (3 * _vp * FixedPointMathLib.cbrt(_basePrices)) / 1 ether;

    assertEq(triCryptoOracle.currentValue(), _maxPrice);
  }

  function testCurrentValueRevertsWhenEthPriceStale(uint32 _ethPrice) public {
    vm.assume(_ethPrice > 0.1e8);
    uint256 _usdtPrice = 1e8;
    uint256 _btcPrice = 0.1e8;
    uint256 _vp = 1.1e18;

    // mockCall to get_virtual_price
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_vp));
    vm.mockCall(
      address(curvePool), abi.encodeWithSelector(ICurvePool.gamma.selector), abi.encode(triCryptoOracle.GAMMA0())
    );
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.A.selector), abi.encode(triCryptoOracle.A0()));

    uint256 _ethStaleDelay = triCryptoOracle.ethStaleDelay();

    // mockCall to feed latestAnswers
    vm.mockCall(
      address(btcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _btcPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(ethFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _ethPrice, 0, block.timestamp - _ethStaleDelay - 1, 0)
    );

    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _usdtPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(wbtcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 1e8, 0, block.timestamp, 0)
    );

    uint256 _basePrices = (uint256(_btcPrice) * 1e10 * _ethPrice * 1e10 * _usdtPrice * 1e10);

    uint256 _maxPrice = (3 * _vp * FixedPointMathLib.cbrt(_basePrices)) / 1 ether;

    assertEq(triCryptoOracle.currentValue(), _maxPrice);
  }

  function testCurrentValueWhenUsdtPriceStale(uint32 _usdtPrice) public {
    vm.assume(_usdtPrice > 0.1e8);
    uint256 _btcPrice = 0.1e8;
    uint256 _ethPrice = 1000e8;
    uint256 _vp = 1.1e18;

    // mockCall to get_virtual_price
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_vp));
    vm.mockCall(
      address(curvePool), abi.encodeWithSelector(ICurvePool.gamma.selector), abi.encode(triCryptoOracle.GAMMA0())
    );
    vm.mockCall(address(curvePool), abi.encodeWithSelector(ICurvePool.A.selector), abi.encode(triCryptoOracle.A0()));

    uint256 _usdtStaleDelay = triCryptoOracle.usdtStaleDelay();

    // mockCall to feed latestAnswers
    vm.mockCall(
      address(btcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _btcPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(ethFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _ethPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _usdtPrice, 0, block.timestamp - _usdtStaleDelay - 1, 0)
    );

    vm.mockCall(
      address(wbtcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 1e8, 0, block.timestamp, 0)
    );

    uint256 _basePrices = (uint256(_btcPrice) * 1e10 * _ethPrice * 1e10 * _usdtPrice * 1e10);

    uint256 _maxPrice = (3 * _vp * FixedPointMathLib.cbrt(_basePrices)) / 1 ether;

    assertEq(triCryptoOracle.currentValue(), _maxPrice);
  }

  function testCurrentValueRevertsWhenWbtcPriceStale(uint32 _btcPrice, uint32 _ethPrice, uint32 _usdtPrice) public {
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

    uint256 _wbtcStaleDelay = triCryptoOracle.wbtcStaleDelay();

    // mockCall to feed latestAnswers
    vm.mockCall(
      address(btcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _btcPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(ethFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _ethPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _usdtPrice, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(wbtcFeed),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, 1e8, 0, block.timestamp - _wbtcStaleDelay - 1, 0)
    );

    uint256 _basePrices = (uint256(_btcPrice) * 1e10 * _ethPrice * 1e10 * _usdtPrice * 1e10);

    uint256 _maxPrice = (3 * _vp * FixedPointMathLib.cbrt(_basePrices)) / 1 ether;

    assertEq(triCryptoOracle.currentValue(), _maxPrice);
  }
}

contract UnitSetDelays is Base {
  function testSetBtcDelayRevertsIfNotOwner(uint256 _btcDelay) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    triCryptoOracle.setBtcStaleDelay(_btcDelay);
  }

  function testSetEthDelayRevertsIfNotOwner(uint256 _ethDelay) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    triCryptoOracle.setEthStaleDelay(_ethDelay);
  }

  function testSetUsdtDelayRevertsIfNotOwner(uint256 _usdtDelay) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    triCryptoOracle.setUsdtStaleDelay(_usdtDelay);
  }

  function testSetWbtcDelayRevertsIfNotOwner(uint256 _wbtcDelay) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    triCryptoOracle.setWbtcStaleDelay(_wbtcDelay);
  }

  function testSetBtcDelay(uint256 _btcDelay) public {
    vm.assume(_btcDelay > 0);
    triCryptoOracle.setBtcStaleDelay(_btcDelay);
    assertEq(triCryptoOracle.btcStaleDelay(), _btcDelay);
  }

  function testSetEthDelay(uint256 _ethDelay) public {
    vm.assume(_ethDelay > 0);
    triCryptoOracle.setEthStaleDelay(_ethDelay);
    assertEq(triCryptoOracle.ethStaleDelay(), _ethDelay);
  }

  function testSetUsdtDelay(uint256 _usdtDelay) public {
    vm.assume(_usdtDelay > 0);
    triCryptoOracle.setUsdtStaleDelay(_usdtDelay);
    assertEq(triCryptoOracle.usdtStaleDelay(), _usdtDelay);
  }

  function testSetWbtcDelay(uint256 _wbtcDelay) public {
    vm.assume(_wbtcDelay > 0);
    triCryptoOracle.setWbtcStaleDelay(_wbtcDelay);
    assertEq(triCryptoOracle.wbtcStaleDelay(), _wbtcDelay);
  }

  function testSetBtcDelayRevertsIfZero() public {
    vm.expectRevert(TriCryptoOracle.TriCryptoOracle_ZeroAmount.selector);
    triCryptoOracle.setBtcStaleDelay(0);
  }

  function testSetEthDelayRevertsIfZero() public {
    vm.expectRevert(TriCryptoOracle.TriCryptoOracle_ZeroAmount.selector);
    triCryptoOracle.setEthStaleDelay(0);
  }

  function testSetUsdtDelayRevertsIfZero() public {
    vm.expectRevert(TriCryptoOracle.TriCryptoOracle_ZeroAmount.selector);
    triCryptoOracle.setUsdtStaleDelay(0);
  }

  function testSetWbtcDelayRevertsIfZero() public {
    vm.expectRevert(TriCryptoOracle.TriCryptoOracle_ZeroAmount.selector);
    triCryptoOracle.setWbtcStaleDelay(0);
  }
}
