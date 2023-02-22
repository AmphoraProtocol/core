// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

interface ICappedToken {
    /*///////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when a deposit surpass the cap
     */
    error CappedToken_CapReached();

    /**
     * @notice Thrown when trying to deposit or withdraw zero amount
     */
    error CappedToken_ZeroAmount();

    /**
     * @notice Thrown when a transfer fails
     */
    error CappedToken_TransferFailed();

    /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

    function _underlying() external view returns (IERC20Metadata underlying);

    function _cap() external view returns (uint256 cap);

    /*///////////////////////////////////////////////////////////////
                              LOGIC
    //////////////////////////////////////////////////////////////*/

    function initialize(string memory name_, string memory symbol_, address underlying_) external;

    function getCap() external view returns (uint256 _cap);

    function underlyingScalar() external view returns (uint256 _underlyingScalar);

    function deposit(uint256 underlying_amount, address target) external;

    function withdraw(uint256 underlying_amount, address target) external;

    function underlyingAddress() external view returns (address _underlyingAddress);

    function totalUnderlying() external view returns (uint256 _totalUnderlying);

    function convertToShares(uint256 assets) external view returns (uint256 _shares);

    function convertToAssets(uint256 shares) external view returns (uint256 _assets);

    function maxDeposit(address receiver) external view returns (uint256 _maxDeposit);

    function previewDeposit(uint256 assets) external view returns (uint256 _shares);

    function maxMint(address receiver) external view returns (uint256 _assets);

    function previewMint(uint256 shares) external view returns (uint256 _assets);

    function mint(uint256 shares, address receiver) external;

    function maxWithdraw(address receiver) external view returns (uint256 _shares);

    function previewWithdraw(uint256 assets) external view returns (uint256 _shares);

    function maxRedeem(address receiver) external view returns (uint256 _assets);

    function previewRedeem(uint256 shares) external view returns (uint256 _assets);

    function redeem(uint256 shares, address receiver) external;
}
