// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title IMentoRouter
/// @notice Minimal interface for the Mento V3 protocol Router used to route swaps
///         through FPMM pools. Source: github.com/mento-protocol/mento-core
interface IMentoRouter {
    struct Route {
        address from;
        address to;
        address factory;
    }

    function factoryRegistry() external view returns (address);

    function defaultFactory() external view returns (address);

    function poolFor(address tokenA, address tokenB, address _factory) external view returns (address pool);

    function getReserves(
        address tokenA,
        address tokenB,
        address _factory
    ) external view returns (uint256 reserveA, uint256 reserveB);

    function getAmountsOut(uint256 amountIn, Route[] memory routes) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] memory routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
