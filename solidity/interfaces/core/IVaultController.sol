// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title VaultController Interface
interface IVaultController {
    event InterestEvent(uint64 epoch, uint192 amount, uint256 curve_val);
    event NewProtocolFee(uint256 protocol_fee);
    event RegisteredErc20(address token_address, uint256 LTVe4, address oracle_address, uint256 liquidationIncentivee4);
    event UpdateRegisteredErc20(
        address token_address, uint256 LTVe4, address oracle_address, uint256 liquidationIncentivee4
    );
    event NewVault(address vault_address, uint256 vaultId, address vaultOwner);
    event RegisterOracleMaster(address oracleMasterAddress);
    event RegisterCurveMaster(address curveMasterAddress);
    event BorrowUSDA(uint256 vaultId, address vaultAddress, uint256 borrowAmount);
    event RepayUSDA(uint256 vaultId, address vaultAddress, uint256 repayAmount);
    event Liquidate(uint256 vaultId, address asset_address, uint256 usda_to_repurchase, uint256 tokens_to_liquidate);
    // initializer

    function initialize() external;

    // view functions

    function tokensRegistered() external view returns (uint256);

    function vaultsMinted() external view returns (uint96);

    function lastInterestTime() external view returns (uint64);

    function totalBaseLiability() external view returns (uint192);

    function interestFactor() external view returns (uint192);

    function protocolFee() external view returns (uint192);

    function vaultAddress(uint96 id) external view returns (address);

    function vaultIDs(address wallet) external view returns (uint96[] memory);

    function amountToSolvency(uint96 id) external view returns (uint256);

    function vaultLiability(uint96 id) external view returns (uint192);

    function vaultBorrowingPower(uint96 id) external view returns (uint192);

    function tokensToLiquidate(uint96 id, address token) external view returns (uint256);

    function checkVault(uint96 id) external view returns (bool);

    function tokenId(address _tokenAddress) external view returns (uint256 _tokenId);

    struct VaultSummary {
        uint96 id;
        uint192 borrowingPower;
        uint192 vaultLiability;
        address[] tokenAddresses;
        uint256[] tokenBalances;
    }

    function vaultSummaries(uint96 start, uint96 stop) external view returns (VaultSummary[] memory);

    // interest calculations
    function calculateInterest() external returns (uint256);

    // vault management business
    function mintVault() external returns (address);

    function liquidateVault(uint96 id, address asset_address, uint256 tokenAmount) external returns (uint256);

    function borrowUSDA(uint96 id, uint192 amount) external;

    function borrowUSDAto(uint96 id, uint192 amount, address target) external;

    function borrowsUSDto(uint96 id, uint192 susd_amount, address target) external;

    function repayUSDA(uint96 id, uint192 amount) external;

    function repayAllUSDA(uint96 id) external;

    // admin
    function pause() external;

    function unpause() external;

    function getOracleMaster() external view returns (address);

    function registerOracleMaster(address master_oracle_address) external;

    function getCurveMaster() external view returns (address);

    function registerCurveMaster(address master_curve_address) external;

    function changeProtocolFee(uint192 new_protocol_fee) external;

    function registerErc20(address token_address, uint256 LTV, address oracle_address, uint256 liquidationIncentive)
        external;

    function registerUSDA(address usda_address) external;

    function updateRegisteredErc20(
        address token_address,
        uint256 LTV,
        address oracle_address,
        uint256 liquidationIncentive
    ) external;
}
