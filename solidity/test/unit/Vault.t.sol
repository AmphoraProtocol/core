// solhint-disable max-states-count
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';

import {Vault} from '@contracts/core/Vault.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IBooster} from '@interfaces/utils/IBooster.sol';
import {IBaseRewardPool} from '@interfaces/utils/IBaseRewardPool.sol';
import {IVirtualBalanceRewardPool} from '@interfaces/utils/IVirtualBalanceRewardPool.sol';
import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {IAmphoraProtocolToken} from '@interfaces/governance/IAmphoraProtocolToken.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';
import {TestConstants} from '@test/utils/TestConstants.sol';
import {ICVX} from '@interfaces/utils/ICVX.sol';

contract ForTestRewardContract is DSTestPlus {
  IERC20[] public tokens;
  uint256 public balanceChange;

  constructor(IERC20[] memory _tokens, uint256 _balanceChange) {
    tokens = _tokens;
    balanceChange = _balanceChange;
  }

  function setTokenBalanceChange(uint256 _newBalanceChange) external {
    balanceChange = _newBalanceChange;
  }

  function getReward(address, bool) external returns (bool _success) {
    for (uint256 _i; _i < tokens.length; _i++) {
      vm.mockCall(
        address(tokens[_i]),
        abi.encodeWithSelector(IERC20.balanceOf.selector),
        abi.encode(tokens[_i].balanceOf(address(this)) + balanceChange)
      );
    }
    _success = true;
  }

  function getReward() external {
    for (uint256 _i; _i < tokens.length; _i++) {
      vm.mockCall(
        address(tokens[_i]),
        abi.encodeWithSelector(IERC20.balanceOf.selector),
        abi.encode(tokens[_i].balanceOf(address(this)) + balanceChange)
      );
    }
  }
}

abstract contract Base is DSTestPlus, TestConstants {
  IERC20 internal _mockToken = IERC20(mockContract(newAddress(), 'mockToken'));
  IVaultController public mockVaultController = IVaultController(mockContract(newAddress(), 'mockVaultController'));
  IAMPHClaimer public mockAmphClaimer = IAMPHClaimer(mockContract(newAddress(), 'mockAmphClaimer'));
  IAmphoraProtocolToken public mockAmphToken = IAmphoraProtocolToken(mockContract(newAddress(), 'mockAmphToken'));
  IERC20 public cvx = IERC20(mockContract(newAddress(), 'cvx'));
  IERC20 public crv = IERC20(mockContract(newAddress(), 'crv'));

  uint256 public cvxTotalSupply = 1000 ether;
  uint256 public cvxMaxSupply = 2000 ether;
  uint256 public cvxTotalCliffs = 1000;
  uint256 public cvxReductionPerCliff = 10 ether;
  address public operator = label(newAddress(), 'operator');
  uint256 public tokenBalanceChange = 10 ether;
  address public stakeToken = label(newAddress(), 'stakeToken');

  IERC20[] public baseTokens = [cvx, crv];
  ForTestRewardContract public forTestBaseRewards = new ForTestRewardContract(baseTokens, tokenBalanceChange);
  IBaseRewardPool public baseRewards = IBaseRewardPool(label(address(forTestBaseRewards), 'baseRewards'));

  IERC20 public mockVirtualRewardsToken = IERC20(mockContract(newAddress(), 'mockVirtualRewardsToken'));
  IERC20[] public extraTokens = [mockVirtualRewardsToken];

  ForTestRewardContract public forTestVirtualRewards = new ForTestRewardContract(extraTokens, tokenBalanceChange);
  IVirtualBalanceRewardPool public mockVirtualRewardsPool =
    IVirtualBalanceRewardPool(label(address(forTestVirtualRewards), 'virtualRewards'));

  Vault public vault;
  address public vaultOwner = label(newAddress(), 'vaultOwner');

  function setUp() public virtual {
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    // solhint-disable-next-line reentrancy
    vault = new Vault(1, vaultOwner, address(mockVaultController), cvx, crv);

    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(cvxTotalSupply));
    vm.mockCall(address(cvx), abi.encodeWithSelector(ICVX.maxSupply.selector), abi.encode(cvxMaxSupply));
    vm.mockCall(address(cvx), abi.encodeWithSelector(ICVX.totalCliffs.selector), abi.encode(cvxTotalCliffs));
    vm.mockCall(address(cvx), abi.encodeWithSelector(ICVX.reductionPerCliff.selector), abi.encode(cvxReductionPerCliff));
    vm.mockCall(address(cvx), abi.encodeWithSelector(ICVX.operator.selector), abi.encode(operator));
    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
    vm.mockCall(address(mockVirtualRewardsToken), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
    vm.mockCall(address(mockVirtualRewardsToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    vm.mockCall(address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.operator.selector), abi.encode(operator));
    vm.mockCall(
      address(mockVirtualRewardsPool),
      abi.encodeWithSelector(IVirtualBalanceRewardPool.rewardToken.selector),
      abi.encode(mockVirtualRewardsToken)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector),
      abi.encode(address(baseRewards))
    );
    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.stakingToken.selector), abi.encode(stakeToken)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.withdrawAndUnwrap.selector), abi.encode(true)
    );
  }

  function depositCurveLpTokenMockCalls(
    uint256 _amount,
    address _token,
    uint256 _poolId,
    IVaultController.CollateralType _type
  ) public {
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.tokenId.selector, _token), abi.encode(1)
    );

    vm.mockCall(_token, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(_type)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, _token),
      abi.encode(_poolId)
    );

    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));
    vm.prank(vaultOwner);
    vault.depositERC20(_token, _amount);
  }
}

