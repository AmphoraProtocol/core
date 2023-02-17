// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title Vault Interface
interface IVault {
    event Deposit(address token_address, uint256 amount);
    event Withdraw(address token_address, uint256 amount);

    /// @notice value of _baseLiability
    function baseLiability() external view returns (uint256);
    /// @notice value of _vaultInfo.minter
    function minter() external view returns (address);
    /// @notice value of _vaultInfo.id
    function id() external view returns (uint96);
    /// @notice value of _tokenBalance
    function tokenBalance(address) external view returns (uint256);

    // business logic

    function withdrawErc20(address token_address, uint256 amount) external;

    // administrative functions
    function controllerTransfer(address _token, address _to, uint256 _amount) external;

    function modifyLiability(bool increase, uint256 base_amount) external returns (uint256);
}
