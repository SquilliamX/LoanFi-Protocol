// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Errors } from "src/libraries/Errors.sol";
import { CoreStorage } from "./CoreStorage.sol";

/**
 * @title HealthFactor Contract
 * @author William Permuy
 * @notice Manages risk assessment and position health monitoring for the lending protocol
 * @dev Implements sophisticated risk management system with the following features:
 *
 * Architecture Highlights:
 * 1. Risk Assessment Engine
 *    - Real-time position monitoring
 *    - Multi-collateral health calculations
 *    - Dynamic liquidation thresholds
 *    - Cross-token risk aggregation
 *
 * 2. Safety Mechanisms
 *    - Overcollateralization requirements
 *    - Liquidation triggers
 *    - Position health validation
 *    - Borrowing capacity limits
 *
 * 3. Oracle Integration
 *    - Chainlink price feeds
 *    - Real-time USD conversions
 *    - Price manipulation protection
 *    - Stale price safeguards
 *
 * Key Formulas:
 * - Health Factor = (Collateral Value * Liquidation Threshold) / Total Borrowed
 * - Minimum Health Factor = 1.0 (scaled by precision)
 * - Liquidation Threshold = 50% (configurable)
 *
 * Example Scenarios:
 * 1. Healthy Position (HF > 1.0):
 *    - $100 ETH collateral
 *    - $50 borrowed
 *    - Health Factor = (100 * 0.5) / 50 = 1.0
 *
 * 2. Liquidatable Position (HF < 1.0):
 *    - $100 ETH collateral
 *    - $75 borrowed
 *    - Health Factor = (100 * 0.5) / 75 = 0.67
 *
 * Security Considerations:
 * - View functions for gas-free monitoring
 * - Precision handling for accurate calculations
 * - Access control for critical functions
 *
 * Inherits:
 * - CoreStorage: Base storage layer and access control
 */