contract UnitVaultGetters is Base {
  function testConstructor() public {
    assertEq(vault.minter(), vaultOwner);
    assertEq(vault.id(), 1);
    assertEq(address(vault.CONTROLLER()), address(mockVaultController));
  }

  function testTokenBalance(uint256 _amount) public {
    vm.assume(_amount > 0);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.Single)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector),
      abi.encode(address(0))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(0)
    );

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);

    assertEq(vault.balances(address(_mockToken)), _amount);
  }

  function testCRV() public {
    assertEq(address(vault.CRV()), address(crv));
  }

  function testCVX() public {
    assertEq(address(vault.CVX()), address(cvx));
  }
}

contract UnitVaultDepositERC20 is Base {
  event Deposit(address _token, uint256 _amount);

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.modifyTotalDeposited.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.Single)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(0))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(0)
    );
  }

  function testRevertIfNotVaultOwner(address _token, uint256 _amount) public {
    vm.assume(_token != address(vm));
    vm.expectRevert(IVault.Vault_NotMinter.selector);
    vm.prank(newAddress());
    vault.depositERC20(_token, _amount);
  }

  function testRevertIfTokenNotRegistered(address _token, uint256 _amount) public {
    vm.assume(_token != address(vm));
    vm.expectRevert(IVault.Vault_TokenNotRegistered.selector);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_token)),
      abi.encode(0)
    );
    vm.prank(vaultOwner);
    vault.depositERC20(_token, _amount);
  }

  function testRevertIfAmountZero() public {
    vm.expectRevert(IVault.Vault_AmountZero.selector);
    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), 0);
  }

  function testRevertIfStakeOnConvexFails(uint256 _amount) public {
    vm.assume(_amount > 0);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(baseRewards))
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(false));
    vm.expectRevert(IVault.Vault_DepositAndStakeOnConvexFailed.selector);

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);
  }

  function testRevertIfStakeOnConvexOnAlreadyStakedTokenFails(uint256 _amount) public {
    vm.assume(_amount > 0 && _amount < type(uint256).max / 2);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(baseRewards))
    );

    depositCurveLpTokenMockCalls(_amount, address(_mockToken), 1, IVaultController.CollateralType.CurveLPStakedOnConvex);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(false));
    vm.expectRevert(IVault.Vault_DepositAndStakeOnConvexFailed.selector);

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);
  }

  function testExpectCallDepositOnConvex(uint256 _amount) public {
    vm.assume(_amount > 0);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(baseRewards))
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));

    vm.expectCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector, 1, _amount, true));
    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);
  }

  function testModifyTotalDepositedIsCalled(uint256 _amount) public {
    vm.assume(_amount > 0);

    vm.prank(vaultOwner);
    vm.expectCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.modifyTotalDeposited.selector, 1, _amount, address(_mockToken), true)
    );
    vault.depositERC20(address(_mockToken), _amount);
  }

  function testDepositERC20(uint256 _amount) public {
    vm.assume(_amount > 0);
    vm.expectEmit(false, false, false, true);
    emit Deposit(address(_mockToken), _amount);
    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);
    assertEq(vault.balances(address(_mockToken)), _amount);
  }

  function testDepositTokenAlreadyStaked(uint256 _amount) public {
    vm.assume(_amount > 0 && _amount < type(uint256).max / 2);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(baseRewards))
    );

    depositCurveLpTokenMockCalls(_amount, address(_mockToken), 1, IVaultController.CollateralType.CurveLPStakedOnConvex);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));

    vm.expectCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector, 1, _amount, true));
    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);

    assertEq(vault.balances(address(_mockToken)), _amount * 2);
  }

  function testDepositMigratesNonStakedToStaked(uint256 _amount) public {
    vm.assume(_amount > 0 && _amount <= 1_000_000_000 ether);

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(baseRewards))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.stakingToken.selector), abi.encode(stakeToken)
    );

    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));
    vm.expectCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector, 1, _amount * 2, true));

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);
  }
}

