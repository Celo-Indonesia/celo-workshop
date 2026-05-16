// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {JointVentures} from "../src/JointVentures.sol";
import {Token} from "../src/Token.sol";
import {PriceFeeds} from "../src/PriceFeed.sol";

contract DeployScript is Script {
    JointVentures public jointVentures;
    Token public token;
    PriceFeeds public priceFeed;

    address constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address constant USDT = 0x617f3112bf5397D0467D315cC709EF968D9ba546;

    address public finance = vm.envAddress("FINANCE_ADDRESS");
    address public operator = vm.envAddress("OPERATOR_ADDRESS");

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);
        
        // DEPLOYMENT
        token = new Token(deployer);
        console.log("Token contract deployed at:", address(token));

        priceFeed = new PriceFeeds(USDC, USDT);
        console.log("PriceFeed contract deployed at:", address(priceFeed));

        jointVentures = new JointVentures(address(token), address(priceFeed));
        console.log("JointVentures contract deployed at:", address(jointVentures));

        token.setJointVenture(address(jointVentures));
        console.log("JointVentures set in Token contract");

        // GRANT ROLE
        jointVentures.grantRole(jointVentures.FINANCE_ROLE(), finance);
        jointVentures.grantRole(jointVentures.OPERATOR_ROLE(), operator);

        vm.stopBroadcast();

        // Finance can activate and whitelist tokens
        uint256 financePrivateKey = vm.envUint("FINANCE_PRIVATE_KEY");
        vm.startBroadcast(financePrivateKey);
        jointVentures.activate(true);
        console.log("JointVentures activated");
        
        jointVentures.setTokenWhitelist(USDC);
        jointVentures.setTokenWhitelist(USDT);
        console.log("Tokens USDC, USDT whitelisted");

        vm.stopBroadcast();
    }
}
