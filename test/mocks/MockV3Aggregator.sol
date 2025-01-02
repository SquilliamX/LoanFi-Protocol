// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MockV3Aggregator
 * @notice Based on the FluxAggregator contract
 * @notice Use this contract when you need to test
 * other contract's ability to read data from an
 * aggregator contract, but how the aggregator got
 * its answer is unimportant
 */
contract MockV3Aggregator {
    // Version of the aggregator
    uint256 public constant version = 0;

    // Decimal places for price precision
    uint8 public decimals;
    // Latest price answer from the oracle
    int256 public latestAnswer;
    // Timestamp of the latest update
    uint256 public latestTimestamp;
    // Latest round ID
    uint256 public latestRound;

    // Mapping to store historical answers by round ID
    mapping(uint256 => int256) public getAnswer;
    // Mapping to store historical timestamps by round ID
    mapping(uint256 => uint256) public getTimestamp;
    // Mapping to store when each round started
    mapping(uint256 => uint256) private getStartedAt;

    /**
     * @notice Initializes the mock aggregator with specified decimals and initial price
     * @param _decimals The number of decimal places for price precision
     * @param _initialAnswer The initial price feed value
     */
    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        updateAnswer(_initialAnswer);
    }

    /**
     * @notice Updates the latest price answer and associated data
     * @param _answer The new price to set
     */
    function updateAnswer(int256 _answer) public {
        latestAnswer = _answer;
        latestTimestamp = block.timestamp;
        latestRound++;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = block.timestamp;
        getStartedAt[latestRound] = block.timestamp;
    }

    /**
     * @notice Updates all round data at once
     * @param _roundId The round ID to update
     * @param _answer The price for this round
     * @param _timestamp When the round was updated
     * @param _startedAt When the round started
     */
    function updateRoundData(uint80 _roundId, int256 _answer, uint256 _timestamp, uint256 _startedAt) public {
        latestRound = _roundId;
        latestAnswer = _answer;
        latestTimestamp = _timestamp;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = _timestamp;
        getStartedAt[latestRound] = _startedAt;
    }

    /**
     * @notice Get price data for a specific round
     * @param _roundId The round ID to query
     * @return roundId The round ID
     * @return answer The price for this round
     * @return startedAt When the round started
     * @return updatedAt When the round was updated
     * @return answeredInRound The round ID of the answer
     */
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, getAnswer[_roundId], getStartedAt[_roundId], getTimestamp[_roundId], _roundId);
    }

    /**
     * @notice Get the latest round data
     * @return roundId The latest round ID
     * @return answer The latest price
     * @return startedAt When the latest round started
     * @return updatedAt When the latest round was updated
     * @return answeredInRound The round ID of the latest answer
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            uint80(latestRound),
            getAnswer[latestRound],
            getStartedAt[latestRound],
            getTimestamp[latestRound],
            uint80(latestRound)
        );
    }

    /**
     * @notice Get the description of this price feed
     * @return The description string
     */
    function description() external pure returns (string memory) {
        return "v0.6/tests/MockV3Aggregator.sol";
    }
}
