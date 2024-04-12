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

    /**
     * @notice Vulnerability - DSC protocol can consume stale price data.
     * Stale period of 3 hrs is too large for Ethereum, Polygon, and Optimism chains, leading to consume stale
     * price data. More info:
     * Since the DSC protocol supports every EVM chain (confirmed by the client), let's consider the ETH / USD oracles on different chains.

     *  On Ethereum, the oracle will update the price data every ~1 hour.
     *  On Polygon, the oracle will update the price data every ~25 seconds.
     *  On BNB (BSC), the oracle will update the price data every ~60 seconds.
     *  On Optimism, the oracle will update the price data every ~20 minutes.
     *  On Arbitrum, the oracle will update the price data every ~24 hours.
     *  On Avalanche, the oracle will update the price data every ~24 hours.
     * 
     * Incorrect prices can cause protocol's functions i.e., mintDsc, burnDsc, redeemCollateral..., to
     * operate incorrectly.
     * 
     * @dev Use mapping data type to record TIMEOUT of each collateral token and setting each token's
     * timeout with appropriate stale period.
     */
    uint256 private constant TIMEOUT = 3 hours;

    function stalePriceCheck(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
