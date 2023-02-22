// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {ICappedToken} from '@interfaces/utils/ICappedToken.sol';

/// @title CappedToken
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract CappedToken is ICappedToken, Initializable, OwnableUpgradeable, ERC20Upgradeable {
    IERC20Metadata public _underlying;
    uint8 private _underlying_decimals;

    /// @notice CAP is in units of the CAP token,so 18 decimals.
    ///         not the underlying!!!!!!!!!
    uint256 public _cap;

    /// @notice initializer for contract
    /// @param name_ name of capped token
    /// @param symbol_ symbol of capped token
    /// @param underlying_ the address of underlying
    function initialize(string memory name_, string memory symbol_, address underlying_) public initializer {
        __Ownable_init();
        __ERC20_init(name_, symbol_);
        _underlying = IERC20Metadata(underlying_);
        _underlying_decimals = _underlying.decimals();
    }

    /// @notice 18 decimal erc20 spec should have been written into the fucking standard
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /// @notice get the Cap
    /// @return cap uint256
    function getCap() public view returns (uint256) {
        return _cap;
    }

    /// @notice set the Cap
    function setCap(uint256 cap_) external onlyOwner {
        _cap = cap_;
    }

    function checkCap(uint256 amount_) internal view {
        if (ERC20Upgradeable.totalSupply() + amount_ > _cap) revert CappedToken_CapReached();
    }

    function underlyingScalar() public view returns (uint256) {
        return (10 ** (18 - _underlying_decimals));
    }

    /// @notice get underlying ratio
    /// @return amount amount of this CappedToken
    function underlyingToCappedAmount(uint256 underlying_amount) internal view returns (uint256 amount) {
        amount = underlying_amount * underlyingScalar();
    }

    function cappedAmountToUnderlying(uint256 underlying_amount) internal view returns (uint256 amount) {
        amount = underlying_amount / underlyingScalar();
    }

    /// @notice deposit _underlying to mint CappedToken
    /// @param underlying_amount amount of underlying to deposit
    /// @param target recipient of tokens
    function deposit(uint256 underlying_amount, address target) public {
        // scale the decimals to THIS token decimals, or 1e18. see underlyingToCappedAmount
        uint256 amount = underlyingToCappedAmount(underlying_amount);
        if (amount == 0) revert CappedToken_ZeroAmount();
        // check cap
        checkCap(amount);
        // mint the scaled amount of tokens to the TARGET
        ERC20Upgradeable._mint(target, amount);
        // transfer underlying from SENDER to THIS
        if (!_underlying.transferFrom(_msgSender(), address(this), underlying_amount)) {
            revert CappedToken_TransferFailed();
        }
    }

    /// @notice withdraw underlying by burning THIS token
    /// caller should obtain 1 underlying for every underlyingScalar() THIS token
    /// @param underlying_amount amount of underlying to withdraw
    function withdraw(uint256 underlying_amount, address target) public {
        // scale the underlying_amount to the THIS token decimal amount, aka 1e18
        uint256 amount = underlyingToCappedAmount(underlying_amount);
        if (amount == 0) revert CappedToken_ZeroAmount();
        // burn the scaled amount of tokens from the SENDER
        ERC20Upgradeable._burn(_msgSender(), amount);
        // transfer underlying to the TARGET
        if (!_underlying.transfer(target, underlying_amount)) revert CappedToken_TransferFailed();
    }

    // EIP-4626 compliance, sorry it's not the most gas efficient.

    function underlyingAddress() external view returns (address) {
        return address(_underlying);
    }

    function totalUnderlying() public view returns (uint256) {
        return _underlying.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return underlyingToCappedAmount(assets);
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return cappedAmountToUnderlying(shares);
    }

    function maxDeposit(address receiver) public view returns (uint256) {
        uint256 remaining = (_cap - underlyingToCappedAmount(totalUnderlying()));
        uint256 _receiverBalance = underlyingToCappedAmount(_underlying.balanceOf(receiver));
        if (remaining > _receiverBalance) return _receiverBalance;
        return remaining;
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return underlyingToCappedAmount(assets);
    }

    function maxMint(address receiver) external view returns (uint256) {
        return cappedAmountToUnderlying(maxDeposit(receiver));
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        return cappedAmountToUnderlying(shares);
    }

    function mint(uint256 shares, address receiver) external {
        return deposit(cappedAmountToUnderlying(shares), receiver);
    }

    function maxWithdraw(address receiver) public view returns (uint256) {
        uint256 receiver_can = cappedAmountToUnderlying(ERC20Upgradeable.balanceOf(receiver));
        if (receiver_can > _underlying.balanceOf(address(this))) return _underlying.balanceOf(address(this));
        return receiver_can;
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return underlyingToCappedAmount(assets);
    }

    function maxRedeem(address receiver) external view returns (uint256) {
        return underlyingToCappedAmount(maxWithdraw(receiver));
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return cappedAmountToUnderlying(shares);
    }

    function redeem(uint256 shares, address receiver) external {
        return withdraw(cappedAmountToUnderlying(shares), receiver);
    }
}
