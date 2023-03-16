// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract TestConstants {
  // Token addresses
  address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant SUSD_ADDRESS = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
  address public constant UNI_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
  address public constant AAVE_ADDRESS = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
  address public constant DYDX_ADDRESS = 0x92D6C1e31e14520e676a687F0a93788B716BEff5;
  address public constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

  // Pool addresses
  address public constant USDC_WETH_POOL_ADDRESS = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
  address public constant USDC_UNI_POOL_ADDRESS = 0xD0fC8bA7E267f2bc56044A7715A489d851dC6D78;
  address public constant AAVE_WETH_POOL_ADDRESS = 0x5aB53EE1d50eeF2C1DD3d5402789cd27bB52c1bB;
  address public constant DYDX_WETH_POOL_ADDRESS = 0xD8de6af55F618a7Bc69835D55DDC6582220c36c0;
  address public constant USDC_WBTC_POOL_ADDRESS = 0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35;

  // Chainlink addresses
  address public constant CHAINLINK_ETH_FEED_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
  address public constant CHAINLINK_UNI_FEED_ADDRESS = 0x553303d460EE0afB37EdFf9bE42922D8FF63220e;
  address public constant CHAINLINK_AAVE_FEED_ADDRESS = 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9;
  address public constant CHAINLINK_BTC_FEED_ADDRESS = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

  // LTV
  uint256 public constant WETH_LTV = 0.85 ether;
  uint256 public constant UNI_LTV = 0.75 ether;
  uint256 public constant AAVE_LTV = 0.75 ether;
  uint256 public constant DYDX_LTV = 0.75 ether;
  uint256 public constant OTHER_LTV = 0.75 ether;
  uint256 public constant WBTC_LTV = 0.8 ether;

  // LIQ INC
  uint256 public constant LIQUIDATION_INCENTIVE = 0.05 ether;

  // CAP
  uint256 public constant AAVE_CAP = 500 ether;
  uint256 public constant DYDX_CAP = 50 ether;

  // MISC
  address public constant SUSD_TOKEN_STATE = 0x05a9CBe762B36632b3594DA4F082340E0e5343e8;
  address public constant UNI_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address public constant UNI_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
  address public constant UNI_V3_NFP_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
  address public constant UNI_V3_SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

  // SCRIPTS
  address public constant VAULT_CONTROLLER_ADDRESS = address(0);
  address public constant USDA_ADDRESS = address(0);
}
