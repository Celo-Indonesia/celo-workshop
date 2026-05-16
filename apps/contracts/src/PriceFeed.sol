// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {AggregatorV3Interface} from "@chainlink/src/interfaces/feeds/AggregatorV3Interface.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED
 * VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

/**
 * If you are reading data feeds on L2 networks, you must
 * check the latest answer from the L2 Sequencer Uptime
 * Feed to ensure that the data is accurate in the event
 * of an L2 sequencer outage. See the
 * https://docs.chain.link/data-feeds/l2-sequencer-feeds
 * page for details.
 */
contract PriceFeeds {
  AggregatorV3Interface internal dataFeed;

  mapping(address => address) public tokenToPriceFeed;

  error TokenNotSupported();
  /**
   * Network: Celo Mainnet
   * Aggregator: BTC/USD
   * Address: 0x128fE88eaa22bFFb868Bb3A584A54C96eE24014b
   */
  constructor(
    address _usdc, 
    address _usdt) {
    tokenToPriceFeed[_usdc] = 0xc7A353BaE210aed958a1A2928b654938EC59DaB2;
    tokenToPriceFeed[_usdt] = 0x5e37AF40A7A344ec9b03CCD34a250F3dA9a20B02;
  }

  /**
   * Returns the latest answer.
   */
  function getChainlinkDataFeedLatestAnswer(address token) public view returns (uint256 price, uint256 decimals) {
    address priceFeedAddress = tokenToPriceFeed[token];

    if (priceFeedAddress == address(0)) {
      revert TokenNotSupported();
    }
    // prettier-ignore
    (
      /* uint80 roundId */
      ,
      int256 answer,
      /*uint256 startedAt*/
      ,
      /*uint256 updatedAt*/
      ,
      /*uint80 answeredInRound*/
    ) = AggregatorV3Interface(priceFeedAddress).latestRoundData();
    return (uint256(answer), AggregatorV3Interface(priceFeedAddress).decimals());
  }
}
