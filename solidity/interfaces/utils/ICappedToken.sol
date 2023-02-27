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

  function underlying() external view returns (IERC20Metadata _underlying);

  function cap() external view returns (uint256 _cap);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
    //////////////////////////////////////////////////////////////*/

  function initialize(string memory _name, string memory _symbol, address _underlying) external;

  function underlyingScalar() external view returns (uint256 _underlyingScalar);

  function deposit(uint256 _underlyingAmount, address _target) external;

  function withdraw(uint256 _underlyingAmount, address _target) external;

  function underlyingAddress() external view returns (address _underlyingAddress);

  function totalUnderlying() external view returns (uint256 _totalUnderlying);

  function convertToShares(uint256 _assets) external view returns (uint256 _shares);

  function convertToAssets(uint256 _shares) external view returns (uint256 _assets);

  function maxDeposit(address _receiver) external view returns (uint256 _maxDeposit);

  function previewDeposit(uint256 _assets) external view returns (uint256 _shares);

  function maxMint(address _receiver) external view returns (uint256 _assets);

  function previewMint(uint256 _shares) external view returns (uint256 _assets);

  function mint(uint256 _shares, address _receiver) external;

  function maxWithdraw(address _receiver) external view returns (uint256 _shares);

  function previewWithdraw(uint256 _assets) external view returns (uint256 _shares);

  function maxRedeem(address _receiver) external view returns (uint256 _assets);

  function previewRedeem(uint256 _shares) external view returns (uint256 _assets);

  function redeem(uint256 _shares, address _receiver) external;
}
