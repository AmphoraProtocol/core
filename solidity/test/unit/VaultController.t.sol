// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {VaultController} from '@contracts/core/VaultController.sol';
import {UniswapV3OracleRelay} from '@contracts/periphery/UniswapV3OracleRelay.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/ChainlinkOracleRelay.sol';
import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';
import {AnchoredViewRelay} from '@contracts/periphery/AnchoredViewRelay.sol';
import {USDA} from '@contracts/core/USDA.sol';

import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

import {console} from 'forge-std/console.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
import {TestConstants} from '@test/utils/TestConstants.sol';

abstract contract Base is DSTestPlus, TestConstants {
  address public governance = label(newAddress(), 'governance');
  address public alice = label(newAddress(), 'alice');
  VaultController public vaultController;
  UniswapV3OracleRelay public uniswapRelayEthUsdc;
  ChainlinkOracleRelay public chainlinkEth;
  AnchoredViewRelay public anchoredViewEth;
  USDA public usdaToken;

  function setUp() public virtual {
    vm.startPrank(governance);
    vaultController = new VaultController();
    vaultController.initialize();

    usdaToken = new USDA();
    usdaToken.initialize(SUSD_ADDRESS);

    vaultController.registerUSDA(address(usdaToken));

    usdaToken.setPauser(governance);

    // Deploy uniswapRelayEthUsdc oracle relay
    uniswapRelayEthUsdc = new UniswapV3OracleRelay(60, USDC_WETH_POOL_ADDRESS, true, 1_000_000_000_000, 1);

    // Deploy chainlinkEth oracle relay
    chainlinkEth = new ChainlinkOracleRelay(CHAINLINK_ETH_FEED_ADDRESS, 10_000_000_000, 1);

    // Deploy anchoredViewEth relay
    anchoredViewEth = new AnchoredViewRelay(address(uniswapRelayEthUsdc), address(chainlinkEth), 10, 100);
    vm.stopPrank();
  }
}

contract UnitVaultControllerInitialize is Base {
  function testInitializedCorrectly() public {
    assertEq(vaultController.lastInterestTime(), block.timestamp);
    assertEq(vaultController.interestFactor(), 1e18);
    assertEq(vaultController.protocolFee(), 1e14);
    assertEq(vaultController.vaultsMinted(), 0);
    assertEq(vaultController.tokensRegistered(), 0);
    assertEq(vaultController.totalBaseLiability(), 0);
  }
}

contract UnitVaultControllerMintVault is Base {
  function testRevertIfPaused() public {
    vm.startPrank(governance);
    vaultController.pause();
    vm.stopPrank();

    vm.expectRevert('Pausable: paused');
    vaultController.mintVault();
  }

  function testMintVault() public {
    address _vault = vaultController.mintVault();
    assertEq(vaultController.vaultsMinted(), 1);
    assertEq(vaultController.vaultAddress(1), _vault);
  }
}

contract UnitVaultControllerRegisterUSDA is Base {
  function testRevertIfRegisterFromNonOwner(address _USDA) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.registerUSDA(_USDA);
  }

  function testRegisterUSDA(address _USDA) public {
    vm.prank(governance);
    vaultController.registerUSDA(_USDA);
    assertEq(address(vaultController.usda()), _USDA);
  }
}

contract UnitVaultControllerChangeProtocolFee is Base {
  event NewProtocolFee(uint192 _newFee);

  function testRevertIfChangeFromNonOwner(uint192 _newFee) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.changeProtocolFee(_newFee);
  }

  function testRevertIfFeeIsTooHigh(uint192 _newFee) public {
    vm.assume(_newFee > 1 ether);
    vm.expectRevert(IVaultController.VaultController_FeeTooLarge.selector);
    vm.prank(governance);
    vaultController.changeProtocolFee(_newFee);
  }

  function testChangeProtocolFee(uint192 _protocolFee) public {
    vm.assume(_protocolFee < 1 ether);
    vm.expectEmit(false, false, false, true);
    emit NewProtocolFee(_protocolFee);

    vm.prank(governance);
    vaultController.changeProtocolFee(_protocolFee);
    assertEq(vaultController.protocolFee(), _protocolFee);
  }
}

contract UnitVaultControllerRegisterCurveMaster is Base {
  event RegisterCurveMaster(address _curveMasterAddress);

  CurveMaster public curveMaster;

  function setUp() public virtual override {
    super.setUp();
    vm.prank(governance);
    curveMaster = new CurveMaster();
  }

  function testRevertIfRegisterFromNonOwner() public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.registerCurveMaster(address(curveMaster));
  }

  function testRegisterCurveMaster() public {
    vm.expectEmit(false, false, false, true);
    emit RegisterCurveMaster(address(curveMaster));
    vm.prank(governance);
    vaultController.registerCurveMaster(address(curveMaster));
    assertEq(address(vaultController.curveMaster()), address(curveMaster));
  }
}

