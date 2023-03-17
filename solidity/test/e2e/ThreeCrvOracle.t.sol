// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, IVault, console} from '@test/e2e/Common.sol';
import {IUSDA} from '@interfaces/core/IUSDA.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IThreeCRVForTest {
  function calc_token_amount(uint256[3] memory _amounts, bool _deposit) external view returns (uint256 _amount);
}

interface ICToken {
  function exchangeRateStored() external view returns (uint256 _exchangeRate);
}

contract E2EThreeCurveOracle is CommonE2EBase {
  ICToken public cUSD = ICToken(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
  ICToken public cDAI = ICToken(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
  IThreeCRVForTest public threeCrv;

  uint256 public constant ONE_PERCENT = 0.1e18;

  function setUp() public override {
    super.setUp();
    threeCrv = IThreeCRVForTest(address(threeCrvOracle.THREE_CRV()));
  }

  function testReturnsTheCorrectPrice() public {
    // Get the current value of the Three crv oracle
    uint256 _currentValue = threeCrvOracle.currentValue();

    // Check how many LP tokens it will take to withdraw _currentValue tokens (note that as usdt has 6 decimals we need to remove 12)
    // usdt is token 2 in the curve pool
    uint256[3] memory _amounts;
    _amounts[2] = _currentValue / 1e12;
    uint256 _lpAmountTaken1 = threeCrv.calc_token_amount(_amounts, false);

    // Check how many LP tokens it will take to withdraw _currentValue tokens (note that the token in curve is compound usdc so we need to calculate the exchange)
    // usdc is token 1 in the curve pool
    uint256 _usdcExchangeRate = cUSD.exchangeRateStored();
    uint256[3] memory _amounts2;
    _amounts2[1] = (((_currentValue) * 1e6) / _usdcExchangeRate);
    uint256 _lpAmountTaken2 = threeCrv.calc_token_amount(_amounts2, false);

    // Check how many LP tokens it will take to withdraw _currentValue tokens (note that the token in curve is compound dai so we need to calculate the exchange)
    // dai is token 0 in the curve pool
    uint256 _daiExchangeRate = cDAI.exchangeRateStored();
    uint256[3] memory _amounts3;
    _amounts3[0] = (((_currentValue) * 1e18) / _daiExchangeRate);
    uint256 _lpAmountTaken3 = threeCrv.calc_token_amount(_amounts3, false);

    // the current value should be close to 1 LP token with less than 0.1% difference
    assertApproxEqRel(_lpAmountTaken1, 1 ether, ONE_PERCENT);
    assertApproxEqRel(_lpAmountTaken2, 1 ether, ONE_PERCENT);
    assertApproxEqRel(_lpAmountTaken3, 1 ether, ONE_PERCENT);
  }
}
