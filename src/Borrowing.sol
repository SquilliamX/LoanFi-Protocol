// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Lending } from "src/Lending.sol";

/**
 * @title Borrowing Contract
 * @author William Permuy
 * @notice Manages the borrowing functionality of the lending protocol
 * @dev Implements core borrowing logic with the following features:
 *
 * Core Features:
 * 1. Token Borrowing
 *    - Collateral-backed loans
 *    - Multi-token support
 *    - Real-time liquidity tracking
 *    - Dynamic borrowing limits
 *
 * 2. Debt Management
 *    - Flexible repayment system
 *    - Altruistic debt repayment
 *    - Overpayment protection
 *    - Accurate debt tracking
 *
 * 3. Risk Management
 *    - Health factor monitoring
 *    - Collateral validation
 *    - Solvency protection
 *    - Protocol-wide accounting
 *
 * Security Features:
 * - Reentrancy protection
 * - CEI (Checks-Effects-Interactions) pattern
 * - Input validation
 * - Access control
 *
 * Inherits:
 * - Lending: Base lending functionality and collateral management
 */
contract Borrowing is Lending {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Lending(tokenAddresses, priceFeedAddresses)
    { }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows users to borrow tokens against their deposited collateral
     * @dev Implements a multi-stage validation and borrowing process with the following features:
     *
     * Security Features:
     * 1. Physical token verification
     * 2. Protocol accounting validation
     * 3. Health factor checks
     * 4. CEI (Checks-Effects-Interactions) pattern
     *
     * Process Flow:
     * 1. Validate token availability
     * 2. Update protocol accounting
     * 3. Verify position health
     * 4. Execute token transfer
     *
     * @param tokenToBorrow The ERC20 token address the user wants to borrow
     * @param amountToBorrow The amount of tokens to borrow (in token's native decimals)
     *
     * Security Features:
     * - Validates token allowlist to prevent unsupported assets
     * - Ensures protocol solvency through health factor checks
     * - Uses internal accounting before external calls (CEI pattern)
     */
    function _borrowFunds(
        address tokenToBorrow,
        uint256 amountToBorrow
    )
        internal
        moreThanZero(amountToBorrow)
        isAllowedToken(tokenToBorrow)
    {
        // STAGE 1: Physical Token Validation
        // Verify the contract has sufficient tokens in its possession
        // This prevents attempts to borrow tokens that don't physically exist in the contract
        // Critical for maintaining protocol solvency and preventing overextension
        if (IERC20(tokenToBorrow).balanceOf(address(this)) < amountToBorrow) {
            revert Errors.Borrowing__NotEnoughAvailableCollateral();
        }

        // STAGE 2: Protocol Accounting Validation
        // Calculate available tokens according to protocol's internal accounting
        // This considers all existing loans and ensures we're not lending tokens
        // that are already promised to other borrowers
        uint256 availableToBorrow = _getAvailableToBorrow(tokenToBorrow);

        // Validate borrowing amount against available liquidity
        // Prevents borrowing more than the protocol can safely lend
        if (amountToBorrow > availableToBorrow) {
            revert Errors.Borrowing__NotEnoughAvailableCollateral();
        }

        // STAGE 3: State Updates (Following CEI Pattern)
        // Update internal accounting before any external interactions
        // Track both token-specific amounts and USD value of borrowed assets
        increaseUserDebtAndTotalDebtBorrowed(msg.sender, tokenToBorrow, amountToBorrow);

        // Emit event for off-chain tracking and transparency
        // Critical for DApp interfaces and protocol monitoring
        emit UserBorrowed(msg.sender, tokenToBorrow, amountToBorrow);

        // STAGE 4: Health Factor Validation
        // Verify that this borrow doesn't break the user's health factor
        // This ensures the position remains safely collateralized
        _revertIfHealthFactorIsBroken(msg.sender);

        // STAGE 5: Token Transfer (Final Interaction)
        // Execute the actual token transfer to the borrower
        // This is the last step in accordance with CEI pattern
        bool success = IERC20(tokenToBorrow).transfer(msg.sender, amountToBorrow);
        if (!success) {
            revert Errors.TransferFailed();
        }
    }

    /**
     * @notice Allows users to repay borrowed tokens, either for themselves or on behalf of others
     * @dev Implements a comprehensive debt repayment process with the following features:
     *
     * Security Features:
     * 1. Input validation
     * 2. Balance verification
     * 3. Overpayment protection
     * 4. CEI (Checks-Effects-Interactions) pattern
     *
     * Process Flow:
     * 1. Validate inputs and addresses
     * 2. Verify repayment amount
     * 3. Update protocol accounting
     * 4. Verify position health
     * 5. Execute token transfer
     *
     * @param tokenToPayBack The ERC20 token address being repaid
     * @param amountToPayBack The amount of tokens to repay (in token's native decimals)
     * @param onBehalfOf The address whose debt is being repaid (enables altruistic repayments)
     *
     * Security Features:
     * - Implements reentrancy protection via modifiers
     * - Validates token allowlist to prevent unsupported assets
     * - Ensures accurate debt accounting
     * - Uses internal accounting before external calls (CEI pattern)
     */
    function _paybackBorrowedAmount(
        address tokenToPayBack,
        uint256 amountToPayBack,
        address onBehalfOf
    )
        internal
        moreThanZero(amountToPayBack)
        isAllowedToken(tokenToPayBack)
    {
        // STAGE 1: Input Validation
        // Prevent repayments to zero address to protect against lost funds
        // Critical for maintaining accurate protocol accounting
        if (onBehalfOf == address(0)) {
            revert Errors.ZeroAddressNotAllowed();
        }

        // STAGE 2: Balance Verification
        // Ensure payer has sufficient tokens to cover the repayment
        // Prevents transaction failures and gas waste
        if (IERC20(tokenToPayBack).balanceOf(msg.sender) < amountToPayBack) {
            revert Errors.Borrowing__NotEnoughTokensToPayDebt();
        }

        // STAGE 3: Overpayment Protection
        // Verify repayment amount doesn't exceed outstanding debt
        // Maintains accurate debt accounting and prevents excess payments
        uint256 borrowedAmount = _getAmountOfTokenBorrowed(onBehalfOf, tokenToPayBack);
        if (borrowedAmount < amountToPayBack) {
            revert Errors.Borrowing__OverpaidDebt();
        }

        // STAGE 4: State Updates (Following CEI Pattern)
        // Update internal accounting before any external interactions
        // Critical for preventing reentrancy attacks and maintaining accurate state
        decreaseUserDebtAndTotalDebtBorrowed(onBehalfOf, tokenToPayBack, amountToPayBack);

        // Emit event for off-chain tracking and transparency
        // Essential for DApp interfaces and protocol monitoring
        emit BorrowedAmountRepaid(msg.sender, onBehalfOf, tokenToPayBack, amountToPayBack);

        // STAGE 5: Health Factor Validation
        // Verify position health after repayment
        // Ensures position remains within protocol safety parameters
        _revertIfHealthFactorIsBroken(onBehalfOf);

        // STAGE 6: Token Transfer (Final Interaction)
        // Execute the actual token transfer from payer to protocol
        // Last step in accordance with CEI pattern
        bool success = IERC20(tokenToPayBack).transferFrom(msg.sender, address(this), amountToPayBack);

        // Check if transfer was successful
        // This is a backup check since transferFrom would normally revert on failure
        if (!success) {
            revert Errors.TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                         PRIVATE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the total amount of a specific token held as collateral by the protocol
     * @dev Implements an efficient token balance lookup with the following features:
     *
     * Architecture Highlights:
     * 1. Linear search through token list (checks each token until match found)
     * 2. Early exit optimization (stops searching after finding match)
     * 3. Direct balance querying
     * 4. Zero gas waste on unnecessary iterations
     *
     * Implementation Strategy:
     * - Iterates through allowed tokens array
     * - Matches target token against allowed tokens
     * - Returns actual balance when match found
     * - Uses break statement to optimize gas usage
     *
     * @param token The ERC20 token address to check total collateral for
     * @return totalCollateral The total amount of tokens held by the contract in native decimals
     *
     * Gas Optimization Features:
     * - Single loop iteration for token lookup
     * - Early break on token match
     * - View function for gas-free calls
     * - Minimal storage reads using memory variables
     */
    function _getTotalCollateralOfToken(address token) private view returns (uint256 totalCollateral) {
        // STAGE 1: Token List Iteration
        // Efficiently search through allowed tokens list
        // Uses cached array length to prevent multiple storage reads
        for (uint256 i = 0; i < _getAllowedTokens().length; i++) {
            // STAGE 2: Token Matching
            // Compare current token against target token
            // Early exit pattern for gas optimization
            if (_getAllowedTokens()[i] == token) {
                // STAGE 3: Balance Retrieval
                // Direct query of contract's token balance
                // Returns actual physical tokens held by contract
                totalCollateral = IERC20(token).balanceOf(address(this));

                // STAGE 4: Early Exit
                // Break loop immediately after finding match
                // Saves gas by preventing unnecessary iterations
                break;
            }
        }

        // STAGE 5: Return Result
        // Return total collateral amount
        // Will be 0 if token not found in allowed list
        return totalCollateral;
    }

    /**
     * @notice Calculates the available amount of tokens that can be borrowed from the protocol
     * @dev Implements a precise liquidity calculation system with the following features:
     *
     * Calculation Method:
     * 1. Total Collateral Tracking
     *    - Queries physical token balance
     *    - Considers all deposited collateral
     *    - Real-time balance updates
     *
     * 2. Borrowed Amount Tracking
     *    - Monitors all outstanding loans
     *    - Aggregates total borrowed amount
     *    - Protocol-wide debt tracking
     *
     * 3. Available Liquidity
     *    - Dynamic calculation: Total Collateral - Total Borrowed
     *    - Ensures protocol solvency
     *    - Prevents over-borrowing
     *
     * @param token The ERC20 token address to check available liquidity for
     * @return uint256 The amount of tokens available for borrowing in native decimals
     *
     * Security Features:
     * - View function for gas-free queries
     * - Real-time balance checking
     * - Underflow protected subtraction
     * - Accurate protocol-wide accounting
     */
    function _getAvailableToBorrow(address token) private view returns (uint256) {
        // STAGE 1: Total Collateral Calculation
        // Query the total amount of this token held as collateral
        // Represents the maximum theoretical amount available
        uint256 totalCollateral = _getTotalCollateralOfToken(token);

        // STAGE 2: Total Borrowed Calculation
        // Get the total amount currently borrowed across all users
        // Represents the amount already committed to borrowers
        uint256 totalBorrowed = _getTotalTokenAmountsBorrowed(token);

        // STAGE 3: Available Liquidity Calculation
        // Calculate actual available liquidity by subtracting borrowed from total
        // This ensures we never over-commit tokens to borrowers
        return totalCollateral - totalBorrowed;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice External interface for querying total protocol collateral for a specific token
     * @dev Provides a secure public access point to internal collateral tracking with the following features:
     *
     * @param token The ERC20 token address to check total collateral for
     * @return totalCollateral The total amount of tokens held by the protocol in native decimals
     *  View function for gas-efficient queries
     */
    function getTotalCollateralOfToken(address token) external view returns (uint256 totalCollateral) {
        // Calls private implementation to save gas
        return _getTotalCollateralOfToken(token);
    }

    /**
     * @notice External interface for querying available protocol liquidity for borrowing
     * @dev Provides essential liquidity data for protocol users and integrations
     *
     * @param token The ERC20 token address to check borrowing availability for
     * @return uint256 The amount of tokens available for borrowing in native decimals
     *
     * View function for gas-efficient queries
     */
    function getAvailableToBorrow(address token) external view returns (uint256) {
        // Calls private implementation to save gas
        return _getAvailableToBorrow(token);
    }
}
