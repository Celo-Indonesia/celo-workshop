// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {AaveLending} from "../src/AaveLending.sol";
import {IAavePool, ICreditDelegationToken} from "../src/interfaces/IAavePool.sol";

/// @notice Fork tests against real Aave V3 on Celo mainnet.
///
/// Run:
///   forge test --match-contract AaveLendingForkTest --fork-url celo -vv
contract AaveLendingForkTest is Test {
    address constant AAVE_POOL = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402;

    address constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address constant USDM = 0x765DE816845861e75A25fCA122bb6898B8B1282a;

    address constant USDC_A_TOKEN = 0xFF8309b9e99bfd2D4021bc71a362aBD93dBd4785;
    address constant USDC_V_TOKEN = 0xDbe517c0FA6467873B684eCcbED77217E471E862;
    address constant USDM_A_TOKEN = 0xBba98352628B0B0c4b40583F593fFCb630935a45;
    address constant USDM_V_TOKEN = 0x05Ee3d1fBACbDbA1259946033cd7A42FDFcCcF0d;

    AaveLending public lending;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.createSelectFork("celo");

        vm.prank(owner);
        lending = new AaveLending(AAVE_POOL);

        assertEq(address(lending.aavePool()), AAVE_POOL);
        assertEq(lending.owner(), owner);
    }

    function test_chainIsCelo() public view {
        assertEq(block.chainid, 42220, "expected Celo mainnet chain id");
    }

    function test_supply_USDC() public {
        uint256 amount = 10 * 1e6; // 10 USDC
        deal(USDC, user, amount);
        console.log("User aUSDC balance before supply:", IERC20(USDC_A_TOKEN).balanceOf(user));

        vm.startPrank(user);
        IERC20(USDC).approve(address(lending), amount);
        lending.supply(USDC, amount);
        vm.stopPrank();

        uint256 aBalance = IERC20(USDC_A_TOKEN).balanceOf(user);
        console.log("aUSDC after supply:", aBalance);

        assertEq(IERC20(USDC).balanceOf(user), 0, "USDC should be moved to Aave");
        assertGe(aBalance, amount - 1, "aUSDC balance should match supply (within rounding)");
        assertEq(IERC20(USDC).balanceOf(address(lending)), 0, "no USDC stuck in contract");
    }

    function test_withdraw_USDC() public {
        uint256 amount = 10 * 1e6;
        deal(USDC, user, amount);

        vm.startPrank(user);
        IERC20(USDC).approve(address(lending), amount);
        lending.supply(USDC, amount);

        vm.warp(block.timestamp + 1 days);

        uint256 aBalance = IERC20(USDC_A_TOKEN).balanceOf(user);
        IERC20(USDC_A_TOKEN).approve(address(lending), aBalance);
        uint256 withdrawn = lending.withdraw(USDC, aBalance, user);
        vm.stopPrank();

        console.log("USDC withdrawn after 1 day:", withdrawn);

        assertGe(withdrawn, amount, "withdraw should return at least the supplied amount");
        assertEq(IERC20(USDC).balanceOf(user), withdrawn);
        assertEq(IERC20(USDC_A_TOKEN).balanceOf(user), 0);
    }

    function test_withdraw_max() public {
        uint256 amount = 10 * 1e6;
        deal(USDC, user, amount);

        vm.startPrank(user);
        IERC20(USDC).approve(address(lending), amount);
        lending.supply(USDC, amount);

        IERC20(USDC_A_TOKEN).approve(address(lending), type(uint256).max);
        uint256 withdrawn = lending.withdraw(USDC, type(uint256).max, user);
        vm.stopPrank();

        assertGe(withdrawn, amount - 1, "rounding may shave 1 wei on supply");
        assertEq(IERC20(USDC_A_TOKEN).balanceOf(user), 0);
    }

    function test_borrow_USDM_againstUSDC() public {
        uint256 collateral = 10 * 1e6; // 10 USDC
        uint256 borrowAmount = 1 * 1e18; // 1 USDM (18 decimals)

        deal(USDC, user, collateral);

        vm.startPrank(user);
        IERC20(USDC).approve(address(lending), collateral);
        lending.supply(USDC, collateral);

        ICreditDelegationToken(USDM_V_TOKEN).approveDelegation(address(lending), borrowAmount);

        lending.borrow(USDM, borrowAmount, user);
        vm.stopPrank();

        uint256 usdmBalance = IERC20(USDM).balanceOf(user);
        uint256 debtBalance = IERC20(USDM_V_TOKEN).balanceOf(user);

        console.log("USDm borrowed:", usdmBalance);
        console.log("USDm variable debt:", debtBalance);

        assertEq(usdmBalance, borrowAmount, "user should receive borrowed USDm");
        assertGe(debtBalance, borrowAmount, "debt token should reflect borrow");

        (uint256 totalCollateralBase, uint256 totalDebtBase, , , , uint256 hf) =
            lending.getUserAccountData(user);
        console.log("collateral (base):", totalCollateralBase);
        console.log("debt (base):", totalDebtBase);
        console.log("health factor:", hf);

        assertGt(totalCollateralBase, 0);
        assertGt(totalDebtBase, 0);
        assertGt(hf, 1e18, "health factor should be above liquidation threshold");
    }

    function test_repay_USDM() public {
        uint256 collateral = 10 * 1e6;
        uint256 borrowAmount = 1 * 1e18;

        deal(USDC, user, collateral);

        vm.startPrank(user);
        IERC20(USDC).approve(address(lending), collateral);
        lending.supply(USDC, collateral);
        ICreditDelegationToken(USDM_V_TOKEN).approveDelegation(address(lending), borrowAmount);
        lending.borrow(USDM, borrowAmount, user);

        vm.warp(block.timestamp + 7 days);

        uint256 currentDebt = IERC20(USDM_V_TOKEN).balanceOf(user);
        deal(USDM, user, currentDebt);

        IERC20(USDM).approve(address(lending), currentDebt);
        uint256 repaid = lending.repay(USDM, type(uint256).max, user);
        vm.stopPrank();

        console.log("USDm repaid (after 7 days interest):", repaid);

        assertGe(repaid, borrowAmount, "should repay at least the borrowed principal");
        assertEq(IERC20(USDM_V_TOKEN).balanceOf(user), 0, "debt should be fully cleared");
    }

    function test_repay_refundsExcess() public {
        uint256 collateral = 10 * 1e6;
        uint256 borrowAmount = 1 * 1e18;

        deal(USDC, user, collateral);

        vm.startPrank(user);
        IERC20(USDC).approve(address(lending), collateral);
        lending.supply(USDC, collateral);
        ICreditDelegationToken(USDM_V_TOKEN).approveDelegation(address(lending), borrowAmount);
        lending.borrow(USDM, borrowAmount, user);

        uint256 overpay = borrowAmount + 5 * 1e17;
        deal(USDM, user, overpay);
        uint256 balanceBefore = IERC20(USDM).balanceOf(user);

        IERC20(USDM).approve(address(lending), overpay);
        lending.repay(USDM, overpay, user);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(USDM).balanceOf(user);
        uint256 spent = balanceBefore - balanceAfter;

        console.log("USDm spent on repay:", spent);
        assertLt(spent, overpay, "user should not be charged the full overpaid amount");
        assertEq(IERC20(USDM_V_TOKEN).balanceOf(user), 0, "debt cleared");
    }

    function test_getUserReservePosition() public {
        uint256 amount = 10 * 1e6;
        deal(USDC, user, amount);

        vm.startPrank(user);
        IERC20(USDC).approve(address(lending), amount);
        lending.supply(USDC, amount);
        vm.stopPrank();

        (uint256 supplied, uint256 debt) = lending.getUserReservePosition(user, USDC);
        assertGe(supplied, amount - 1);
        assertEq(debt, 0);
    }

    function test_revert_supplyZero() public {
        vm.expectRevert(AaveLending.ZeroAmount.selector);
        lending.supply(USDC, 0);
    }

    function test_revert_borrowWithoutDelegation() public {
        uint256 collateral = 10 * 1e6;
        deal(USDC, user, collateral);

        vm.startPrank(user);
        IERC20(USDC).approve(address(lending), collateral);
        lending.supply(USDC, collateral);

        vm.expectRevert();
        lending.borrow(USDM, 1 * 1e18, user);
        vm.stopPrank();
    }

    function test_pause_blocksOperations() public {
        vm.prank(owner);
        lending.pause();

        deal(USDC, user, 10 * 1e6);
        vm.startPrank(user);
        IERC20(USDC).approve(address(lending), 10 * 1e6);
        vm.expectRevert();
        lending.supply(USDC, 10 * 1e6);
        vm.stopPrank();
    }
}
