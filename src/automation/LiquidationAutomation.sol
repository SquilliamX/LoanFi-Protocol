// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AutomationCompatibleInterface } from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import { LiquidationEngine } from "../Liquidation-Operations/LiquidationEngine.sol";

/**
 * @title LiquidationAutomation
 * @author William Permuy
 * @notice Automated liquidation system using Chainlink Automation
 * @dev Implements Chainlink's AutomationCompatibleInterface for automated position monitoring
 */
contract LiquidationAutomation is AutomationCompatibleInterface, Ownable {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Core components for liquidation automation
    LiquidationEngine private immutable i_liquidations; // Reference to the main liquidation engine contract

    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // Minimum health factor (1.0) before liquidation is possible

    uint256 private constant CHECK_BATCH_SIZE = 100; // Process users in batches of 100 for gas efficiency

    uint256 private s_lastCheckedIndex; // Tracks the last user checked to ensure all users are monitored over time

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address liquidationsAddress) Ownable(msg.sender) {
        i_liquidations = LiquidationEngine(liquidationsAddress); // Initialize the immutable reference to LiquidationEngine
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        // Step 1: Get batch info
        (address[] memory batchUsers, uint256 totalUsers) = _getCurrentBatch();
        if (totalUsers == 0) return (false, "");

        // Step 2: Process batch and get results
        (bool hasUnhealthyUsers, bytes memory batchData) = _processBatchUsers(batchUsers);

        // Step 3: Update state and return results
        _updateCheckBatchIndex(totalUsers);
        return (hasUnhealthyUsers, batchData);
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

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves the current batch of users for health factor checking
     * @dev Implements batch processing pattern for gas optimization and scalability:
     * - Uses CHECK_BATCH_SIZE (100) to limit gas consumption per upkeep
     * - Tracks progress using s_lastCheckedIndex for continuous monitoring
     * - Circular buffer pattern ensures all users are checked over time
     *
     * @return batchUsers Array of user addresses in current batch
     * @return totalUsers Total number of users in the protocol (for circular buffer calculation)
     */
    function _getCurrentBatch() private view returns (address[] memory batchUsers, uint256 totalUsers) {
        return i_liquidations.getUserBatch(CHECK_BATCH_SIZE, s_lastCheckedIndex);
    }

    /**
     * @notice Processes a batch of users to identify positions requiring liquidation
     * @dev Implements efficient batch scanning and data collection:
     * - Memory optimization through pre-allocated arrays
     * - Single-pass scanning for minimal gas consumption
     * - Compact data encoding for Chainlink automation
     *
     * Process Flow:
     * 1. Initialize fixed-size arrays for collecting unhealthy positions
     * 2. Scan each user's health factor in the batch
     * 3. Encode results for performUpkeep if unhealthy positions found
     *
     * @param batchUsers Array of user addresses to check in this batch
     * @return hasUnhealthyUsers Boolean indicating if any users need liquidation
     * @return batchData ABI-encoded data containing unhealthy positions for liquidation
     */
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

    /**
     * @notice Initializes fixed-size arrays for collecting unhealthy positions
     * @dev Implements efficient memory allocation strategy:
     * - Uses CHECK_BATCH_SIZE (100) for optimal memory pre-allocation
     * - Marked as 'pure' since it doesn't read state, maximizing gas efficiency
     * - Returns multiple arrays in a single operation to avoid stack depth issues
     *
     * Memory Management:
     * - Arrays are allocated in memory for temporary storage during batch processing
     * - Size is fixed to CHECK_BATCH_SIZE to prevent dynamic resizing costs
     * - Counter initialized to track actual number of unhealthy positions found
     *
     * @return users Memory array to store addresses of users with unhealthy positions
     * @return healthFactors Memory array to store corresponding health factors
     * @return count Initial count set to 0, will track number of unhealthy positions
     */
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

    /**
     * @notice Scans a batch of users and identifies positions below minimum health factor
     * @dev Implements efficient health factor monitoring system:
     * - Single-pass iteration for gas optimization
     * - In-place array population to minimize memory operations
     * - Early position identification for timely liquidations
     *
     * Risk Assessment Process:
     * 1. Iterates through provided batch of user addresses
     * 2. Queries each user's current health factor from LiquidationEngine
     * 3. Records users with health factors below MIN_HEALTH_FACTOR (1.0)
     * 4. Maintains count of identified at-risk positions
     *
     * @param batchUsers Source array of user addresses to check
     * @param users Destination array for storing users needing liquidation
     * @param healthFactors Parallel array storing corresponding health factors
     * @return count Number of unhealthy positions identified in this batch
     *
     */
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

    /**
     * @notice Updates the batch tracking index using circular buffer pattern
     * @dev Implements continuous monitoring system:
     * - Uses modulo arithmetic for circular progression through user list
     * - Advances by CHECK_BATCH_SIZE (100) for consistent batch sizes
     * - Wraps around to start when reaching total user count
     *
     * @param totalUsers Total number of users in protocol for modulo calculation
     */
    function _updateCheckBatchIndex(uint256 totalUsers) private {
        s_lastCheckedIndex = (s_lastCheckedIndex + CHECK_BATCH_SIZE) % totalUsers;
    }

    /**
     * @notice Decodes the performData from Chainlink Automation for liquidation execution
     * @dev Implements efficient ABI decoding strategy:
     * - Single abi.decode call to minimize gas consumption
     * - Handles packed data format from checkUpkeep
     * - Discards unused health factors array to optimize memory usage
     *
     * Data Structure:
     * - Input: ABI-encoded tuple of (address[], uint256[], uint256)
     * - Output: Decoded user addresses and count for batch processing
     *
     * @param performData Encoded data from checkUpkeep containing liquidation targets
     * @return users Array of user addresses requiring liquidation
     * @return count Number of users in the batch to process
     */
    function _decodePerformData(bytes calldata performData)
        private
        pure
        returns (address[] memory users, uint256 count)
    {
        // Decode all components at once
        (users,, count) = abi.decode(performData, (address[], uint256[], uint256));
        return (users, count);
    }

    /**
     * @notice Processes a batch of users identified for liquidation
     * @dev Implements systematic liquidation processing:
     * - Sequential processing of users identified by checkUpkeep
     * - Bounded iteration using count parameter for gas predictability
     * - Delegates individual user processing to specialized function
     *
     * Processing Flow:
     * - Iterates through array of users needing liquidation
     * - Processes each user's positions independently
     * - Maintains batch integrity through count parameter
     *
     * @param users Array of user addresses requiring liquidation
     * @param count Number of valid entries in the users array to process
     *
     * Note: count parameter ensures we only process actual unhealthy positions,
     * avoiding unnecessary iterations over empty array slots
     */
    function _processUserBatch(address[] memory users, uint256 count) private {
        for (uint256 i = 0; i < count; i++) {
            address user = users[i];
            _processUserPositions(user);
        }
    }

    /**
     * @notice Processes all liquidatable positions for a single user
     * @dev Implements comprehensive position liquidation strategy:
     * - Retrieves all underwater positions from LiquidationEngine
     * - Handles multiple debt/collateral pairs per user
     * - Processes positions in order of increasing health factor
     *
     * Position Processing:
     * - Fetches positions below bonus threshold
     * - Processes each debt-collateral pair independently
     * - Maintains atomicity per position liquidation
     *
     * Return Values from getInsufficientBonusPositions:
     * @dev Arrays are parallel, index i in each array corresponds to the same position
     * - debtTokens[i]: Address of the borrowed token
     * - collaterals[i]: Address of the collateral token
     * - debtAmounts[i]: Amount of debt to be repaid
     *
     * @param user Address of the user whose positions need liquidation
     */
    function _processUserPositions(address user) private {
        // Get all positions that need liquidation
        (address[] memory debtTokens, address[] memory collaterals, uint256[] memory debtAmounts) =
            i_liquidations.getInsufficientBonusPositions(user);

        // Process each position
        for (uint256 j = 0; j < debtTokens.length; j++) {
            _attemptLiquidation(user, debtTokens[j], collaterals[j], debtAmounts[j]);
        }
    }

    /**
     * @notice Executes a single liquidation attempt for a specific position
     * @dev Implements safe liquidation execution pattern:
     * - Validates token addresses to prevent invalid liquidations
     * - Direct interaction with LiquidationEngine for core logic
     * - Maintains position-level atomicity
     *
     * Safety Checks:
     * - Validates both debt and collateral token addresses
     * - Skips invalid positions without reverting
     * - Delegates actual liquidation to trusted LiquidationEngine
     *
     * @param user Address of the user being liquidated
     * @param debtToken Address of the token user has borrowed
     * @param collateral Address of the token used as collateral
     * @param debtAmount Amount of debt to be liquidated
     *
     * Note: Function continues processing remaining positions even if one fails,
     * ensuring system resilience during batch liquidations
     */
    function _attemptLiquidation(address user, address debtToken, address collateral, uint256 debtAmount) private {
        // Skip invalid positions
        if (debtToken == address(0) || collateral == address(0)) {
            return;
        }

        // liquidate
        i_liquidations.protocolLiquidate(user, debtToken, debtAmount);
    }

    /**
     * @notice Updates global batch tracking state after liquidation processing
     * @dev Implements state synchronization for continuous monitoring:
     * - Retrieves current total user count from LiquidationEngine
     * - Updates global index using circular buffer pattern
     * - Ensures seamless transition to next batch
     *
     * State Management:
     * - Minimizes storage operations for gas efficiency
     * - Uses modulo arithmetic for index wraparound
     * - Maintains protocol-wide monitoring progress
     *
     * Implementation Details:
     * - Fetches total user count with minimal data (batch size 1)
     * - Updates s_lastCheckedIndex for next checkUpkeep cycle
     * - Ensures no users are skipped in monitoring rotation
     */
    function _updateBatchTracking() private {
        // Get total user count
        (, uint256 totalUsers) = i_liquidations.getUserBatch(1, 0);

        // Update last checked index with wraparound
        s_lastCheckedIndex = (s_lastCheckedIndex + CHECK_BATCH_SIZE) % totalUsers;
    }
}
