// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {VaultController} from '@contracts/core/VaultController.sol';
import {VaultDeployer} from '@contracts/core/VaultDeployer.sol';
import {Vault} from '@contracts/core/Vault.sol';
import {UniswapV3OracleRelay} from '@contracts/periphery/UniswapV3OracleRelay.sol';
import {ChainlinkOracleRelay} from '@contracts/periphery/ChainlinkOracleRelay.sol';
import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';
import {AnchoredViewRelay} from '@contracts/periphery/AnchoredViewRelay.sol';
import {USDA} from '@contracts/core/USDA.sol';
import {ThreeLines0_100} from '@contracts/utils/ThreeLines0_100.sol';
import {ExponentialNoError} from '@contracts/utils/ExponentialNoError.sol';

import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {IAnchoredViewRelay} from '@interfaces/periphery/IAnchoredViewRelay.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IUSDA} from '@interfaces/core/IUSDA.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IBooster} from '@interfaces/utils/IBooster.sol';
import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {IVaultDeployer} from '@interfaces/core/IVaultDeployer.sol';

import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
import {TestConstants} from '@test/utils/TestConstants.sol';

contract VaultControllerForTest is VaultController {
  function migrateCollateralsFrom(IVaultController _oldVaultController, address[] memory _tokenAddresses) public {
    _migrateCollateralsFrom(_oldVaultController, _tokenAddresses);
  }

  function getVault(uint96 _id) public view returns (IVault _vault) {
    _vault = _getVault(_id);
  }
}

abstract contract Base is DSTestPlus, TestConstants {
  address public governance = label(newAddress(), 'governance');
  address public alice = label(newAddress(), 'alice');
  address public vaultOwner = label(newAddress(), 'vaultOwner');

  IERC20 public mockToken = IERC20(mockContract(newAddress(), 'mockToken'));
  IAMPHClaimer public mockAmphClaimer = IAMPHClaimer(mockContract(newAddress(), 'mockAmphClaimer'));
  VaultController public vaultController;
  VaultControllerForTest public mockVaultController;
  VaultDeployer public vaultDeployer;
  USDA public usdaToken;
  CurveMaster public curveMaster;
  ThreeLines0_100 public threeLines;

  UniswapV3OracleRelay public uniswapRelayEthUsdc;
  UniswapV3OracleRelay public uniswapRelayUniUsdc;
  ChainlinkOracleRelay public chainlinkEth;
  ChainlinkOracleRelay public chainLinkUni;
  AnchoredViewRelay public anchoredViewEth;
  AnchoredViewRelay public anchoredViewUni;

  uint256 public cap = 100 ether;

  function setUp() public virtual {
    address[] memory _tokens = new address[](1);
    vm.startPrank(governance);
    vaultController = new VaultController();
    vaultDeployer = new VaultDeployer(IVaultController(address(vaultController)));
    vaultController.initialize(IVaultController(address(0)), _tokens, mockAmphClaimer, vaultDeployer);

    curveMaster = new CurveMaster();
    threeLines = new ThreeLines0_100(2 ether, 0.05 ether, 0.045 ether, 0.5 ether, 0.55 ether);

    vaultController.registerCurveMaster(address(curveMaster));
    curveMaster.setCurve(address(0), address(threeLines));

    usdaToken = new USDA();
    usdaToken.initialize(address(mockToken));

    vaultController.registerUSDA(address(usdaToken));

    usdaToken.setPauser(governance);
    usdaToken.addVaultController(address(vaultController));

    // Deploy uniswapRelayEthUsdc & uniswapRelayUniUsdc oracle relay
    uniswapRelayEthUsdc = new UniswapV3OracleRelay(60, USDC_WETH_POOL_ADDRESS, true, 1_000_000_000_000, 1);
    uniswapRelayUniUsdc = new UniswapV3OracleRelay(60, USDC_UNI_POOL_ADDRESS, false, 1_000_000_000_000, 1);

    // Deploy chainlinkEth oracle & chainLinkUni relay
    chainlinkEth = new ChainlinkOracleRelay(CHAINLINK_ETH_FEED_ADDRESS, 10_000_000_000, 1);
    chainLinkUni = new ChainlinkOracleRelay(CHAINLINK_UNI_FEED_ADDRESS, 10_000_000_000, 1);

    // Deploy anchoredViewEth & anchoredViewUni relay
    anchoredViewEth = new AnchoredViewRelay(address(uniswapRelayEthUsdc), address(chainlinkEth), 10, 100);
    anchoredViewUni = new AnchoredViewRelay(address(uniswapRelayUniUsdc), address(chainLinkUni), 30, 100);
    vm.stopPrank();
  }
}

