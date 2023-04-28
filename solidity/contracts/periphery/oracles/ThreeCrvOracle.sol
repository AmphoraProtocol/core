// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IOracleRelay, OracleRelay} from '@contracts/periphery/oracles/OracleRelay.sol';
import {AggregatorV2V3Interface} from '@chainlink/interfaces/AggregatorV2V3Interface.sol';
import {ICurvePool} from '@interfaces/utils/ICurvePool.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {ChainlinkStalePriceLib} from '@contracts/periphery/oracles/ChainlinkStalePriceLib.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

/// @notice Oracle Relay for the Tree Curve Pool (DAI/USDC/USDT)
contract ThreeCrvOracle is OracleRelay, Ownable {
  /// @notice Emitted when the amount is zero
  error ThreeCrvOracle_ZeroAmount();

  ICurvePool public constant THREE_CRV = ICurvePool(0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C);
  AggregatorV2V3Interface public constant DAI = AggregatorV2V3Interface(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);
  AggregatorV2V3Interface public constant USDC = AggregatorV2V3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
  AggregatorV2V3Interface public constant USDT = AggregatorV2V3Interface(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);

  uint256 public daiStaleDelay = 1 hours;
  uint256 public usdcStaleDelay = 1 days;
  uint256 public usdtStaleDelay = 1 days;

  constructor() OracleRelay(OracleType.Chainlink) {}

  /// @notice The current reported value of the oracle
  /// @dev Implementation in _get()
  /// @return _value The current value
  function currentValue() external view override returns (uint256 _value) {
    _value = _get();
  }

  /// @notice Sets the stale price delay for DAI
  /// @param _daiStaleDelay The new stale price delay
  /// @dev Only the owner can call this function
  function setDaiStaleDelay(uint256 _daiStaleDelay) external onlyOwner {
    if (_daiStaleDelay == 0) revert ThreeCrvOracle_ZeroAmount();
    daiStaleDelay = _daiStaleDelay;
  }

  /// @notice Sets the stale price delay for USDC
  /// @param _usdcStaleDelay The new stale price delay
  /// @dev Only the owner can call this function
  function setUsdcStaleDelay(uint256 _usdcStaleDelay) external onlyOwner {
    if (_usdcStaleDelay == 0) revert ThreeCrvOracle_ZeroAmount();
    usdcStaleDelay = _usdcStaleDelay;
  }

  /// @notice Sets the stale price delay for USDT
  /// @param _usdtStaleDelay The new stale price delay
  /// @dev Only the owner can call this function
  function setUsdtStaleDelay(uint256 _usdtStaleDelay) external onlyOwner {
    if (_usdtStaleDelay == 0) revert ThreeCrvOracle_ZeroAmount();
    usdtStaleDelay = _usdtStaleDelay;
  }

  /// @notice Calculates the lastest exchange rate
  /// @dev Uses both divide and multiply only for tokens not supported directly by Chainlink, for example MKR/USD
  function _get() internal view returns (uint256 _value) {
    // As the price should never be negative, the unchecked conversion is acceptable
    // TODO: need to be added as anchor oracler, stale delay is set in ChainlinkOracleRelay
    uint256 _minStable = Math.min(
      (ChainlinkStalePriceLib.getCurrentPrice(DAI)),
      Math.min((ChainlinkStalePriceLib.getCurrentPrice(USDC)), (ChainlinkStalePriceLib.getCurrentPrice(USDT)))
    );

    uint256 _lpPrice = THREE_CRV.get_virtual_price() * _minStable;

    // Chainlink price has 8 decimals
    _value = _lpPrice / 1e8;
  }
}