contract UnitVaultWithdrawERC20 is Base {
  event Withdraw(address _token, uint256 _amount);

  function setUp() public virtual override {
    super.setUp();

    vm.mockCall(
      USDT_LP_REWARDS_ADDRESS, abi.encodeWithSelector(IBaseRewardPool.stakingToken.selector), abi.encode(stakeToken)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.Single)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector),
      abi.encode(address(baseRewards))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), 1 ether);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.checkVault.selector, 1), abi.encode(true)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.modifyTotalDeposited.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector), abi.encode(1)
    );
  }

  function testRevertIfNotVaultOwner(address _token, uint256 _amount) public {
    vm.assume(_token != address(vm));
    vm.expectRevert(IVault.Vault_NotMinter.selector);
    vm.prank(newAddress());
    vault.withdrawERC20(_token, _amount);
  }

  function testRevertIfTokenNotRegistered(address _token, uint256 _amount) public {
    vm.assume(_token != address(vm));
    vm.expectRevert(IVault.Vault_TokenNotRegistered.selector);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_token)),
      abi.encode(0)
    );
    vm.prank(vaultOwner);
    vault.withdrawERC20(_token, _amount);
  }

  function testRevertIfOverWithdrawal(uint256 _amount) public {
    vm.assume(_amount <= 1 ether);

    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.checkVault.selector, 1), abi.encode(false)
    );
    vm.expectRevert(IVault.Vault_OverWithdrawal.selector);
    vm.prank(vaultOwner);
    vault.withdrawERC20(address(_mockToken), _amount);
  }

  function testRevertIfUnstakeOnConvexFails(uint256 _amount) public {
    vm.assume(_amount > 0 && _amount <= 100_000 ether);

    depositCurveLpTokenMockCalls(_amount, address(_mockToken), 1, IVaultController.CollateralType.CurveLPStakedOnConvex);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.withdrawAndUnwrap.selector), abi.encode(false)
    );
    vm.expectRevert(IVault.Vault_WithdrawAndUnstakeOnConvexFailed.selector);

    vm.prank(vaultOwner);
    vault.withdrawERC20(address(_mockToken), _amount);
  }

  function testExpectCallWithdrawOnConvex(uint256 _amount) public {
    vm.assume(_amount > 0 && _amount <= 100_000 ether);

    depositCurveLpTokenMockCalls(_amount, address(_mockToken), 1, IVaultController.CollateralType.CurveLPStakedOnConvex);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );

    vm.expectCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.withdrawAndUnwrap.selector, 1 ether, false)
    );
    vm.prank(vaultOwner);
    vault.withdrawERC20(address(_mockToken), 1 ether);
  }

  function testModifyTotalDepositedIsCalled() public {
    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.withdrawAndUnwrap.selector), abi.encode(true)
    );
    vm.expectCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.modifyTotalDeposited.selector, 1, 1 ether, address(_mockToken), false)
    );
    vm.prank(vaultOwner);
    vault.withdrawERC20(address(_mockToken), 1 ether);
  }

  function testWithdrawERC20() public {
    vm.expectEmit(false, false, false, true);
    emit Withdraw(address(_mockToken), 1 ether);
    assertEq(vault.balances(address(_mockToken)), 1 ether);
    vm.prank(vaultOwner);
    vault.withdrawERC20(address(_mockToken), 1 ether);
    assertEq(vault.balances(address(_mockToken)), 0);
  }

  function testWithdrawERC20CallsCheckVault() public {
    vm.expectCall(address(mockVaultController), abi.encodeWithSelector(IVaultController.checkVault.selector, 1));
    vm.prank(vaultOwner);
    vault.withdrawERC20(address(_mockToken), 1 ether);
  }

  function testWithdrawERC20CallsCalculateInterest() public {
    vm.expectCall(address(mockVaultController), abi.encodeWithSelector(IVaultController.calculateInterest.selector));
    vm.prank(vaultOwner);
    vault.withdrawERC20(address(_mockToken), 1 ether);
  }
}

contract UnitVaultControllerTransfer is Base {
  uint256 internal _deposit = 5 ether;

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(0))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.Single)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(0)
    );

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _deposit);
  }

  function testRevertsIfCalledByNonVault(uint256 _amount) public {
    vm.expectRevert(IVault.Vault_NotVaultController.selector);
    vault.controllerTransfer(address(_mockToken), address(this), _amount);
  }

  function testControllerTransfer(address _to) public {
    assertEq(vault.balances(address(_mockToken)), _deposit);
    vm.prank(address(mockVaultController));
    vault.controllerTransfer(address(_mockToken), _to, _deposit);
    assertEq(vault.balances(address(_mockToken)), 0);
  }
}

contract UnitVaultControllerWithdrawAndUnwrap is Base {
  function testRevertsIfCalledByNonVault(address _token, uint256 _amount) public {
    vm.expectRevert(IVault.Vault_NotVaultController.selector);
    vault.controllerWithdrawAndUnwrap(_token, _amount);
  }

  function testControllerWithdrawAndUnwrap(uint128 _amount) public {
    vm.assume(address(baseRewards) != address(vm) && address(baseRewards) > address(10));
    vm.assume(_amount > 0 && _amount < type(uint256).max / 2);

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.withdrawAndUnwrap.selector), abi.encode(true)
    );

    vm.expectCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.withdrawAndUnwrap.selector, _amount, false)
    );

    depositCurveLpTokenMockCalls(_amount, address(_mockToken), 1, IVaultController.CollateralType.CurveLPStakedOnConvex);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);

    depositCurveLpTokenMockCalls(_amount, address(_mockToken), 1, IVaultController.CollateralType.CurveLPStakedOnConvex);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);

    vm.prank(address(mockVaultController));
    vault.controllerWithdrawAndUnwrap(address(_mockToken), _amount);
  }

  function testRevertControllerWithdrawAndUnwrap(uint256 _amount) public {
    vm.assume(address(baseRewards) != address(vm) && address(baseRewards) > address(10));
    vm.assume(_amount > 0 && _amount < type(uint256).max / 2);

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.stakingToken.selector), abi.encode(stakeToken)
    );

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.withdrawAndUnwrap.selector), abi.encode(false)
    );

    depositCurveLpTokenMockCalls(_amount, address(_mockToken), 1, IVaultController.CollateralType.CurveLPStakedOnConvex);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(address(_mockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));

    vm.prank(vaultOwner);
    vault.depositERC20(address(_mockToken), _amount);

    vm.expectRevert(IVault.Vault_WithdrawAndUnstakeOnConvexFailed.selector);
    vm.prank(address(mockVaultController));
    vault.controllerWithdrawAndUnwrap(address(_mockToken), _amount);
  }
}

