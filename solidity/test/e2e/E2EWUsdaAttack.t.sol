// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test, stdError} from 'forge-std/Test.sol';
import {USDA} from '@contracts/core/USDA.sol';
import {WUSDA} from '@contracts/core/WUSDA.sol';
import {ERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract SUSD is ERC20 {
  constructor() ERC20('SUSD', 'S') {}
}

contract TestWUSDAAttack is Test {
  address public susd;
  USDA public usda;
  WUSDA public wusda;

  function setUp() public {
    susd = address(new SUSD());
    usda = new USDA(IERC20(susd));
    wusda = new WUSDA(address(usda), 'WUSDA', 'WUSDA');
  }

  function testWUSDASandwichArbitrage() public {
    address _alice = makeAddr('Alice');
    address _bob = makeAddr('Bob');
    uint256 _depositAmt = 1 ether;

    // 1. Alice frontun to deposit
    vm.startPrank(_alice);
    deal(susd, _alice, _depositAmt);
    assertEq(IERC20(susd).balanceOf(_alice), _depositAmt);
    IERC20(susd).approve(address(usda), _depositAmt);
    usda.deposit(_depositAmt);
    usda.approve(address(wusda), _depositAmt);
    wusda.wrap(_depositAmt);
    vm.stopPrank();
    assertEq(IERC20(susd).balanceOf(_alice), 0);
    assertEq(IERC20(usda).balanceOf(_alice), 0);
    assertEq(IERC20(wusda).balanceOf(_alice), _depositAmt);

    // 2. Bob deposit
    vm.startPrank(_bob);
    deal(susd, _bob, _depositAmt);
    assertEq(IERC20(susd).balanceOf(_bob), _depositAmt);
    IERC20(susd).approve(address(usda), _depositAmt);
    usda.deposit(_depositAmt);
    usda.approve(address(wusda), _depositAmt);
    wusda.wrap(_depositAmt);
    vm.stopPrank();
    assertEq(IERC20(susd).balanceOf(_bob), 0);
    assertEq(IERC20(usda).balanceOf(_bob), 0);
    assertEq(IERC20(wusda).balanceOf(_bob), _depositAmt);

    // 3. Alice backrun to withdraw
    vm.startPrank(_alice);
    wusda.unwrap(wusda.balanceOf(_alice));
    usda.withdrawAll();
    vm.stopPrank();
    assertEq(IERC20(susd).balanceOf(_alice), _depositAmt);
    assertEq(IERC20(usda).balanceOf(_alice), 0);
    assertEq(IERC20(wusda).balanceOf(_alice), 0);

    // 4. Bob withdraw
    vm.startPrank(_bob);
    wusda.unwrap(wusda.balanceOf(_bob));
    usda.withdrawAll();
    vm.stopPrank();
    assertEq(IERC20(susd).balanceOf(_bob), _depositAmt);
    assertEq(IERC20(usda).balanceOf(_bob), 0);
    assertEq(IERC20(wusda).balanceOf(_bob), 0);
  }
}

// NOTE: https://media.dedaub.com/latent-bugs-in-billion-plus-dollar-code-c2e67a25b689
contract TestFrontrunningAttack is Test {
  address public susd;
  USDA public usda;
  WUSDA public wusda;

  function setUp() public {
    susd = address(new SUSD());
    usda = new USDA(IERC20(susd));
    wusda = new WUSDA(address(usda), 'WUSDA', 'WUSDA');
  }

  function testNotSuccessfullFrontrunning() public {
    address _alice = makeAddr('Alice');

    uint256 _oneWeiDeposit = 1;

    // 1. Alice is the first to deposit 1 wei
    vm.startPrank(_alice);
    deal(susd, _alice, _oneWeiDeposit);
    IERC20(susd).approve(address(usda), _oneWeiDeposit);
    usda.deposit(_oneWeiDeposit);
    usda.approve(address(wusda), _oneWeiDeposit);
    // Tx will revert because you need to mint more than 10000 wei
    vm.expectRevert(stdError.arithmeticError);
    wusda.wrap(_oneWeiDeposit);
    vm.stopPrank();
  }
}