contract UnitVaultControllerRegisterERC20 is Base {
  event RegisteredErc20(address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive);

  function testRevertIfRegisterFromNonOwner(IERC20 _token, address _oracle, uint256 _ltv, uint256 _liquidationIncentive) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.registerErc20(address(_token), _ltv, _oracle, _liquidationIncentive);
  }

  function testRevertIfTokenAlreadyRegistered(IERC20 _token, address _oracle, uint64 _ltv) public {
    vm.assume(_ltv < 0.95 ether);
    // Register WETH as acceptable erc20 collateral to vault controller and set oracle
    vm.prank(governance);
    vaultController.registerErc20(address(_token), _ltv, _oracle, LIQUIDATION_INCENTIVE);
    vm.expectRevert(IVaultController.VaultController_TokenAlreadyRegistered.selector);
    // Try to register the same again
    vm.prank(governance);
    vaultController.registerErc20(address(_token), _ltv, _oracle, LIQUIDATION_INCENTIVE);
  }

  function testRevertIfIncompatibleLTV(IERC20 _token, address _oracle, uint64 _liquidationIncentive) public {
    vm.assume(_liquidationIncentive < 1 ether && _liquidationIncentive > 0.2 ether);
    vm.expectRevert(IVaultController.VaultController_LTVIncompatible.selector);
    vm.prank(governance);
    vaultController.registerErc20(address(_token), WETH_LTV, _oracle, _liquidationIncentive);
  }

  function testRegisterERC20(IERC20 _token, address _oracle) public {
    vm.expectEmit(false, false, false, true);
    emit RegisteredErc20(address(_token), WETH_LTV, _oracle, LIQUIDATION_INCENTIVE);

    vm.prank(governance);
    vaultController.registerErc20(address(_token), WETH_LTV, _oracle, LIQUIDATION_INCENTIVE);
    assertEq(address(vaultController.tokenOracle(address(_token))), _oracle);
    assertEq(vaultController.tokensRegistered(), 1);
    assertEq(vaultController.tokenId(address(_token)), 1);
    assertEq(vaultController.tokenIdTokenLTV(1), WETH_LTV);
    assertEq(vaultController.tokenAddressLiquidationIncentive(address(_token)), LIQUIDATION_INCENTIVE);
  }
}

contract UnitVaultControllerUpdateERC20 is Base {
  event UpdateRegisteredErc20(address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive);

  function setUp() public virtual override {
    super.setUp();
    vm.prank(governance);
    vaultController.registerErc20(WETH_ADDRESS, WETH_LTV, address(anchoredViewEth), LIQUIDATION_INCENTIVE);
  }

  function testRevertIfUpdateFromNonOwner(IERC20 _token, address _oracle, uint64 _ltv, uint256 _liquidationIncentive) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.updateRegisteredErc20(address(_token), _ltv, _oracle, _liquidationIncentive);
  }

  function testRevertIfTokenNotRegistered(IERC20 _token, address _oracle, uint64 _ltv) public {
    vm.assume(_ltv < 0.95 ether && address(_token) != WETH_ADDRESS);
    vm.expectRevert(IVaultController.VaultController_TokenNotRegistered.selector);
    // Try to update a non registered token
    vm.prank(governance);
    vaultController.updateRegisteredErc20(address(_token), _ltv, _oracle, LIQUIDATION_INCENTIVE);
  }

  function testRevertIfIncompatibleLTV(address _oracle, uint64 _liquidationIncentive) public {
    vm.assume(_liquidationIncentive < 1 ether && _liquidationIncentive > 0.2 ether);
    vm.expectRevert(IVaultController.VaultController_LTVIncompatible.selector);
    vm.prank(governance);
    vaultController.updateRegisteredErc20(WETH_ADDRESS, WETH_LTV, _oracle, _liquidationIncentive);
  }

  function testUpdateERC20(address _oracle, uint256 _ltv) public {
    vm.assume(_ltv < 0.95 ether);
    vm.expectEmit(false, false, false, true);
    emit UpdateRegisteredErc20(WETH_ADDRESS, _ltv, _oracle, LIQUIDATION_INCENTIVE);

    vm.prank(governance);
    vaultController.updateRegisteredErc20(WETH_ADDRESS, _ltv, _oracle, LIQUIDATION_INCENTIVE);
    assertEq(address(vaultController.tokenOracle(WETH_ADDRESS)), _oracle);
    assertEq(vaultController.tokenIdTokenLTV(1), _ltv);
    assertEq(vaultController.tokenAddressLiquidationIncentive(WETH_ADDRESS), LIQUIDATION_INCENTIVE);
  }
}
