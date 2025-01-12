// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AutomationCompatibleInterface } from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import { Liquidations } from "../Liquidations.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidationAutomation is AutomationCompatibleInterface, Ownable {
    Liquidations private immutable i_liquidations;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant CHECK_BATCH_SIZE = 1000; // Check 1000 users per upkeep
    uint256 private s_lastCheckedIndex;

    constructor(address liquidationsAddress) Ownable(msg.sender) {
        i_liquidations = Liquidations(liquidationsAddress);
    }

    /**
     * notice Chainlink Automation checks this function to determine if liquidations are needed
     * dev This is the monitoring system for protocol safety:
     * - Runs periodically based on Chainlink Automation configuration
     * - Scans batches of users for unhealthy positions
     * - Identifies positions needing protocol intervention
     *
     * param checkData Not used in this implementation, but required by Chainlink interface
     * return upkeepNeeded Boolean flag indicating if liquidations are needed
     * return performData Encoded data containing users to liquidate
     */
    function checkUpkeep(bytes calldata /* checkData */ )
        external
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // Step 1: Initialize arrays for batch processing
        // Fixed-size arrays to store users we find that need liquidation
        // Size is determined by CHECK_BATCH_SIZE (e.g., 1000 users per check)
        address[] memory users = new address[](CHECK_BATCH_SIZE);
        uint256[] memory healthFactors = new uint256[](CHECK_BATCH_SIZE);

        // Counter to track how many users actually need liquidation
        // This might be less than CHECK_BATCH_SIZE
        uint256 count = 0;

        // Step 2: Get the current batch of users to check
        // getUserBatch returns two things:
        // 1. batchUsers: Array of user addresses to check in this batch
        // 2. totalUsers: Total number of users in the system
        (address[] memory batchUsers, uint256 totalUsers) =
            i_liquidations.getUserBatch(CHECK_BATCH_SIZE, s_lastCheckedIndex);

        // Step 3: Early return if system is empty
        // If there are no users in the system, no need to continue checking
        if (totalUsers == 0) return (false, "");

        // Step 4: Check each user in the current batch
        for (uint256 i = 0; i < batchUsers.length; i++) {
            // Get the current user's address
            address user = batchUsers[i];

            // Get this user's health factor from the Liquidations contract
            // Health factor is a measure of position safety:
            // - < 1e18 (1.0): Position is unhealthy and can be liquidated
            // - >= 1e18: Position is healthy
            uint256 healthFactor = i_liquidations.getHealthFactor(user);

            // Step 5: If user's position is unhealthy, add them to our list
            if (healthFactor < MIN_HEALTH_FACTOR) {
                // MIN_HEALTH_FACTOR = 1e18
                // Store the user's address in our array
                users[count] = user;
                // Store their health factor (might be useful for prioritization)
                healthFactors[count] = healthFactor;
                // Increment our counter of users needing liquidation
                count++;
            }
        }

        // Step 6: Prepare return values based on what we found
        if (count > 0) {
            // We found users needing liquidation
            upkeepNeeded = true;

            // Package the data needed by performUpkeep:
            // - users: Array of addresses needing liquidation
            // - healthFactors: Their corresponding health factors
            // - count: How many users we found
            performData = abi.encode(users, healthFactors, count);
        }

        // Step 7: Update state for next check
        // Get total user count (efficiently with batch size 1)
        (batchUsers, totalUsers) = i_liquidations.getUserBatch(1, 0);

        // Calculate the starting index for next batch
        // Uses modulo (%) to wrap around to start when we reach the end
        s_lastCheckedIndex = (s_lastCheckedIndex + CHECK_BATCH_SIZE) % totalUsers;

        // Return our findings:
        // - upkeepNeeded: true if we found users to liquidate, false otherwise
        // - performData: encoded data if upkeepNeeded, empty otherwise
        return (upkeepNeeded, performData);
    }

    /**
     * @notice Executes protocol liquidations for unhealthy positions
     * @dev This is the core automation function that protects protocol solvency:
     * - Called automatically by Chainlink when checkUpkeep returns true
     * - Handles multiple users and multiple positions per user
     * - Uses try/catch for resilient execution
     *
     * Key Features:
     * - Batch processing of liquidations
     * - Graceful error handling
     * - Gas-efficient execution
     * - Complete position coverage
     *
     * @param performData Encoded batch data from checkUpkeep containing users to liquidate
     */
    function performUpkeep(bytes calldata performData) external override {
        // Step 1: Decode the batch data passed from checkUpkeep
        // The data contains three pieces of information:
        // 1. users: Array of addresses that need liquidation
        // 2. healthFactors: Array of health factors (skipped since already verified)
        // 3. count: Number of users in this batch
        (
            address[] memory users, // Array of users to process
            , // Skip healthFactors (comma maintains decode structure)
            uint256 count // How many users are in this batch
        ) = abi.decode(performData, (address[], uint256[], uint256));

        // Step 2: Process each user in the batch
        // Iterate through users up to 'count' (might be less than array length)
        for (uint256 i = 0; i < count; i++) {
            // Get the current user's address
            address user = users[i];

            // Step 3: Find ALL positions for this user that need protocol liquidation
            // This returns three parallel arrays:
            // - debtTokens: Which tokens the user borrowed
            // - collaterals: Which collateral tokens to seize
            // - debtAmounts: How much debt to repay for each position
            (address[] memory debtTokens, address[] memory collaterals, uint256[] memory debtAmounts) =
                i_liquidations.getInsufficientBonusPositions(user);

            // Step 4: Liquidate each position found for this user
            // Process all positions that need protocol intervention
            for (uint256 j = 0; j < debtTokens.length; j++) {
                // Verify position is valid (non-zero addresses)
                // address(0) would indicate an invalid or empty position
                if (debtTokens[j] != address(0) && collaterals[j] != address(0)) {
                    // Step 5: Attempt to liquidate this specific position
                    // We use try/catch because:
                    // - Liquidation might fail due to market conditions
                    // - We don't want one failure to stop other liquidations
                    // - Ensures maximum possible positions are handled
                    try i_liquidations.protocolLiquidate(
                        user, // The user being liquidated
                        collaterals[j], // The collateral token to seize
                        debtTokens[j], // The debt token to repay
                        debtAmounts[j] // How much debt to repay
                    ) { } catch { } // Empty catch means continue even if this one fails
                }
            }
        }

        // Step 6: Update the batch tracking for next time
        // Get the total number of users in the system
        (, uint256 totalUsers) = i_liquidations.getUserBatch(1, 0);

        // Update the index for the next batch
        // Uses modulo to wrap around to the beginning when reaching the end
        s_lastCheckedIndex = (s_lastCheckedIndex + CHECK_BATCH_SIZE) % totalUsers;
    }
}
