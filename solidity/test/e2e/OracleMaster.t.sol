// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import '@test/e2e/Common.sol';

// TODO: These tests are not needed, since we are gonna remove the OracleMaster
contract E2EOracleMaster is CommonE2EBase {
    function setUp() public override {
        super.setUp();
    }

    function testEthPriceFromChainlinkRelay() public {
        uint256 anchorPrice = chainlinkEth.currentValue();
        assertGt(anchorPrice, 1000 * 1 ether);
        assertLt(anchorPrice, 10000 * 1 ether);
    }
}
