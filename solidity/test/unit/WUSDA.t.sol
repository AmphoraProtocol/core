// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {IWUSDA, WUSDA} from '@contracts/core/WUSDA.sol';
import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

abstract contract Base is DSTestPlus {
  event Wrapped(address indexed _from, uint256 _usdaAmount, uint256 _wusdaAmount);
  event Unwrapped(address indexed _from, uint256 _usdaAmount, uint256 _wusdaAmount);

  uint256 internal constant _DELTA = 100;

  address public usdaToken = newAddress();
  string public name = 'wUSDA Token';
  string public symbol = 'wUSDA';
  uint256 public usdaTotalSupply = 1_000_000 ether;
  WUSDA public wusda;

  function setUp() public virtual {
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    // solhint-disable-next-line reentrancy
    wusda = new WUSDA(usdaToken, name, symbol);
  }
}

contract UnitWUSDAViewFunctions is Base {
  function setUp() public override {
    super.setUp();
  }

  function testUSDAAddress() public {
    assertEq(wusda.USDA(), usdaToken);
  }

  function testBootstrapMint() public {
    assertEq(wusda.BOOTSTRAP_MINT(), 10_000);
  }

  function testGetWUsdaByUsdaWhenTotalWUSDAIsZero(uint256 _usdaAmount) public {
    vm.assume(_usdaAmount > 0);

    // There is not wUSDA in circulation, but I added some USDAs to the contract simulating someone sending them to the contract
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(usdaTotalSupply));

    uint256 _wusdaAmount = wusda.getWUsdaByUsda(_usdaAmount);
    assertEq(_wusdaAmount, _usdaAmount);
  }

  function testGetWUsdaByUsdaWhenTotalUSDAIsZero(uint256 _usdaAmount) public {
    vm.assume(_usdaAmount > 0);

    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    uint256 _wusdaAmount = wusda.getWUsdaByUsda(_usdaAmount);
    assertEq(_wusdaAmount, _usdaAmount);
  }

  function testGetWUsdaByUsdaWhenSuppliesAreNotZero(uint256 _usdaAmount) public {
    vm.assume(_usdaAmount > 0);
    vm.assume(_usdaAmount < type(uint256).max / usdaTotalSupply); // upper limit

    // wrap some
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
    wusda.wrap(usdaTotalSupply);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(usdaTotalSupply));

    uint256 _wusdaAmount = wusda.getWUsdaByUsda(_usdaAmount);
    assertEq(_wusdaAmount, _usdaAmount);
  }

  function testGetUsdaByWUsdaWhenTotalWUSDAIsZero(uint256 _wusdaAmount) public {
    vm.assume(_wusdaAmount > 0);

    // There is not wUSDA in circulation, but I added some USDAs to the contract simulating someone sending them to the contract
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(usdaTotalSupply));

    uint256 _usdaAmount = wusda.getUsdaByWUsda(_wusdaAmount);
    assertEq(0, _usdaAmount);
  }

  function testGetUsdaByWUsdaWhenTotalUSDAIsZero(uint256 _wusdaAmount) public {
    vm.assume(_wusdaAmount > 0);

    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    uint256 _usdaAmount = wusda.getUsdaByWUsda(_wusdaAmount);
    assertEq(0, _usdaAmount);
  }

  function testGetUsdaByWUsdaWhenSuppliesAreNotZero(uint256 _wusdaAmount) public {
    vm.assume(_wusdaAmount > 0);
    vm.assume(_wusdaAmount < type(uint256).max / usdaTotalSupply); // upper limit

    // wrap some
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
    wusda.wrap(usdaTotalSupply);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(usdaTotalSupply));

    uint256 _usdaAmount = wusda.getUsdaByWUsda(_wusdaAmount);
    assertEq(_usdaAmount, _wusdaAmount);
  }

  function testEquivalenceBetweenConversions(uint256 _usdaAmount, uint256 _wusdaAmount) public {
    vm.assume(_usdaAmount > 0);
    vm.assume(_wusdaAmount > 0);
    vm.assume(_usdaAmount < type(uint256).max / usdaTotalSupply); // upper limit
    vm.assume(_wusdaAmount < type(uint256).max / usdaTotalSupply); // upper limit

    // wrap some
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
    wusda.wrap(usdaTotalSupply);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(usdaTotalSupply));

    uint256 _usdaAmount2 = wusda.getUsdaByWUsda(wusda.getWUsdaByUsda(_usdaAmount));
    assertEq(_usdaAmount, _usdaAmount2);

    uint256 _wusdaAmount2 = wusda.getWUsdaByUsda(wusda.getUsdaByWUsda(_wusdaAmount));
    assertEq(_wusdaAmount, _wusdaAmount2);
  }

  function testUsdaPerToken() public {
    // wrap some
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
    wusda.wrap(usdaTotalSupply);
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(usdaTotalSupply));

    uint256 _usdaPerToken = wusda.usdaPerToken();
    assertEq(_usdaPerToken, 1 ether);
  }

  function testTokensPerUsda() public {
    // There is not wUSDA in circulation, but I added some USDAs to the contract simulating someone sending them to the contract
    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(usdaTotalSupply));

    uint256 _tokensPerUsda = wusda.tokensPerUsda();
    assertEq(_tokensPerUsda, 1 ether);
  }
}