contract UnitVaultModifyLiability is Base {
  function setUp() public virtual override {
    super.setUp();

    // increase liability first
    vm.prank(address(mockVaultController));
    vault.modifyLiability(true, 1 ether);
  }

  function testRevertsIfCalledByNonVault(bool _increase, uint256 _baseAmount) public {
    vm.expectRevert(IVault.Vault_NotVaultController.selector);
    vault.modifyLiability(_increase, _baseAmount);
  }

  function testRevertIfTooMuchRepay() public {
    vm.expectRevert(IVault.Vault_RepayTooMuch.selector);
    vm.prank(address(mockVaultController));
    vault.modifyLiability(false, 10 ether);
  }

  function testModifyLiabilitIncrease(uint56 _baseAmount) public {
    uint256 _liabilityBefore = vault.baseLiability();
    vm.prank(address(mockVaultController));
    vault.modifyLiability(true, _baseAmount);
    assertEq(vault.baseLiability(), _liabilityBefore + _baseAmount);
  }

  function testModifyLiabilitDecrease() public {
    vm.prank(address(mockVaultController));
    vault.modifyLiability(false, 1 ether);
    assertEq(vault.baseLiability(), 0);
  }
}

contract UnitVaultClaimRewards is Base {
  IERC20 public otherMockToken = IERC20(newAddress());
  uint256 public crvDeposit = 100 ether;
  uint256 public stakeTokenBalance = 10 ether;

  IVaultController.CollateralInfo public collateralInfo;

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(stakeToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(crvDeposit));
    vm.mockCall(address(otherMockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(address(otherMockToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    vm.mockCall(address(otherMockToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector, address(crv)),
      abi.encode(IVaultController.CollateralType.Single)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(crv)),
      abi.encode(2)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(crv)),
      abi.encode(0)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(crv)),
      abi.encode(address(0))
    );

    vm.prank(vaultOwner);
    vault.depositERC20(address(crv), crvDeposit);

    // solhint-disable-next-line reentrancy
    collateralInfo = IVaultController.CollateralInfo({
      tokenId: 1,
      ltv: 0,
      cap: 0,
      totalDeposited: 0,
      liquidationIncentive: 0,
      oracle: IOracleRelay(address(0)),
      collateralType: IVaultController.CollateralType.CurveLPStakedOnConvex,
      crvRewardsContract: IBaseRewardPool(address(baseRewards)),
      poolId: 15,
      decimals: 18
    });

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralInfo.selector),
      abi.encode(collateralInfo)
    );

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.earned.selector, address(vault)), abi.encode(1 ether)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.claimerContract.selector),
      abi.encode(mockAmphClaimer)
    );

    vm.mockCall(address(mockAmphClaimer), abi.encodeWithSelector(IAMPHClaimer.AMPH.selector), abi.encode(mockAmphToken));

    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));

    vm.mockCall(
      address(mockAmphClaimer), abi.encodeWithSelector(IAMPHClaimer.claimAmph.selector), abi.encode(0, 0.5 ether, 0)
    );

    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(baseRewards))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(address(_mockToken));
  }

  function testRevertIfNotVaultOwner(address _token) public {
    vm.assume(_token != address(vm));
    address[] memory _tokens = new address[](1);
    _tokens[0] = _token;
    vm.expectRevert(IVault.Vault_NotMinter.selector);
    vm.prank(newAddress());
    vault.claimRewards(_tokens, true);
  }

  function testRevertIfTokenNotRegistered(address _token) public {
    vm.assume(_token != address(vm));
    address[] memory _tokens = new address[](1);
    _tokens[0] = _token;
    collateralInfo.tokenId = 0;
    vm.expectRevert(IVault.Vault_TokenNotRegistered.selector);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralInfo.selector),
      abi.encode(collateralInfo)
    );
    vm.prank(vaultOwner);
    vault.claimRewards(_tokens, true);
  }

  function testRevertIfProvidedTokenIsNotCurveLP() public {
    // Migrate to non staked
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(0))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(0)
    );

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(address(_mockToken));

    address[] memory _tokens = new address[](1);
    _tokens[0] = address(_mockToken);
    collateralInfo.collateralType = IVaultController.CollateralType.Single;
    vm.expectRevert(IVault.Vault_TokenNotStaked.selector);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralInfo.selector),
      abi.encode(collateralInfo)
    );
    vm.prank(vaultOwner);
    vault.claimRewards(_tokens, true);
  }

  function testExpectTransferCRV() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(_mockToken);
    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(0)
    );

    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimable.selector, address(vault), 1, tokenBalanceChange, tokenBalanceChange),
      abi.encode(0, 0.5 ether, 1 ether)
    );

    vm.expectCall(
      address(crv), abi.encodeWithSelector(IERC20.transfer.selector, vaultOwner, tokenBalanceChange - 0.5 ether)
    );

    vm.prank(vaultOwner);
    vault.claimRewards(_tokens, true);
  }

  function testClaimExtraRewards() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(_mockToken);
    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(1)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 0),
      abi.encode(mockVirtualRewardsPool)
    );

    vm.mockCall(
      address(mockVirtualRewardsPool),
      abi.encodeWithSelector(IVirtualBalanceRewardPool.earned.selector, address(vault)),
      abi.encode(1 ether)
    );

    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimable.selector),
      abi.encode(0, 0.5 ether, 1 ether)
    );

    vm.mockCall(address(mockVirtualRewardsToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    vm.expectCall(
      address(mockVirtualRewardsToken), abi.encodeWithSelector(IERC20.transfer.selector, vaultOwner, tokenBalanceChange)
    );

    vm.expectCall(
      address(crv), abi.encodeWithSelector(IERC20.transfer.selector, vaultOwner, tokenBalanceChange - 0.5 ether)
    );
    vm.prank(vaultOwner);
    vault.claimRewards(_tokens, true);
  }

  function testDontClaimExtraRewards() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(_mockToken);
    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(1)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 0),
      abi.encode(mockVirtualRewardsPool)
    );

    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimable.selector, address(vault), 1, tokenBalanceChange, tokenBalanceChange),
      abi.encode(0, 0.5 ether, 1 ether)
    );

    vm.expectCall(address(mockVirtualRewardsPool), abi.encodeWithSelector(IVirtualBalanceRewardPool.earned.selector), 0);

    vm.expectCall(address(mockVirtualRewardsToken), abi.encodeWithSelector(IERC20.transfer.selector), 0);
    vm.expectCall(
      address(crv), abi.encodeWithSelector(IERC20.transfer.selector, vaultOwner, tokenBalanceChange - 0.5 ether)
    );
    vm.prank(vaultOwner);
    vault.claimRewards(_tokens, false);
  }

  function testClaimMultipleTokens() public {
    address[] memory _tokens = new address[](2);
    _tokens[0] = address(_mockToken);
    _tokens[1] = address(otherMockToken);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(otherMockToken)),
      abi.encode(2)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(otherMockToken)),
      abi.encode(2)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector, address(otherMockToken)),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(otherMockToken)),
      abi.encode(address(baseRewards))
    );

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(address(otherMockToken));

    vm.mockCall(
      address(mockVirtualRewardsPool),
      abi.encodeWithSelector(IVirtualBalanceRewardPool.earned.selector, address(vault)),
      abi.encode(1 ether)
    );

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(0)
    );

    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimable.selector),
      abi.encode(0, 0.5 ether, 1 ether)
    );

    vm.mockCall(address(mockAmphClaimer), abi.encodeWithSelector(IAMPHClaimer.AMPH.selector), abi.encode(mockAmphToken));

    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));

    vm.mockCall(
      address(mockAmphClaimer), abi.encodeWithSelector(IAMPHClaimer.claimAmph.selector), abi.encode(0, 2 ether, 0)
    );

    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    vm.expectCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(
        IAMPHClaimer.claimAmph.selector, 1, 2 * tokenBalanceChange, 2 * tokenBalanceChange, vaultOwner
      )
    );

    vm.expectCall(
      address(crv), abi.encodeWithSelector(IERC20.transfer.selector, vaultOwner, 2 * tokenBalanceChange - 0.5 ether)
    );
    vm.prank(vaultOwner);
    vault.claimRewards(_tokens, true);
  }

  function testClaimWhenNoAMPHToClaim() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(_mockToken);
    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(1)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 0),
      abi.encode(mockVirtualRewardsPool)
    );

    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimable.selector, address(vault), 1, tokenBalanceChange, tokenBalanceChange),
      abi.encode(0, 0.5 ether, 0)
    );

    vm.expectCall(
      address(mockVirtualRewardsToken), abi.encodeWithSelector(IERC20.transfer.selector, vaultOwner, tokenBalanceChange)
    );

    // user gets the full amount
    vm.expectCall(address(crv), abi.encodeWithSelector(IERC20.transfer.selector, vaultOwner, tokenBalanceChange));
    vm.prank(vaultOwner);
    vault.claimRewards(_tokens, true);
  }

  function testClaimWhenTheRewardsAreZero() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(_mockToken);

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.earned.selector, address(vault)), abi.encode(0)
    );

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(1)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 0),
      abi.encode(mockVirtualRewardsPool)
    );

    vm.mockCall(
      address(mockVirtualRewardsPool),
      abi.encodeWithSelector(IVirtualBalanceRewardPool.earned.selector, address(vault)),
      abi.encode(0)
    );

    forTestBaseRewards.setTokenBalanceChange(0);
    forTestVirtualRewards.setTokenBalanceChange(0);
    vm.prank(vaultOwner);
    vault.claimRewards(_tokens, true);
  }
}

