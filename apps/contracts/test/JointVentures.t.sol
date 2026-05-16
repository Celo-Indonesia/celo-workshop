// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {JointVentures} from "../src/JointVentures.sol";
import {Token} from "../src/Token.sol";
import {PriceFeeds} from "../src/PriceFeed.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract JointVenturesTest is Test {
    JointVentures public jointVentures;
    Token public token;
    PriceFeeds public priceFeed;

    address constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address constant USDT = 0x617f3112bf5397D0467D315cC709EF968D9ba546;

    address public owner = address(0x1234);
    address public finance = address(0x123);
    address public member1 = address(0x1);

    function setUp() public {
        vm.createSelectFork("celo");

        vm.startPrank(owner);
        token = new Token(address(owner));
        priceFeed = new PriceFeeds(USDC, USDT);
        jointVentures = new JointVentures(address(token), address(priceFeed));
        token.setJointVenture(address(jointVentures));

        // Granting role
        jointVentures.grantRole(jointVentures.FINANCE_ROLE(), finance);
        jointVentures.grantRole(jointVentures.OPERATOR_ROLE(), finance);
        vm.stopPrank();

        vm.startPrank(finance);
        jointVentures.activate(true);
        // Whitelist tokens
        jointVentures.setTokenWhitelist(USDC);
        jointVentures.setTokenWhitelist(USDT);
        vm.stopPrank();

        vm.prank(member1);
        jointVentures.register("test");
    }

    function test_depositUseUSDC() public {
        uint256 amount = 100 * 1e6; // 100 USDC
        deal(USDC, member1, amount);

        vm.startPrank(member1);
        IERC20(USDC).approve(address(jointVentures), amount);
        jointVentures.deposit(USDC, amount);
        vm.stopPrank();

        uint256 contribution = jointVentures.contributions(member1, USDC);
        uint256 collectedUSD = jointVentures.collectedUSD();
        
        console.log("Member contribution:", contribution);
        console.log("Member token balance:", token.balanceOf(member1));
        console.log("Collected USD:", collectedUSD);

        assertEq(contribution, amount, "Member contribution should be 100 USDC");
        assertEq(token.balanceOf(member1), amount, "Token balance should be 100");
    }

    function test_depositUseUSDT() public {
        uint256 amount = 100 * 1e6; // 100 USDT
        deal(USDT, member1, amount);

        vm.startPrank(member1);
        IERC20(USDT).approve(address(jointVentures), amount);
        jointVentures.deposit(USDT, amount);
        vm.stopPrank();

        uint256 contribution = jointVentures.contributions(member1, USDT);
        uint256 collectedUSD = jointVentures.collectedUSD();

        console.log("Member contribution:", contribution);
        console.log("Member token balance:", token.balanceOf(member1));
        console.log("Collected USD:", collectedUSD);

        assertEq(contribution, amount, "Member contribution should be 100 USDT");
        assertEq(token.balanceOf(member1), amount, "Token balance should be 100");
    }
}