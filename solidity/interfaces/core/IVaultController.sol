// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {IBooster} from '@interfaces/utils/IBooster.sol';
import {IBaseRewardPool} from '@interfaces/utils/IBaseRewardPool.sol';
import {IVaultDeployer} from '@interfaces/core/IVaultDeployer.sol';
import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';

/// @title VaultController Interface
interface IVaultController {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Emited when payInterest is called to accrue interest and distribute it
   * @param _epoch The block timestamp when the function called
   * @param _amount The increase amount of the interest factor
   * @param _curveVal The value at the curve
   */
  event InterestEvent(uint64 _epoch, uint192 _amount, uint256 _curveVal);

  /**
   * @notice Emited when a new protocol fee is being set
   * @param _protocolFee The new fee for the protocol
   */
  event NewProtocolFee(uint192 _protocolFee);

  /**
   * @notice Emited when a new erc20 token is being registered as acceptable collateral
   * @param _tokenAddress The addres of the erc20 token
   * @param _ltv The loan to value amount of the erc20
   * @param _oracleAddress The address of the oracle to use to fetch the price
   * @param _liquidationIncentive The liquidation penalty for the token
   * @param _cap The maximum amount that can be deposited
   */
  event RegisteredErc20(
    address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive, uint256 _cap
  );

  /**
   * @notice Emited when the information about an acceptable erc20 token is being update
   *  @param _tokenAddress The addres of the erc20 token to update
   *  @param _ltv The new loan to value amount of the erc20
   *  @param _oracleAddress The new address of the oracle to use to fetch the price
   *  @param _liquidationIncentive The new liquidation penalty for the token
   *  @param _cap The maximum amount that can be deposited
   */
  event UpdateRegisteredErc20(
    address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive, uint256 _cap
  );

  /**
   * @notice Emited when a new vault is being minted
   * @param _vaultAddress The address of the new vault
   * @param _vaultId The id of the vault
   * @param _vaultOwner The address of the owner of the vault
   */
  event NewVault(address _vaultAddress, uint256 _vaultId, address _vaultOwner);

  /**
   * @notice Emited when the owner registers a curve master
   * @param _curveMasterAddress The address of the curve master
   */
  event RegisterCurveMaster(address _curveMasterAddress);
  /**
   * @notice Emited when someone successfully borrows USDA
   * @param _vaultId The id of the vault that borrowed against
   * @param _vaultAddress The address of the vault that borrowed against
   * @param _borrowAmount The amounnt that was borrowed
   */
  event BorrowUSDA(uint256 _vaultId, address _vaultAddress, uint256 _borrowAmount);

  /**
   * @notice Emited when someone successfully repayed a vault's loan
   * @param _vaultId The id of the vault that was repayed
   * @param _vaultAddress The address of the vault that was repayed
   * @param _repayAmount The amount that was repayed
   */
  event RepayUSDA(uint256 _vaultId, address _vaultAddress, uint256 _repayAmount);

  /**
   * @notice Emited when someone successfully liquidates a vault
   * @param _vaultId The id of the vault that was liquidated
   * @param _assetAddress The address of the token that was liquidated
   * @param _usdaToRepurchase The amount of USDA that was repurchased
   * @param _tokensToLiquidate The number of tokens that were liquidated
   */
  event Liquidate(uint256 _vaultId, address _assetAddress, uint256 _usdaToRepurchase, uint256 _tokensToLiquidate);

  /**
   * @notice Emited when governance changes the curve lp fee
   *  @param _oldFee The old curve lp fee
   *  @param _newFee The new curve lp fee
   */
  event ChangedCurveLpFee(uint256 _oldFee, uint256 _newFee);

  /**
   * @notice Emited when governance changes the claimer contract
   *  @param _oldClaimerContract The old claimer contract
   *  @param _newClaimerContract The new claimer contract
   */
  event ChangedClaimerContract(IAMPHClaimer _oldClaimerContract, IAMPHClaimer _newClaimerContract);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when _msgSender is not the pauser of the contract
  error VaultController_OnlyPauser();

  /// @notice Thrown when the fee is too large
  error VaultController_FeeTooLarge();

  /// @notice Thrown when oracle does not exist
  error VaultController_OracleNotRegistered();

  /// @notice Thrown when the token is already registered
  error VaultController_TokenAlreadyRegistered();

  /// @notice Thrown when the token is not registered
  error VaultController_TokenNotRegistered();

  /// @notice Thrown when the _ltv is incompatible
  error VaultController_LTVIncompatible();

  /// @notice Thrown when _msgSender is not the minter
  error VaultController_OnlyMinter();

  /// @notice Thrown when vault is insolvent
  error VaultController_VaultInsolvent();

  /// @notice Thrown when repay is grater than borrow
  error VaultController_RepayTooMuch();

  /// @notice Thrown when trying to liquidate 0 tokens
  error VaultController_LiquidateZeroTokens();

  /// @notice Thrown when trying to liquidate more than is possible
  error VaultController_OverLiquidation();

  /// @notice Thrown when vault is solvent
  error VaultController_VaultSolvent();

  /// @notice Thrown when vault does not exist
  error VaultController_VaultDoesNotExist();

  /// @notice Thrown when migrating collaterals to a new vault controller
  error VaultController_WrongCollateralAddress();

  /// @notice Thrown when a not valid vault is trying to modify the total deposited
  error VaultController_NotValidVault();