contract UnitVaultClaimableRewards is Base {
  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.earned.selector, address(vault)), abi.encode(1 ether)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.claimerContract.selector),
      abi.encode(mockAmphClaimer)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(baseRewards))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(address(_mockToken));
  }

  function testRevertIfTokenNotRegistered(address _token) public {
    vm.assume(_token != address(vm));
    vm.expectRevert(IVault.Vault_TokenNotRegistered.selector);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(_token)),
      abi.encode(0)
    );
    vault.claimableRewards(_token, true);
  }

  function testRevertIfProvidedTokenIsNotCurveLP() public {
    // Migrate to non staked
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(0))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(0)
    );

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(address(_mockToken));

    vm.expectRevert(IVault.Vault_TokenNotStaked.selector);
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.Single)
    );
    vault.claimableRewards(address(_mockToken), true);
  }

  function testClaimableRewards() public {
    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(1)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 0),
      abi.encode(mockVirtualRewardsPool)
    );

    vm.mockCall(
      address(mockVirtualRewardsPool),
      abi.encodeWithSelector(IVirtualBalanceRewardPool.earned.selector, address(vault)),
      abi.encode(1 ether)
    );

    uint256 _claimedCVX = 1 ether * 90 / 100;
    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimable.selector, address(vault), 1, _claimedCVX, 1 ether),
      abi.encode(0, 0.5 ether, 3 ether)
    );

    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    vm.mockCall(address(mockAmphClaimer), abi.encodeWithSelector(IAMPHClaimer.AMPH.selector), abi.encode(mockAmphToken));

    IVault.Reward[] memory _rewards = vault.claimableRewards(address(_mockToken), true);
    assertEq(_rewards.length, 4);
    assertEq(address(_rewards[0].token), address(crv));
    assertEq(_rewards[0].amount, 0.5 ether);

    assertEq(address(_rewards[1].token), address(cvx));
    assertEq(_rewards[1].amount, _claimedCVX);

    assertEq(address(_rewards[2].token), address(mockVirtualRewardsToken));
    assertEq(_rewards[2].amount, 1 ether);

    assertEq(address(_rewards[3].token), address(mockAmphToken));
    assertEq(_rewards[3].amount, 3 ether);
  }

  function testClaimableRewardsNoExtraRewards() public {
    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(1)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 0),
      abi.encode(mockVirtualRewardsPool)
    );

    vm.mockCall(
      address(mockVirtualRewardsPool),
      abi.encodeWithSelector(IVirtualBalanceRewardPool.earned.selector, address(vault)),
      abi.encode(1 ether)
    );

    uint256 _claimedCVX = 1 ether * 90 / 100;
    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimable.selector, address(vault), 1, _claimedCVX, 1 ether),
      abi.encode(0, 0.5 ether, 3 ether)
    );

    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    vm.mockCall(address(mockAmphClaimer), abi.encodeWithSelector(IAMPHClaimer.AMPH.selector), abi.encode(mockAmphToken));

    IVault.Reward[] memory _rewards = vault.claimableRewards(address(_mockToken), false);
    assertEq(_rewards.length, 3);
    assertEq(address(_rewards[0].token), address(crv));
    assertEq(_rewards[0].amount, 0.5 ether);

    assertEq(address(_rewards[1].token), address(cvx));
    assertEq(_rewards[1].amount, _claimedCVX);

    assertEq(address(_rewards[2].token), address(mockAmphToken));
    assertEq(_rewards[2].amount, 3 ether);
  }

  function testClaimableWhenAmphClaimerIsZeroAddress() public {
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.claimerContract.selector),
      abi.encode(address(0))
    );

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(1)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 0),
      abi.encode(mockVirtualRewardsPool)
    );

    vm.mockCall(
      address(mockVirtualRewardsPool),
      abi.encodeWithSelector(IVirtualBalanceRewardPool.earned.selector, address(vault)),
      abi.encode(1 ether)
    );

    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    IVault.Reward[] memory _rewards = vault.claimableRewards(address(_mockToken), true);

    assertEq(_rewards.length, 4);

    assertEq(address(_rewards[0].token), address(crv));
    assertEq(_rewards[0].amount, 1 ether);

    assertEq(address(_rewards[1].token), address(cvx));
    assertEq(_rewards[1].amount, 1 ether * 90 / 100);

    assertEq(address(_rewards[2].token), address(mockVirtualRewardsToken));
    assertEq(_rewards[2].amount, 1 ether);

    assertEq(address(_rewards[3].token), address(0));
    assertEq(_rewards[3].amount, 0);
  }

  function testClaimableRewardsWhenOperatorChanged() public {
    vm.mockCall(address(cvx), abi.encodeWithSelector(ICVX.operator.selector), abi.encode(newAddress()));

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.extraRewardsLength.selector), abi.encode(1)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 0),
      abi.encode(mockVirtualRewardsPool)
    );

    vm.mockCall(
      address(mockVirtualRewardsPool),
      abi.encodeWithSelector(IVirtualBalanceRewardPool.earned.selector, address(vault)),
      abi.encode(1 ether)
    );

    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimable.selector, address(vault), 1, 0, 1 ether),
      abi.encode(0, 0.5 ether, 3 ether)
    );

    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));

    vm.mockCall(address(mockAmphClaimer), abi.encodeWithSelector(IAMPHClaimer.AMPH.selector), abi.encode(mockAmphToken));

    IVault.Reward[] memory _rewards = vault.claimableRewards(address(_mockToken), true);
    assertEq(address(_rewards[0].token), address(crv));
    assertEq(_rewards[0].amount, 0.5 ether);

    assertEq(address(_rewards[1].token), address(cvx));
    assertEq(_rewards[1].amount, 0);

    assertEq(address(_rewards[2].token), address(mockVirtualRewardsToken));
    assertEq(_rewards[2].amount, 1 ether);

    assertEq(address(_rewards[3].token), address(mockAmphToken));
    assertEq(_rewards[3].amount, 3 ether);
  }
}

