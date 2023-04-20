// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestPlus, console} from 'solidity-utils/test/DSTestPlus.sol';
import {ThreeCrvOracle} from '@contracts/periphery/oracles/ThreeCrvOracle.sol';

import {ICurvePool} from '@interfaces/utils/ICurvePool.sol';
import {AggregatorV3Interface} from '@chainlink/interfaces/AggregatorV3Interface.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {ChainlinkStalePriceLib} from '@contracts/periphery/oracles/ChainlinkStalePriceLib.sol';

abstract contract Base is DSTestPlus {
  ThreeCrvOracle public threeCrvOracle;

  AggregatorV3Interface internal _mockAggregatorDai;
  AggregatorV3Interface internal _mockAggregatorUsdc;
  AggregatorV3Interface internal _mockAggregatorUsdt;

  ICurvePool internal _mockCurvePool;

  IOracleRelay.OracleType public oracleType = IOracleRelay.OracleType(0); // 0 == Chainlink

  function setUp() public virtual {
    // Deploy contract
    threeCrvOracle = new ThreeCrvOracle();

    _mockAggregatorDai = AggregatorV3Interface(mockContract(address(threeCrvOracle.DAI()), 'mockAggregatorDai'));
    _mockAggregatorUsdc = AggregatorV3Interface(mockContract(address(threeCrvOracle.USDC()), 'mockAggregatorUsdc'));
    _mockAggregatorUsdt = AggregatorV3Interface(mockContract(address(threeCrvOracle.USDT()), 'mockAggregatorUsdt'));

    _mockCurvePool = ICurvePool(mockContract(address(threeCrvOracle.THREE_CRV()), 'mockCurvePool'));

    vm.warp(block.timestamp + 365 days);
  }

  function _getMin(int256 _x, int256 _z) internal pure returns (int256 _min) {
    _min = _x >= _z ? _z : _x;
  }
}

contract UnitTestThreeCrvOracleType is Base {
  function testOracleType() public {
    assertEq(uint256(oracleType), uint256(threeCrvOracle.oracleType()));
  }
}

contract UnitTestThreeCrvCurrentValue is Base {
  function testThreeCrvCurrentValue(
    int256 _latestAnswerDai,
    int256 _latestAnswerUsdc,
    int256 _latestAnswerUsdt,
    uint256 _virtualPrice
  ) public {
    vm.assume(_latestAnswerDai > 0);
    vm.assume(_latestAnswerUsdc > 0);
    vm.assume(_latestAnswerUsdt > 0);

    uint256 _minStable = uint256(_getMin(_getMin(_latestAnswerDai, _latestAnswerUsdc), _latestAnswerUsdt));

    vm.assume(_virtualPrice < type(uint256).max / _minStable);

    uint256 _lpPrice = _virtualPrice * _minStable;

    vm.assume(_lpPrice > 1e8);

    vm.mockCall(
      address(_mockAggregatorDai),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerDai, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(_mockAggregatorUsdc),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerUsdc, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(_mockAggregatorUsdt),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerUsdt, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(_mockCurvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_virtualPrice)
    );

    uint256 _price = threeCrvOracle.currentValue();
    assertEq(_price, _lpPrice / 1e8);
  }

  function testThreeCrvCurrentValueRevertsOnDaiStale(
    int256 _latestAnswerDai,
    int256 _latestAnswerUsdc,
    int256 _latestAnswerUsdt,
    uint256 _virtualPrice
  ) public {
    vm.assume(_latestAnswerDai > 0);
    vm.assume(_latestAnswerUsdc > 0);
    vm.assume(_latestAnswerUsdt > 0);

    uint256 _minStable = uint256(_getMin(_getMin(_latestAnswerDai, _latestAnswerUsdc), _latestAnswerUsdt));

    vm.assume(_virtualPrice < type(uint256).max / _minStable);

    uint256 _lpPrice = _virtualPrice * _minStable;

    vm.assume(_lpPrice > 1e8);

    uint256 _daiStaleDelay = threeCrvOracle.daiStaleDelay();

    vm.mockCall(
      address(_mockAggregatorDai),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerDai, 0, block.timestamp - _daiStaleDelay - 1, 0)
    );

    vm.mockCall(
      address(_mockAggregatorUsdc),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerUsdc, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(_mockAggregatorUsdt),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerUsdt, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(_mockCurvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_virtualPrice)
    );

    vm.expectRevert(ChainlinkStalePriceLib.Chainlink_StalePrice.selector);
    threeCrvOracle.currentValue();
  }

  function testThreeCrvCurrentValueRevertsOnUsdcStale(
    int256 _latestAnswerDai,
    int256 _latestAnswerUsdc,
    int256 _latestAnswerUsdt,
    uint256 _virtualPrice
  ) public {
    vm.assume(_latestAnswerDai > 0);
    vm.assume(_latestAnswerUsdc > 0);
    vm.assume(_latestAnswerUsdt > 0);

    uint256 _minStable = uint256(_getMin(_getMin(_latestAnswerDai, _latestAnswerUsdc), _latestAnswerUsdt));

    vm.assume(_virtualPrice < type(uint256).max / _minStable);

    uint256 _lpPrice = _virtualPrice * _minStable;

    vm.assume(_lpPrice > 1e8);

    uint256 _usdcStaleDelay = threeCrvOracle.usdcStaleDelay();

    vm.mockCall(
      address(_mockAggregatorDai),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerDai, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(_mockAggregatorUsdc),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerUsdc, 0, block.timestamp - _usdcStaleDelay - 1, 0)
    );

    vm.mockCall(
      address(_mockAggregatorUsdt),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerUsdt, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(_mockCurvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_virtualPrice)
    );

    vm.expectRevert(ChainlinkStalePriceLib.Chainlink_StalePrice.selector);
    threeCrvOracle.currentValue();
  }

  function testThreeCrvCurrentValueRevertsOnUsdtStale(
    int256 _latestAnswerDai,
    int256 _latestAnswerUsdc,
    int256 _latestAnswerUsdt,
    uint256 _virtualPrice
  ) public {
    vm.assume(_latestAnswerDai > 0);
    vm.assume(_latestAnswerUsdc > 0);
    vm.assume(_latestAnswerUsdt > 0);

    uint256 _minStable = uint256(_getMin(_getMin(_latestAnswerDai, _latestAnswerUsdc), _latestAnswerUsdt));

    vm.assume(_virtualPrice < type(uint256).max / _minStable);

    uint256 _lpPrice = _virtualPrice * _minStable;

    vm.assume(_lpPrice > 1e8);

    uint256 _usdtStaleDelay = threeCrvOracle.usdtStaleDelay();

    vm.mockCall(
      address(_mockAggregatorDai),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerDai, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(_mockAggregatorUsdc),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerUsdc, 0, block.timestamp, 0)
    );

    vm.mockCall(
      address(_mockAggregatorUsdt),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(0, _latestAnswerUsdt, 0, block.timestamp - _usdtStaleDelay - 1, 0)
    );

    vm.mockCall(
      address(_mockCurvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_virtualPrice)
    );

    vm.expectRevert(ChainlinkStalePriceLib.Chainlink_StalePrice.selector);
    threeCrvOracle.currentValue();
  }
}

