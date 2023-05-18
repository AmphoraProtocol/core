// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {ICToken} from '@interfaces/periphery/ICToken.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {CTokenOracle} from '@contracts/periphery/oracles/CTokenOracle.sol';
import {AnchoredViewRelay} from '@contracts/periphery/oracles/AnchoredViewRelay.sol';

abstract contract Base is DSTestPlus {
  CTokenOracle public cTokenOracle;

  ICToken internal _cToken;
  AnchoredViewRelay internal _underlyingAnchoredView;
  IERC20Metadata internal _underlying;

  function setUp() public virtual {
    _cToken = ICToken(mockContract(newAddress(), 'mockCToken'));
    _underlyingAnchoredView = AnchoredViewRelay(mockContract(newAddress(), 'mockUnderlyingAnchoredView'));
    _underlying = IERC20Metadata(mockContract(newAddress(), 'mockUnderlying'));

    vm.mockCall(address(_cToken), abi.encodeWithSelector(ICToken.underlying.selector), abi.encode(address(_underlying)));
    vm.mockCall(address(_cToken), abi.encodeWithSelector(ICToken.decimals.selector), abi.encode(uint8(8)));
    vm.mockCall(address(_underlying), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(uint8(6)));

    cTokenOracle = new CTokenOracle(address(_cToken), address(_underlyingAnchoredView));
  }
}

contract UnitCTokenOracleContructor is Base {
  function testCTokenOracleConstructorWhenUnderlyingIsUSDC() public {
    assert(address(cTokenOracle.cToken()) == address(_cToken));
    assert(address(cTokenOracle.anchoredViewUnderlying()) == address(_underlyingAnchoredView));
    assert(cTokenOracle.div() == 10 ** (18 - 8 + 6));
  }

  function testCTokenOracleConstructorWhenUnderlyingIsETH() public {
    _cToken = ICToken(mockContract(cTokenOracle.cETH_ADDRESS(), 'mockCToken'));
    vm.mockCall(address(_cToken), abi.encodeWithSelector(ICToken.decimals.selector), abi.encode(uint8(8)));

    cTokenOracle = new CTokenOracle(address(_cToken), address(_underlyingAnchoredView));

    assert(address(cTokenOracle.cToken()) == address(_cToken));
    assert(address(cTokenOracle.anchoredViewUnderlying()) == address(_underlyingAnchoredView));
    assert(cTokenOracle.div() == 10 ** (18 - 8 + 18));
  }
}

contract UnitCTokenOracleCurrentValue is Base {
  function testCTokenOracleCurrentValue(uint256 _exchangeRateStored, uint256 _anchoredViewValue) public {
    vm.assume(_exchangeRateStored > 0);
    vm.assume(_anchoredViewValue > 0);
    vm.assume(_anchoredViewValue <= type(uint256).max / _exchangeRateStored);
    vm.assume(_anchoredViewValue * _exchangeRateStored > cTokenOracle.div());

    vm.mockCall(
      address(_cToken), abi.encodeWithSelector(ICToken.exchangeRateStored.selector), abi.encode(_exchangeRateStored)
    );
    vm.mockCall(
      address(_underlyingAnchoredView),
      abi.encodeWithSelector(IOracleRelay.currentValue.selector),
      abi.encode(_anchoredViewValue)
    );

    assertEq(cTokenOracle.currentValue(), _exchangeRateStored * _anchoredViewValue / cTokenOracle.div());
  }
}

contract UnitCTokenOracleChangeAnchoredView is Base {
  function testCTokenOracleChangeAnchoredViewRevertWhenCalledByNonOwner(address _caller) public {
    vm.assume(_caller != cTokenOracle.owner());

    vm.prank(_caller);
    vm.expectRevert('Ownable: caller is not the owner');
    cTokenOracle.changeAnchoredView(address(0));
  }

  function testCTokenOracleChangeAnchoredView(address _newAnchoredView) public {
    vm.assume(_newAnchoredView != address(_underlyingAnchoredView));

    vm.prank(cTokenOracle.owner());
    cTokenOracle.changeAnchoredView(_newAnchoredView);

    assertEq(address(cTokenOracle.anchoredViewUnderlying()), _newAnchoredView);
  }
}