  /// @notice Thrown when a deposit surpass the cap
  error VaultController_CapReached();

  /// @notice Thrown when registering a crv lp token with wrong address
  error VaultController_TokenAddressDoesNotMatchLpAddress();

  /*///////////////////////////////////////////////////////////////
                            ENUMS
  //////////////////////////////////////////////////////////////*/

  enum CollateralType {
    Single,
    CurveLP
  }

  /*///////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

  struct VaultSummary {
    uint96 id;
    uint192 borrowingPower;
    uint192 vaultLiability;
    address[] tokenAddresses;
    uint256[] tokenBalances;
  }

  struct Interest {
    uint64 lastTime;
    uint192 factor;
  }

  struct CollateralInfo {
    uint256 tokenId;
    uint256 ltv;
    uint256 cap;
    uint256 totalDeposited;
    uint256 liquidationIncentive;
    IOracleRelay oracle;
    CollateralType collateralType;
    IBaseRewardPool crvRewardsContract;
    uint256 poolId;
  }

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

  function tokensRegistered() external view returns (uint256 _tokensRegistered);

  function vaultsMinted() external view returns (uint96 _vaultsMinted);

  function lastInterestTime() external view returns (uint64 _lastInterestTime);

  function totalBaseLiability() external view returns (uint192 _totalBaseLiability);

  function interestFactor() external view returns (uint192 _interestFactor);

  function protocolFee() external view returns (uint192 _protocolFee);

  function vaultAddress(uint96 _id) external view returns (address _vaultAddress);

  function vaultIDs(address _wallet) external view returns (uint96[] memory _vaultIDs);

  function curveMaster() external view returns (CurveMaster _curveMaster);

  function tokenId(address _tokenAddress) external view returns (uint256 _tokenId);

  function tokensOracle(address _tokenAddress) external view returns (IOracleRelay _oracle);

  function tokenLTV(address _tokenAddress) external view returns (uint256 _ltv);

  function tokenLiquidationIncentive(address _tokenAddress) external view returns (uint256 _liquidationIncentive);

  function tokenCap(address _tokenAddress) external view returns (uint256 _cap);

  function tokenTotalDeposited(address _tokenAddress) external view returns (uint256 _totalDeposited);

  function tokenCollateralType(address _tokenAddress) external view returns (CollateralType _type);

  function tokenCrvRewardsContract(address _tokenAddress) external view returns (IBaseRewardPool _crvRewardsContract);

  function tokenPoolId(address _tokenAddress) external view returns (uint256 _poolId);

  function tokenCollateralInfo(address _tokenAddress) external view returns (CollateralInfo memory _collateralInfo);

  function booster() external view returns (IBooster _booster);

  function curveLpRewardsFee() external view returns (uint256 _fee);

  function claimerContract() external view returns (IAMPHClaimer _claimerContract);

  function VAULT_DEPLOYER() external view returns (IVaultDeployer _vaultDeployer);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/

  function initialize(
    IVaultController _oldVaultController,
    address[] memory _tokenAddresses,
    IAMPHClaimer _claimerContract,
    uint256 _curveLpRewardsFee,
    IVaultDeployer _vaultDeployer
  ) external;

  function amountToSolvency(uint96 _id) external view returns (uint256 _amountToSolvency);

  function vaultLiability(uint96 _id) external view returns (uint192 _vaultLiability);

  function vaultBorrowingPower(uint96 _id) external view returns (uint192 _vaultBorrowingPower);

  function tokensToLiquidate(uint96 _id, address _token) external view returns (uint256 _tokensToLiquidate);

  function checkVault(uint96 _id) external view returns (bool _overCollateralized);

  function vaultSummaries(uint96 _start, uint96 _stop) external view returns (VaultSummary[] memory _vaultSummaries);

  // interest calculations
  function calculateInterest() external returns (uint256 _interest);

  // vault management business
  function mintVault() external returns (address _vaultAddress);

  function liquidateVault(
    uint96 _id,
    address _assetAddress,
    uint256 _tokenAmount
  ) external returns (uint256 _tokensToLiquidate);

  function borrowUSDA(uint96 _id, uint192 _amount) external;

  function borrowUSDAto(uint96 _id, uint192 _amount, address _target) external;

  function borrowsUSDto(uint96 _id, uint192 _susdAmount, address _target) external;

  function repayUSDA(uint96 _id, uint192 _amount) external;

  function repayAllUSDA(uint96 _id) external;

  function modifyTotalDeposited(uint96 _vaultID, uint256 _amount, address _token, bool _increase) external;

  // admin
  function pause() external;

  function unpause() external;

  function registerCurveMaster(address _masterCurveAddress) external;

  function changeProtocolFee(uint192 _newProtocolFee) external;

  function registerErc20(
    address _tokenAddress,
    uint256 _ltv,
    address _oracleAddress,
    uint256 _liquidationIncentive,
    uint256 _cap,
    uint256 _poolId
  ) external;

  function registerUSDA(address _usdaAddress) external;

  function updateRegisteredErc20(
    address _tokenAddress,
    uint256 _ltv,
    address _oracleAddress,
    uint256 _liquidationIncentive,
    uint256 _cap
  ) external;

  function changeCurveLpFee(uint256 _newFee) external;

  function changeClaimerContract(IAMPHClaimer _newClaimerContract) external;
}
