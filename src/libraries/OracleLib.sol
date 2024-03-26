// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/** 
 * @title OracleLib
 * @author FalseGenius
 * @notice This library is used to check Chainlink Oracle for stale data.
 * If price is stale, the function will revert, and render DSCEngine unusable - This is by design.
 * We want DSCEngine to freeze if prices become stale.
 * 
 * If Chainlink network explodes, and there is a lot of money locked in the protocol.... too bad!
 */ 

library OracleLib {

    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function stalePriceCheck(AggregatorV3Interface priceFeed) public view returns (uint80, int256, uint256, uint256, uint80) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}