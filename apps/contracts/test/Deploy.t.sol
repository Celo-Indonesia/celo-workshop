// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DeployScript} from "../script/Deploy.s.sol";

contract DeployTest is Test {
    DeployScript public deployScript;

    function setUp() public {
        deployScript = new DeployScript();
    }

    function testDeploy() public {
        deployScript.run();

        console.log("JointVentures deployed at:", address(deployScript.jointVentures()));
        console.log("Token deployed at:", address(deployScript.token()));
    }
}