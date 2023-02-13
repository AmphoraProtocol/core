// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20Detailed} from '@contracts/_external/ERC20Detailed.sol';
import {ExponentialNoError} from '@contracts/_external/ExponentialNoError.sol';
import {UFragments} from '@contracts/utils/UFragments.sol';

import {IUSDA} from '@interfaces/core/IUSDA.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

/// @title USDA token contract
/// @notice handles all minting/burning of usda
/// @dev extends UFragments
contract USDA is Initializable, PausableUpgradeable, UFragments, IUSDA, ExponentialNoError {
    IERC20 public _reserve;
    IVaultController public _VaultController;

    address public _pauser;

    /// @notice checks if _msgSender() is VaultController
    modifier onlyVaultController() {
        require(_msgSender() == address(_VaultController), 'only VaultController');
        _;
    }

    /// @notice checks if _msgSender() is pauser
    modifier onlyPauser() {
        require(_msgSender() == address(_pauser), 'only pauser');
        _;
    }

    /// @notice any function with this modifier will call the pay_interest() function before any function logic is called
    modifier paysInterest() {
        _VaultController.calculateInterest();
        _;
    }

    /// @notice initializer for contract
    /// @param reserveAddr the address of sUSD
    /// @dev consider adding decimals?
    function initialize(address reserveAddr) public override initializer {
        __UFragments_init('USDA Token', 'USDA');
        __Pausable_init();
        _reserve = IERC20(reserveAddr);
    }

    ///@notice sets the pauser for both USDA and VaultController
    ///@notice the pauser is a separate role from the owner
    function setPauser(address pauser_) external override onlyOwner {
        _pauser = pauser_;
    }

    /// @notice pause contract, pauser only
    function pause() external override onlyPauser {
        _pause();
    }

    /// @notice unpause contract, pauser only
    function unpause() external override onlyPauser {
        _unpause();
    }

    ///@notice gets the pauser for both USDA and VaultController
    function pauser() public view returns (address) {
        return _pauser;
    }

    ///@notice gets the owner of the USDA contract
    function owner() public view override(IUSDA, OwnableUpgradeable) returns (address) {
        return super.owner();
    }

    /// @notice getter for name
    /// @return name of token
    function name() public view override(IERC20Metadata, ERC20Detailed) returns (string memory) {
        return super.name();
    }

    /// @notice getter for symbol
    /// @return symbol for token
    function symbol() public view override(IERC20Metadata, ERC20Detailed) returns (string memory) {
        return super.symbol();
    }

    /// @notice getter for decimals
    /// @return decimals for token
    function decimals() public view override(IERC20Metadata, ERC20Detailed) returns (uint8) {
        return super.decimals();
    }

    /// @notice getter for address of the reserve currency, or susd
    /// @return decimals for of reserve currency
    function reserveAddress() public view override returns (address) {
        return address(_reserve);
    }

    /// @notice get the VaultController addr
    /// @return vaultcontroller addr
    function getVaultController() public view override returns (address) {
        return address(_VaultController);
    }

    /// @notice set the VaultController addr so that vault_master may mint/burn USDA without restriction
    /// @param vault_master_address address of vault master
    function setVaultController(address vault_master_address) external override onlyOwner {
        _VaultController = IVaultController(vault_master_address);
    }

    /// @notice deposit sUSD to mint USDA
    /// @dev caller should obtain 1e12 USDA for each sUSD
    /// the calculations for deposit mimic the calculations done by mint in the ampleforth contract, simply with the susd transfer
    /// "fragments" are the units that we see, so 1000 fragments == 1000 USDA
    /// "gons" are the internal accounting unit, used to keep scale.
    /// we use the variable _gonsPerFragment in order to convert between the two
    /// try dimensional analysis when doing the math in order to verify units are correct
    /// @param susd_amount amount of sUSD to deposit
    function deposit(uint256 susd_amount) external override {
        _deposit(susd_amount, _msgSender());
    }

    function depositTo(uint256 susd_amount, address target) external override {
        _deposit(susd_amount, target);
    }

    function _deposit(uint256 susd_amount, address target) internal paysInterest whenNotPaused {
        // scale the susd_amount to the usda decimal amount, aka 1e18. since susd is 6 decimals, we multiply by 1e12
        uint256 amount = susd_amount * 1e12;
        require(amount > 0, 'Cannot deposit 0');
        // check allowance and ensure transfer success
        uint256 allowance = _reserve.allowance(_msgSender(), address(this));
        require(allowance >= susd_amount, 'Insufficient Allowance');
        require(_reserve.transferFrom(_msgSender(), address(this), susd_amount), 'transfer failed');
        // the gonbalances of the sender is in gons, therefore we must multiply the deposit amount, which is in fragments, by gonsperfragment
        _gonBalances[target] = _gonBalances[target] + amount * _gonsPerFragment;
        // total supply is in fragments, and so we add amount
        _totalSupply = _totalSupply + amount;
        // and totalgons of course is in gons, and so we multiply amount by gonsperfragment to get the amount of gons we must add to totalGons
        _totalGons = _totalGons + amount * _gonsPerFragment;

        emit Transfer(address(0), target, amount);
        emit Deposit(target, amount);
    }

    /// @notice withdraw sUSD by burning USDA
    /// caller should obtain 1 sUSD for every 1e12 USDA
    /// @param susd_amount amount of sUSD to withdraw
    function withdraw(uint256 susd_amount) external override {
        _withdraw(susd_amount, _msgSender());
    }

    ///@notice withdraw sUSD to a specific address by burning USDA from the caller
    /// target should obtain 1 sUSD for every 1e12 USDA burned from the caller
    /// @param susd_amount amount of sUSD to withdraw
    /// @param target address to receive the sUSD
    function withdrawTo(uint256 susd_amount, address target) external override {
        _withdraw(susd_amount, target);
    }

    ///@notice business logic to withdraw sUSD and burn USDA from the caller
    function _withdraw(uint256 susd_amount, address target) internal paysInterest whenNotPaused {
        // scale the susd_amount to the USDA decimal amount, aka 1e18
        uint256 amount = susd_amount * 1e12;
        // check balances all around
        require(amount <= this.balanceOf(_msgSender()), 'insufficient funds');
        require(amount > 0, 'Cannot withdraw 0');
        uint256 balance = _reserve.balanceOf(address(this));
        require(balance >= susd_amount, 'Insufficient Reserve in Bank');
        // ensure transfer success
        require(_reserve.transfer(target, susd_amount), 'transfer failed');
        // modify the gonbalances of the sender, subtracting the amount of gons, therefore amount*gonsperfragment
        _gonBalances[_msgSender()] = _gonBalances[_msgSender()] - amount * _gonsPerFragment;
        // modify totalSupply and totalGons
        _totalSupply = _totalSupply - amount;
        _totalGons = _totalGons - amount * _gonsPerFragment;
        // emit both a Withdraw and transfer event
        emit Transfer(_msgSender(), address(0), amount);
        emit Withdraw(target, amount);
    }

    /// @notice withdraw sUSD by burning USDA
    /// caller should obtain 1 sUSD for every 1e12 USDA
    /// this function is effectively just withdraw, but we calculate the amount for the sender
    function withdrawAll() external override {
        _withdrawAll(_msgSender());
    }

    /// @notice withdraw sUSD by burning USDA
    /// @param target should obtain 1 sUSD for every 1e12 USDA burned from caller
    /// this function is effectively just withdraw, but we calculate the amount for the target
    function withdrawAllTo(address target) external override {
        _withdrawAll(target);
    }

    /// @notice business logic for withdrawAll
    /// @param target should obtain 1 sUSD for every 1e12 USDA burned from caller
    /// this function is effectively just withdraw, but we calculate the amount for the target
    function _withdrawAll(address target) internal paysInterest whenNotPaused {
        uint256 reserve = _reserve.balanceOf(address(this));
        require(reserve != 0, 'Reserve is empty');
        uint256 susd_amount = (this.balanceOf(_msgSender())) / 1e12;
        //user's USDA value is more than reserve
        if (susd_amount > reserve) susd_amount = reserve;
        uint256 amount = susd_amount * 1e12;
        require(_reserve.transfer(target, susd_amount), 'transfer failed');
        // see comments in the withdraw function for an explaination of this math
        _gonBalances[_msgSender()] = _gonBalances[_msgSender()] - (amount * _gonsPerFragment);
        _totalSupply = _totalSupply - amount;
        _totalGons = _totalGons - (amount * _gonsPerFragment);
        // emit both a Withdraw and transfer event
        emit Transfer(_msgSender(), address(0), amount);
        emit Withdraw(target, amount);
    }

    /// @notice admin function to mint USDA
    /// @param susd_amount the amount of USDA to mint, denominated in sUSD
    function mint(uint256 susd_amount) external override paysInterest onlyOwner {
        require(susd_amount != 0, 'Cannot mint 0');
        uint256 amount = susd_amount * 1e12;
        // see comments in the deposit function for an explaination of this math
        _gonBalances[_msgSender()] = _gonBalances[_msgSender()] + amount * _gonsPerFragment;
        _totalSupply = _totalSupply + amount;
        _totalGons = _totalGons + amount * _gonsPerFragment;
        // emit both a mint and transfer event
        emit Transfer(address(0), _msgSender(), amount);
        emit Mint(_msgSender(), amount);
    }

    /// @notice admin function to burn USDA
    /// @param susd_amount the amount of USDA to burn, denominated in sUSD
    function burn(uint256 susd_amount) external override paysInterest onlyOwner {
        require(susd_amount != 0, 'Cannot burn 0');
        uint256 amount = susd_amount * 1e12;
        // see comments in the deposit function for an explaination of this math
        _gonBalances[_msgSender()] = _gonBalances[_msgSender()] - amount * _gonsPerFragment;
        _totalSupply = _totalSupply - amount;
        _totalGons = _totalGons - amount * _gonsPerFragment;
        // emit both a mint and transfer event
        emit Transfer(_msgSender(), address(0), amount);
        emit Burn(_msgSender(), amount);
    }

    /// @notice donates susd to the protocol reserve
    /// @param susd_amount the amount of sUSD to donate
    function donate(uint256 susd_amount) external override paysInterest whenNotPaused {
        uint256 amount = susd_amount * 1e12;
        require(amount > 0, 'Cannot deposit 0');
        uint256 allowance = _reserve.allowance(_msgSender(), address(this));
        require(allowance >= susd_amount, 'Insufficient Allowance');
        require(_reserve.transferFrom(_msgSender(), address(this), susd_amount), 'transfer failed');
        _donation(amount);
    }

    /// @notice donates any sUSD held by this contract to the USDA holders
    /// @notice accounts for any sUSD that may have been sent here accidently
    /// @notice without this, any sUSD sent to the contract could mess up the reserve ratio
    function donateReserve() external override onlyOwner whenNotPaused {
        uint256 totalsUSD = (_reserve.balanceOf(address(this))) * 1e12;
        uint256 totalLiability = truncate(_VaultController.totalBaseLiability() * _VaultController.interestFactor());
        require((totalsUSD + totalLiability) > _totalSupply, 'No extra reserve');

        _donation((totalsUSD + totalLiability) - _totalSupply);
    }

    /// @notice function for the vaultController to mint
    /// @param target whom to mint the USDA to
    /// @param amount the amount of USDA to mint
    function vaultControllerMint(address target, uint256 amount) external override onlyVaultController {
        // see comments in the deposit function for an explaination of this math
        _gonBalances[target] = _gonBalances[target] + amount * _gonsPerFragment;
        _totalSupply = _totalSupply + amount;
        _totalGons = _totalGons + amount * _gonsPerFragment;
        emit Transfer(address(0), target, amount);
        emit Mint(target, amount);
    }

    /// @notice function for the vaultController to burn
    /// @param target whom to burn the USDA from
    /// @param amount the amount of USDA to burn
    function vaultControllerBurn(address target, uint256 amount) external override onlyVaultController {
        require(_gonBalances[target] > (amount * _gonsPerFragment), 'USDA: not enough balance');
        // see comments in the withdraw function for an explaination of this math
        _gonBalances[target] = _gonBalances[target] - amount * _gonsPerFragment;
        _totalSupply = _totalSupply - amount;
        _totalGons = _totalGons - amount * _gonsPerFragment;
        emit Transfer(target, address(0), amount);
        emit Burn(target, amount);
    }

    /// @notice Allows VaultController to send sUSD from the reserve
    /// @param target whom to receive the sUSD from reserve
    /// @param susd_amount the amount of sUSD to send
    function vaultControllerTransfer(address target, uint256 susd_amount) external override onlyVaultController {
        // ensure transfer success
        require(_reserve.transfer(target, susd_amount), 'transfer failed');
    }

    /// @notice function for the vaultController to scale all USDA balances
    /// @param amount amount of USDA (e18) to donate
    function vaultControllerDonate(uint256 amount) external override onlyVaultController {
        _donation(amount);
    }

    /// @notice function for distributing the donation to all USDA holders
    /// @param amount amount of USDA to donate
    function _donation(uint256 amount) internal {
        _totalSupply = _totalSupply + amount;
        if (_totalSupply > MAX_SUPPLY) _totalSupply = MAX_SUPPLY;
        _gonsPerFragment = _totalGons / _totalSupply;
        emit Donation(_msgSender(), amount, _totalSupply);
    }

    /// @notice get reserve ratio
    /// @return e18_reserve_ratio USDA reserve ratio
    function reserveRatio() external view override returns (uint192 e18_reserve_ratio) {
        e18_reserve_ratio = safeu192(((_reserve.balanceOf(address(this)) * expScale) / _totalSupply) * 1e12);
    }
}
