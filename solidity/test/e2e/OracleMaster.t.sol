// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase} from '@test/e2e/Common.sol';

// TODO: These tests are not needed, since we are gonna remove the OracleMaster
contract E2EOracleMaster is CommonE2EBase {
  function setUp() public override {
    super.setUp();
  }

  function testEthPriceFromChainlinkRelay() public {
    uint256 _anchorPrice = chainlinkEth.currentValue();
    assertGt(_anchorPrice, 1000 * 1 ether);
    assertLt(_anchorPrice, 10_000 * 1 ether);
  }
}
