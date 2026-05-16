// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Test, console} from "forge-std/Test.sol";
import {PriceFeeds} from "../src/PriceFeed.sol";


contract PriceFeedTest is Test {
  PriceFeeds priceFeeds;

  address constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
  address constant USDT = 0x617f3112bf5397D0467D315cC709EF968D9ba546;

  function setUp() public {
    vm.createSelectFork("celo");
    priceFeeds = new PriceFeeds(USDC, USDT);
  }

  function testGetChainlinkDataFeedLatestAnswer() public view {
    (uint256 answer, uint256 decimals) = priceFeeds.getChainlinkDataFeedLatestAnswer(USDC);
    console.log("Latest answer from Chainlink data feed:", answer);
    console.log("Decimals:", decimals);
    assertTrue(answer > 0, "Answer should be greater than 0");
  }
}