abstract contract VaultBase is Base {
  event BorrowUSDA(uint256 _vaultId, address _vaultAddress, uint256 _borrowAmount);

  IVault internal _vault;
  uint256 internal _vaultDeposit = 10 ether;
  uint96 internal _vaultId = 1;
  uint192 internal _borrowAmount = 5 ether;

  function setUp() public virtual override {
    super.setUp();

    vm.prank(governance);
    vaultController.registerErc20(
      WETH_ADDRESS, WETH_LTV, address(anchoredViewEth), LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );

    vm.startPrank(vaultOwner);
    _vault = IVault(vaultController.mintVault());
    vm.mockCall(
      WETH_ADDRESS,
      abi.encode(IERC20.transferFrom.selector, vaultOwner, address(_vault), _vaultDeposit),
      abi.encode(true)
    );
    _vault.depositERC20(WETH_ADDRESS, _vaultDeposit);
    vm.stopPrank();

    vm.mockCall(
      address(anchoredViewEth), abi.encodeWithSelector(IAnchoredViewRelay.currentValue.selector), abi.encode(1 ether)
    );
  }
}

contract UnitVaultControllerInitialize is Base {
  function testInitializedCorrectly() public {
    assertEq(vaultController.lastInterestTime(), block.timestamp);
    assertEq(vaultController.interestFactor(), 1 ether);
    assertEq(vaultController.protocolFee(), 100_000_000_000_000);
    assertEq(vaultController.vaultsMinted(), 0);
    assertEq(vaultController.tokensRegistered(), 0);
    assertEq(vaultController.totalBaseLiability(), 0);
    assertEq(address(vaultController.claimerContract()), address(mockAmphClaimer));
  }
}

contract UnitVaultControllerMigrateCollateralsFrom is Base {
  function testRevertIfWrongCollateral() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = WETH_ADDRESS;
    vm.startPrank(governance);
    // Deploy the new vault controller
    mockVaultController = new VaultControllerForTest();
    vm.expectRevert(IVaultController.VaultController_WrongCollateralAddress.selector);
    mockVaultController.migrateCollateralsFrom(IVaultController(address(vaultController)), _tokens);
    vm.stopPrank();
  }

  function testMigrateCollaterallsFrom() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = WETH_ADDRESS;
    vm.startPrank(governance);
    // Add erc20 collateral in first vault controller
    vaultController.registerErc20(
      WETH_ADDRESS, WETH_LTV, address(anchoredViewEth), LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );
    // Deploy the new vault controller
    mockVaultController = new VaultControllerForTest();
    mockVaultController.migrateCollateralsFrom(IVaultController(address(vaultController)), _tokens);
    vm.stopPrank();

    assertEq(address(mockVaultController.tokensOracle(WETH_ADDRESS)), address(anchoredViewEth));
    assertEq(mockVaultController.tokensRegistered(), 1);
    assertEq(mockVaultController.tokenId(WETH_ADDRESS), 1);
    assertEq(mockVaultController.tokenLTV(WETH_ADDRESS), WETH_LTV);
    assertEq(mockVaultController.tokenLiquidationIncentive(WETH_ADDRESS), LIQUIDATION_INCENTIVE);
    assertEq(mockVaultController.tokenCap(WETH_ADDRESS), type(uint256).max);
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
  function testRevertIfRegisterFromNonOwner(address _usda) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.registerUSDA(_usda);
  }

  function testRegisterUSDA(address _usda) public {
    vm.prank(governance);
    vaultController.registerUSDA(_usda);
    assertEq(address(vaultController.usda()), _usda);
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

  CurveMaster public otherCurveMaster;

  function setUp() public virtual override {
    super.setUp();
    vm.prank(governance);
    otherCurveMaster = new CurveMaster();
  }

  function testRevertIfRegisterFromNonOwner() public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.registerCurveMaster(address(otherCurveMaster));
  }

  function testRegisterCurveMaster() public {
    vm.expectEmit(false, false, false, true);
    emit RegisterCurveMaster(address(otherCurveMaster));
    vm.prank(governance);
    vaultController.registerCurveMaster(address(otherCurveMaster));
    assertEq(address(vaultController.curveMaster()), address(otherCurveMaster));
  }
}

