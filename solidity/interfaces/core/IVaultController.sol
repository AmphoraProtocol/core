// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';

/// @title VaultController Interface
interface IVaultController {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

  event InterestEvent(uint64 _epoch, uint192 _amount, uint256 _curveVal);
  event NewProtocolFee(uint256 _protocolFee);
  event RegisteredErc20(address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive);
  event UpdateRegisteredErc20(
    address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive
  );
  event NewVault(address _vaultAddress, uint256 _vaultId, address _vaultOwner);
  event RegisterOracleMaster(address _oracleMasterAddress);
  event RegisterCurveMaster(address _curveMasterAddress);
  event BorrowUSDA(uint256 _vaultId, address _vaultAddress, uint256 _borrowAmount);
  event RepayUSDA(uint256 _vaultId, address _vaultAddress, uint256 _repayAmount);
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

  function initialize() external;

  function tokensRegistered() external view returns (uint256 _tokensRegistered);

  function vaultsMinted() external view returns (uint96 _vaultsMinted);

  function lastInterestTime() external view returns (uint64 _lastInterestTime);

  function totalBaseLiability() external view returns (uint192 _totalBaseLiability);

  function interestFactor() external view returns (uint192 _interestFactor);

  function protocolFee() external view returns (uint192 _protocolFee);

  function vaultAddress(uint96 _id) external view returns (address _vaultAddress);

  function vaultIDs(address _wallet) external view returns (uint96[] memory _vaultIDs);

  function curveMaster() external view returns (CurveMaster _curveMaster);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/

  function amountToSolvency(uint96 _id) external view returns (uint256 _amountToSolvency);

  function vaultLiability(uint96 _id) external view returns (uint192 _vaultLiability);

  function vaultBorrowingPower(uint96 _id) external view returns (uint192 _vaultBorrowingPower);

  function tokensToLiquidate(uint96 _id, address _token) external view returns (uint256 _tokensToLiquidate);

  function tokenId(address _tokenAddress) external view returns (uint256 _tokenId);

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

  function getOracleMaster() external view returns (address _oracleMasterAddress);

  function registerOracleMaster(address _masterOracleAddress) external;

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
