// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';

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
   */
  event RegisteredErc20(address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive);

  /**
   * @notice Emited when the information about an acceptable erc20 token is being update
   *  @param _tokenAddress The addres of the erc20 token to update
   *  @param _ltv The new loan to value amount of the erc20
   *  @param _oracleAddress The new address of the oracle to use to fetch the price
   *  @param _liquidationIncentive The new liquidation penalty for the token
   */
  event UpdateRegisteredErc20(
    address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive
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

  function tokenLTV(uint256 _tokenId) external view returns (uint256 _ltv);

  function tokenLiquidationIncentive(address _token) external view returns (uint256 _liquidationIncentive);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/

  function initialize(IVaultController _oldVaultController, address[] memory _tokenAddresses) external;

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

  // admin
  function pause() external;

  function unpause() external;

  function registerCurveMaster(address _masterCurveAddress) external;

  function changeProtocolFee(uint192 _newProtocolFee) external;

  function registerErc20(
    address _tokenAddress,
    uint256 _ltv,
    address _oracleAddress,
    uint256 _liquidationIncentive
  ) external;

  function registerUSDA(address _usdaAddress) external;

  function updateRegisteredErc20(
    address _tokenAddress,
    uint256 _ltv,
    address _oracleAddress,
    uint256 _liquidationIncentive
  ) external;
}
