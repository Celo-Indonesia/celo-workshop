// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {MorphoEarn} from "../src/MorphoEarn.sol";
import {IMorpho, IMorphoOracle, MarketParams, Id, Position, Market} from "../src/interfaces/IMorpho.sol";

/// @notice Simple fixed-price oracle for testing Morpho markets.
///         Morpho price is the collateral price quoted in the loan token,
///         scaled by 1e36 + loanDecimals - collateralDecimals.
contract MockOracle is IMorphoOracle {
    uint256 public scaledPrice;

    constructor(uint256 _scaledPrice) {
        scaledPrice = _scaledPrice;
    }

    function price() external view returns (uint256) {
        return scaledPrice;
    }
}

/// @notice Fork tests against real Morpho Blue on Celo. We create our own
///         market (loan = USDC, collateral = USDm) with a mock oracle, seed
///         a borrower so interest accrues, and verify a lender earns yield
///         through the MorphoEarn wrapper.
///
/// Run:
///   forge test --match-contract MorphoEarnForkTest --fork-url celo -vv
contract MorphoEarnForkTest is Test {
    address constant MORPHO = 0xd24ECdD8C1e0E57a4E26B1a7bbeAa3e95466A569;
    address constant ADAPTIVE_CURVE_IRM = 0x683CAAADdfA2F42e24880E202676526d501a5dED;
    uint256 constant LLTV_86 = 860000000000000000;

    address constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address constant USDM = 0x765DE816845861e75A25fCA122bb6898B8B1282a;

    MorphoEarn public earn;
    MockOracle public oracle;
    MarketParams public marketParams;

    address public owner = makeAddr("owner");
    address public lender = makeAddr("lender");
    address public borrower = makeAddr("borrower");

    function setUp() public {
        vm.createSelectFork("celo");

        vm.prank(owner);
        earn = new MorphoEarn(MORPHO);

        // 1 USDm = 1 USDC, scaled by 1e36 + loanDec(6) - collateralDec(18) = 1e24
        oracle = new MockOracle(1e24);

        marketParams = MarketParams({
            loanToken: USDC,
            collateralToken: USDM,
            oracle: address(oracle),
            irm: ADAPTIVE_CURVE_IRM,
            lltv: LLTV_86
        });

        IMorpho(MORPHO).createMarket(marketParams);
    }

    function test_chainAndMarket() public view {
        assertEq(block.chainid, 42220);
        Id id = earn.marketId(marketParams);
        Market memory m = IMorpho(MORPHO).market(id);
        assertGt(m.lastUpdate, 0, "market should be created");
    }

    function test_deposit_USDC() public {
        uint256 amount = 100 * 1e6;
        deal(USDC, lender, amount);

        vm.startPrank(lender);
        IERC20(USDC).approve(address(earn), amount);
        (uint256 supplied, uint256 shares) = earn.deposit(marketParams, amount);
        vm.stopPrank();

        console.log("USDC supplied:", supplied);
        console.log("supply shares:", shares);

        assertEq(supplied, amount, "all USDC should be supplied");
        assertGt(shares, 0);
        assertEq(IERC20(USDC).balanceOf(lender), 0);

        (uint256 shareBal, uint256 assetsEst) = earn.getEarnPosition(marketParams, lender);
        assertEq(shareBal, shares);
        assertEq(assetsEst, amount);
    }

    function test_withdraw_USDC_noBorrowers() public {
        uint256 amount = 50 * 1e6;
        deal(USDC, lender, amount);

        vm.startPrank(lender);
        IERC20(USDC).approve(address(earn), amount);
        earn.deposit(marketParams, amount);

        IMorpho(MORPHO).setAuthorization(address(earn), true);
        (uint256 withdrawn,) = earn.withdraw(marketParams, amount, lender);
        vm.stopPrank();

        assertEq(withdrawn, amount, "no borrowers = no yield, full principal returned");
        assertEq(IERC20(USDC).balanceOf(lender), amount);
    }

    function test_earnsYield_whenBorrowerOpensPosition() public {
        uint256 lendAmount = 100 * 1e6;
        uint256 collateralAmount = 50 * 1e18;
        uint256 borrowAmount = 30 * 1e6;

        // 1. Lender deposits via the wrapper.
        deal(USDC, lender, lendAmount);
        vm.startPrank(lender);
        IERC20(USDC).approve(address(earn), lendAmount);
        earn.deposit(marketParams, lendAmount);
        vm.stopPrank();

        // 2. Borrower supplies USDm collateral and borrows USDC directly on Morpho.
        deal(USDM, borrower, collateralAmount);
        vm.startPrank(borrower);
        IERC20(USDM).approve(MORPHO, collateralAmount);
        IMorpho(MORPHO).supplyCollateral(marketParams, collateralAmount, borrower, "");
        IMorpho(MORPHO).borrow(marketParams, borrowAmount, 0, borrower, borrower);
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(borrower), borrowAmount);

        // 3. Move time forward — interest accrues on borrower's debt and
        //    therefore on lender's supply position.
        vm.warp(block.timestamp + 30 days);
        IMorpho(MORPHO).accrueInterest(marketParams);

        (, uint256 estimatedAssets) = earn.getEarnPosition(marketParams, lender);
        console.log("lender position after 30d (USDC):", estimatedAssets);
        assertGt(estimatedAssets, lendAmount, "supply should have accrued interest");

        // 4. Borrower repays the full debt so the loan pool is liquid again.
        Id id = earn.marketId(marketParams);
        uint256 borrowShares = IMorpho(MORPHO).position(id, borrower).borrowShares;
        Market memory m = IMorpho(MORPHO).market(id);
        uint256 owed =
            (uint256(m.totalBorrowAssets) * borrowShares + uint256(m.totalBorrowShares) - 1)
            / uint256(m.totalBorrowShares);
        deal(USDC, borrower, owed);

        vm.startPrank(borrower);
        IERC20(USDC).approve(MORPHO, owed);
        IMorpho(MORPHO).repay(marketParams, 0, borrowShares, borrower, "");
        vm.stopPrank();

        // 5. Lender withdraws all — should receive principal + yield.
        vm.startPrank(lender);
        IMorpho(MORPHO).setAuthorization(address(earn), true);
        (uint256 withdrawn,) = earn.withdrawAll(marketParams, lender);
        vm.stopPrank();

        console.log("USDC withdrawn by lender:", withdrawn);
        assertGt(withdrawn, lendAmount, "lender should earn yield");
        assertEq(IERC20(USDC).balanceOf(lender), withdrawn);
    }

    function test_revert_depositZero() public {
        vm.expectRevert(MorphoEarn.ZeroAmount.selector);
        earn.deposit(marketParams, 0);
    }

    function test_revert_withdrawWithoutAuthorization() public {
        uint256 amount = 10 * 1e6;
        deal(USDC, lender, amount);

        vm.startPrank(lender);
        IERC20(USDC).approve(address(earn), amount);
        earn.deposit(marketParams, amount);

        vm.expectRevert();
        earn.withdraw(marketParams, amount, lender);
        vm.stopPrank();
    }

    function test_pause_blocksDeposits() public {
        vm.prank(owner);
        earn.pause();

        deal(USDC, lender, 10 * 1e6);
        vm.startPrank(lender);
        IERC20(USDC).approve(address(earn), 10 * 1e6);
        vm.expectRevert();
        earn.deposit(marketParams, 10 * 1e6);
        vm.stopPrank();
    }
}