contract UnitSetDelays is Base {
  function testSetDaiDelayRevertsIfNotOwner(uint256 _daiDelay) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    threeCrvOracle.setDaiStaleDelay(_daiDelay);
  }

  function testSetUsdtDelayRevertsIfNotOwner(uint256 _usdtDelay) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    threeCrvOracle.setUsdtStaleDelay(_usdtDelay);
  }

  function testSetUsdcDelayRevertsIfNotOwner(uint256 _usdcDelay) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(newAddress());
    threeCrvOracle.setUsdcStaleDelay(_usdcDelay);
  }

  function testSetDaiDelay(uint256 _daiDelay) public {
    vm.assume(_daiDelay > 0);
    threeCrvOracle.setDaiStaleDelay(_daiDelay);
    assertEq(threeCrvOracle.daiStaleDelay(), _daiDelay);
  }

  function testSetUsdtDelay(uint256 _usdtDelay) public {
    vm.assume(_usdtDelay > 0);
    threeCrvOracle.setUsdtStaleDelay(_usdtDelay);
    assertEq(threeCrvOracle.usdtStaleDelay(), _usdtDelay);
  }

  function testSetUsdcDelay(uint256 _usdcDelay) public {
    vm.assume(_usdcDelay > 0);
    threeCrvOracle.setUsdcStaleDelay(_usdcDelay);
    assertEq(threeCrvOracle.usdcStaleDelay(), _usdcDelay);
  }

  function testSetDaiDelayRevertsIfZero() public {
    vm.expectRevert(ThreeCrvOracle.ThreeCrvOracle_ZeroAmount.selector);
    threeCrvOracle.setDaiStaleDelay(0);
  }

  function testSetUsdtDelayRevertsIfZero() public {
    vm.expectRevert(ThreeCrvOracle.ThreeCrvOracle_ZeroAmount.selector);
    threeCrvOracle.setUsdtStaleDelay(0);
  }

  function testSetUsdcDelayRevertsIfZero() public {
    vm.expectRevert(ThreeCrvOracle.ThreeCrvOracle_ZeroAmount.selector);
    threeCrvOracle.setUsdcStaleDelay(0);
  }
}