contract UnitVaultStakeCrvLPCollateral is Base {
  event Migrated(address _token, uint256 _amount);

  function testRevertIfStakeFails(address _token) public {
    vm.assume(_token != address(vm));
    /// deposit
    depositCurveLpTokenMockCalls(1 ether, _token, 0, IVaultController.CollateralType.Single);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(false));
    vm.expectRevert(IVault.Vault_DepositAndStakeOnConvexFailed.selector);

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(_token);
  }

  function testRevertIfTokenIsStaked(address _token) public {
    vm.assume(_token != address(vm));
    depositCurveLpTokenMockCalls(1 ether, _token, 0, IVaultController.CollateralType.Single);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(_token);

    vm.expectRevert(IVault.Vault_TokenAlreadyMigrated.selector);
    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(_token);
  }

  function testStakeCurveLP(address _token) public {
    vm.assume(_token != address(vm));
    /// deposit
    depositCurveLpTokenMockCalls(1 ether, _token, 0, IVaultController.CollateralType.Single);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));
    vm.expectCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector, 1, 1 ether, true));

    vm.expectEmit(true, true, true, true);
    emit Migrated(_token, 1 ether);

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(_token);
  }

  function testUnstakeCurveLP(address _token) public {
    vm.assume(_token != address(vm));

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector),
      abi.encode(address(baseRewards))
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );

    /// deposit
    depositCurveLpTokenMockCalls(1 ether, _token, 1, IVaultController.CollateralType.CurveLPStakedOnConvex);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector),
      abi.encode(address(0))
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(0)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.Single)
    );

    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.expectCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.withdrawAndUnwrap.selector, 1 ether, false)
    );

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(_token);
  }

  function testMigrateCurveLPToOtherPool(address _token) public {
    vm.assume(_token != address(vm));

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.stakingToken.selector), abi.encode(stakeToken)
    );

    vm.mockCall(
      USDT_LP_REWARDS_ADDRESS, abi.encodeWithSelector(IBaseRewardPool.stakingToken.selector), abi.encode(stakeToken)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector),
      abi.encode(address(baseRewards))
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );

    /// deposit
    depositCurveLpTokenMockCalls(1 ether, _token, 1, IVaultController.CollateralType.CurveLPStakedOnConvex);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector),
      abi.encode(USDT_LP_REWARDS_ADDRESS)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(2)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );

    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.expectCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.withdrawAndUnwrap.selector, 1 ether, false)
    );

    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));

    vm.expectCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector, 2, 1 ether, true));

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(_token);
  }
}