contract UnitVaultControllerRegisterERC20 is Base {
  IBooster public booster = IBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

  event RegisteredErc20(
    address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive, uint256 _cap
  );

  function testRevertIfRegisterFromNonOwner(
    IERC20 _token,
    address _oracle,
    uint256 _ltv,
    uint256 _liquidationIncentive,
    uint256 _cap
  ) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.registerErc20(address(_token), _ltv, _oracle, _liquidationIncentive, _cap, 0);
  }

  function testRevertIfTokenAlreadyRegistered(IERC20 _token, address _oracle, uint64 _ltv, uint256 _cap) public {
    vm.assume(_ltv < 0.95 ether);
    // Register WETH as acceptable erc20 collateral to vault controller and set oracle
    vm.prank(governance);
    vaultController.registerErc20(address(_token), _ltv, _oracle, LIQUIDATION_INCENTIVE, _cap, 0);
    vm.expectRevert(IVaultController.VaultController_TokenAlreadyRegistered.selector);
    // Try to register the same again
    vm.prank(governance);
    vaultController.registerErc20(address(_token), _ltv, _oracle, LIQUIDATION_INCENTIVE, _cap, 0);
  }

  function testRevertIfIncompatibleLTV(
    IERC20 _token,
    address _oracle,
    uint64 _liquidationIncentive,
    uint256 _cap
  ) public {
    vm.assume(_liquidationIncentive < 1 ether && _liquidationIncentive > 0.2 ether);
    vm.expectRevert(IVaultController.VaultController_LTVIncompatible.selector);
    vm.prank(governance);
    vaultController.registerErc20(address(_token), WETH_LTV, _oracle, _liquidationIncentive, _cap, 0);
  }

  function testRevertIfTokenAddressDoesNotMatchLPTokenAddress(
    IERC20 _token,
    address _oracle,
    uint64 _ltv,
    uint256 _cap
  ) public {
    vm.assume(_ltv < 0.95 ether);
    vm.assume(address(_token) != address(0));
    vm.mockCall(
      address(booster),
      abi.encodeWithSelector(IBooster.poolInfo.selector, 136),
      abi.encode(address(0), address(0), address(0), address(0), address(0), false)
    );
    vm.expectRevert(IVaultController.VaultController_TokenAddressDoesNotMatchLpAddress.selector);
    vm.prank(governance);
    vaultController.registerErc20(address(_token), WETH_LTV, _oracle, LIQUIDATION_INCENTIVE, _cap, 136);
  }

  function testRegisterERC20(IERC20 _token, address _oracle) public {
    vm.expectEmit(false, false, false, true);
    emit RegisteredErc20(address(_token), WETH_LTV, _oracle, LIQUIDATION_INCENTIVE, type(uint256).max);

    vm.prank(governance);
    vaultController.registerErc20(address(_token), WETH_LTV, _oracle, LIQUIDATION_INCENTIVE, type(uint256).max, 0);
    assertEq(address(vaultController.tokensOracle(address(_token))), _oracle);
    assertEq(vaultController.tokensRegistered(), 1);
    assertEq(vaultController.tokenId(address(_token)), 1);
    assertEq(vaultController.tokenLTV(address(_token)), WETH_LTV);
    assertEq(vaultController.tokenLiquidationIncentive(address(_token)), LIQUIDATION_INCENTIVE);
    assertEq(vaultController.tokenCap(address(_token)), type(uint256).max);
  }
}

contract UnitVaultControllerUpdateRegisteredERC20 is Base {
  event UpdateRegisteredErc20(
    address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive, uint256 _cap
  );

  function setUp() public virtual override {
    super.setUp();
    vm.prank(governance);
    vaultController.registerErc20(
      WETH_ADDRESS, WETH_LTV, address(anchoredViewEth), LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );
  }

  function testRevertIfUpdateFromNonOwner(
    IERC20 _token,
    address _oracle,
    uint64 _ltv,
    uint256 _liquidationIncentive
  ) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.updateRegisteredErc20(address(_token), _ltv, _oracle, _liquidationIncentive, type(uint256).max);
  }

  function testRevertIfTokenNotRegistered(IERC20 _token, address _oracle, uint64 _ltv) public {
    vm.assume(_ltv < 0.95 ether && address(_token) != WETH_ADDRESS);
    vm.expectRevert(IVaultController.VaultController_TokenNotRegistered.selector);
    // Try to update a non registered token
    vm.prank(governance);
    vaultController.updateRegisteredErc20(address(_token), _ltv, _oracle, LIQUIDATION_INCENTIVE, type(uint256).max);
  }

  function testRevertIfIncompatibleLTV(address _oracle, uint64 _liquidationIncentive) public {
    vm.assume(_liquidationIncentive < 1 ether && _liquidationIncentive > 0.2 ether);
    vm.expectRevert(IVaultController.VaultController_LTVIncompatible.selector);
    vm.prank(governance);
    vaultController.updateRegisteredErc20(WETH_ADDRESS, WETH_LTV, _oracle, _liquidationIncentive, type(uint256).max);
  }

  function testUpdateRegisteredERC20(address _oracle, uint256 _ltv, uint256 _cap) public {
    vm.assume(_ltv < 0.95 ether);
    vm.expectEmit(false, false, false, true);
    emit UpdateRegisteredErc20(WETH_ADDRESS, _ltv, _oracle, LIQUIDATION_INCENTIVE, _cap);

    vm.prank(governance);
    vaultController.updateRegisteredErc20(WETH_ADDRESS, _ltv, _oracle, LIQUIDATION_INCENTIVE, _cap);
    assertEq(address(vaultController.tokensOracle(WETH_ADDRESS)), _oracle);
    assertEq(vaultController.tokenLTV(WETH_ADDRESS), _ltv);
    assertEq(vaultController.tokenLiquidationIncentive(WETH_ADDRESS), LIQUIDATION_INCENTIVE);
    assertEq(vaultController.tokenCap(WETH_ADDRESS), _cap);
  }
}

