# Amphora Protocol

## repository

```
~~ Structure ~~
├── solidity: All our contracts and interfaces are here
│   ├─── contracts/: All the contracts
│   │    ├─── core/: All core contracts
│   │    │   ├─── VaultManager.sol : Can liquidate a vault, pay interest, changes protocol settings
│   │    │   ├─── VaultDeployer.sol : Will mint and deploy new Vaults
│   │    │   ├─── Vault.sol : User's vault, can deposit/withdraw collateral, claim protocol rewards, borrow sUSD
│   │    │   ├─── CappedCollateralToken.sol : A wrapper for an underlying asset that can be listed as collateral on the protocol
│   │    │   ├─── USDA.sol : ERC20, given by the protocol 1:1 ratio when a lender deposits sUSD
│   │    │   └─── WUSDA.sol : Warped version of USDA to interact with other DeFi protocols
│   │    ├─── periphery/: All periphery contracts
│   │    │   ├─── CurveMaster.sol : The CurveMaster manages the various interest rate curves, used in VaultManagerLogic
│   │    │   ├─── CurveLPOracle.sol : Responsible for getting the price of a curve LP token in USD
│   │    │   └─── ETHOracle.sol : Responsible for getting the price of ETH in USD
│   │    ├─── utils/: Util contracts that are being extended or used by other contracts
│   │    │   ├─── GovernanceStructs.sol : Structs needed to create proposals or governance related transactions
│   │    │   ├─── CappedToken.sol : Contract used to create a capped token
│   │    │   ├─── UFragments.sol : ERC20, extended by USDA, adjusts balances of all USDA holders
│   │    │   └─── ThreeLines0_100.sol : The interest rate curve math for USDA **(NOT SURE ABOUT THIS)**
│   │    ├─── governance/: All contracts that are specific for the governance of the protocol
│   │    │   ├─── Amphora.sol : Protocol governance token
│   │    │   └─── ....
│   ├─── interfaces/: The interfaces of all the contracts (SAME STRUCTURE WITH CONTRACTS)
│   ├─── tests/: All our tests for the contracts
│   │    ├─── e2e/: ...
│   │    ├─── unit/: ...
├── README.md
```
