// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestPlus, console} from 'solidity-utils/test/DSTestPlus.sol';
import {ThreeCrvOracle} from '@contracts/periphery/oracles/ThreeCrvOracle.sol';

import {ICurvePool} from '@interfaces/utils/ICurvePool.sol';
import {AggregatorInterface} from '@chainlink/interfaces/AggregatorInterface.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

abstract contract Base is DSTestPlus {
  ThreeCrvOracle public threeCrvOracle;

  AggregatorInterface internal _mockAggregatorDai;
  AggregatorInterface internal _mockAggregatorUsdc;
  AggregatorInterface internal _mockAggregatorUsdt;

  ICurvePool internal _mockCurvePool;

  IOracleRelay.OracleType public oracleType = IOracleRelay.OracleType(0); // 0 == Chainlink

  function setUp() public virtual {
    // Deploy contract
    threeCrvOracle = new ThreeCrvOracle();

    _mockAggregatorDai = AggregatorInterface(mockContract(address(threeCrvOracle.DAI()), 'mockAggregatorDai'));
    _mockAggregatorUsdc = AggregatorInterface(mockContract(address(threeCrvOracle.USDC()), 'mockAggregatorUsdc'));
    _mockAggregatorUsdt = AggregatorInterface(mockContract(address(threeCrvOracle.USDT()), 'mockAggregatorUsdt'));

    _mockCurvePool = ICurvePool(mockContract(address(threeCrvOracle.THREE_CRV()), 'mockCurvePool'));
  }

  function _getMin(int256 _x, int256 _z) internal view returns (int256 _min) {
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
      abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector),
      abi.encode(_latestAnswerDai)
    );
    vm.mockCall(
      address(_mockAggregatorUsdc),
      abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector),
      abi.encode(_latestAnswerUsdc)
    );
    vm.mockCall(
      address(_mockAggregatorUsdt),
      abi.encodeWithSelector(AggregatorInterface.latestAnswer.selector),
      abi.encode(_latestAnswerUsdt)
    );
    vm.mockCall(
      address(_mockCurvePool), abi.encodeWithSelector(ICurvePool.get_virtual_price.selector), abi.encode(_virtualPrice)
    );

    uint256 _price = threeCrvOracle.currentValue();
    assertEq(_price, _lpPrice / 1e8);
  }
}
