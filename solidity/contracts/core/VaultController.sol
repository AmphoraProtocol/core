// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ExponentialNoError} from '@contracts/utils/ExponentialNoError.sol';
import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';

import {IUSDA} from '@interfaces/core/IUSDA.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {IBooster} from '@interfaces/utils/IBooster.sol';
import {IBaseRewardPool} from '@interfaces/utils/IBaseRewardPool.sol';
import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {IVaultDeployer} from '@interfaces/core/IVaultDeployer.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';

/// @title Controller of all vaults in the USDA borrow/lend system
/// @notice VaultController contains all business logic for borrowing and lending through the protocol.
/// It is also in charge of accruing interest.
contract VaultController is
  Initializable,
  PausableUpgradeable,
  IVaultController,
  ExponentialNoError,
  OwnableUpgradeable
{
  // The convex booster contract
  IBooster public immutable BOOSTER = IBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
  // TODO: Change to immutable, can't initialize it in initializer
  // solhint-disable-next-line defi-wonderland/wonder-var-name-mixedcase
  IVaultDeployer public VAULT_DEPLOYER;

  // mapping of vault id to vault address
  mapping(uint96 => address) public vaultIdVaultAddress;

  // mapping of wallet address to vault IDs []
  mapping(address => uint96[]) public walletVaultIDs;

  // mapping of token address to collateral info
  mapping(address => CollateralInfo) public tokenAddressCollateralInfo;

  address[] public enabledTokens;

  CurveMaster public curveMaster;
  Interest public interest;

  IUSDA public usda;
  IAMPHClaimer public claimerContract;

  uint96 public vaultsMinted;
  uint256 public tokensRegistered;
  uint192 public totalBaseLiability;
  uint192 public protocolFee;

  /// @notice any function with this modifier will call the _payInterest() function before
  modifier paysInterest() {
    _payInterest();
    _;
  }

  ///@notice any function with this modifier can be paused or unpaused by USDA._pauser() in the case of an emergency
  modifier onlyPauser() {
    if (_msgSender() != usda.pauser()) revert VaultController_OnlyPauser();
    _;
  }

  /// @notice Can initialize collaterals from an older vault controller
  /// @param _oldVaultController The old vault controller
  /// @param _tokenAddresses The addresses of the collateral we want to take information for
  /// @param _claimerContract The claimer contract
  function initialize(
    IVaultController _oldVaultController,
    address[] memory _tokenAddresses,
    IAMPHClaimer _claimerContract,
    IVaultDeployer _vaultDeployer
  ) external override initializer {
    __Ownable_init();
    __Pausable_init();
    VAULT_DEPLOYER = _vaultDeployer;
    interest = Interest(uint64(block.timestamp), 1 ether);
    protocolFee = 1e14;

    claimerContract = _claimerContract;

    vaultsMinted = 0;
    tokensRegistered = 0;
    totalBaseLiability = 0;

    if (address(_oldVaultController) != address(0)) _migrateCollateralsFrom(_oldVaultController, _tokenAddresses);
  }

  /// @notice Returns the latest interest factor
  /// @return _interestFactor The latest interest factor
  function interestFactor() external view override returns (uint192 _interestFactor) {
    return interest.factor;
  }

  /// @notice Returns the block timestamp when pay interest was last called
  /// @return _lastInterestTime The block timestamp when pay interest was last called
  function lastInterestTime() external view override returns (uint64 _lastInterestTime) {
    return interest.lastTime;
  }

  /// @notice Returns the address of a vault given it's id
  /// @param _id The id of the vault to target
  /// @return _vaultAddress The address of the targetted vault
  function vaultAddress(uint96 _id) external view override returns (address _vaultAddress) {
    return vaultIdVaultAddress[_id];
  }

  /// @notice Returns an array of all the vault ids a specific wallet has
  /// @param _wallet The address of the wallet to target
  /// @return _vaultIDs The ids of the vaults the wallet has
  function vaultIDs(address _wallet) external view override returns (uint96[] memory _vaultIDs) {
    return walletVaultIDs[_wallet];
  }

  /// @notice Returns an array of all enabled tokens
  /// @return _enabledTokens array containing the token addresses
  function getEnabledTokens() external view override returns (address[] memory _enabledTokens) {
    _enabledTokens = enabledTokens;
  }

  /// @notice Returns the token id given a token's address
  /// @param _tokenAddress The address of the token to target
  /// @return _tokenId The id of the token
  function tokenId(address _tokenAddress) external view override returns (uint256 _tokenId) {
    return tokenAddressCollateralInfo[_tokenAddress].tokenId;
  }

  /// @notice Returns the oracle given a token's address
  /// @param _tokenAddress The id of the token
  /// @return _oracle The address of the token's oracle
  function tokensOracle(address _tokenAddress) external view override returns (IOracleRelay _oracle) {
    return tokenAddressCollateralInfo[_tokenAddress].oracle;
  }

  /// @notice Returns the ltv of a given token address
  /// @param _tokenAddress The address of the token
  /// @return _ltv The loan-to-value of a token
  function tokenLTV(address _tokenAddress) external view override returns (uint256 _ltv) {
    return tokenAddressCollateralInfo[_tokenAddress].ltv;
  }

  /// @notice Returns the liquidation incentive of an accepted token collateral
  /// @param _tokenAddress The address of the token
  /// @return _liquidationIncentive The liquidation incentive of the token
  function tokenLiquidationIncentive(address _tokenAddress)
    external
    view
    override
    returns (uint256 _liquidationIncentive)
  {
    return tokenAddressCollateralInfo[_tokenAddress].liquidationIncentive;
  }

  /// @notice Returns the cap of a given token address
  /// @param _tokenAddress The address of the token
  /// @return _cap The cap of the token
  function tokenCap(address _tokenAddress) external view override returns (uint256 _cap) {
    return tokenAddressCollateralInfo[_tokenAddress].cap;
  }

  /// @notice Returns the total deposited of a given token address
  /// @param _tokenAddress The address of the token
  /// @return _totalDeposited The total deposited of a token
  function tokenTotalDeposited(address _tokenAddress) external view override returns (uint256 _totalDeposited) {
    return tokenAddressCollateralInfo[_tokenAddress].totalDeposited;
  }

  /// @notice Returns the collateral type of a token
  /// @param _tokenAddress The address of the token
  /// @return _type The collateral type of a token
  function tokenCollateralType(address _tokenAddress) external view override returns (CollateralType _type) {
    return tokenAddressCollateralInfo[_tokenAddress].collateralType;
  }

  /// @notice Returns the address of the crvRewards contract
  /// @param _tokenAddress The address of the token
  /// @return _crvRewardsContract The address of the crvRewards contract
  function tokenCrvRewardsContract(address _tokenAddress)
    external
    view
    override
    returns (IBaseRewardPool _crvRewardsContract)
  {
    return tokenAddressCollateralInfo[_tokenAddress].crvRewardsContract;
  }

  /// @notice Returns the pool id of a curve LP type token
  /// @dev    If the token is not of type CurveLP then it returns 0
  /// @param _tokenAddress The address of the token
  /// @return _poolId The pool id of a curve LP type token
  function tokenPoolId(address _tokenAddress) external view override returns (uint256 _poolId) {
    return tokenAddressCollateralInfo[_tokenAddress].poolId;
  }

  /// @notice Returns the collateral info of a given token address
  /// @param _tokenAddress The address of the token
  /// @return _collateralInfo The complete collateral info of the token
  function tokenCollateralInfo(address _tokenAddress)
    external
    view
    override
    returns (CollateralInfo memory _collateralInfo)
  {
    return tokenAddressCollateralInfo[_tokenAddress];
  }

  /// @notice Returns the booster contract from convex
  /// @return _booster The booster contract from convex
  function booster() external view returns (IBooster _booster) {
    return BOOSTER;
  }

  /// @notice Returns the selected collaterals info. Will iterate from `_start` (included) until `_end` (not included)
  /// @param _start the start number to loop on the array
  /// @param _end the end number to loop on the array
  /// @return _collateralsInfo an array containing all the collateral info
  function getCollateralsInfo(
    uint256 _start,
    uint256 _end
  ) external view override returns (CollateralInfo[] memory _collateralsInfo) {
    // check if `_end` is bigger than the tokens length
    uint256 _enabledTokensLength = enabledTokens.length;
    _end = _enabledTokensLength < _end ? _enabledTokensLength : _end;

    _collateralsInfo = new CollateralInfo[](_end - _start);

    for (uint256 _i = _start; _i < _end; _i++) {
      _collateralsInfo[_i - _start] = tokenAddressCollateralInfo[enabledTokens[_i]];
    }
  }

  /// @notice Migrates all collateral information from previous vault controller
  /// @param _oldVaultController The address of the vault controller to take the information from
  /// @param _tokenAddresses The addresses of the tokens we want to target
  function _migrateCollateralsFrom(IVaultController _oldVaultController, address[] memory _tokenAddresses) internal {
    uint256 _tokenId;
    uint256 _tokensRegistered;
    for (uint256 _i = 0; _i < _tokenAddresses.length; _i++) {
      _tokenId = _oldVaultController.tokenId(_tokenAddresses[_i]);
      if (_tokenId == 0) revert VaultController_WrongCollateralAddress();
      _tokensRegistered++;

      CollateralInfo memory _collateral = _oldVaultController.tokenCollateralInfo(_tokenAddresses[_i]);
      _collateral.tokenId = _tokensRegistered;
      _collateral.totalDeposited = 0;

      enabledTokens.push(_tokenAddresses[_i]);
      tokenAddressCollateralInfo[_tokenAddresses[_i]] = _collateral;
    }
    tokensRegistered += _tokensRegistered;
  }

  /// @notice Creates a new vault and returns it's address
  /// @return _vaultAddress The address of the newly created vault
  function mintVault() public override whenNotPaused returns (address _vaultAddress) {
    // increment  minted vaults
    vaultsMinted = vaultsMinted + 1;
    // mint the vault itself, deploying the contract
    _vaultAddress = _createVault(vaultsMinted, _msgSender());
    // add the vault to our system
    vaultIdVaultAddress[vaultsMinted] = _vaultAddress;

    //push new vault ID onto mapping
    walletVaultIDs[_msgSender()].push(vaultsMinted);

    // emit the event
    emit NewVault(_vaultAddress, vaultsMinted, _msgSender());
  }

  /// @notice Pauses the functionality of the contract
  function pause() external override onlyPauser {
    _pause();
  }

  /// @notice Unpauses the functionality of the contract
  function unpause() external override onlyPauser {
    _unpause();
  }

  /// @notice Registers the USDA contract
  /// @param _usdaAddress The address to register as USDA
  function registerUSDA(address _usdaAddress) external override onlyOwner {
    usda = IUSDA(_usdaAddress);
  }

  /// @notice Emited when the owner registers a curve master
  /// @param _masterCurveAddress The address of the curve master
  function registerCurveMaster(address _masterCurveAddress) external override onlyOwner {
    curveMaster = CurveMaster(_masterCurveAddress);
    emit RegisterCurveMaster(_masterCurveAddress);
  }

  /// @notice Updates the protocol fee
  /// @param _newProtocolFee The new protocol fee in terms of 1e18=100%
  function changeProtocolFee(uint192 _newProtocolFee) external override onlyOwner {
    if (_newProtocolFee >= 1e18) revert VaultController_FeeTooLarge();
    protocolFee = _newProtocolFee;
    emit NewProtocolFee(_newProtocolFee);
  }

  /// @notice Register a new token to be used as collateral
  /// @param _tokenAddress The address of the token to register
  /// @param _ltv The ltv of the token, 1e18=100%
  /// @param _oracleAddress The address of oracle to fetch the price of the token
  /// @param _liquidationIncentive The liquidation penalty for the token, 1e18=100%
  /// @param _cap The maximum amount to be deposited
  function registerErc20(
    address _tokenAddress,
    uint256 _ltv,
    address _oracleAddress,
    uint256 _liquidationIncentive,
    uint256 _cap,
    uint256 _poolId
  ) external override onlyOwner {
    CollateralInfo memory _collateral = tokenAddressCollateralInfo[_tokenAddress];
    if (_collateral.tokenId != 0) revert VaultController_TokenAlreadyRegistered();
    if (_poolId != 0) {
      (address _lpToken,,, address _crvRewards,,) = BOOSTER.poolInfo(_poolId);
      if (_lpToken != _tokenAddress) revert VaultController_TokenAddressDoesNotMatchLpAddress();
      _collateral.collateralType = CollateralType.CurveLP;
      _collateral.crvRewardsContract = IBaseRewardPool(_crvRewards);
      _collateral.poolId = _poolId;
    } else {
      _collateral.collateralType = CollateralType.Single;
      _collateral.crvRewardsContract = IBaseRewardPool(address(0));
      _collateral.poolId = 0;
    }
    //ltv must be compatible with liquidation incentive
    if (_ltv >= (EXP_SCALE - _liquidationIncentive)) revert VaultController_LTVIncompatible();
    // increment the amount of registered token
    tokensRegistered = tokensRegistered + 1;
    // set & give the token an id
    _collateral.tokenId = tokensRegistered;
    // set the token's oracle
    _collateral.oracle = IOracleRelay(_oracleAddress);
    // set the token's ltv
    _collateral.ltv = _ltv;
    // set the token's liquidation incentive
    _collateral.liquidationIncentive = _liquidationIncentive;
    // set the cap
    _collateral.cap = _cap;
    // finally, add the token to the array of enabled tokens
    enabledTokens.push(_tokenAddress);
    // and save in mapping
    tokenAddressCollateralInfo[_tokenAddress] = _collateral;
    emit RegisteredErc20(_tokenAddress, _ltv, _oracleAddress, _liquidationIncentive, _cap);
  }

  /// @notice Updates an existing collateral with new collateral parameters
  /// @param _tokenAddress The address of the token to modify
  /// @param _ltv The new loan-to-value of the token, 1e18=100%
  /// @param _oracleAddress The address of oracle to modify for the price of the token
  /// @param _liquidationIncentive The new liquidation penalty for the token, 1e18=100%
  /// @param _cap The maximum amount to be deposited
  function updateRegisteredErc20(
    address _tokenAddress,
    uint256 _ltv,
    address _oracleAddress,
    uint256 _liquidationIncentive,
    uint256 _cap
  ) external override onlyOwner {
    CollateralInfo memory _collateral = tokenAddressCollateralInfo[_tokenAddress];
    if (_collateral.tokenId == 0) revert VaultController_TokenNotRegistered();
    //_ltv must be compatible with liquidation incentive
    if (_ltv >= (EXP_SCALE - _liquidationIncentive)) revert VaultController_LTVIncompatible();
    // set the oracle of the token
    _collateral.oracle = IOracleRelay(_oracleAddress);
    // set the ltv of the token
    _collateral.ltv = _ltv;
    // set the liquidation incentive of the token
    _collateral.liquidationIncentive = _liquidationIncentive;
    // set the cap
    _collateral.cap = _cap;
    // finally save in mapping
    tokenAddressCollateralInfo[_tokenAddress] = _collateral;

    emit UpdateRegisteredErc20(_tokenAddress, _ltv, _oracleAddress, _liquidationIncentive, _cap);
  }

  /// @notice Change the claimer contract, used to exchange a fee from curve lp rewards for AMPH tokens
  /// @param _newClaimerContract the new claimer contract
  function changeClaimerContract(IAMPHClaimer _newClaimerContract) external override onlyOwner {
    IAMPHClaimer _oldClaimerContract = claimerContract;
    claimerContract = _newClaimerContract;

    emit ChangedClaimerContract(_oldClaimerContract, _newClaimerContract);
  }

  /// @notice Check a vault for over-collateralization
  /// @param _id The id of vault we want to target
  /// @return _overCollateralized Returns true if vault over-collateralized; false if vault under-collaterlized
  function checkVault(uint96 _id) public view override returns (bool _overCollateralized) {
    // grab the vault by id if part of our system. revert if not
    IVault _vault = _getVault(_id);
    // calculate the total value of the vault's liquidity
    uint256 _totalLiquidityValue = _getVaultBorrowingPower(_vault);
    // calculate the total liability of the vault
    uint256 _usdaLiability = _truncate((_vault.baseLiability() * interest.factor));
    // if the ltv >= liability, the vault is solvent
    return (_totalLiquidityValue >= _usdaLiability);
  }

  /// @notice Borrows USDA from a vault. Only the vault minter may borrow from their vault
  /// @param _id The id of vault we want to target
  /// @param _amount The amount of USDA to borrow
  function borrowUSDA(uint96 _id, uint192 _amount) external override {
    _borrow(_id, _amount, _msgSender(), true);
  }

  /// @notice Borrows USDA from a vault and send the USDA to a specific address
  /// @param _id The id of vault we want to target
  /// @param _amount The amount of USDA to borrow
  /// @param _target The address to receive borrowed USDA
  function borrowUSDAto(uint96 _id, uint192 _amount, address _target) external override {
    _borrow(_id, _amount, _target, true);
  }

  /// @notice Borrows sUSD directly from reserve, liability is still in USDA, and USDA must be repaid
  /// @param _id The id of vault we want to target
  /// @param _susdAmount The amount of sUSD to borrow
  /// @param _target The address to receive borrowed sUSD
  function borrowsUSDto(uint96 _id, uint192 _susdAmount, address _target) external override {
    _borrow(_id, _susdAmount, _target, false);
  }

  /// @notice business logic to perform the USDA loan
  /// @param _id vault to borrow against
  /// @param _amount amount of USDA to borrow
  /// @param _target address to receive borrowed USDA
  /// @param _isUSDA boolean indicating if the borrowed asset is USDA (if FALSE is sUSD)
  /// @dev pays interest
  function _borrow(uint96 _id, uint192 _amount, address _target, bool _isUSDA) internal paysInterest whenNotPaused {
    // grab the vault by id if part of our system. revert if not
    IVault _vault = _getVault(_id);
    // only the minter of the vault may borrow from their vault
    if (_msgSender() != _vault.minter()) revert VaultController_OnlyMinter();
    // the base amount is the amount of USDA they wish to borrow divided by the interest factor
    uint192 _baseAmount = _safeu192(uint256(_amount * EXP_SCALE) / uint256(interest.factor));
    // _baseLiability should contain the vault's new liability, in terms of base units
    // true indicates that we are adding to the liability
    uint256 _baseLiability = _vault.modifyLiability(true, _baseAmount);
    // increase the total base liability by the _baseAmount
    // the same amount we added to the vault's liability
    totalBaseLiability = totalBaseLiability + _safeu192(_baseAmount);
    // now take the vault's total base liability and multiply it by the interest factor
    uint256 _usdaLiability = _truncate(uint256(interest.factor) * _baseLiability);
    // now get the ltv of the vault, aka their borrowing power, in usda
    uint256 _totalLiquidityValue = _getVaultBorrowingPower(_vault);
    // the ltv must be above the newly calculated _usdaLiability, else revert
    if (_totalLiquidityValue < _usdaLiability) revert VaultController_VaultInsolvent();

    if (_isUSDA) {
      // now send usda to the target, equal to the amount they are owed
      usda.vaultControllerMint(_target, _amount);
    } else {
      // send sUSD to the target from reserve instead of mint
      usda.vaultControllerTransfer(_target, _amount);
    }

    // emit the event
    emit BorrowUSDA(_id, address(_vault), _amount);
  }

  /// @notice Repays a vault's USDA loan. Anyone may repay
  /// @dev Pays interest
  /// @param _id The id of vault we want to target
  /// @param _amount The amount of USDA to repay
  function repayUSDA(uint96 _id, uint192 _amount) external override {
    _repay(_id, _amount, false);
  }

  /// @notice Repays all of a vault's USDA. Anyone may repay a vault's liabilities
  /// @dev Pays interest
  /// @param _id The id of vault we want to target
  function repayAllUSDA(uint96 _id) external override {
    _repay(_id, 0, true);
  }

  /// @notice business logic to perform the USDA repay
  /// @param _id vault to repay
  /// @param _amountInUSDA amount of USDA to borrow
  /// @param _repayAll if TRUE, repay all debt
  /// @dev pays interest
  function _repay(uint96 _id, uint192 _amountInUSDA, bool _repayAll) internal paysInterest whenNotPaused {
    // grab the vault by id if part of our system. revert if not
    IVault _vault = _getVault(_id);
    uint192 _baseAmount;

    // if _repayAll == TRUE, repay total liability
    if (_repayAll) {
      // store the vault baseLiability in memory
      _baseAmount = _safeu192(_vault.baseLiability());
      // get the total USDA liability, equal to the interest factor * vault's base liabilty
      _amountInUSDA = _safeu192(_truncate(interest.factor * _baseAmount));
    } else {
      // the base amount is the amount of USDA entered divided by the interest factor
      _baseAmount = _safeu192((_amountInUSDA * EXP_SCALE) / interest.factor);
    }
    // decrease the total base liability by the calculated base amount
    totalBaseLiability = totalBaseLiability - _baseAmount;
    // ensure that _baseAmount is lower than the vault's base liability.
    // this may not be needed, since modifyLiability *should* revert if is not true
    if (_baseAmount > _vault.baseLiability()) revert VaultController_RepayTooMuch();
    // decrease the vault's liability by the calculated base amount
    _vault.modifyLiability(false, _baseAmount);
    // burn the amount of USDA submitted from the sender
    usda.vaultControllerBurn(_msgSender(), _amountInUSDA);

    emit RepayUSDA(_id, address(_vault), _amountInUSDA);
  }

  /// @notice Liquidates an underwater vault
  /// @dev Pays interest before liquidation. Vaults may be liquidated up to the point where they are exactly solvent
  /// @param _id The id of vault we want to target
  /// @param _assetAddress The address of the token the liquidator wishes to liquidate
  /// @param _tokensToLiquidate The number of tokens to liquidate
  /// @return _toLiquidate The number of tokens that got liquidated
  function liquidateVault(
    uint96 _id,
    address _assetAddress,
    uint256 _tokensToLiquidate
  ) external override paysInterest whenNotPaused returns (uint256 _toLiquidate) {
    // cannot liquidate 0
    if (_tokensToLiquidate == 0) revert VaultController_LiquidateZeroTokens();
    // check for registered asset
    if (tokenAddressCollateralInfo[_assetAddress].tokenId == 0) revert VaultController_TokenNotRegistered();

    // calculate the amount to liquidate and the 'bad fill price' using liquidationMath
    // see _liquidationMath for more detailed explaination of the math
    (uint256 _tokenAmount, uint256 _badFillPrice) = _liquidationMath(_id, _assetAddress, _tokensToLiquidate);
    // set _tokensToLiquidate to this calculated amount if the function does not fail
    if (_tokenAmount != 0) _tokensToLiquidate = _tokenAmount;
    // the USDA to repurchase is equal to the bad fill price multiplied by the amount of tokens to liquidate
    uint256 _usdaToRepurchase = _truncate(_badFillPrice * _tokensToLiquidate);
    // get the vault that the liquidator wishes to liquidate
    IVault _vault = _getVault(_id);

    // decrease the vault's liability
    _vault.modifyLiability(false, (_usdaToRepurchase * 1e18) / interest.factor);

    // decrease the total base liability
    totalBaseLiability = totalBaseLiability - _safeu192((_usdaToRepurchase * 1e18) / interest.factor);

    // decrease liquidator's USDA balance
    usda.vaultControllerBurn(_msgSender(), _usdaToRepurchase);

    // withdraw from convex
    CollateralInfo memory _assetInfo = tokenAddressCollateralInfo[_assetAddress];
    if (_assetInfo.collateralType == IVaultController.CollateralType.CurveLP) {
      _vault.controllerWithdrawAndUnwrap(_assetInfo.crvRewardsContract, _tokensToLiquidate);
    }

    // finally, deliver tokens to liquidator
    _vault.controllerTransfer(_assetAddress, _msgSender(), _tokensToLiquidate);
    // and reduces total
    _modifyTotalDeposited(_tokensToLiquidate, _assetAddress, false);

    // this mainly prevents reentrancy
    if (_getVaultBorrowingPower(_vault) > _vaultLiability(_id)) revert VaultController_OverLiquidation();

    // emit the event
    emit Liquidate(_id, _assetAddress, _usdaToRepurchase, _tokensToLiquidate);
    // return the amount of tokens liquidated
    return _tokensToLiquidate;
  }

  /// @notice Returns the calculated amount of tokens to liquidate for a vault
  /// @dev The amount of tokens owed is a moving target and changes with each block as payInterest is called
  ///      This function can serve to give an indication of how many tokens can be liquidated
  ///      All this function does is call _liquidationMath with 2**256-1 as the amount
  /// @param _id The id of vault we want to target
  /// @param _assetAddress The address of token to calculate how many tokens to liquidate
  /// @return _tokensToLiquidate The amount of tokens liquidatable
  function tokensToLiquidate(
    uint96 _id,
    address _assetAddress
  ) external view override returns (uint256 _tokensToLiquidate) {
    (
      _tokensToLiquidate, // bad fill price
    ) = _liquidationMath(_id, _assetAddress, 2 ** 256 - 1);
  }

  /// @notice internal function with business logic for liquidation math
  /// @param _id the vault to get info for
  /// @param _assetAddress the token to calculate how many tokens to liquidate
  /// @param _tokensToLiquidate the max amount of tokens one wishes to liquidate
  /// @return _actualTokensToLiquidate the amount of tokens underwater this vault is
  /// @return _badFillPrice the bad fill price for the token
  function _liquidationMath(
    uint96 _id,
    address _assetAddress,
    uint256 _tokensToLiquidate
  ) internal view returns (uint256 _actualTokensToLiquidate, uint256 _badFillPrice) {
    //require that the vault is not solvent
    if (checkVault(_id)) revert VaultController_VaultSolvent();

    IVault _vault = _getVault(_id);

    CollateralInfo memory _collateral = tokenAddressCollateralInfo[_assetAddress];

    uint256 _price = _collateral.oracle.currentValue();

    // get price discounted by liquidation penalty
    // price * (100% - liquidationIncentive)
    _badFillPrice = _truncate(_price * (1e18 - _collateral.liquidationIncentive));

    // the ltv discount is the amount of collateral value that one token provides
    uint256 _ltvDiscount = _truncate(_price * _collateral.ltv);
    // this number is the denominator when calculating the _maxTokensToLiquidate
    // it is simply the badFillPrice - ltvDiscount
    uint256 _denominator = _badFillPrice - _ltvDiscount;

    // the maximum amount of tokens to liquidate is the amount that will bring the vault to solvency
    // divided by the denominator
    uint256 _maxTokensToLiquidate = (_amountToSolvency(_id) * 1e18) / _denominator;
    //Cannot liquidate more than is necessary to make vault over-collateralized
    if (_tokensToLiquidate > _maxTokensToLiquidate) _tokensToLiquidate = _maxTokensToLiquidate;

    //Cannot liquidate more collateral than there is in the vault
    if (_tokensToLiquidate > _vault.tokenBalance(_assetAddress)) {
      _tokensToLiquidate = _vault.tokenBalance(_assetAddress);
    }

    _actualTokensToLiquidate = _tokensToLiquidate;
  }

  /// @notice internal helper function to wrap getting of vaults
  /// @notice it will revert if the vault does not exist
  /// @param _id id of vault
  /// @return _vault IVault contract of
  function _getVault(uint96 _id) internal view returns (IVault _vault) {
    address _vaultAddress = vaultIdVaultAddress[_id];
    if (_vaultAddress == address(0)) revert VaultController_VaultDoesNotExist();
    _vault = IVault(_vaultAddress);
  }

  /// @notice Returns the amount of USDA needed to reach even solvency
  /// @dev this amount is a moving target and changes with each block as payInterest is called
  /// @param _id The id of vault we want to target
  /// @return _usdaToSolvency The amount of USDA needed to reach even solvency
  function amountToSolvency(uint96 _id) public view override returns (uint256 _usdaToSolvency) {
    if (checkVault(_id)) revert VaultController_VaultSolvent();
    return _amountToSolvency(_id);
  }

  /// @notice bussiness logic for amountToSolvency
  /// @param _id id of vault
  /// @return _usdaToSolvency amount of USDA needed to reach even solvency
  function _amountToSolvency(uint96 _id) internal view returns (uint256 _usdaToSolvency) {
    return _vaultLiability(_id) - _getVaultBorrowingPower(_getVault(_id));
  }

  /// @notice get vault liability of vault
  /// @param _id id of vault
  /// @return _liability amount of USDA the vault owes
  function vaultLiability(uint96 _id) external view override returns (uint192 _liability) {
    return _vaultLiability(_id);
  }

  /// @notice Returns the liability of a vault
  /// @dev Implementation in _vaultLiability
  /// @param _id The id of vault we want to target
  /// @return _liability The amount of USDA the vault owes
  function _vaultLiability(uint96 _id) internal view returns (uint192 _liability) {
    address _vaultAddress = vaultIdVaultAddress[_id];
    if (_vaultAddress == address(0)) revert VaultController_VaultDoesNotExist();
    IVault _vault = IVault(_vaultAddress);
    return _safeu192(_truncate(_vault.baseLiability() * interest.factor));
  }

  /// @notice Returns the vault borrowing power for vault
  /// @dev Implementation in getVaultBorrowingPower
  /// @param _id The id of vault we want to target
  /// @return _borrowPower The amount of USDA the vault can borrow
  function vaultBorrowingPower(uint96 _id) external view override returns (uint192 _borrowPower) {
    return _getVaultBorrowingPower(_getVault(_id));
  }

  /// @notice returns the borrowing power of a vault
  /// @param _vault the vault to get the borrowing power of
  /// @return _borrowPower the borrowing power of the vault
  //solhint-disable-next-line code-complexity
  function _getVaultBorrowingPower(IVault _vault) private view returns (uint192 _borrowPower) {
    // loop over each registed token, adding the indivuduals ltv to the total ltv of the vault
    for (uint192 _i = 1; _i <= enabledTokens.length; ++_i) {
      CollateralInfo memory _collateral = tokenAddressCollateralInfo[enabledTokens[_i - 1]];
      // if the ltv is 0, continue
      if (_collateral.ltv == 0) continue;
      // get the address of the token through the array of enabled tokens
      // note that index 0 of enabledTokens corresponds to a vaultId of 1, so we must subtract 1 from i to get the correct index
      address _tokenAddress = enabledTokens[_i - 1];
      // the balance is the vault's token balance of the current collateral token in the loop
      uint256 _balance = _vault.tokenBalance(_tokenAddress);
      if (_balance == 0) continue;
      // the raw price is simply the oracle price of the token
      uint192 _rawPrice = _safeu192(_collateral.oracle.currentValue());
      if (_rawPrice == 0) continue;
      // the token value is equal to the price * balance * tokenLTV
      uint192 _tokenValue = _safeu192(_truncate(_truncate(_rawPrice * _balance * _collateral.ltv)));
      // increase the ltv of the vault by the token value
      _borrowPower = _borrowPower + _tokenValue;
    }
  }

  /// @notice Returns the increase amount of the interest factor. Accrues interest to borrowers and distribute it to USDA holders
  /// @dev Implementation in payInterest
  /// @return _interest The increase amount of the interest factor
  function calculateInterest() external override returns (uint256 _interest) {
    return _payInterest();
  }

  /// @notice accrue interest to borrowers and distribute it to USDA holders.
  /// this function is called before any function that changes the reserve ratio
  /// @return _interest the interest to distribute to USDA holders
  function _payInterest() private returns (uint256 _interest) {
    // calculate the time difference between the current block and the last time the block was called
    uint64 _timeDifference = uint64(block.timestamp) - interest.lastTime;
    // if the time difference is 0, there is no interest. this saves gas in the case that
    // if multiple users call interest paying functions in the same block
    if (_timeDifference == 0) return 0;
    // the current reserve ratio, cast to a uint256
    uint256 _ui18 = uint256(usda.reserveRatio());
    // cast the reserve ratio now to an int in order to get a curve value
    int256 _reserveRatio = int256(_ui18);
    // calculate the value at the curve. this vault controller is a USDA vault and will reference
    // the vault at address 0
    int256 _intCurveVal = curveMaster.getValueAt(address(0x00), _reserveRatio);
    // cast the integer curve value to a u192
    uint192 _curveVal = _safeu192(uint256(_intCurveVal));
    // calculate the amount of total outstanding loans before and after this interest accrual
    // first calculate how much the interest factor should increase by
    // this is equal to (timedifference * (curve value) / (seconds in a year)) * (interest factor)
    uint192 _e18FactorIncrease = _safeu192(
      _truncate(
        _truncate((uint256(_timeDifference) * uint256(1e18) * uint256(_curveVal)) / (365 days + 6 hours))
          * uint256(interest.factor)
      )
    );
    // get the total outstanding value before we increase the interest factor
    uint192 _valueBefore = _safeu192(_truncate(uint256(totalBaseLiability) * uint256(interest.factor)));
    // interest is a struct which contains the last timestamp and the current interest factor
    // set the value of this struct to a struct containing {(current block timestamp), (interest factor + increase)}
    // this should save ~5000 gas/call
    interest = Interest(uint64(block.timestamp), interest.factor + _e18FactorIncrease);
    // using that new value, calculate the new total outstanding value
    uint192 _valueAfter = _safeu192(_truncate(uint256(totalBaseLiability) * uint256(interest.factor)));
    // valueAfter - valueBefore is now equal to the true amount of interest accured
    // this mitigates rounding errors
    // the protocol's fee amount is equal to this value multiplied by the protocol fee percentage, 1e18=100%
    uint192 _protocolAmount = _safeu192(_truncate(uint256(_valueAfter - _valueBefore) * uint256(protocolFee)));
    // donate the true amount of interest less the amount which the protocol is taking for itself
    // this donation is what pays out interest to USDA holders
    usda.vaultControllerDonate(_valueAfter - _valueBefore - _protocolAmount);
    // send the protocol's fee to the owner of this contract.
    usda.vaultControllerMint(owner(), _protocolAmount);
    // emit the event
    emit InterestEvent(uint64(block.timestamp), _e18FactorIncrease, _curveVal);
    // return the interest factor increase
    return _e18FactorIncrease;
  }

  /**
   * @notice Deploys a new Vault
   * @param _id The id of the vault
   * @param _minter The address of the minter of the vault
   * @return _vault The vault that was created
   */
  function _createVault(uint96 _id, address _minter) internal virtual returns (address _vault) {
    _vault = address(VAULT_DEPLOYER.deployVault(_id, _minter));
  }

  /// special view only function to help liquidators
  /// @notice Returns the status of a range of vaults
  /// @param _start The id of the vault to start looping
  /// @param _stop The id of vault to stop looping
  /// @return _vaultSummaries An array of vault information
  function vaultSummaries(
    uint96 _start,
    uint96 _stop
  ) public view override returns (VaultSummary[] memory _vaultSummaries) {
    _vaultSummaries = new VaultSummary[](_stop - _start + 1);
    for (uint96 _i = _start; _i <= _stop; _i++) {
      IVault _vault = _getVault(_i);
      uint256[] memory _tokenBalances = new uint256[](enabledTokens.length);

      for (uint256 _j = 0; _j < enabledTokens.length; _j++) {
        _tokenBalances[_j] = _vault.tokenBalance(enabledTokens[_j]);
      }
      _vaultSummaries[_i - _start] =
        VaultSummary(_i, this.vaultBorrowingPower(_i), this.vaultLiability(_i), enabledTokens, _tokenBalances);
    }
  }

  function _modifyTotalDeposited(uint256 _amount, address _token, bool _increase) internal {
    CollateralInfo memory _collateral = tokenAddressCollateralInfo[_token];
    if (_collateral.tokenId == 0) revert VaultController_TokenNotRegistered();
    if (_increase && (_collateral.totalDeposited + _amount) > _collateral.cap) revert VaultController_CapReached();

    tokenAddressCollateralInfo[_token].totalDeposited =
      _increase ? _collateral.totalDeposited + _amount : _collateral.totalDeposited - _amount;
  }

  /// @notice external function used by vaults to increase or decrease the `totalDeposited`.
  /// Should only be called by a valid vault
  /// @param _vaultID The id of vault which is calling (used to verify)
  /// @param _amount The amount to modify
  /// @param _token The token address which should modify the total
  /// @param _increase Boolean that indicates if should increase or decrease (TRUE -> increase, FALSE -> decrease)
  function modifyTotalDeposited(uint96 _vaultID, uint256 _amount, address _token, bool _increase) external override {
    if (_msgSender() != vaultIdVaultAddress[_vaultID]) revert VaultController_NotValidVault();
    _modifyTotalDeposited(_amount, _token, _increase);
  }
}
