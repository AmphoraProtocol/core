// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {UniswapV3TokenOracleRelay} from '@contracts/periphery/oracles/UniswapV3TokenOracleRelay.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/oracles/ChainlinkOracleRelay.sol';
import {AnchoredViewRelay} from '@contracts/periphery/oracles/AnchoredViewRelay.sol';
import {StableCurveLpOracle} from '@contracts/periphery/oracles/StableCurveLpOracle.sol';
import {CreateOracles} from '@scripts/CreateOracles.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {ICurvePool} from '@interfaces/utils/ICurvePool.sol';

import {CommonE2EBase, console} from '@test/e2e/Common.sol';
import {TestConstants} from '@test/utils/TestConstants.sol';

contract E2ECurveLpOracle is TestConstants, CommonE2EBase {
  uint256 public constant POINT_ONE_PERCENT = 0.001e18;

  StableCurveLpOracle public fraxCrvOracle;
  StableCurveLpOracle public frax3CrvOracle;

  function setUp() public virtual override {
    super.setUp();
    /// Deploy FraxCrv oracle relay
    IOracleRelay _anchoredViewFrax = IOracleRelay(_createFraxOracle());
    /// Deploy usdc oracle relay
    IOracleRelay _anchoredViewUsdc = IOracleRelay(_createUsdcOracle());
    /// Deploy dai oracle relay
    IOracleRelay _anchoredViewDai = IOracleRelay(_createDaiOracle());
    /// Deploy usdt oracle relay
    IOracleRelay _anchoredViewUsdt = IOracleRelay(_createUsdtOracle());

    fraxCrvOracle =
      StableCurveLpOracle(_createFraxCrvOracle(FRAX_USDC_CRV_POOL_ADDRESS, _anchoredViewFrax, _anchoredViewUsdc));

    frax3CrvOracle = StableCurveLpOracle(
      _createFrax3CrvOracle(
        FRAX_3CRV_META_POOL_ADDRESS, _anchoredViewFrax, _anchoredViewDai, _anchoredViewUsdt, _anchoredViewUsdc
      )
    );
  }

  function testFraxCrvOracleReturnsTheCorrectPrice() public {
    assertGt(fraxCrvOracle.currentValue(), 0);
    assertEq(
      fraxCrvOracle.currentValue(),
      (fraxCrvOracle.anchoredUnderlyingTokens(0).currentValue() * fraxCrvOracle.CRV_POOL().get_virtual_price() / 1e18)
    );

    assertApproxEqRel(
      fraxCrvOracle.currentValue(),
      (fraxCrvOracle.anchoredUnderlyingTokens(1).currentValue() * fraxCrvOracle.CRV_POOL().get_virtual_price() / 1e18),
      POINT_ONE_PERCENT
    );
  }

  function test3CrvOracleReturnsTheCorrectPrice() public {
    assertGt(threeCrvOracle.currentValue(), 0);
    assertEq(
      threeCrvOracle.currentValue(),
      (threeCrvOracle.anchoredUnderlyingTokens(0).currentValue() * threeCrvOracle.CRV_POOL().get_virtual_price() / 1e18)
    );

    assertApproxEqRel(
      threeCrvOracle.currentValue(),
      (threeCrvOracle.anchoredUnderlyingTokens(1).currentValue() * threeCrvOracle.CRV_POOL().get_virtual_price() / 1e18),
      POINT_ONE_PERCENT
    );

    assertApproxEqRel(
      threeCrvOracle.currentValue(),
      (threeCrvOracle.anchoredUnderlyingTokens(2).currentValue() * threeCrvOracle.CRV_POOL().get_virtual_price() / 1e18),
      POINT_ONE_PERCENT
    );
  }

  function testFrax3CrvOracleReturnsTheCorrectPrice() public {
    assertGt(frax3CrvOracle.currentValue(), 0);
    assertEq(
      frax3CrvOracle.currentValue(),
      (frax3CrvOracle.anchoredUnderlyingTokens(0).currentValue() * frax3CrvOracle.CRV_POOL().get_virtual_price() / 1e18)
    );

    assertApproxEqRel(
      frax3CrvOracle.currentValue(),
      (frax3CrvOracle.anchoredUnderlyingTokens(1).currentValue() * frax3CrvOracle.CRV_POOL().get_virtual_price() / 1e18),
      POINT_ONE_PERCENT
    );

    assertApproxEqRel(
      frax3CrvOracle.currentValue(),
      (frax3CrvOracle.anchoredUnderlyingTokens(2).currentValue() * frax3CrvOracle.CRV_POOL().get_virtual_price() / 1e18),
      POINT_ONE_PERCENT
    );

    assertApproxEqRel(
      frax3CrvOracle.currentValue(),
      (frax3CrvOracle.anchoredUnderlyingTokens(3).currentValue() * frax3CrvOracle.CRV_POOL().get_virtual_price() / 1e18),
      POINT_ONE_PERCENT
    );
  }
}
