// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {IAavePool} from "./interfaces/IAavePool.sol";

/// @title AaveLending
/// @notice Passthrough integration with Aave V3 on Celo. Each caller owns their
///         own collateral (aTokens) and debt (variable debt tokens) directly on
///         Aave, so health factors stay isolated per user.
///
///         Aave V3 only supports variable-rate borrows (mode = 2).
contract AaveLending is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant VARIABLE_RATE_MODE = 2;

    IAavePool public immutable aavePool;

    event Supplied(address indexed user, address indexed asset, uint256 amount);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount, address to);
    event Borrowed(address indexed user, address indexed asset, uint256 amount, address to);
    event Repaid(address indexed user, address indexed asset, uint256 amountPaid, uint256 actualRepaid);
    event CollateralFlagSet(address indexed user, address indexed asset, bool useAsCollateral);

    error ZeroAddress();
    error ZeroAmount();
    error WithdrawFailed();

    constructor(address _aavePool) Ownable(msg.sender) {
        if (_aavePool == address(0)) revert ZeroAddress();
        aavePool = IAavePool(_aavePool);
    }

    /// @notice Supply `amount` of `asset` to Aave on behalf of msg.sender.
    ///         The corresponding aTokens are minted directly to msg.sender.
    function supply(address asset, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).forceApprove(address(aavePool), amount);
        aavePool.supply(asset, amount, msg.sender, 0);

        emit Supplied(msg.sender, asset, amount);
    }

    /// @notice Withdraw `amount` of `asset` from Aave. The caller must have
    ///         approved this contract on the aToken before calling, since
    ///         Aave burns aTokens from `msg.sender` (this contract).
    /// @param  amount  Use type(uint256).max to withdraw the entire balance.
    function withdraw(address asset, uint256 amount, address to) external nonReentrant whenNotPaused returns (uint256) {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        address aToken = _getAToken(asset);

        uint256 pullAmount = amount;
        if (amount == type(uint256).max) {
            pullAmount = IERC20(aToken).balanceOf(msg.sender);
            if (pullAmount == 0) revert ZeroAmount();
        }

        IERC20(aToken).safeTransferFrom(msg.sender, address(this), pullAmount);
        uint256 withdrawn = aavePool.withdraw(asset, pullAmount, to);
        if (withdrawn == 0) revert WithdrawFailed();

        emit Withdrawn(msg.sender, asset, withdrawn, to);
        return withdrawn;
    }

    /// @notice Borrow `amount` of `asset` from Aave with msg.sender as the
    ///         debt holder. Caller must have called `approveDelegation` on the
    ///         variable debt token for at least `amount` so this contract can
    ///         borrow on their behalf.
    function borrow(address asset, uint256 amount, address to) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        aavePool.borrow(asset, amount, VARIABLE_RATE_MODE, 0, msg.sender);

        IERC20(asset).safeTransfer(to, amount);

        emit Borrowed(msg.sender, asset, amount, to);
    }

    /// @notice Repay `amount` of `asset` debt on behalf of `onBehalfOf`. Use
    ///         type(uint256).max to repay the full outstanding debt — the
    ///         contract pulls only what is actually owed and refunds any excess.
    function repay(address asset, uint256 amount, address onBehalfOf)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 actualRepaid)
    {
        if (amount == 0) revert ZeroAmount();
        if (onBehalfOf == address(0)) revert ZeroAddress();

        uint256 pullAmount = amount;
        if (amount == type(uint256).max) {
            address vToken = _getVariableDebtToken(asset);
            pullAmount = IERC20(vToken).balanceOf(onBehalfOf);
            if (pullAmount == 0) revert ZeroAmount();
        }

        IERC20(asset).safeTransferFrom(msg.sender, address(this), pullAmount);
        IERC20(asset).forceApprove(address(aavePool), pullAmount);

        actualRepaid = aavePool.repay(asset, pullAmount, VARIABLE_RATE_MODE, onBehalfOf);

        uint256 leftover = pullAmount - actualRepaid;
        if (leftover > 0) {
            IERC20(asset).safeTransfer(msg.sender, leftover);
        }

        emit Repaid(msg.sender, asset, pullAmount, actualRepaid);
    }

    /// @notice Toggle whether the caller's supplied `asset` should be counted
    ///         as collateral on Aave.
    function setUseAsCollateral(address asset, bool useAsCollateral) external nonReentrant whenNotPaused {
        aavePool.setUserUseReserveAsCollateral(asset, useAsCollateral);
        emit CollateralFlagSet(msg.sender, asset, useAsCollateral);
    }

    /// @notice Aggregated account snapshot from Aave for `user`. All `*Base`
    ///         values are denominated in the price oracle's base unit (USD
    ///         with 8 decimals on Aave V3). Health factor is in 18 decimals,
    ///         and a value below 1e18 means the position can be liquidated.
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
        )
    {
        return aavePool.getUserAccountData(user);
    }

    /// @notice Lookup the user's current aToken balance (collateral position)
    ///         and variable debt token balance for `asset`.
    function getUserReservePosition(address user, address asset)
        external
        view
        returns (uint256 suppliedBalance, uint256 variableDebtBalance)
    {
        IAavePool.ReserveDataLegacy memory data = aavePool.getReserveData(asset);
        suppliedBalance = IERC20(data.aTokenAddress).balanceOf(user);
        variableDebtBalance = IERC20(data.variableDebtTokenAddress).balanceOf(user);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _getAToken(address asset) internal view returns (address) {
        return aavePool.getReserveData(asset).aTokenAddress;
    }

    function _getVariableDebtToken(address asset) internal view returns (address) {
        return aavePool.getReserveData(asset).variableDebtTokenAddress;
    }
}