contract UnitVaultControllerChangeClaimerContract is Base {
  event ChangedClaimerContract(IAMPHClaimer _oldClaimerContract, IAMPHClaimer _newClaimerContract);

  function testRevertIfChangeFromNonOwner(IAMPHClaimer _claimerContract) public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(alice);
    vaultController.changeClaimerContract(_claimerContract);
  }

  function testChangeClaimerContract(IAMPHClaimer _claimerContract) public {
    vm.expectEmit(false, false, false, true);
    emit ChangedClaimerContract(vaultController.claimerContract(), _claimerContract);

    vm.prank(governance);
    vaultController.changeClaimerContract(_claimerContract);
    assertEq(address(vaultController.claimerContract()), address(_claimerContract));
  }
}

contract UnitVaultControllerLiquidateVault is VaultBase {
  event Liquidate(uint256 _vaultId, address _assetAddress, uint256 _usdaToRepurchase, uint256 _tokensToLiquidate);

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(address(mockToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    usdaToken.deposit(100 ether);
  }

  function testRevertIfPaused(uint96 _id, address _assetAddress, uint256 _tokensToLiquidate) public {
    vm.startPrank(governance);
    vaultController.pause();
    vm.stopPrank();

    vm.expectRevert('Pausable: paused');
    vaultController.liquidateVault(_id, _assetAddress, _tokensToLiquidate);
  }

  function testRevertIfLiquidateZeroAmount(uint96 _id, address _assetAddress) public {
    vm.expectRevert(IVaultController.VaultController_LiquidateZeroTokens.selector);
    vaultController.liquidateVault(_id, _assetAddress, 0);
  }

  function testRevertIfLiquidateTokenNotRegistered(
    uint96 _id,
    address _assetAddress,
    uint256 _tokensToLiquidate
  ) public {
    vm.assume(_assetAddress != WETH_ADDRESS && _tokensToLiquidate != 0);
    vm.expectRevert(IVaultController.VaultController_TokenNotRegistered.selector);
    vaultController.liquidateVault(_id, _assetAddress, _tokensToLiquidate);
  }

  function testRevertIfVaultDoesNotExist(uint96 _id, uint256 _tokensToLiquidate) public {
    vm.assume(_tokensToLiquidate != 0 && _id != _vaultId);
    vm.expectRevert(IVaultController.VaultController_VaultDoesNotExist.selector);
    vaultController.liquidateVault(_id, WETH_ADDRESS, _tokensToLiquidate);
  }

  function testRevertIfVaultIsSolvent(uint256 _tokensToLiquidate) public {
    vm.assume(_tokensToLiquidate != 0);
    vm.expectRevert(IVaultController.VaultController_VaultSolvent.selector);
    vaultController.liquidateVault(_vaultId, WETH_ADDRESS, _tokensToLiquidate);
  }

  function testCallExternalCalls() public {
    // borrow a few usda
    vm.prank(vaultOwner);
    vaultController.borrowUSDA(_vaultId, _borrowAmount);
    // make vault insolvent
    vm.prank(vaultOwner);
    _vault.withdrawERC20(WETH_ADDRESS, 8 ether);

    // 2 ether is left in the vault, 0.95 is the liquidation incentive
    vm.expectCall(address(_vault), abi.encodeWithSelector(IVault.modifyLiability.selector, false, 2 ether * 0.95));
    vm.expectCall(
      address(usdaToken), abi.encodeWithSelector(IUSDA.vaultControllerBurn.selector, address(this), 2 ether * 0.95)
    );
    vm.expectCall(
      address(_vault), abi.encodeWithSelector(IVault.controllerTransfer.selector, WETH_ADDRESS, address(this), 2 ether)
    );
    vaultController.liquidateVault(_vaultId, WETH_ADDRESS, 10 ether);
  }

  function testEmitEvent() public {
    // borrow a few usda
    vm.prank(vaultOwner);
    vaultController.borrowUSDA(_vaultId, _borrowAmount);
    // make vault insolvent
    vm.prank(vaultOwner);
    _vault.withdrawERC20(WETH_ADDRESS, 8 ether);

    vm.expectEmit(true, true, true, true);
    emit Liquidate(_vaultId, WETH_ADDRESS, 2 ether * 0.95, 2 ether);
    vaultController.liquidateVault(_vaultId, WETH_ADDRESS, 10 ether);
  }
}

contract UnitVaultControllerCheckVault is VaultBase {
  function setUp() public virtual override {
    super.setUp();
  }

  function testRevertIfVaultNotFound(uint96 _id) public {
    vm.assume(_id != _vaultId);
    vm.expectRevert(IVaultController.VaultController_VaultDoesNotExist.selector);
    vaultController.checkVault(_id);
  }

  function testCheckVaultSolvent() public {
    assertTrue(vaultController.checkVault(_vaultId));
  }

  function testCheckVaultInsolvent() public {
    vm.prank(vaultOwner);
    vaultController.borrowUSDA(_vaultId, _borrowAmount);

    vm.mockCall(
      address(anchoredViewEth),
      abi.encodeWithSelector(IAnchoredViewRelay.currentValue.selector),
      abi.encode(1 ether / 4)
    );
    assertFalse(vaultController.checkVault(_vaultId));
  }
}

contract UnitVaultControllerBorrow is VaultBase {
  function setUp() public virtual override {
    super.setUp();
  }

  function testRevertIfPaused(uint96 _id, uint192 _amount) public {
    vm.prank(governance);
    vaultController.pause();

    vm.expectRevert('Pausable: paused');
    vaultController.borrowUSDA(_id, _amount);
  }

  function testRevertIfNotMinter(uint192 _amount) public {
    vm.expectRevert(IVaultController.VaultController_OnlyMinter.selector);
    vm.prank(alice);
    vaultController.borrowUSDA(_vaultId, _amount);
  }

  function testRevertIfVaultInsolvent() public {
    vm.expectRevert(IVaultController.VaultController_VaultInsolvent.selector);
    vm.prank(vaultOwner);
    vaultController.borrowUSDA(_vaultId, uint192(_vaultDeposit * 1000));
  }

  function testBorrowUSDA() public {
    uint256 _usdaBalanceBefore = usdaToken.balanceOf(vaultOwner);
    vm.expectEmit(true, true, true, true);
    emit BorrowUSDA(_vaultId, address(_vault), _borrowAmount);

    vm.prank(vaultOwner);
    vaultController.borrowUSDA(_vaultId, _borrowAmount);
    assertEq(usdaToken.balanceOf(vaultOwner), _usdaBalanceBefore + _borrowAmount);
  }

  function testBorrowUSDATo() public {
    uint256 _usdaBalanceBefore = usdaToken.balanceOf(vaultOwner);
    vm.expectEmit(true, true, true, true);
    emit BorrowUSDA(_vaultId, address(_vault), _borrowAmount);

    vm.prank(vaultOwner);
    vaultController.borrowUSDAto(_vaultId, _borrowAmount, vaultOwner);
    assertEq(usdaToken.balanceOf(vaultOwner), _usdaBalanceBefore + _borrowAmount);
  }
}

contract UnitVaultControllerBorrowSUSDto is VaultBase {
  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(address(mockToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    usdaToken.deposit(10 ether);
    vm.mockCall(address(mockToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
  }

  function testRevertIfPaused(uint96 _id, uint192 _amount, address _receiver) public {
    vm.prank(governance);
    vaultController.pause();

    vm.expectRevert('Pausable: paused');
    vaultController.borrowsUSDto(_id, _amount, _receiver);
  }

  function testRevertIfNotMinter(uint192 _amount, address _receiver) public {
    vm.expectRevert(IVaultController.VaultController_OnlyMinter.selector);
    vm.prank(alice);
    vaultController.borrowsUSDto(_vaultId, _amount, _receiver);
  }

  function testRevertIfVaultInsolvent(address _receiver) public {
    vm.expectRevert(IVaultController.VaultController_VaultInsolvent.selector);
    vm.prank(vaultOwner);
    vaultController.borrowsUSDto(_vaultId, uint192(_vaultDeposit * 1000), _receiver);
  }

  function testCallModifyLiability(address _receiver) public {
    vm.expectCall(address(_vault), abi.encodeWithSelector(IVault.modifyLiability.selector, true, _borrowAmount));
    vm.prank(vaultOwner);
    vaultController.borrowsUSDto(_vaultId, _borrowAmount, _receiver);
  }

  function testCallVaultControllerTransfer(address _receiver) public {
    vm.expectCall(
      address(usdaToken), abi.encodeWithSelector(IUSDA.vaultControllerTransfer.selector, _receiver, _borrowAmount)
    );
    vm.prank(vaultOwner);
    vaultController.borrowsUSDto(_vaultId, _borrowAmount, _receiver);
  }

  function testEmitEvent(address _receiver) public {
    vm.expectEmit(true, true, true, true);
    emit BorrowUSDA(_vaultId, address(_vault), _borrowAmount);

    vm.prank(vaultOwner);
    vaultController.borrowsUSDto(_vaultId, _borrowAmount, _receiver);
  }
}

contract UnitVaultControllerModifyTotalDeposited is VaultBase {
  function testRevertIfNotValidVault(address _caller) public {
    vm.assume(_caller != alice);
    vm.assume(_caller != address(_vault));
    vm.prank(_caller);

    vm.expectRevert(IVaultController.VaultController_NotValidVault.selector);
    vaultController.modifyTotalDeposited(_vaultId, 0, WETH_ADDRESS, true);
  }

  function testRevertNotValidToken(address _token) public {
    vm.assume(_token != WETH_ADDRESS);

    vm.prank(vaultController.vaultAddress(_vaultId));
    vaultController.modifyTotalDeposited(_vaultId, 0, WETH_ADDRESS, true);
  }

  function testValidVault() public {
    vm.prank(vaultController.vaultAddress(_vaultId));
    vaultController.modifyTotalDeposited(_vaultId, 0, WETH_ADDRESS, true);
  }

  function testIncrease(uint56 _toIncrease) public {
    vm.startPrank(vaultController.vaultAddress(_vaultId));
    uint256 _totalDepositedBefore = vaultController.tokenTotalDeposited(WETH_ADDRESS);
    vaultController.modifyTotalDeposited(_vaultId, _toIncrease, WETH_ADDRESS, true);
    uint256 _totalDepositedAfter = vaultController.tokenTotalDeposited(WETH_ADDRESS);
    assert(_totalDepositedBefore + _toIncrease == _totalDepositedAfter);
    vm.stopPrank();
  }

  function testDecrease(uint56 _toDecrease) public {
    vm.startPrank(vaultController.vaultAddress(_vaultId));
    vaultController.modifyTotalDeposited(_vaultId, _toDecrease, WETH_ADDRESS, true);

    uint256 _totalDepositedBefore = vaultController.tokenTotalDeposited(WETH_ADDRESS);
    vaultController.modifyTotalDeposited(_vaultId, _toDecrease, WETH_ADDRESS, false);
    uint256 _totalDepositedAfter = vaultController.tokenTotalDeposited(WETH_ADDRESS);
    assert(_totalDepositedBefore - _toDecrease == _totalDepositedAfter);
    vm.stopPrank();
  }
}

contract UnitVaultControllerCapReached is Base {
  function setUp() public virtual override {
    super.setUp();

    // register token
    vm.prank(governance);
    vaultController.registerErc20(WETH_ADDRESS, WETH_LTV, address(anchoredViewEth), LIQUIDATION_INCENTIVE, cap, 0);

    // mint vault
    vm.prank(alice);
    vaultController.mintVault();

    vm.mockCall(WETH_ADDRESS, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
  }

  function testCap(uint256 _amount) public {
    vm.assume(cap >= _amount);
    vm.assume(_amount > 0);

    address _vaultAddress = vaultController.vaultAddress(1);
    vm.prank(alice);
    IVault(_vaultAddress).depositERC20(WETH_ADDRESS, _amount);
  }

  function testRevertCapReached(uint256 _amount) public {
    vm.assume(cap < _amount);
    vm.assume(_amount > 0);

    address _vaultAddress = vaultController.vaultAddress(1);
    vm.prank(alice);
    vm.expectRevert(IVaultController.VaultController_CapReached.selector);
    IVault(_vaultAddress).depositERC20(WETH_ADDRESS, _amount);
  }
}

contract UnitVaultControllerRepayUSDA is VaultBase {
  event RepayUSDA(uint256 _vaultId, address _vaultAddress, uint256 _repayAmount);

  function setUp() public virtual override {
    super.setUp();
    vm.prank(vaultOwner);
    vaultController.borrowUSDA(_vaultId, _borrowAmount);
    vm.mockCall(address(mockToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    usdaToken.deposit(5 ether);
  }

  function testRevertIfPaused(uint96 _id, uint192 _amount) public {
    vm.prank(governance);
    vaultController.pause();

    vm.expectRevert('Pausable: paused');
    vaultController.repayUSDA(_id, _amount);
  }

  // function testRevertIfRepayTooMuch(uint56 _amount) public {
  //   vm.assume(_amount > 0 && _amount < _borrowAmount);
  //   vm.mockCall(address(_vault), abi.encodeWithSelector(IVault.baseLiability.selector), abi.encode(_amount));
  //   vm.expectRevert(IVaultController.VaultController_RepayTooMuch.selector);
  //   vaultController.repayUSDA(_vaultId, _amount * 10);
  // }

  function testCallModifyLiability(uint56 _amount) public {
    vm.assume(_amount > 0 && _amount <= _borrowAmount);
    vm.expectCall(address(_vault), abi.encodeWithSelector(IVault.modifyLiability.selector, false, _amount));
    vaultController.repayUSDA(_vaultId, _amount);
  }

  function testCallVaultControllerBurn(uint56 _amount) public {
    vm.assume(_amount > 0 && _amount <= _borrowAmount);
    vm.expectCall(
      address(usdaToken), abi.encodeWithSelector(IUSDA.vaultControllerBurn.selector, address(this), _amount)
    );
    vaultController.repayUSDA(_vaultId, _amount);
  }

  function testRepayUSDA(uint56 _amount) public {
    vm.assume(_amount > 0 && _amount <= _borrowAmount);
    vm.expectEmit(true, true, true, true);
    emit RepayUSDA(_vaultId, address(_vault), _amount);
    vaultController.repayUSDA(_vaultId, _amount);
  }
}

contract UnitVaultControllerRepayAllUSDA is VaultBase {
  function setUp() public virtual override {
    super.setUp();
    vm.prank(vaultOwner);
    vaultController.borrowUSDA(_vaultId, _borrowAmount);

    vm.mockCall(address(mockToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    usdaToken.deposit(5 ether);

    vm.mockCall(address(_vault), abi.encodeWithSelector(IVault.baseLiability.selector), abi.encode(_borrowAmount));
  }

  function testRevertIfPaused(uint96 _id) public {
    vm.prank(governance);
    vaultController.pause();

    vm.expectRevert('Pausable: paused');
    vaultController.repayAllUSDA(_id);
  }

  function testCallModifyLiability() public {
    vm.expectCall(address(_vault), abi.encodeWithSelector(IVault.modifyLiability.selector, false, _borrowAmount));
    vaultController.repayAllUSDA(_vaultId);
  }

  function testCallVaultControllerBurn() public {
    vm.expectCall(
      address(usdaToken), abi.encodeWithSelector(IUSDA.vaultControllerBurn.selector, address(this), _borrowAmount)
    );
    vaultController.repayAllUSDA(_vaultId);
  }
}

contract UnitVaultControllerTokensToLiquidate is VaultBase {
  function setUp() public virtual override {
    super.setUp();
    vm.prank(vaultOwner);
    vaultController.borrowUSDA(_vaultId, _borrowAmount);
  }

  function testRevertIfVaultIsSolvent() public {
    vm.expectRevert(IVaultController.VaultController_VaultSolvent.selector);
    vaultController.tokensToLiquidate(_vaultId, WETH_ADDRESS);
  }

  function testTokensToLiquidate() public {
    vm.mockCall(
      address(anchoredViewEth),
      abi.encodeWithSelector(IAnchoredViewRelay.currentValue.selector),
      abi.encode(1 ether / 4)
    );
    assertEq(vaultController.tokensToLiquidate(_vaultId, WETH_ADDRESS), _vaultDeposit);
  }
}

contract UnitVaultControllerGetVault is VaultBase {
  IVault internal _mockVault;
  VaultDeployer internal _mockVaultDeployer;

  function setUp() public virtual override {
    super.setUp();
    address[] memory _tokens = new address[](1);
    mockVaultController = new VaultControllerForTest();
    _mockVaultDeployer = new VaultDeployer(IVaultController(address(mockVaultController)));
    mockVaultController.initialize(IVaultController(address(0)), _tokens, mockAmphClaimer, _mockVaultDeployer);
  }

  function testRevertIfVaultDoesNotExist(uint96 _id) public {
    vm.expectRevert(IVaultController.VaultController_VaultDoesNotExist.selector);
    mockVaultController.getVault(_id);
  }

  function testGetVault() public {
    vm.startPrank(vaultOwner);
    _mockVault = IVault(mockVaultController.mintVault());
    assertEq(address(mockVaultController.getVault(1)), address(_mockVault));
  }
}

contract UnitVaultControllerAmountToSolvency is VaultBase {
  function testRevertIfVaultIsSolvent() public {
    vm.expectRevert(IVaultController.VaultController_VaultSolvent.selector);
    vaultController.amountToSolvency(_vaultId);
  }

  function testAmountToSolvency() public {
    uint256 _borrowingPower = vaultController.vaultBorrowingPower(_vaultId);
    vm.mockCall(
      address(_vault), abi.encodeWithSelector(IVault.baseLiability.selector), abi.encode(_vaultDeposit + 1 ether)
    );
    assertEq(vaultController.amountToSolvency(_vaultId), 11 ether - _borrowingPower);
  }
}

contract UnitVaultControllerVaultLiability is VaultBase {
  function testRevertIfVaultDoesNotExist(uint96 _id) public {
    vm.assume(_id != 1);
    vm.expectRevert(IVaultController.VaultController_VaultDoesNotExist.selector);
    vaultController.vaultLiability(_id);
  }

  function testVaultLiability(uint56 _amount) public {
    vm.mockCall(address(_vault), abi.encodeWithSelector(IVault.baseLiability.selector), abi.encode(_amount));
    assertEq(vaultController.vaultLiability(_vaultId), _amount);
  }
}

contract UnitVaultControllerVaultBorrowingPower is VaultBase {
  function testVaultBorrowingPower() public {
    assertEq(vaultController.vaultBorrowingPower(_vaultId), _vaultDeposit * WETH_LTV / 1 ether);
  }

  function testVaultBorrowingPowerMultipleCollateral() public {
    vm.prank(governance);
    vaultController.registerErc20(
      UNI_ADDRESS, UNI_LTV, address(anchoredViewUni), LIQUIDATION_INCENTIVE, type(uint256).max, 0
    );

    vm.startPrank(vaultOwner);
    vm.mockCall(
      UNI_ADDRESS,
      abi.encode(IERC20.transferFrom.selector, vaultOwner, address(_vault), _vaultDeposit),
      abi.encode(true)
    );
    _vault.depositERC20(UNI_ADDRESS, _vaultDeposit);
    vm.stopPrank();

    vm.mockCall(
      address(anchoredViewEth), abi.encodeWithSelector(IAnchoredViewRelay.currentValue.selector), abi.encode(1 ether)
    );
    vm.mockCall(
      address(anchoredViewUni), abi.encodeWithSelector(IAnchoredViewRelay.currentValue.selector), abi.encode(1 ether)
    );

    uint256 _borrowingPower = _vaultDeposit * WETH_LTV + _vaultDeposit * UNI_LTV;
    assertEq(vaultController.vaultBorrowingPower(_vaultId), _borrowingPower / 1 ether);
  }
}

contract UnitVaultControllerCalculateInterest is VaultBase, ExponentialNoError {
  event InterestEvent(uint64 _epoch, uint192 _amount, uint256 _curveVal);

  uint256 internal _protocolFee = 100_000_000_000_000;

  function setUp() public virtual override {
    super.setUp();
    vm.prank(vaultOwner);
    vaultController.borrowUSDA(_vaultId, _borrowAmount);
  }

  function testCalculateInterestZero() public {
    assertEq(vaultController.calculateInterest(), 0);
  }

  function testCallExternalCalls() public {
    vm.warp(block.timestamp + 1);
    uint256 _curveValue = uint256(curveMaster.getValueAt(address(0x00), 0));
    uint192 _e18FactorIncrease =
      _safeu192(_truncate(_truncate((1 ether * _curveValue) / (365 days + 6 hours)) * 1 ether));
    uint192 _newIF = 1 ether + _e18FactorIncrease;
    uint256 _valueBefore = _borrowAmount;
    uint256 _valueAfter = _borrowAmount * _newIF / 1 ether;
    uint192 _protocolAmount = _safeu192(_truncate(uint256(_valueAfter - _valueBefore) * _protocolFee));
    uint256 _donate = _valueAfter - _valueBefore - _protocolAmount;

    vm.expectCall(address(usdaToken), abi.encodeWithSelector(IUSDA.vaultControllerDonate.selector, _donate));
    vm.expectCall(
      address(usdaToken), abi.encodeWithSelector(IUSDA.vaultControllerMint.selector, governance, _protocolAmount)
    );
    vm.expectEmit(true, true, true, true);
    emit InterestEvent(uint64(block.timestamp), _e18FactorIncrease, _curveValue);

    vaultController.calculateInterest();
  }
}

contract UnitVaultControllerVaultSummaries is VaultBase {
  function testVaultSummaries() public {
    IVaultController.VaultSummary[] memory _summary = vaultController.vaultSummaries(1, 1);
    assertEq(_summary.length, 1);
    assertEq(_summary[0].id, _vaultId);
    assertEq(_summary[0].borrowingPower, vaultController.vaultBorrowingPower(_vaultId));
    assertEq(_summary[0].vaultLiability, vaultController.vaultLiability(_vaultId));
    assertEq(_summary[0].tokenAddresses[0], WETH_ADDRESS);
    assertEq(_summary[0].tokenBalances[0], _vaultDeposit);
  }
}
