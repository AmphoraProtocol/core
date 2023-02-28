// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {ExponentialNoError} from '@contracts/_external/ExponentialNoError.sol';
import {Vault} from '@contracts/core/Vault.sol';
import {OracleMaster} from '@contracts/periphery/OracleMaster.sol';
import {CurveMaster} from '@contracts/periphery/CurveMaster.sol';

import {IUSDA} from '@interfaces/core/IUSDA.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

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
  // mapping of vault id to vault address
  mapping(uint96 => address) public vaultIdVaultAddress;

  //mapping of wallet address to vault IDs []
  mapping(address => uint96[]) public walletVaultIDs;

  // mapping of token address to token id
  mapping(address => uint256) public tokenAddressTokenId;

  //mapping of tokenId to the LTV*1
  mapping(uint256 => uint256) public tokenIdTokenLTV;

  //mapping of tokenId to its corresponding oracleAddress (which are addresses)
  mapping(uint256 => address) public tokenIdOracleAddress;

  //mapping of token address to its corresponding liquidation incentive
  mapping(address => uint256) public tokenAddressLiquidationIncentive;
  address[] public enabledTokens;

  OracleMaster public oracleMaster;
  CurveMaster public curveMaster;
  Interest public interest;

  IUSDA public usda;

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

  /// @notice no initialization arguments.
  function initialize() external override initializer {
    __Ownable_init();
    __Pausable_init();
    interest = Interest(uint64(block.timestamp), 1e18);
    protocolFee = 1e14;

    vaultsMinted = 0;
    tokensRegistered = 0;
    totalBaseLiability = 0;
  }

  /// @notice get current interest factor
  /// @return _interestFactor interest factor
  function interestFactor() external view override returns (uint192 _interestFactor) {
    return interest.factor;
  }

  /// @notice get last interest time
  /// @return _lastInterestTime interest time
  function lastInterestTime() external view override returns (uint64 _lastInterestTime) {
    return interest.lastTime;
  }

  /// @notice _id get vault address of id
  /// @return _vaultAddress the address of vault
  function vaultAddress(uint96 _id) external view override returns (address _vaultAddress) {
    return vaultIdVaultAddress[_id];
  }

  ///@notice _wallet get vaultIDs of a particular wallet
  ///@return _vaultIDs array of vault IDs owned by the wallet, from 0 to many
  function vaultIDs(address _wallet) external view override returns (uint96[] memory _vaultIDs) {
    return walletVaultIDs[_wallet];
  }

  /// @notice Returns the token id given a token's address
  /// @param _tokenAddress The address of the token to target
  /// @return _tokenId The id of the token
  function tokenId(address _tokenAddress) external view override returns (uint256 _tokenId) {
    return tokenAddressTokenId[_tokenAddress];
  }

  /// @notice create a new vault
  /// @return _vaultAddress address of the new vault
  function mintVault() public override whenNotPaused returns (address _vaultAddress) {
    // increment  minted vaults
    vaultsMinted = vaultsMinted + 1;
    // mint the vault itself, deploying the contract
    _vaultAddress = address(new Vault(vaultsMinted, _msgSender(), address(this)));
    // add the vault to our system
    vaultIdVaultAddress[vaultsMinted] = _vaultAddress;

    //push new vault ID onto mapping
    walletVaultIDs[_msgSender()].push(vaultsMinted);

    // emit the event
    emit NewVault(_vaultAddress, vaultsMinted, _msgSender());
    // return the vault address, allowing the caller to automatically find their vault
    return _vaultAddress;
  }

  /// @notice pause the contract
  function pause() external override onlyPauser {
    _pause();
  }

  /// @notice unpause the contract
  function unpause() external override onlyPauser {
    _unpause();
  }

  /// @notice register the USDA contract
  /// @param _usdaAddress address to register as USDA
  function registerUSDA(address _usdaAddress) external override onlyOwner {
    usda = IUSDA(_usdaAddress);
  }

  /// @notice get oraclemaster address
  /// @return _oracleMasterAddress the address
  function getOracleMaster() external view override returns (address _oracleMasterAddress) {
    return address(oracleMaster);
  }

  /// @notice register the OracleMaster contract
  /// @param _masterOracleAddress address to register as OracleMaster
  function registerOracleMaster(address _masterOracleAddress) external override onlyOwner {
    oracleMaster = OracleMaster(_masterOracleAddress);
    emit RegisterOracleMaster(_masterOracleAddress);
  }

  /// @notice register the CurveMaster address
  /// @param _masterCurveAddress address to register as CurveMaster
  function registerCurveMaster(address _masterCurveAddress) external override onlyOwner {
    curveMaster = CurveMaster(_masterCurveAddress);
    emit RegisterCurveMaster(_masterCurveAddress);
  }

  /// @notice update the protocol fee
  /// @param _newProtocolFee protocol fee in terms of 1e18=100%
  function changeProtocolFee(uint192 _newProtocolFee) external override onlyOwner {
    if (_newProtocolFee >= 1e18) revert VaultController_FeeTooLarge();
    protocolFee = _newProtocolFee;
    emit NewProtocolFee(_newProtocolFee);
  }

  /// @notice register a new token to be used as collateral
  /// @param _tokenAddress token to register
  /// @param _ltv LTV of the token, 1e18=100%
  /// @param _oracleAddress address of the token which should be used when querying oracles
  /// @param _liquidationIncentive liquidation penalty for the token, 1e18=100%
  function registerErc20(
    address _tokenAddress,
    uint256 _ltv,
    address _oracleAddress,
    uint256 _liquidationIncentive
  ) external override onlyOwner {
    // the oracle must be registered & the token must be unregistered
    if (oracleMaster.relays(_oracleAddress) == address(0)) revert VaultController_OracleNotRegistered();
    if (tokenAddressTokenId[_tokenAddress] != 0) revert VaultController_TokenAlreadyRegistered();
    //LTV must be compatible with liquidation incentive
    if (_ltv >= (EXP_SCALE - _liquidationIncentive)) revert VaultController_LTVIncompatible();
    // increment the amount of registered token
    tokensRegistered = tokensRegistered + 1;
    // set & give the token an id
    tokenAddressTokenId[_tokenAddress] = tokensRegistered;
    // set the token's oracle
    tokenIdOracleAddress[tokensRegistered] = _oracleAddress;
    // set the token's ltv
    tokenIdTokenLTV[tokensRegistered] = _ltv;
    // set the token's liquidation incentive
    tokenAddressLiquidationIncentive[_tokenAddress] = _liquidationIncentive;
    // finally, add the token to the array of enabled tokens
    enabledTokens.push(_tokenAddress);
    emit RegisteredErc20(_tokenAddress, _ltv, _oracleAddress, _liquidationIncentive);
  }

  /// @notice update an existing collateral with new collateral parameters
  /// @param _tokenAddress the token to modify
  /// @param _ltv new loan-to-value of the token, 1e18=100%
  /// @param _oracleAddress new oracle to attach to the token
  /// @param _liquidationIncentive new liquidation penalty for the token, 1e18=100%
  function updateRegisteredErc20(
    address _tokenAddress,
    uint256 _ltv,
    address _oracleAddress,
    uint256 _liquidationIncentive
  ) external override onlyOwner {
    // the oracle and token must both exist and be registerd
    if (oracleMaster.relays(_oracleAddress) == address(0)) revert VaultController_OracleNotRegistered();
    if (tokenAddressTokenId[_tokenAddress] == 0) revert VaultController_TokenNotRegistered();
    // we know the token has been registered, get the Id
    uint256 _tokenId = tokenAddressTokenId[_tokenAddress];
    //_ltv must be compatible with liquidation incentive
    if (_ltv >= (EXP_SCALE - _liquidationIncentive)) revert VaultController_LTVIncompatible();
    // set the oracle of the token
    tokenIdOracleAddress[_tokenId] = _oracleAddress;
    // set the ltv of the token
    tokenIdTokenLTV[_tokenId] = _ltv;
    // set the liquidation incentive of the token
    tokenAddressLiquidationIncentive[_tokenAddress] = _liquidationIncentive;

    emit UpdateRegisteredErc20(_tokenAddress, _ltv, _oracleAddress, _liquidationIncentive);
  }

  /// @notice check an vault for over-collateralization. returns false if amount borrowed is greater than borrowing power.
  /// @param _id the vault to check
  /// @return _overCollateralized true if vault over-collateralized false if not
  function checkVault(uint96 _id) public view override returns (bool _overCollateralized) {
    // grab the vault by id if part of our system. revert if not
    IVault _vault = _getVault(_id);
    // calculate the total value of the vault's liquidity
    uint256 _totalLiquidityValue = _getVaultBorrowingPower(_vault);
    // calculate the total liability of the vault
    uint256 _usdaLiability = _truncate((_vault.baseLiability() * interest.factor));
    // if the LTV >= liability, the vault is solvent
    return (_totalLiquidityValue >= _usdaLiability);
  }

  /// @notice borrow USDA from a vault. only vault minter may borrow from their vault
  /// @param _id vault to borrow against
  /// @param _amount amount of USDA to borrow
  function borrowUSDA(uint96 _id, uint192 _amount) external override {
    _borrowUSDA(_id, _amount, _msgSender());
  }

  /// @notice borrow USDA from a vault and send the USDA to a specific address
  /// @notice Only vault minter may borrow from their vault
  /// @param _id vault to borrow against
  /// @param _amount amount of USDA to borrow
  /// @param _target address to receive borrowed USDA
  function borrowUSDAto(uint96 _id, uint192 _amount, address _target) external override {
    _borrowUSDA(_id, _amount, _target);
  }

  /// @notice business logic to perform the USDA loan
  /// @param _id vault to borrow against
  /// @param _amount amount of USDA to borrow
  /// @param _target address to receive borrowed USDA
  /// @dev pays interest
  function _borrowUSDA(uint96 _id, uint192 _amount, address _target) internal paysInterest whenNotPaused {
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
    // now get the LTV of the vault, aka their borrowing power, in usda
    uint256 _totalLiquidityValue = _getVaultBorrowingPower(_vault);
    // the LTV must be above the newly calculated _usdaLiability, else revert
    if (_totalLiquidityValue < _usdaLiability) revert VaultController_VaultInsolvent();
    // now send usda to the target, equal to the amount they are owed
    usda.vaultControllerMint(_target, _amount);
    // emit the event
    emit BorrowUSDA(_id, address(_vault), _amount);
  }

  /// @notice borrow sUSD directly from reserve
  /// @notice liability is still in USDA, and USDA must be repaid
  /// @param _id vault to borrow against
  /// @param _susdAmount amount of sUSD to borrow
  /// @param _target address to receive borrowed sUSD
  function borrowsUSDto(uint96 _id, uint192 _susdAmount, address _target) external override paysInterest whenNotPaused {
    // grab the vault by id if part of our system. revert if not
    IVault _vault = _getVault(_id);
    // only the minter of the vault may borrow from their vault
    if (_msgSender() != _vault.minter()) revert VaultController_OnlyMinter();
    // the base amount is the amount of USDA they wish to borrow divided by the interest factor
    uint192 _baseAmount = _safeu192(uint256(_susdAmount * EXP_SCALE) / uint256(interest.factor));
    // _baseLiability should contain the vault's new liability, in terms of base units
    // true indicates that we are adding to the liability
    uint256 _baseLiability = _vault.modifyLiability(true, _baseAmount);
    // increase the total base liability by the _baseAmount
    // the same amount we added to the vault's liability
    totalBaseLiability = totalBaseLiability + _safeu192(_baseAmount);
    // now take the vault's total base liability and multiply it by the interest factor
    uint256 _usdaLiability = _truncate(uint256(interest.factor) * _baseLiability);
    // now get the LTV of the vault, aka their borrowing power, in usda
    uint256 _totalLiquidityValue = _getVaultBorrowingPower(_vault);
    // the LTV must be above the newly calculated _usdaLiability, else revert
    if (_totalLiquidityValue < _usdaLiability) revert VaultController_VaultInsolvent();
    // emit the event
    emit BorrowUSDA(_id, address(_vault), _susdAmount);
    //send sUSD to the target from reserve instead of mint
    usda.vaultControllerTransfer(_target, _susdAmount);
  }

  /// @notice repay a vault's USDA loan. anyone may repay
  /// @param _id vault to repay
  /// @param _amount amount of USDA to repay
  /// @dev pays interest
  function repayUSDA(uint96 _id, uint192 _amount) external override paysInterest whenNotPaused {
    // grab the vault by id if part of our system. revert if not
    IVault _vault = _getVault(_id);
    // the base amount is the amount of USDA entered divided by the interest factor
    uint192 _baseAmount = _safeu192((_amount * EXP_SCALE) / interest.factor);
    // decrease the total base liability by the calculated base amount
    totalBaseLiability = totalBaseLiability - _baseAmount;
    // ensure that _baseAmount is lower than the vault's base liability.
    // this may not be needed, since modifyLiability *should* revert if is not true
    if (_baseAmount > _vault.baseLiability()) revert VaultController_RepayTooMuch(); //repay all here if true?
    // decrease the vault's liability by the calculated base amount
    _vault.modifyLiability(false, _baseAmount);
    // burn the amount of USDA submitted from the sender
    usda.vaultControllerBurn(_msgSender(), _amount);
    // emit the event
    emit RepayUSDA(_id, address(_vault), _amount);
  }

  /// @notice repay all of a vault's USDA. anyone may repay a vault's liabilities
  /// @param _id the vault to repay
  /// @dev pays interest
  function repayAllUSDA(uint96 _id) external override paysInterest whenNotPaused {
    // grab the vault by id if part of our system. revert if not
    IVault _vault = _getVault(_id);
    //store the vault baseLiability in memory
    uint256 _baseLiability = _vault.baseLiability();
    // get the total USDA liability, equal to the interest factor * vault's base liabilty
    //uint256 _usdaLiability = _truncate(_safeu192(interest.factor * vault.baseLiability()));
    uint256 _usdaLiability = uint256(_safeu192(_truncate(interest.factor * _baseLiability)));
    // decrease the total base liability by the vault's base liability
    totalBaseLiability = totalBaseLiability - _safeu192(_baseLiability);
    // decrease the vault's liability by the vault's base liability
    _vault.modifyLiability(false, _baseLiability);
    // burn the amount of USDA paid back from the vault
    usda.vaultControllerBurn(_msgSender(), _usdaLiability);

    emit RepayUSDA(_id, address(_vault), _usdaLiability);
  }

  /// @notice liquidate an underwater vault
  /// @notice vaults may be liquidated up to the point where they are exactly solvent
  /// @param _id the vault to liquidate
  /// @param _assetAddress the token the liquidator wishes to liquidate
  /// @param _tokensToLiquidate  number of tokens to liquidate
  /// @return _toLiquidate the amount of tokens to liquidate
  /// @dev pays interest before liquidation
  function liquidateVault(
    uint96 _id,
    address _assetAddress,
    uint256 _tokensToLiquidate
  ) external override paysInterest whenNotPaused returns (uint256 _toLiquidate) {
    //cannot liquidate 0
    if (_tokensToLiquidate == 0) revert VaultController_LiquidateZeroTokens();
    //check for registered asset - audit L3
    if (tokenAddressTokenId[_assetAddress] == 0) revert VaultController_TokenNotRegistered();

    // calculate the amount to liquidate and the 'bad fill price' using liquidationMath
    // see _liquidationMath for more detailed explaination of the math
    (uint256 _tokenAmount, uint256 _badFillPrice) = _liquidationMath(_id, _assetAddress, _tokensToLiquidate);
    // set _tokensToLiquidate to this calculated amount if the function does not fail
    if (_tokenAmount != 0) _tokensToLiquidate = _tokenAmount;
    // the USDA to repurchase is equal to the bad fill price multiplied by the amount of tokens to liquidate
    uint256 _usdaToRepurchase = _truncate(_badFillPrice * _tokensToLiquidate);
    // get the vault that the liquidator wishes to liquidate
    IVault _vault = _getVault(_id);

    //decrease the vault's liability
    _vault.modifyLiability(false, (_usdaToRepurchase * 1e18) / interest.factor);

    // decrease the total base liability
    totalBaseLiability = totalBaseLiability - _safeu192((_usdaToRepurchase * 1e18) / interest.factor);

    //decrease liquidator's USDA balance
    usda.vaultControllerBurn(_msgSender(), _usdaToRepurchase);

    // finally, deliver tokens to liquidator
    _vault.controllerTransfer(_assetAddress, _msgSender(), _tokensToLiquidate);

    // this mainly prevents reentrancy
    if (_getVaultBorrowingPower(_vault) > _vaultLiability(_id)) revert VaultController_OverLiquidation();

    // emit the event
    emit Liquidate(_id, _assetAddress, _usdaToRepurchase, _tokensToLiquidate);
    // return the amount of tokens liquidated
    return _tokensToLiquidate;
  }

  /// @notice calculate amount of tokens to liquidate for a vault
  /// @param _id the vault to get info for
  /// @param _assetAddress the token to calculate how many tokens to liquidate
  /// @return _tokensToLiquidate amount of tokens liquidatable
  /// @notice the amount of tokens owed is a moving target and changes with each block as _payInterest is called
  /// @notice this function can serve to give an indication of how many tokens can be liquidated
  /// @dev all this function does is call _liquidationMath with 2**256-1 as the amount
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

    //get price of asset scaled to decimal 18
    uint256 _price = oracleMaster.getLivePrice(_assetAddress);

    // get price discounted by liquidation penalty
    // price * (100% - liquidationIncentive)
    _badFillPrice = _truncate(_price * (1e18 - tokenAddressLiquidationIncentive[_assetAddress]));

    // the ltv discount is the amount of collateral value that one token provides
    uint256 _ltvDiscount = _truncate(_price * tokenIdTokenLTV[tokenAddressTokenId[_assetAddress]]);
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

  /// @notice amount of USDA needed to reach even solvency
  /// @notice this amount is a moving target and changes with each block as _payInterest is called
  /// @param _id id of vault
  /// @return _usdaToSolvency amount of USDA needed to reach even solvency
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

  /// @notice bussiness logic for vaultLiability
  /// @param _id id of vault
  function _vaultLiability(uint96 _id) internal view returns (uint192 _liability) {
    address _vaultAddress = vaultIdVaultAddress[_id];
    if (_vaultAddress == address(0)) revert VaultController_VaultDoesNotExist();
    IVault _vault = IVault(_vaultAddress);
    return _safeu192(_truncate(_vault.baseLiability() * interest.factor));
  }

  /// @notice get vault borrowing power for vault
  /// @param _id id of vault
  /// @return _borrowPower amount of USDA the vault can borrow
  /// @dev implementation in _getVaultBorrowingPower
  function vaultBorrowingPower(uint96 _id) external view override returns (uint192 _borrowPower) {
    return _getVaultBorrowingPower(_getVault(_id));
  }

  /// @notice returns the borrowing power of a vault
  /// @param _vault the vault to get the borrowing power of
  /// @return _borrowPower the borrowing power of the vault
  //solhint-disable-next-line code-complexity
  function _getVaultBorrowingPower(IVault _vault) private view returns (uint192 _borrowPower) {
    // loop over each registed token, adding the indivuduals LTV to the total LTV of the vault
    for (uint192 _i = 1; _i <= tokensRegistered; ++_i) {
      // if the ltv is 0, continue
      if (tokenIdTokenLTV[_i] == 0) continue;
      // get the address of the token through the array of enabled tokens
      // note that index 0 of enabledTokens corresponds to a vaultId of 1, so we must subtract 1 from i to get the correct index
      address _tokenAddress = enabledTokens[_i - 1];
      // the balance is the vault's token balance of the current collateral token in the loop
      uint256 _balance = _vault.tokenBalance(_tokenAddress);
      if (_balance == 0) continue;
      // the raw price is simply the oraclemaster price of the token
      uint192 _rawPrice = _safeu192(oracleMaster.getLivePrice(_tokenAddress));
      if (_rawPrice == 0) continue;
      // the token value is equal to the price * balance * tokenLTV
      uint192 _tokenValue = _safeu192(_truncate(_truncate(_rawPrice * _balance * tokenIdTokenLTV[_i])));
      // increase the LTV of the vault by the token value
      _borrowPower = _borrowPower + _tokenValue;
    }
  }

  /// @notice calls the pay interest function
  /// @dev implementation in _payInterest
  /// @return _interest the interest to distribute to USDA holders
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

  /// special view only function to help liquidators

  /// @notice helper function to view the status of a range of vaults
  /// @param _start the vault to start looping
  /// @param _stop the vault to stop looping
  /// @return _vaultSummaries a collection of vault information
  function vaultSummaries(
    uint96 _start,
    uint96 _stop
  ) public view override returns (VaultSummary[] memory _vaultSummaries) {
    VaultSummary[] memory _summaries = new VaultSummary[](_stop - _start + 1);
    for (uint96 _i = _start; _i <= _stop; _i++) {
      IVault _vault = _getVault(_i);
      uint256[] memory _tokenBalances = new uint256[](enabledTokens.length);

      for (uint256 _j = 0; _j < enabledTokens.length; _j++) {
        _tokenBalances[_j] = _vault.tokenBalance(enabledTokens[_j]);
      }
      _summaries[_i - _start] =
        VaultSummary(_i, this.vaultBorrowingPower(_i), this.vaultLiability(_i), enabledTokens, _tokenBalances);
    }
    return _summaries;
  }
}