contract UnitVaultCanMigrate is Base {
  function testCanMigrateReturnFalseWithZeroBalance(address _token) public {
    vm.assume(_token != address(vm));
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(1)
    );

    vm.prank(vaultOwner);
    assertFalse(vault.canMigrate(_token));
  }

  function testCanMigrateReturnFalseWhenTokenAlreadyStaked(address _token) public {
    vm.assume(_token != address(vm));
    depositCurveLpTokenMockCalls(1 ether, _token, 0, IVaultController.CollateralType.Single);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(1)
    );
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector),
      abi.encode(IVaultController.CollateralType.CurveLPStakedOnConvex)
    );
    vm.mockCall(
      address(mockVaultController), abi.encodeWithSelector(IVaultController.BOOSTER.selector), abi.encode(BOOSTER)
    );
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(BOOSTER, abi.encodeWithSelector(IBooster.deposit.selector), abi.encode(true));

    vm.prank(vaultOwner);
    vault.migrateCrvLPCollateral(_token);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(1)
    );

    vm.prank(vaultOwner);
    assertFalse(vault.canMigrate(_token));
  }

  function testCanMigrateReturnTrue(address _token) public {
    vm.assume(_token != address(vm));
    depositCurveLpTokenMockCalls(1 ether, _token, 0, IVaultController.CollateralType.Single);

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_token)),
      abi.encode(1)
    );

    vm.prank(vaultOwner);
    assertTrue(vault.canMigrate(_token));
  }
}

