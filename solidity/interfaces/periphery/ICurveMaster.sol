// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title CurveMaster Interface
/// @notice Interface for interacting with CurveMaster
interface ICurveMaster {
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
