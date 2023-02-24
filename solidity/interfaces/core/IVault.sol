// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title Vault Interface
interface IVault {
    /*///////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emited after depositing a token
     * @param _token The address of the token to deposit
     * @param _amount The amount to deposit
     */
    event Deposit(address _token, uint256 _amount);

    /**
     * @notice Emited after withdrawing a token
     * @param _token The address of the token to deposit
     * @param _amount The amount to deposit
     */
    event Withdraw(address _token, uint256 _amount);

    /*///////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Thrown when trying to deposit a token that is not registered
     */
    error Vault_TokenNotRegistered();

    /**
     * @notice Thrown when trying to deposit 0 amount
     */
    error Vault_AmountZero();

    /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the current vault base liability
     * @return _liability The current vault base liability of the vault
     */
    function baseLiability() external view returns (uint256 _liability);

    /**
     * @notice Returns the minter's address of the vault
     * @return _minter The minter's address
     */
    function minter() external view returns (address _minter);

    /**
     * @notice Returns the id of the vault
     * @return _id The id of the vault
     */
    function id() external view returns (uint96 _id);

    /*///////////////////////////////////////////////////////////////
                              LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the vault's balance of a token
     * @param _token The address of the token
     * @return _balance The token's balance of the vault
     */
    function tokenBalance(address _token) external view returns (uint256 _balance);

    /**
     * @notice Used to deposit a token to the vault
     * @param _token The address of the token to deposit
     * @param _amount The amount of the token to deposit
     */
    function depositERC20(address _token, uint256 _amount) external;

    /**
     * @notice Used to withdraw a token from the vault. This can only be called by the minter
     * @dev The withdraw will be denied if ones vault would become insolvent
     * @param _token The address of the token
     * @param _amount The amount of the token to withdraw
     */
    function withdrawERC20(address _token, uint256 _amount) external;

    /**
     * @notice Function used by the VaultController to transfer tokens
     * @param _token The address of the token to transfer
     * @param _to The address of the person to send the coins to
     * @param _amount The amount of coins to move
     */
    function controllerTransfer(address _token, address _to, uint256 _amount) external;

    /**
     * @notice Modifies a vault's liability. Can only be called by VaultController
     * @param _increase True to increase liability, false to decrease
     * @param _baseAmount The change amount in base liability
     * @return _liability The new base liability
     */
    function modifyLiability(bool _increase, uint256 _baseAmount) external returns (uint256 _liability);
}
