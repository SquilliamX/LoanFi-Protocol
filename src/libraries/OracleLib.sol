// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/* 
 * @title OracleLib
 * @author Squilliam
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, the function will revert and render the DSCEngine unusable - this is by design
 * We want the DSCEngine to freeze if prices becomes stale.
 * 
 * So if the Chainlink network explodes and you have a lot of money locked in the protocol... a pause will begin in order to protect users funds
 */
library OracleLib {
    // Custom error for when price data is considered stale
    error OracleLib__StalePrice();

    // `hours` is a solidity keyword, means 3 * 60 * 60 = 10800 seconds
    uint256 private constant TIMEOUT = 3 hours;

    /**
     * @notice Checks if the latest price data from Chainlink is fresh (not stale)
     * @param priceFeed The Chainlink price feed to check
     * @return A tuple containing the round data from Chainlink:
     *         - roundId: The round ID of the price data
     *         - answer: The price value
     *         - startedAt: Timestamp when the round started
     *         - updatedAt: Timestamp when the round was last updated
     *         - answeredInRound: The round ID in which the answer was computed
     */
    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (
            // returns the same return value of the latest round data function in an aggregator v3
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        // Get the latest round data from the Chainlink price feed
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        // Calculate how many seconds have passed since the last update
        uint256 secondsSince = block.timestamp - updatedAt;

        // If more time has passed than our TIMEOUT, consider the price stale and revert
        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }

        // If price is fresh, return all the round data
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
