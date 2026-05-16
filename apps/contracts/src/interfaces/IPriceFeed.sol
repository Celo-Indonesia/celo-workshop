// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IPriceFeed {
    function getChainlinkDataFeedLatestAnswer(address token) external view returns (uint256 price, uint256 decimals);
}