// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title CurveMaster Interface
/// @notice Interface for interacting with CurveMaster
interface ICurveMaster {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emited when the owner changes the vault controller address
   * @param _oldVaultControllerAddress The old address of the vault controller
   * @param _newVaultControllerAddress The new address of the vault controller
   */
  event VaultControllerSet(address _oldVaultControllerAddress, address _newVaultControllerAddress);

  /**
   * @notice Emited when the owner changes the curve address
   * @param _oldCurveAddress The old address of the curve
   * @param _token The token to set
   * @param _newCurveAddress The new address of the curve
   */
  event CurveSet(address _oldCurveAddress, address _token, address _newCurveAddress);

  /**
   * @notice Emited when the owner changes the curve address skipping the checks
   * @param _oldCurveAddress The old address of the curve
   * @param _token The token to set
   * @param _newCurveAddress The new address of the curve
   */
  event CurveForceSet(address _oldCurveAddress, address _token, address _newCurveAddress);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when the token is not enabled
  error CurveMaster_TokenNotEnabled();

  /// @notice Thrown when result is zero
  error CurveMaster_ZeroResult();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

  function vaultControllerAddress() external view returns (address _vaultController);

  function getValueAt(address _tokenAddress, int256 _xValue) external view returns (int256 _value);

  function curves(address _tokenAddress) external view returns (address _curve);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/
  function setVaultController(address _vaultMasterAddress) external;

  function setCurve(address _tokenAddress, address _curveAddress) external;

  function forceSetCurve(address _tokenAddress, address _curveAddress) external;
}