contract UnitVaultClaimPreviousRewards is Base {
  IERC20 public otherMockToken = IERC20(newAddress());
  uint256 public crvDeposit = 100 ether;
  uint256 public stakeTokenBalance = 10 ether;

  IVaultController.CollateralInfo public collateralInfo;

  ForTestRewardContract public forTestVirtualRewards2 = new ForTestRewardContract(extraTokens, tokenBalanceChange);
  IVirtualBalanceRewardPool public mockVirtualRewardsPool2 =
    IVirtualBalanceRewardPool(label(address(forTestVirtualRewards2), 'virtualRewards2'));

  function setUp() public virtual override {
    super.setUp();
    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(stakeToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(crvDeposit));
    vm.mockCall(address(otherMockToken), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(address(otherMockToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    vm.mockCall(address(otherMockToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralType.selector, address(crv)),
      abi.encode(IVaultController.CollateralType.Single)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenId.selector, address(crv)),
      abi.encode(2)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(crv)),
      abi.encode(0)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(crv)),
      abi.encode(address(0))
    );

    vm.prank(vaultOwner);
    vault.depositERC20(address(crv), crvDeposit);

    // solhint-disable-next-line reentrancy
    collateralInfo = IVaultController.CollateralInfo({
      tokenId: 1,
      ltv: 0,
      cap: 0,
      totalDeposited: 0,
      liquidationIncentive: 0,
      oracle: IOracleRelay(address(0)),
      collateralType: IVaultController.CollateralType.CurveLPStakedOnConvex,
      crvRewardsContract: IBaseRewardPool(address(baseRewards)),
      poolId: 15,
      decimals: 18
    });

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCollateralInfo.selector),
      abi.encode(collateralInfo)
    );

    vm.mockCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.earned.selector, address(vault)), abi.encode(1 ether)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.claimerContract.selector),
      abi.encode(mockAmphClaimer)
    );

    vm.mockCall(address(mockAmphClaimer), abi.encodeWithSelector(IAMPHClaimer.AMPH.selector), abi.encode(mockAmphToken));

    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    vm.mockCall(address(crv), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));

    vm.mockCall(address(cvx), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenCrvRewardsContract.selector, address(_mockToken)),
      abi.encode(address(baseRewards))
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.tokenPoolId.selector, address(_mockToken)),
      abi.encode(1)
    );

    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.baseRewardContracts.selector, address(baseRewards)),
      abi.encode(true)
    );

    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimable.selector),
      abi.encode(0.5 ether, 0.5 ether, 1 ether)
    );

    vm.mockCall(
      address(mockAmphClaimer),
      abi.encodeWithSelector(IAMPHClaimer.claimAmph.selector),
      abi.encode(0.5 ether, 0.5 ether, 1 ether)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 1),
      abi.encode(mockVirtualRewardsPool)
    );

    vm.mockCall(
      address(baseRewards),
      abi.encodeWithSelector(IBaseRewardPool.extraRewards.selector, 2),
      abi.encode(mockVirtualRewardsPool2)
    );

    vm.mockCall(
      address(mockVirtualRewardsPool2),
      abi.encodeWithSelector(IVirtualBalanceRewardPool.rewardToken.selector),
      abi.encode(mockVirtualRewardsToken)
    );
  }

  function testRevertIfNotVaultOwner() public {
    uint256[] memory _ids;
    vm.expectRevert(IVault.Vault_NotMinter.selector);
    vm.prank(newAddress());
    vault.claimPreviousRewards(baseRewards, false, _ids);
  }

  function testRevertIfBaseRewardsNotRegistered() public {
    vm.mockCall(
      address(mockVaultController),
      abi.encodeWithSelector(IVaultController.baseRewardContracts.selector, address(baseRewards)),
      abi.encode(false)
    );
    uint256[] memory _ids;

    vm.expectRevert(IVault.Vault_InvalidBaseRewardContract.selector);
    vm.prank(vaultOwner);
    vault.claimPreviousRewards(baseRewards, false, _ids);
  }

  function testClaimsMainRewards() public {
    uint256[] memory _ids;

    vm.expectCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.getReward.selector, address(vault), false)
    );

    vm.prank(vaultOwner);
    vault.claimPreviousRewards(baseRewards, true, _ids);
  }

  function testClaimsExtraRewards() public {
    uint256[] memory _ids = new uint256[](2);
    _ids[0] = 1;
    _ids[1] = 2;

    vm.expectCall(
      address(baseRewards), abi.encodeWithSelector(IBaseRewardPool.getReward.selector, address(vault), false), 0
    );

    vm.expectCall(address(mockVirtualRewardsPool), abi.encodeWithSelector(IVirtualBalanceRewardPool.getReward.selector));

    vm.expectCall(
      address(mockVirtualRewardsPool2), abi.encodeWithSelector(IVirtualBalanceRewardPool.getReward.selector)
    );

    vm.prank(vaultOwner);
    vault.claimPreviousRewards(baseRewards, false, _ids);
  }
}