contract UnitWUSDAWrap is Base {
  function setUp() public override {
    super.setUp();

    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(usdaTotalSupply));
  }

  function testWrapAddsToTotalSupply(uint256 _amount) public {
    vm.assume(_amount > wusda.BOOTSTRAP_MINT());

    wusda.wrap(_amount);
    assertEq(wusda.totalSupply(), _amount);
  }

  function testWrapAddsToUserBalance(uint256 _amount) public {
    vm.assume(_amount > wusda.BOOTSTRAP_MINT());

    wusda.wrap(_amount);
    assertEq(wusda.balanceOf(address(this)), _amount - wusda.BOOTSTRAP_MINT());
  }

  function testRevertWhenSendingZeroAmount() public {
    vm.expectRevert(IWUSDA.WUsda_ZeroAmount.selector);
    wusda.wrap(0);
  }

  function testWrapCallsTransferFromOnUser(uint256 _amount) public {
    vm.assume(_amount > wusda.BOOTSTRAP_MINT());

    vm.expectCall(
      usdaToken,
      abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(wusda), wusda.getWUsdaByUsda(_amount))
    );
    wusda.wrap(_amount);
  }

  function testWrapWorksWithMoreWrappedMintedThanZero(uint256 _amount) public {
    vm.assume(_amount > wusda.BOOTSTRAP_MINT());
    vm.assume(_amount < type(uint256).max / wusda.BOOTSTRAP_MINT());

    // wrap some
    vm.prank(newAddress());
    wusda.wrap(wusda.BOOTSTRAP_MINT());

    // wrap some more
    wusda.wrap(_amount);
    assertEq(wusda.balanceOf(address(this)), (_amount * wusda.BOOTSTRAP_MINT()) / usdaTotalSupply);
  }

  function testEmitEvent(uint256 _amount) public {
    vm.assume(_amount > wusda.BOOTSTRAP_MINT());

    vm.expectEmit(true, true, false, true);
    emit Wrapped(address(this), wusda.getWUsdaByUsda(_amount), _amount - wusda.BOOTSTRAP_MINT());

    wusda.wrap(_amount);
  }
}

contract UnitWUSDAUnwrap is Base {
  uint256 public wusdaMinted = 100_000 ether;

  function setUp() public override {
    super.setUp();

    vm.mockCall(usdaToken, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(usdaTotalSupply));

    wusda.wrap(wusdaMinted);
  }

  function testUnwrapSubtractsFromTotalSupply(uint256 _amount) public {
    vm.assume(_amount <= wusdaMinted - wusda.BOOTSTRAP_MINT());
    vm.assume(_amount > wusda.BOOTSTRAP_MINT());

    wusda.unwrap(_amount);
    assertEq(wusda.totalSupply(), wusdaMinted - _amount);
  }

  function testUnwrapSubtractsFromUserBalance(uint256 _amount) public {
    vm.assume(_amount <= wusdaMinted - wusda.BOOTSTRAP_MINT());
    vm.assume(_amount > wusda.BOOTSTRAP_MINT());

    wusda.unwrap(_amount);
    assertEq(wusda.balanceOf(address(this)), wusdaMinted - _amount - wusda.BOOTSTRAP_MINT());
  }

  function testUnwrapCallsTransferToUser(uint256 _amount) public {
    vm.assume(_amount <= wusdaMinted - wusda.BOOTSTRAP_MINT());
    vm.assume(_amount > wusda.BOOTSTRAP_MINT());

    vm.expectCall(
      usdaToken, abi.encodeWithSelector(IERC20.transfer.selector, address(this), wusda.getUsdaByWUsda(_amount))
    );
    wusda.unwrap(_amount);
  }

  function testEmitEvent(uint256 _amount) public {
    vm.assume(_amount <= wusdaMinted - wusda.BOOTSTRAP_MINT());
    vm.assume(_amount > wusda.BOOTSTRAP_MINT());

    vm.expectEmit(true, true, false, true);
    emit Unwrapped(address(this), wusda.getUsdaByWUsda(_amount), _amount);

    wusda.unwrap(_amount);
  }
}
