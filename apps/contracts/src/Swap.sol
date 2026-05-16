// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {IMentoRouter} from "./interfaces/IMentoRouter.sol";

/// @title Swap
/// @notice Thin wrapper around the Mento V3 Router that lets users swap one
///         ERC20 for another through Mento's FPMM pools (cUSD, USDC, USDT,
///         axlUSDC, USDm, GBPm, ...). Supports single-hop and multi-hop routes.
contract Swap is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IMentoRouter public immutable mentoRouter;

    uint256 public feeBps;
    address public feeRecipient;
    
    // Basis Points (BPS) are used to represent fees as parts per 10,000. For example, a fee of 25 BPS corresponds to a fee of 0.25%.
    uint256 public constant MAX_FEE_BPS = 100;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    event Swapped(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount
    );

    event FeeConfigUpdated(uint256 feeBps, address feeRecipient);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    error ZeroAddress();
    error InvalidAmount();
    error InvalidRoute();
    error DeadlineExpired();
    error FeeTooHigh();

    constructor(address _mentoRouter, address _feeRecipient, uint256 _feeBps) Ownable(msg.sender) {
        if (_mentoRouter == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        if (_feeBps != 0 && _feeRecipient == address(0)) revert ZeroAddress();

        mentoRouter = IMentoRouter(_mentoRouter);
        feeBps = _feeBps;
        feeRecipient = _feeRecipient;
    }

    /// @notice Quote a direct swap between two tokens through Mento's default factory.
    function quote(
        address tokenIn, // USDC -> Dijual
        address tokenOut, //USDm -> Dibeli
        uint256 amountIn // Jumlah USDC yang ingin ditukar
    ) external view returns (uint256 amountOut) {
        // Buat route
        IMentoRouter.Route[] memory routes = new IMentoRouter.Route[](1);

        // Masukan data route
        routes[0] = IMentoRouter.Route({from: tokenIn, to: tokenOut, factory: address(0)});

        // Dapatkan jumlah output dengan memanggil getAmountsOut pada Mento Router
        uint256[] memory amounts = mentoRouter.getAmountsOut(amountIn, routes);
        amountOut = amounts[amounts.length - 1];
    }

    /// @notice Quote a multi-hop swap.
    function quoteRoute(
        uint256 amountIn,
        IMentoRouter.Route[] calldata routes
    ) external view returns (uint256[] memory amounts) {
        amounts = mentoRouter.getAmountsOut(amountIn, routes);
    }

    /// @notice Swap `amountIn` of `tokenIn` for at least `amountOutMin` of `tokenOut`
    ///         directly via Mento's default FPMM factory.
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin, // slipage
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        IMentoRouter.Route[] memory routes = new IMentoRouter.Route[](1);
        routes[0] = IMentoRouter.Route({from: tokenIn, to: tokenOut, factory: address(0)});

        amountOut = _executeSwap(routes, amountIn, amountOutMin, deadline);
    }

    /// @notice Swap through an arbitrary route (multi-hop supported).
    function swapWithRoute(
        IMentoRouter.Route[] calldata routes,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        if (routes.length == 0) revert InvalidRoute();

        IMentoRouter.Route[] memory mem = new IMentoRouter.Route[](routes.length);
        for (uint256 i = 0; i < routes.length; i++) {
            mem[i] = routes[i];
        }

        amountOut = _executeSwap(mem, amountIn, amountOutMin, deadline);
    }

    function setFeeConfig(uint256 _feeBps, address _feeRecipient) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        if (_feeBps != 0 && _feeRecipient == address(0)) revert ZeroAddress();

        feeBps = _feeBps;
        feeRecipient = _feeRecipient;

        emit FeeConfigUpdated(_feeBps, _feeRecipient);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
        emit TokensRescued(token, to, amount);
    }

    function _executeSwap(
        IMentoRouter.Route[] memory routes,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmount();
        if (deadline < block.timestamp) revert DeadlineExpired();

        address tokenIn = routes[0].from;
        address tokenOut = routes[routes.length - 1].to;
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZeroAddress();
        if (tokenIn == tokenOut) revert InvalidRoute();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 feeAmount = (amountIn * feeBps) / BPS_DENOMINATOR;
        if (feeAmount > 0) {
            IERC20(tokenIn).safeTransfer(feeRecipient, feeAmount); // treasury
        }
        uint256 swapAmount = amountIn - feeAmount;

        IERC20(tokenIn).forceApprove(address(mentoRouter), swapAmount);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(msg.sender);

        uint256[] memory amounts = mentoRouter.swapExactTokensForTokens(
            swapAmount,
            amountOutMin,
            routes,
            msg.sender,
            deadline
        );

        amountOut = amounts[amounts.length - 1];

        uint256 received = IERC20(tokenOut).balanceOf(msg.sender) - balanceBefore;
        if (received < amountOutMin) revert InvalidAmount();

        emit Swapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeAmount);
    }
}
