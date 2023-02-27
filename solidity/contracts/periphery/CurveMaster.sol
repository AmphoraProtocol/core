// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ICurveMaster} from '@interfaces/periphery/ICurveMaster.sol';
import {ICurveSlave} from '@interfaces/utils/ICurveSlave.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

/// @title Curve Master
/// @notice Curve master keeps a record of CurveSlave contracts and links it with an address
/// @dev all numbers should be scaled to 1e18. for instance, number 5e17 represents 50%
contract CurveMaster is ICurveMaster, Ownable {
  // mapping of token to address
  mapping(address => address) public curves;

  address public vaultControllerAddress;
  IVaultController private _vaultController;

  /// @notice gets the return value of curve labled _tokenAddress at _xValue
  /// @param _tokenAddress the key to lookup the curve with in the mapping
  /// @param _xValue the x value to pass to the slave
  /// @return _value y value of the curve
  function getValueAt(address _tokenAddress, int256 _xValue) external view override returns (int256 _value) {
    if (curves[_tokenAddress] == address(0)) revert CurveMaster_TokenNotEnabled();
    ICurveSlave _curve = ICurveSlave(curves[_tokenAddress]);
    _value = _curve.valueAt(_xValue);
    if (_value == 0) revert CurveMaster_ZeroResult();
  }

  /// @notice set the VaultController addr in order to pay interest on curve setting
  /// @param _vaultMasterAddress address of vault master
  function setVaultController(address _vaultMasterAddress) external override onlyOwner {
    vaultControllerAddress = _vaultMasterAddress;
    _vaultController = IVaultController(_vaultMasterAddress);
  }

  ///@notice setting a new curve should pay interest
  function setCurve(address _tokenAddress, address _curveAddress) external override onlyOwner {
    if (address(_vaultController) != address(0)) _vaultController.calculateInterest();
    curves[_tokenAddress] = _curveAddress;
  }

  /// @notice special function that does not calculate interest, used for deployment et al
  function forceSetCurve(address _tokenAddress, address _curveAddress) external override onlyOwner {
    curves[_tokenAddress] = _curveAddress;
  }
}
