// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {Swap} from "../src/Swap.sol";
import {IMentoRouter} from "../src/interfaces/IMentoRouter.sol";

interface IFPMM {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256, uint256, uint256);
}

/// @notice Fork test against real Celo mainnet state. Tests swap USDC <-> USDm
///         (a.k.a. cUSD / StableTokenUSD `0x765D...`) through the Mento V3 Router.
///
/// Run:
///   forge test --match-contract SwapForkTest --fork-url celo -vv
contract SwapForkTest is Test {
    address constant MENTO_ROUTER = 0x4861840C2EfB2b98312B0aE34d86fD73E8f9B6f6;
    address constant USDC_USDM_POOL = 0x462fe04b4FD719Cbd04C0310365D421D02AaA19E;

    address constant USDM = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    address constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;

    Swap public swapContract;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public feeRecipient = makeAddr("feeRecipient");

    function setUp() public {
        vm.createSelectFork("celo");

        vm.startPrank(owner);
        swapContract = new Swap(MENTO_ROUTER, address(0), 0);
        vm.stopPrank();

        assertEq(address(swapContract.mentoRouter()), MENTO_ROUTER);
        assertEq(swapContract.owner(), owner);
    }

    function test_mainnetForkIsCelo() public view {
        assertEq(block.chainid, 42220, "expected Celo mainnet chain id");
        assertEq(IFPMM(USDC_USDM_POOL).token0(), USDM);
        assertEq(IFPMM(USDC_USDM_POOL).token1(), USDC);
    }

    function test_quote_returnsExpectedAmountOut() public view {
        uint256 amountIn = 1_000_000;
        uint256 amountOut = swapContract.quote(USDC, USDM, amountIn);

        console.log("Quote 1 USDC ->", amountOut, "USDm wei");
        assertGt(amountOut, 0, "quote should return non-zero amount");
    }

    function test_swap_USDCtoUSDM() public {
        uint256 amountIn = 10 * 1e6; // 10 USDC with 6 decimals

        deal(USDC, user, amountIn);
        assertEq(IERC20(USDC).balanceOf(user), amountIn);

        uint256 expectedOut = swapContract.quote(USDC, USDM, amountIn);
        uint256 amountOutMin = (expectedOut * 99) / 100; // 1% slippage

        vm.startPrank(user);
        IERC20(USDC).approve(address(swapContract), amountIn);

        // Cek usdm di wallet user sebelum transaksi swap
        uint256 userUsdmBefore = IERC20(USDM).balanceOf(user);

        // proses swaping
        uint256 amountOut = swapContract.swap(
            USDC,
            USDM,
            amountIn,
            amountOutMin,
            block.timestamp + 300
        );
        vm.stopPrank();

        // Cek usdm di wallet user setelah transaksi swap
        uint256 userUsdmAfter = IERC20(USDM).balanceOf(user);

        console.log("USDC in:", amountIn);
        console.log("USDm out:", amountOut);

        assertEq(IERC20(USDC).balanceOf(user), 0, "user USDC should be zero");
        assertEq(userUsdmAfter - userUsdmBefore, amountOut, "USDm received should match return value");
        assertGe(amountOut, amountOutMin, "amountOut below slippage floor");
        assertEq(IERC20(USDC).balanceOf(address(swapContract)), 0, "no USDC stuck in swap");
        assertEq(IERC20(USDM).balanceOf(address(swapContract)), 0, "no USDm stuck in swap");
    }

    /// @dev USDm uses 18 decimals while USDC uses 6, and the live pool currently
    ///      holds only ~0.15 USDC. We use 0.01 USDm (1 * 1e16 wei) so the swap
    ///      produces a non-zero USDC output and fits within available reserves.
    function test_swap_USDMtoUSDC() public {
        uint256 amountIn = 1 * 1e16;

        deal(USDM, user, amountIn);
        assertEq(IERC20(USDM).balanceOf(user), amountIn);

        uint256 expectedOut = swapContract.quote(USDM, USDC, amountIn);
        uint256 amountOutMin = (expectedOut * 99) / 100;

        vm.startPrank(user);
        IERC20(USDM).approve(address(swapContract), amountIn);

        uint256 userUsdcBefore = IERC20(USDC).balanceOf(user);
        uint256 amountOut = swapContract.swap(
            USDM,
            USDC,
            amountIn,
            amountOutMin,
            block.timestamp + 300
        );
        vm.stopPrank();

        uint256 userUsdcAfter = IERC20(USDC).balanceOf(user);

        console.log("USDm in:", amountIn);
        console.log("USDC out:", amountOut);

        assertEq(IERC20(USDM).balanceOf(user), 0);
        assertEq(userUsdcAfter - userUsdcBefore, amountOut);
        assertGe(amountOut, amountOutMin);
    }

    function test_swap_chargesProtocolFee() public {
        vm.prank(owner);
        swapContract.setFeeConfig(50, feeRecipient);

        uint256 amountIn = 10 * 1e6;
        deal(USDC, user, amountIn);

        uint256 expectedFee = (amountIn * 50) / 10_000;
        uint256 amountAfterFee = amountIn - expectedFee;
        uint256 quoteAfterFee = swapContract.quote(USDC, USDM, amountAfterFee);
        uint256 amountOutMin = (quoteAfterFee * 99) / 100;

        vm.startPrank(user);
        IERC20(USDC).approve(address(swapContract), amountIn);
        uint256 amountOut = swapContract.swap(
            USDC,
            USDM,
            amountIn,
            amountOutMin,
            block.timestamp + 300
        );
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(feeRecipient), expectedFee, "fee not collected");
        assertGe(amountOut, amountOutMin, "swap output below floor");
    }

    function test_revert_whenAmountInZero() public {
        vm.expectRevert(Swap.InvalidAmount.selector);
        swapContract.swap(USDC, USDM, 0, 0, block.timestamp + 300);
    }

    function test_revert_whenSameToken() public {
        deal(USDC, user, 1e6);
        vm.startPrank(user);
        IERC20(USDC).approve(address(swapContract), 1e6);
        vm.expectRevert(Swap.InvalidRoute.selector);
        swapContract.swap(USDC, USDC, 1e6, 0, block.timestamp + 300);
        vm.stopPrank();
    }

    function test_revert_whenDeadlinePassed() public {
        deal(USDC, user, 1e6);
        vm.startPrank(user);
        IERC20(USDC).approve(address(swapContract), 1e6);
        vm.expectRevert(Swap.DeadlineExpired.selector);
        swapContract.swap(USDC, USDM, 1e6, 0, block.timestamp - 1);
        vm.stopPrank();
    }

    function test_revert_whenSlippageTooTight() public {
        uint256 amountIn = 10 * 1e6;
        deal(USDC, user, amountIn);

        uint256 expectedOut = swapContract.quote(USDC, USDM, amountIn);
        uint256 unreachableMin = expectedOut * 2;

        vm.startPrank(user);
        IERC20(USDC).approve(address(swapContract), amountIn);
        vm.expectRevert();
        swapContract.swap(USDC, USDM, amountIn, unreachableMin, block.timestamp + 300);
        vm.stopPrank();
    }

    function test_pause_blocksSwaps() public {
        vm.prank(owner);
        swapContract.pause();

        deal(USDC, user, 1e6);
        vm.startPrank(user);
        IERC20(USDC).approve(address(swapContract), 1e6);
        vm.expectRevert();
        swapContract.swap(USDC, USDM, 1e6, 0, block.timestamp + 300);
        vm.stopPrank();
    }

    function test_swapWithRoute_singleHop() public {
        uint256 amountIn = 5 * 1e6;
        deal(USDC, user, amountIn);

        IMentoRouter.Route[] memory routes = new IMentoRouter.Route[](1);
        routes[0] = IMentoRouter.Route({from: USDC, to: USDM, factory: address(0)});

        uint256[] memory quoted = swapContract.quoteRoute(amountIn, routes);
        uint256 amountOutMin = (quoted[quoted.length - 1] * 99) / 100;

        vm.startPrank(user);
        IERC20(USDC).approve(address(swapContract), amountIn);
        uint256 amountOut = swapContract.swapWithRoute(
            routes,
            amountIn,
            amountOutMin,
            block.timestamp + 300
        );
        vm.stopPrank();

        assertGe(amountOut, amountOutMin);
        assertEq(IERC20(USDM).balanceOf(user), amountOut);
    }

    function test_rescueTokens() public {
        deal(USDC, address(swapContract), 10 * 1e6);
        address treasury = makeAddr("treasury");

        vm.prank(owner);
        swapContract.rescueTokens(USDC, treasury, 10 * 1e6);

        assertEq(IERC20(USDC).balanceOf(treasury), 10 * 1e6);
        assertEq(IERC20(USDC).balanceOf(address(swapContract)), 0);
    }

    function test_revert_rescueByNonOwner() public {
        deal(USDC, address(swapContract), 10 * 1e6);
        vm.prank(user);
        vm.expectRevert();
        swapContract.rescueTokens(USDC, user, 10 * 1e6);
    }
}
