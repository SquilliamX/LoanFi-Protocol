// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ILoanFi } from "../interfaces/ILoanFi.sol";

/**
 * @title Getters Contract
 * @author William Permuy
 * @notice Provides standardized access to LoanFi protocol state and calculations
 * @dev Implements a facade pattern for protocol state access with consistent error handling
 *      and access control. All getter functions maintain view-only status for gas efficiency.
 */
contract Getters is Ownable {
    /// @notice Immutable reference to the main LoanFi protocol contract
    /// @dev Made immutable to prevent tampering and reduce gas costs
    ILoanFi internal immutable i_loanFi;

    /**
     * @notice Initializes the Getters contract with LoanFi protocol address
     * @dev Sets up immutable protocol reference and ownership
     * @param loanFiAddress The address of the main LoanFi protocol contract
     */
    constructor(address loanFiAddress) Ownable(msg.sender) {
        i_loanFi = ILoanFi(loanFiAddress);
    }

    /**
     * @notice Retrieves user's current health factor
     * @dev Internal view function for efficient health checks
     * @param user Address of the user to check
     * @return Current health factor scaled by protocol precision
     */
    function _healthFactor(address user) internal view returns (uint256) {
        return i_loanFi.getHealthFactor(user);
    }

    /**
     * @notice Gets protocol's minimum required health factor
     * @dev Used as threshold for liquidation eligibility
     * @return Minimum health factor scaled by protocol precision
     */
    function _getMinimumHealthFactor() internal view returns (uint256) {
        return i_loanFi.getMinimumHealthFactor();
    }

    /**
     * @notice Calculates USD value of token amount using protocol oracle
     * @dev Handles price feed decimals and scaling internally
     * @param token Address of token to value
     * @param amount Amount of tokens to convert to USD
     * @return USD value scaled by protocol precision
     */
    function _getUsdValue(address token, uint256 amount) internal view returns (uint256) {
        return i_loanFi.getUsdValue(token, amount);
    }

    /**
     * @notice Retrieves array of protocol-supported tokens
     * @dev Used for validation and iteration over supported assets
     * @return Array of token addresses supported by protocol
     */
    function _getAllowedTokens() internal view returns (address[] memory) {
        return i_loanFi.getAllowedTokens();
    }

    /**
     * @notice Gets user's collateral balance for specific token
     * @dev Used in liquidation calculations and position management
     * @param user Address of user to check
     * @param token Address of collateral token
     * @return Amount of collateral in token's native decimals
     */
    function _getCollateralBalanceOfUser(address user, address token) internal view returns (uint256) {
        return i_loanFi.getCollateralBalanceOfUser(user, token);
    }

    /**
     * @notice Processes collateral withdrawal through main protocol
     * @dev Maintains protocol accounting and safety checks
     * @param tokenCollateralAddress: Address of collateral token
     * @param amountCollateralToWithdraw: Amount to withdraw
     */
    function _withdrawCollateral(address tokenCollateralAddress, uint256 amountCollateralToWithdraw) internal {
        // Remove unused parameters warning by commenting them
        // from and to are handled internally by LoanFi's withdrawCollateral
        i_loanFi.withdrawCollateral(tokenCollateralAddress, amountCollateralToWithdraw);
    }

    /**
     * @notice Processes debt repayment through main protocol
     * @dev Updates debt accounting and validates repayment
     * @param tokenToPayBack Address of debt token being repaid
     * @param amountToPayBack Amount of debt to repay
     * @param onBehalfOf User whose debt is being repaid
     */
    function _paybackBorrowedAmount(address tokenToPayBack, uint256 amountToPayBack, address onBehalfOf) internal {
        i_loanFi.paybackBorrowedAmount(tokenToPayBack, amountToPayBack, onBehalfOf);
    }

    /**
     * @notice Validates user's health factor remains above minimum
     * @dev Reverts if health factor would break minimum threshold
     * @param user Address of user to validate
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        i_loanFi.revertIfHealthFactorIsBroken(user);
    }

    /**
     * @notice Gets amount of specific token borrowed by user
     * @dev Used in liquidation eligibility checks
     * @param user Address of borrower
     * @param token Address of borrowed token
     * @return Amount borrowed in token's native decimals
     */
    function _getAmountOfTokenBorrowed(address user, address token) internal view returns (uint256) {
        return i_loanFi.getAmountOfTokenBorrowed(user, token);
    }

    /**
     * @notice Retrieves protocol's liquidation bonus percentage
     * @dev Used to calculate liquidator rewards
     * @return Bonus percentage scaled by protocol precision
     */
    function _getLiquidationBonus() internal view returns (uint256) {
        return i_loanFi.getLiquidationBonus();
    }

    /**
     * @notice Gets protocol's liquidation precision scalar
     * @dev Used for consistent decimal handling in liquidations
     * @return Precision scalar for liquidation calculations
     */
    function _getLiquidationPrecision() internal view returns (uint256) {
        return i_loanFi.getLiquidationPrecision();
    }

    /**
     * @notice Retrieves protocol's global precision scalar
     * @dev Used for consistent decimal handling across protocol
     * @return Protocol precision scalar (typically 1e18)
     */
    function _getPrecision() internal view returns (uint256) {
        return i_loanFi.getPrecision();
    }

    /**
     * @notice Converts USD amount to equivalent token amount
     * @dev Handles price feed decimals and scaling
     * @param token Address of token to convert to
     * @param usdAmountInWei USD amount scaled by protocol precision
     * @return Token amount in native decimals
     */
    function _getTokenAmountFromUsd(address token, uint256 usdAmountInWei) internal view returns (uint256) {
        return i_loanFi.getTokenAmountFromUsd(token, usdAmountInWei);
    }

    /**
     * @notice Calculates total USD value of user's collateral
     * @dev Aggregates value across all collateral types
     * @param user Address of user to value
     * @return Total collateral value in USD
     */
    function _getAccountCollateralValueInUsd(address user) internal view returns (uint256) {
        return i_loanFi.getAccountCollateralValueInUsd(user);
    }

    /**
     * @notice Retrieves batch of protocol users for processing
     * @dev Supports pagination for gas-efficient processing
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
        returns (address[] memory users, uint256 totalUsers)
    {
        return i_loanFi.getUserBatch(batchSize, offset);
    }

    /**
     * @notice Gets user's current health factor
     * @dev External wrapper for health factor calculation
     * @param user Address of user to check
     * @return Current health factor scaled by protocol precision
     */
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
