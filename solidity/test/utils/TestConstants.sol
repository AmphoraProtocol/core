// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract TestConstants {
    // Token addresses
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant SUSD_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant UNI_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant AAVE_ADDRESS = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address constant DYDX_ADDRESS = 0x92D6C1e31e14520e676a687F0a93788B716BEff5;

    // Pool addresses
    address constant USDC_WETH_POOL_ADDRESS = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
    address constant USDC_UNI_POOL_ADDRESS = 0xD0fC8bA7E267f2bc56044A7715A489d851dC6D78;
    address constant AAVE_WETH_POOL_ADDRESS = 0x5aB53EE1d50eeF2C1DD3d5402789cd27bB52c1bB;

    // Chainlink addresses
    address constant CHAINLINK_ETH_FEED_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant CHAINLINK_UNI_FEED_ADDRESS = 0x553303d460EE0afB37EdFf9bE42922D8FF63220e;
    address constant CHAINLINK_AAVE_FEED_ADDRESS = 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9;

    // LTV
    uint256 constant WETH_LTV = 0.85 ether;
    uint256 constant UNI_LTV = 0.75 ether;
    uint256 constant AAVE_LTV = 0.75 ether;
    uint256 constant DYDX_LTV = 0.75 ether;

    uint256 constant LIQUIDATION_INCENTIVE = 0.05 ether;

    // CAP
    uint256 constant AAVE_CAP = 500 ether;
    uint256 constant DYDX_CAP = 50 ether;
}
