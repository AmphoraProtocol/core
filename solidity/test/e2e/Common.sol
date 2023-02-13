// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {console} from 'forge-std/console.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';

contract CommonE2EBase is DSTestPlus {
    uint256 constant FORK_BLOCK = 15452788;

    address user = label('user');
    address owner = label('owner');

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
    }
}
