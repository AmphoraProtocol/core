// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract TestConstants {
  // Token addresses
  address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant SUSD_ADDRESS = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
  address public constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address public constant UNI_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
  address public constant AAVE_ADDRESS = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
  address public constant DYDX_ADDRESS = 0x92D6C1e31e14520e676a687F0a93788B716BEff5;
  address public constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address public constant USDT_LP_ADDRESS = 0x9fC689CCaDa600B6DF723D9E47D84d76664a1F23;
  address public constant BOR_DAO_ADDRESS = 0x3c9d6c1C73b31c837832c72E04D3152f051fc1A9;
  address public constant THREE_CRV_LP_ADDRESS = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
  address public constant BORING_DAO_ADDRESS = 0xBC19712FEB3a26080eBf6f2F7849b417FdD792CA;
  address public constant BORING_DAO_LP_ADDRESS = 0x2fE94ea3d5d4a175184081439753DE15AeF9d614;
  address public constant CVX_ADDRESS = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
  address public constant CRV_ADDRESS = 0xD533a949740bb3306d119CC777fa900bA034cd52;
  address public constant TRI_CRYPTO_LP_TOKEN = 0xc4AD29ba4B3c580e6D59105FFf484999997675Ff;

  // Pool addresses
  address public constant USDC_WETH_POOL_ADDRESS = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
  address public constant USDC_UNI_POOL_ADDRESS = 0xD0fC8bA7E267f2bc56044A7715A489d851dC6D78;
  address public constant AAVE_WETH_POOL_ADDRESS = 0x5aB53EE1d50eeF2C1DD3d5402789cd27bB52c1bB;
  address public constant DYDX_WETH_POOL_ADDRESS = 0xe0CfA17aa9B8f930Fd936633c0252d5cB745C2C3;
  address public constant USDC_WBTC_POOL_ADDRESS = 0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35;
  address public constant TRI_CRYPTO2_POOL_ADDRESS = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46;

  // Chainlink addresses
  address public constant CHAINLINK_ETH_FEED_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
  address public constant CHAINLINK_UNI_FEED_ADDRESS = 0x553303d460EE0afB37EdFf9bE42922D8FF63220e;
  address public constant CHAINLINK_AAVE_FEED_ADDRESS = 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9;
  address public constant CHAINLINK_BTC_FEED_ADDRESS = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
  address public constant CHAINLINK_DYDX_FEED_ADDRESS = 0x478909D4D798f3a1F11fFB25E4920C959B4aDe0b;

  // Curve rewards contract addresses
  address public constant USDT_LP_REWARDS_ADDRESS = 0x8B55351ea358e5Eda371575B031ee24F462d503e;
  address public constant BORING_DAO_LP_REWARDS_ADDRESS = 0xeeeCE77e0bc5e59c77fc408789A9A172A504bD2f;
  address public constant THREE_CRV_LP_REWARDS_ADDRESS = 0x689440f2Ff927E1f24c72F1087E1FAF471eCe1c8;

  // CONVEX BOOSTER
  address public constant BOOSTER = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

  // VIRTUAL BALANCE REWARD POOL
  address public constant BORING_DAO_LP_VIRTUAL_REWARDS_CONTRACT = 0xAE97D3766924526084dA88ba9B2bd7aF989Bf6fC;
  address public constant BORING_DAO_VIRTUAL_REWARDS_OPERATOR_CONTRACT = 0x9a669fb0191D977e588b20CdA3C52EDbC6c9926c;

  // STAKED CONTRACT
  address public constant USDT_LP_STAKED_CONTRACT = 0xBC89cd85491d81C6AD2954E6d0362Ee29fCa8F53;
  address public constant BORING_DAO_LP_STAKED_CONTRACT = 0x11137B10C210b579405c21A07489e28F3c040AB1;
  address public constant THREE_CRV_LP_STAKED_CONTRACT = 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A;

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
