// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILoanFi Interface
 * @author William Permuy
 * @notice Interface defining core functionality for the LoanFi lending protocol
 * @dev This interface serves as the primary interaction point for external contracts
 *      and provides a comprehensive API for the protocol's core functions
 */
interface ILoanFi {
    /**
     * @notice Retrieves the current health factor for a user's position
     * @dev Health factor is calculated as: (collateral * liquidation threshold) / total borrowed
     * @param user Address of the user to check
     * @return Current health factor scaled by 1e18 (1.0 = 1e18)
     */
    function getHealthFactor(address user) external view returns (uint256);

    /**
     * @notice Gets the amount of collateral a user has deposited for a specific token
     * @dev Used for position management and liquidation calculations
     * @param user Address of the user to check
     * @param token Address of the collateral token
     * @return Amount of collateral deposited in token's native decimals
     */
    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256);

    /**
     * @notice Calculates the USD value of a given token amount
     * @dev Uses Chainlink price feeds with additional precision handling
     * @param token Address of the token to value
     * @param amount Amount of tokens to convert to USD
     * @return USD value scaled by protocol's precision factor
     */
    function getUsdValue(address token, uint256 amount) external view returns (uint256);

    /**
     * @notice Converts a USD amount to equivalent token amount
     * @dev Inverse operation of getUsdValue, used for liquidation calculations
     * @param token Address of the token to convert to
     * @param usdAmountInWei USD amount scaled by protocol's precision factor
     * @return Token amount in native decimals
     */
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) external view returns (uint256);

    /**
     * @notice Calculates total USD value of all collateral for a user
     * @dev Aggregates value across all collateral types
     * @param user Address of the user to value
     * @return Total collateral value in USD, scaled by protocol's precision
     */
    function getAccountCollateralValueInUsd(address user) external view returns (uint256);

    /**
     * @notice Returns array of all supported collateral tokens
     * @dev Used for iterating over supported assets and validation
     * @return Array of token addresses supported by the protocol
     */
    function getAllowedTokens() external view returns (address[] memory);

    /**
     * @notice Returns the minimum health factor before liquidation
     * @dev Positions below this threshold are eligible for liquidation
     * @return Minimum health factor scaled by 1e18 (1.0 = 1e18)
     */
    function getMinimumHealthFactor() external view returns (uint256);

    /**
     * @notice Returns the liquidation threshold percentage
     * @dev Used in health factor calculations, determines how much collateral is counted
     * @return Threshold percentage scaled by protocol's precision
     */
    function getLiquidationThreshold() external view returns (uint256);

    /**
     * @notice Returns the precision scalar for liquidation calculations
     * @dev Used for consistent decimal handling in liquidation math
     * @return Precision scalar (typically 100 for percentage calculations)
     */
    function getLiquidationPrecision() external pure returns (uint256);

    /**
     * @notice Returns the bonus percentage liquidators receive
     * @dev Incentivizes liquidators to maintain protocol solvency
     * @return Bonus percentage scaled by protocol's precision
     */
    function getLiquidationBonus() external pure returns (uint256);

    /**
     * @notice Returns the protocol's global precision scalar
     * @dev Used for consistent decimal handling across all calculations
     * @return Precision scalar (typically 1e18)
     */
    function getPrecision() external pure returns (uint256);

    /**
     * @notice Allows users to withdraw their collateral
     * @dev Checks health factor after withdrawal to prevent insolvency
     * @param tokenCollateralAddress Address of collateral token to withdraw
     * @param amountCollateralToWithdraw Amount of collateral to withdraw
     */
    function withdrawCollateral(address tokenCollateralAddress, uint256 amountCollateralToWithdraw) external;

    /**
     * @notice Allows repayment of borrowed assets
     * @dev Updates user's debt and protocol accounting
     * @param tokenToPayBack Address of the borrowed token being repaid
     * @param amountToPayBack Amount of tokens to repay
     * @param onBehalfOf Address of the user whose debt is being repaid
     */
    function paybackBorrowedAmount(address tokenToPayBack, uint256 amountToPayBack, address onBehalfOf) external;

    /**
     * @notice Validates if a user's position would remain healthy
     * @dev Reverts if health factor would drop below minimum
     * @param user Address of the user to check
     */
    function revertIfHealthFactorIsBroken(address user) external view;

    /**
     * @notice Gets the amount of tokens a user has borrowed
     * @dev Used for debt tracking and liquidation calculations
     * @param user Address of the borrower
     * @param token Address of the borrowed token
     * @return Amount borrowed in token's native decimals
     */
    function getAmountOfTokenBorrowed(address user, address token) external view returns (uint256);

    /**
     * @notice Retrieves a batch of user addresses for processing
     * @dev Used by automation system for efficient position monitoring
     * @param batchSize Number of users to retrieve
     * @param offset Starting position in user list
     * @return users Array of user addresses
     * @return totalUsers Total number of users in protocol
     */
    function getUserBatch(
        uint256 batchSize,
        uint256 offset
    )
        external
        view
        returns (address[] memory users, uint256 totalUsers);

    /**
     * @notice Decreases a user's debt during liquidation
     * @dev Only callable by liquidation system
     * @param user Address of the user being liquidated
     * @param token Address of the debt token
     * @param amount Amount of debt to decrease
     */
    function liquidationDecreaseDebt(address user, address token, uint256 amount) external;

    /**
     * @notice Withdraws collateral during liquidation process
     * @dev Only callable by liquidation system
     * @param collateral Address of collateral token
     * @param amount Amount of collateral to withdraw
     * @param user Address of user being liquidated
     * @param recipient Address receiving the collateral
     */
    function liquidationWithdrawCollateral(
        address collateral,
        uint256 amount,
        address user,
        address recipient
    )
        external;

    /**
     * @notice Processes debt repayment during liquidation
     * @dev Only callable by liquidation system
     * @param token Address of debt token
     * @param amount Amount of debt being repaid
     * @param user Address of user being liquidated
     * @param liquidator Address of the liquidator
     */
    function liquidationPaybackBorrowedAmount(
        address token,
        uint256 amount,
        address user,
        address liquidator
    )
        external;

    /**
     * @notice Returns the address of the protocol owner
     * @dev Used for access control and administrative functions
     * @return Address of the protocol owner
     */
    function owner() external view returns (address);
}
