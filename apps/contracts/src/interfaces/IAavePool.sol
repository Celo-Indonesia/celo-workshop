// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title IAavePool
/// @notice Minimal interface for the Aave V3 `Pool` contract used by AaveLending.
///         Source: aave-v3-origin/src/contracts/interfaces/IPool.sol
interface IAavePool {
    /// @dev Mirrors `DataTypes.ReserveDataLegacy` used by `getReserveData`.
    struct ReserveDataLegacy {
        uint256 configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function getReserveData(address asset) external view returns (ReserveDataLegacy memory);
}

/// @notice Aave V3 variable-debt token. Borrowers must call `approveDelegation`
///         to let this contract borrow on their behalf.
interface ICreditDelegationToken {
    function approveDelegation(address delegatee, uint256 amount) external;
    function borrowAllowance(address fromUser, address toUser) external view returns (uint256);
}
