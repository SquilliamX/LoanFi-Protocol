// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AutomationCompatibleInterface } from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import { LiquidationEngine } from "../Liquidation-Operations/LiquidationEngine.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidationAutomation is AutomationCompatibleInterface, Ownable {
    LiquidationEngine private immutable i_liquidations;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant CHECK_BATCH_SIZE = 100; // Check 100 users per upkeep
    uint256 private s_lastCheckedIndex;

    constructor(address liquidationsAddress) Ownable(msg.sender) {
        i_liquidations = LiquidationEngine(liquidationsAddress);
    }

    /**
     * notice Chainlink Automation checks this function to determine if liquidations are needed
     * dev This is the monitoring system for protocol safety:
     * - Runs periodically based on Chainlink Automation configuration (every 30 seconds)
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
        // Step 1: Get batch info
        (address[] memory batchUsers, uint256 totalUsers) = _getCurrentBatch();
        if (totalUsers == 0) return (false, "");

        // Step 2: Process batch and get results
        (bool hasUnhealthyUsers, bytes memory batchData) = _processBatchUsers(batchUsers);

        // Step 3: Update state and return results
        _updateCheckBatchIndex(totalUsers);
        return (hasUnhealthyUsers, batchData);
    }

    function _getCurrentBatch() private view returns (address[] memory batchUsers, uint256 totalUsers) {
        return i_liquidations.getUserBatch(CHECK_BATCH_SIZE, s_lastCheckedIndex);
    }

    function _processBatchUsers(address[] memory batchUsers)
        private
        view
        returns (bool hasUnhealthyUsers, bytes memory batchData)
    {
        // Initialize arrays for unhealthy positions
        (address[] memory users, uint256[] memory healthFactors, uint256 count) = _initializeArrays();

        // Scan users and collect unhealthy positions
        count = _scanUsersHealth(batchUsers, users, healthFactors);

        // Return results
        if (count > 0) {
            hasUnhealthyUsers = true;
            batchData = abi.encode(users, healthFactors, count);
        }

        return (hasUnhealthyUsers, batchData);
    }

    function _initializeArrays()
        private
        pure
        returns (address[] memory users, uint256[] memory healthFactors, uint256 count)
    {
        users = new address[](CHECK_BATCH_SIZE);
        healthFactors = new uint256[](CHECK_BATCH_SIZE);
        count = 0;
        return (users, healthFactors, count);
    }

    function _scanUsersHealth(
        address[] memory batchUsers,
        address[] memory users,
        uint256[] memory healthFactors
    )
        private
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < batchUsers.length; i++) {
            address user = batchUsers[i];
            uint256 healthFactor = i_liquidations.getHealthFactor(user);

            if (healthFactor < MIN_HEALTH_FACTOR) {
                users[count] = user;
                healthFactors[count] = healthFactor;
                count++;
            }
        }
        return count;
    }

    function _updateCheckBatchIndex(uint256 totalUsers) private {
        s_lastCheckedIndex = (s_lastCheckedIndex + CHECK_BATCH_SIZE) % totalUsers;
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
        // Step 1: Decode the batch data
        (address[] memory users, uint256 count) = _decodePerformData(performData);

        // Step 2: Process each user's positions
        _processUserBatch(users, count);

        // Step 3: Update state for next batch
        _updateBatchTracking();
    }

    function _decodePerformData(bytes calldata performData)
        private
        pure
        returns (address[] memory users, uint256 count)
    {
        // Decode all components at once
        (users,, count) = abi.decode(performData, (address[], uint256[], uint256));
        return (users, count);
    }

    function _processUserBatch(address[] memory users, uint256 count) private {
        for (uint256 i = 0; i < count; i++) {
            address user = users[i];
            _processUserPositions(user);
        }
    }

    function _processUserPositions(address user) private {
        // Get all positions that need liquidation
        (address[] memory debtTokens, address[] memory collaterals, uint256[] memory debtAmounts) =
            i_liquidations.getInsufficientBonusPositions(user);

        // Process each position
        for (uint256 j = 0; j < debtTokens.length; j++) {
            _attemptLiquidation(user, debtTokens[j], collaterals[j], debtAmounts[j]);
        }
    }

    function _attemptLiquidation(address user, address debtToken, address collateral, uint256 debtAmount) private {
        // Skip invalid positions
        if (debtToken == address(0) || collateral == address(0)) {
            return;
        }

        // Try to liquidate, ignore failures
        try i_liquidations.protocolLiquidate(user, collateral, debtToken, debtAmount) { } catch { }
    }

    function _updateBatchTracking() private {
        // Get total user count
        (, uint256 totalUsers) = i_liquidations.getUserBatch(1, 0);

        // Update last checked index with wraparound
        s_lastCheckedIndex = (s_lastCheckedIndex + CHECK_BATCH_SIZE) % totalUsers;
    }
}