contract HealthFactor is CoreStorage {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        CoreStorage(tokenAddresses, priceFeedAddresses)
    { }

    /*//////////////////////////////////////////////////////////////
                INTERNAL & PRIVATE VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates user's health factor and reverts if undercollateralized
     * @dev Critical safety check for all collateral/debt modifications
     * @param user Address of position to validate
     * @custom:error HealthFactor__BreaksHealthFactor if position is unsafe
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        // Calculate current health factor for user
        uint256 userHealthFactor = _healthFactor(user);
        // Revert if below minimum threshold
        if (userHealthFactor < _getMinimumHealthFactor()) {
            revert Errors.HealthFactor__BreaksHealthFactor(userHealthFactor);
        }
    }

    /**
     * @notice Retrieves user's complete position information
     * @dev Aggregates borrowed and collateral values with the following features:
     * - Real-time USD value calculations
     * - Cross-token position tracking
     * - Oracle-based price updates
     *
     * @param user Address to get position information for
     * @return totalAmountBorrowed Total USD value of all borrowed assets
     * @return collateralValueInUsd Total USD value of all deposited collateral
     */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalAmountBorrowed, uint256 collateralValueInUsd)
    {
        // Get total borrowed value in USD
        totalAmountBorrowed = getAccountBorrowedValueInUsd(user);
        // Get total collateral value in USD
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
        // Return combined position information
        return (totalAmountBorrowed, collateralValueInUsd);
    }

    /**
     * @notice Calculates user's current health factor
     * @dev Core risk metric for protocol solvency with the following features:
     * - Ratio of collateral to borrowed value
     * - Values above 1 are healthy
     * - Values below 1 are eligible for liquidation
     *
     * @param user Address to calculate health factor for
     * @return uint256 Current health factor (scaled by precision)
     */
    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalAmountBorrowed, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalAmountBorrowed, collateralValueInUsd);
    }

    /**
     * @notice Calculates health factor from USD values
     * @dev Implements core health factor logic:
     * - Perfect health (∞) for zero borrows/collateral
     * - Adjusts collateral by liquidation threshold
     * - Scales result by protocol precision
     *
     * Formula: (collateral * threshold * precision) / borrowed
     * Example: ($1000 * 50% * 1e18) / $100 = 5e18 (health factor of 5)
     *
     * @param totalAmountBorrowed Total borrowed value in USD
     * @param collateralValueInUsd Total collateral value in USD
     * @return uint256 Health factor (scaled by precision)
     */
    function _calculateHealthFactor(
        uint256 totalAmountBorrowed,
        uint256 collateralValueInUsd
    )
        internal
        pure
        returns (uint256)
    {
        // Perfect health for zero positions
        if (totalAmountBorrowed == 0 || collateralValueInUsd == 0) return type(uint256).max;

        // Adjust collateral by liquidation threshold
        uint256 collateralAdjustedForThreshold =
            (collateralValueInUsd * _getLiquidationThreshold()) / _getLiquidationPrecision();

        // Calculate final health factor
        return (collateralAdjustedForThreshold * _getPrecision()) / totalAmountBorrowed;
    }

    /*//////////////////////////////////////////////////////////////
                EXTERNAL & PUBLIC VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves user's complete position information
     * @dev Aggregates borrowed and collateral values with the following features:
     * - Real-time USD value calculations
     * - Cross-token position tracking
     * - Oracle-based price updates
     *
     * @param user Address to get position information for
     * @return totalAmountBorrowed Total USD value of all borrowed assets
     * @return collateralValueInUsd Total USD value of all deposited collateral
     */
    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalAmountBorrowed, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    /**
     * @notice Returns user's current position health factor
     * @dev Key risk metric that determines:
     * - Liquidation eligibility (< MIN_HEALTH_FACTOR)
     * - Position safety margin
     * - Borrowing capacity
     *
     * @param user Address to check health factor for
     * @return uint256 Current health factor (scaled by precision)
     */
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    /**
     * @notice External validation of user's health factor
     * @dev Reverts if position is undercollateralized
     * @param user Address of position to check
     */
    function revertIfHealthFactorIsBroken(address user) external view {
        _revertIfHealthFactorIsBroken(user);
    }

    /**
     * @notice Calculates total USD value of user's borrowed assets across all supported tokens
     * @dev Implements a comprehensive borrowed value calculation with the following features:
     *
     * Architecture Highlights:
     * 1. Cross-Token Aggregation
     *    - Iterates through all supported tokens
     *    - Handles multiple debt positions
     *    - Maintains precision across different token decimals
     *
     * 2. Price Calculations
     *    - Real-time oracle price feeds
     *    - USD normalization for consistent valuation
     *    - Protected against price manipulation
     *
     * @param user Address to calculate total borrowed value for
     * @return totalBorrowedValueInUsd Aggregated USD value of all borrowed assets
     */
    function getAccountBorrowedValueInUsd(address user) public view returns (uint256 totalBorrowedValueInUsd) {
        // STAGE 1: Token Iteration
        // Systematically process each supported token to aggregate total borrowed value
        // This ensures we capture all user's debt positions across the protocol
        for (uint256 i = 0; i < _getAllowedTokens().length; i++) {
            // STAGE 2: Token Resolution
            // Get current token address from supported tokens array
            // This maintains protocol flexibility as new tokens can be added
            address token = _getAllowedTokens()[i];

            // STAGE 3: Position Calculation
            // Query user's borrowed amount for current token
            // This represents their actual debt position for this asset
            uint256 amount = _getAmountOfTokenBorrowed(user, token);

            // STAGE 4: USD Conversion
            // Convert borrowed amount to USD using oracle price feeds
            // Aggregates into running total while maintaining precision
            totalBorrowedValueInUsd += _getUsdValue(token, amount);
        }

        // STAGE 5: Return Aggregated Value
        // Final USD value represents user's total debt across all assets
        return totalBorrowedValueInUsd;
    }

    /**
     * @notice Calculates total USD value of user's collateral across all supported tokens
     * @dev Implements sophisticated collateral valuation system with the following features:
     *
     * Architecture Highlights:
     * 1. Multi-Collateral Support
     *    - Handles diverse asset types
     *    - Cross-token position tracking
     *    - Extensible token support
     *
     * 2. Real-time Valuation
     *    - Oracle-based price feeds
     *    - Current market rates
     *    - Precision-aware calculations
     *
     * @param user Address to calculate total collateral value for
     * @return totalCollateralValueInUsd Aggregated USD value of all collateral
     */
    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // STAGE 1: Collateral Scanning
        // Iterate through all supported collateral tokens
        // This ensures complete position coverage for accurate risk assessment
        for (uint256 i = 0; i < _getAllowedTokens().length; i++) {
            // STAGE 2: Asset Identification
            // Retrieve current token from supported assets list
            // Maintains protocol flexibility for future token additions
            address token = _getAllowedTokens()[i];

            // STAGE 3: Balance Resolution
            // Get user's deposited amount for current token
            // This represents their actual collateral position
            uint256 amount = _getCollateralBalanceOfUser(user, token);

            // STAGE 4: Value Aggregation
            // Convert collateral to USD value using oracle prices
            // Accumulates total value while maintaining precision
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }

        // STAGE 5: Position Valuation
        // Return total USD value of all collateral
        // Critical for health factor calculations and risk assessment
        return totalCollateralValueInUsd;
    }

    /**
     * @notice Calculates position health factor from USD values
     * @dev Pure calculation without state access
     * @param totalAmountBorrowed Total borrowed value in USD
     * @param collateralValueInUsd Total collateral value in USD
     * @return uint256 Health factor (scaled by precision)
     */
    function calculateHealthFactor(
        uint256 totalAmountBorrowed,
        uint256 collateralValueInUsd
    )
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalAmountBorrowed, collateralValueInUsd);
    }
}
