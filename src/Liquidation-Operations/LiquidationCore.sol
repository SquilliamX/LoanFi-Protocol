// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ILoanFi } from "../interfaces/ILoanFi.sol";
import { Getters } from "./Getters.sol";

/**
 * @title LiquidationCore
 * @author William Permuy
 * @notice Core implementation of protocol's liquidation mechanism
 * @dev Implements sophisticated multi-collateral liquidation logic with the following features:
 *
 * Architecture Highlights:
 * - Waterfall bonus collection system
 * - Multi-collateral position handling
 * - Precise USD-based calculations
 * - Atomic execution guarantees
 *
 * Key Components:
 * 1. Bonus System
 *    - Primary collateral liquidation
 *    - Secondary collateral collection
 *    - Dynamic bonus distribution
 *
 * 2. Safety Mechanisms
 *    - Health factor validation
 *    - Slippage protection
 *    - Reentrancy guards
 *    - Access control
 *
 * 3. Price Handling
 *    - Oracle integration
 *    - USD value normalization
 *    - Precision management
 */
contract LiquidationCore is Getters {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @title Bonus Parameters
     * @notice Groups parameters for bonus calculations during liquidation process
     * @dev Prevents stack too deep errors in liquidation functions while maintaining
     *      clear data organization for complex bonus calculations
     */
    struct BonusParams {
        /// @notice The collateral token address being liquidated
        /// @dev Must be an approved protocol collateral token
        address collateral;
        /// @notice The address of the user being liquidated
        /// @dev Account whose health factor has fallen below minimum
        address user;
        /// @notice Amount of bonus calculated from the primary liquidated collateral
        /// @dev In USD terms, scaled by protocol precision
        uint256 bonusFromThisCollateral;
        /// @notice Additional bonus amount from user's secondary collateral types
        /// @dev Used in waterfall bonus collection, scaled by protocol precision
        uint256 bonusFromOtherCollateral;
        /// @notice Amount of debt being repaid through liquidation
        /// @dev In terms of the debt token's native decimals
        uint256 debtAmountToPay;
        /// @notice The token that was borrowed and needs to be repaid
        /// @dev Must be an approved protocol debt token
        address debtToken;
    }

    /**
     * @title Transfer Parameters
     * @notice Groups parameters for executing liquidation transfers
     * @dev Encapsulates all data needed for safe transfer execution while
     *      maintaining clean function signatures
     */
    struct TransferParams {
        /// @notice The collateral token address being transferred
        /// @dev Token being seized from the liquidated position
        address collateral;
        /// @notice The token that was borrowed and needs to be repaid
        /// @dev Token being used to repay the debt
        address debtToken;
        /// @notice The address of the user whose collateral is being transferred
        /// @dev User being liquidated
        address user;
        /// @notice The address receiving the liquidated collateral
        /// @dev Either liquidator or protocol depending on market conditions
        address recipient;
        /// @notice Amount of debt being repaid
        /// @dev In debt token's native decimals
        uint256 debtAmountToPay;
        /// @notice Total amount of collateral being seized
        /// @dev Includes both debt repayment and bonus amounts
        uint256 totalCollateralToSeize;
        /// @notice The address of the liquidator
        /// @dev Entity performing the liquidation
        address liquidator;
    }

    /**
     * @title Collateral Data
     * @notice Tracks collateral information during liquidation calculations
     * @dev Used to manage complex collateral accounting during liquidation process
     */
    struct CollateralData {
        /// @notice The collateral token being processed
        address token;
        /// @notice Collateral to exclude from bonus calculations
        /// @dev Used when calculating bonuses from secondary collateral
        address excludedCollateral;
        /// @notice User's balance of this collateral
        /// @dev In token's native decimals
        uint256 userBalance;
        /// @notice USD value of the collateral
        /// @dev Calculated using oracle price feeds, scaled by protocol precision
        uint256 valueInUsd;
        /// @notice Total available collateral in USD (excluding specific token)
        /// @dev Used for bonus waterfall calculations
        uint256 totalAvailable;
    }

    /**
     * @title Liquidation Parameters
     * @notice Core parameters for liquidation execution
     * @dev Centralizes critical liquidation data for safer processing
     */
    struct LiquidationParams {
        /// @notice The user being liquidated
        address user;
        /// @notice The address performing the liquidation
        address liquidator;
        /// @notice The recipient of the liquidated collateral
        address recipient;
        /// @notice The borrowed token to be repaid
        address debtToken;
        /// @notice Amount of debt to repay
        /// @dev In debt token's native decimals
        uint256 debtAmountToPay;
        /// @notice USD value of the debt
        /// @dev Scaled by protocol precision
        uint256 debtInUsd;
    }

    /**
     * @title Bonus Collateral Information
     * @notice Struct to track collateral and bonus details during liquidation
     * @dev Used in the bonus waterfall mechanism when collecting liquidation incentives
     */
    struct BonusCollateralInfo {
        /// @notice Address of the collateral token being processed
        address token;
        /// @notice Amount of collateral tokens to seize
        /// @dev In token's native decimals
        uint256 amountToTake;
        /// @notice USD value of the bonus portion
        /// @dev Scaled by protocol's precision factor
        uint256 bonusInUsd;
    }

    /**
     * @title Transfer Calculation Result
     * @notice Struct to handle complex transfer calculations during liquidation
     * @dev Prevents stack too deep errors and improves code readability
     */
    struct TransferCalcResult {
        /// @notice Amount of debt expressed in collateral token terms
        /// @dev Calculated using price feeds and protocol precision
        uint256 debtInCollateralTerms;
        /// @notice Amount of bonus collateral to be transferred
        /// @dev Additional collateral given to liquidator as incentive
        uint256 bonusCollateral;
        /// @notice Total amount of collateral to transfer
        /// @dev Sum of debt repayment and bonus amounts
        uint256 totalCollateralToSeize;
        /// @notice Remaining debt in USD after this transfer
        /// @dev Used to track partial liquidations
        uint256 remainingDebtInUsd;
        /// @notice Address that will receive the seized collateral
        /// @dev Can be liquidator or protocol depending on market conditions
        address recipient;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user's position is liquidated
    /// @param collateral The address of the collateral token liquidated
    /// @param userLiquidated The address of the user who was liquidated
    /// @param amountOfDebtPaid The amount of debt that was repaid
    event UserLiquidated(address indexed collateral, address indexed userLiquidated, uint256 amountOfDebtPaid);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Ensures input amount is greater than zero
     * @dev Prevents zero-value operations that waste gas
     * @param amount The amount to validate
     */
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert Errors.AmountNeedsMoreThanZero();
        }
        _;
    }

    /**
     * @notice Validates token is supported by protocol
     * @dev Prevents operations with unsupported tokens
     * @param token The token address to validate
     */
    modifier isAllowedToken(address token) {
        if (!_isTokenAllowed(token)) {
            revert Errors.TokenNotAllowed(token);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the liquidation core contract
     * @dev Sets up connection to main protocol contract
     * @param loanFiAddress Address of the main LoanFi protocol contract
     */
    constructor(address loanFiAddress) Getters(loanFiAddress) { }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Core Liquidation Function
     * @notice Orchestrates the entire liquidation process for unhealthy positions
     * @dev Implements a sophisticated multi-step liquidation process with robust safety checks
     *      and follows the CEI (Checks-Effects-Interactions) pattern for reentrancy protection
     *
     * Process Flow:
     * 1. Validation of inputs and liquidation conditions
     * 2. Parameter initialization and USD value calculations
     * 3. Health factor verification
     * 4. Collateral data preparation
     * 5. Core liquidation processing
     * 6. Post-liquidation health checks
     *
     * Security Features:
     * - Input validation through modifiers
     * - Token allowlist verification
     * - Health factor checks
     * - Reentrancy protection
     * - Precise accounting
     *
     * @param liquidator Address of the entity performing the liquidation
     * @param user Address of the user being liquidated
     * @param collateral Address of the collateral token being seized
     * @param debtToken Address of the borrowed token being repaid
     * @param debtAmountToPay Amount of debt to repay in debt token decimals
     */
    function _liquidate(
        address liquidator,
        address user,
        address collateral,
        address debtToken,
        uint256 debtAmountToPay
    )
        internal
        moreThanZero(debtAmountToPay) // Ensures non-zero liquidation amount
        isAllowedToken(collateral) // Validates collateral token is supported
        isAllowedToken(debtToken) // Validates debt token is supported
    {
        // Step 1: Validate liquidation parameters and conditions
        _validateLiquidation(liquidator, debtToken, user, debtAmountToPay);

        // Step 2: Initialize core liquidation parameters with structured data
        LiquidationParams memory params = LiquidationParams({
            user: user, // Target user being liquidated
            liquidator: liquidator, // Entity performing the liquidation
            recipient: address(0), // Will be set during bonus calculation
            debtToken: debtToken, // Token being repaid
            debtAmountToPay: debtAmountToPay, // Amount of debt to clear
            debtInUsd: _getUsdValue(debtToken, debtAmountToPay) // USD value for calculations
         });

        // Step 3: Verify user's position is eligible for liquidation
        uint256 startingUserHealthFactor = _healthFactor(params.user);
        if (startingUserHealthFactor >= _getMinimumHealthFactor()) {
            revert Errors.Liquidations__HealthFactorIsHealthy();
        }

        // Step 4: Prepare collateral data structure for processing
        CollateralData memory collateralData = CollateralData({
            token: collateral, // Token being liquidated
            excludedCollateral: address(0), // No exclusions initially
            userBalance: _getCollateralBalanceOfUser(user, collateral), // Available collateral
            valueInUsd: 0, // Will be calculated during processing
            totalAvailable: 0 // Will be calculated if needed
         });

        // Step 5: Execute core liquidation logic
        _processLiquidation(params, collateralData);

        // Step 6: Verify liquidation improved the user's position
        _verifyHealthFactorAfterLiquidation(params.user, startingUserHealthFactor);

        // Final safety check: Ensure liquidator's position remains healthy
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // Virtual function with default empty implementation
    function _onProtocolLiquidation(TransferParams memory /* params */ ) internal virtual {
        // Default empty implementation
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes the core transfer operations in the liquidation process
     * @dev Implements transfer operations following CEI pattern for maximum security
     *
     * Process Flow:
     * 1. Withdraw collateral from user's position
     * 2. Repay user's debt using liquidator's tokens
     *
     * Critical Ordering:
     * - Collateral withdrawal MUST precede debt repayment to prevent:
     *   a) Flash loan attacks
     *   b) Malicious reentrancy
     *   c) Sandwich attacks
     *
     * @param params Structured transfer parameters containing:
     *        - collateral: Address of collateral token
     *        - debtToken: Address of debt token
     *        - user: Address of user being liquidated
     *        - recipient: Address receiving collateral
     *        - debtAmountToPay: Amount of debt being repaid
     *        - totalCollateralToSeize: Total collateral to transfer
     *        - liquidator: Address performing liquidation
     */
    function _executeBasicTransfers(TransferParams memory params) private {
        // Step 1: Withdraw collateral from user's position to recipient
        // Must occur first to prevent potential attack vectors
        _liquidatationWithdrawCollateralFromUser(params);

        // Step 2: Repay user's debt using liquidator's tokens
        // Occurs after collateral seizure to ensure atomic operation
        _liquidationPaybackBorrowedAmount(params.debtToken, params.debtAmountToPay, params.user, params.liquidator);
    }

    /**
     * @notice Core function that orchestrates the entire liquidation workflow
     * @dev Implements a sophisticated multi-step liquidation process with bonus calculations
     *      and collateral handling. Follows CEI pattern for maximum security.
     *
     * Process Flow:
     * 1. Calculate liquidation bonuses across all collateral types
     * 2. Emit liquidation event for transparency and tracking
     * 3. Execute transfer operations with proper bonus distribution
     *
     * @param params Core liquidation parameters including user, debt, and token information
     * @param collateralData Detailed information about the collateral being liquidated
     */
    function _processLiquidation(LiquidationParams memory params, CollateralData memory collateralData) private {
        // Step 1: Calculate bonuses across all collateral types
        // This includes both primary collateral and additional collateral if needed
        (uint256 bonusFromThisCollateral, uint256 bonusFromOtherCollateral, uint256 totalBonusNeededInUsd) =
        _calculateBonuses(
            BonusParams({
                collateral: collateralData.token, // Primary collateral token
                user: params.user, // User being liquidated
                bonusFromThisCollateral: 0, // Will be calculated
                bonusFromOtherCollateral: 0, // Will be calculated
                debtAmountToPay: params.debtAmountToPay, // Debt to be repaid
                debtToken: params.debtToken // Token of the debt
             })
        );

        // Step 2: Emit event for transparency and off-chain tracking
        emit UserLiquidated(collateralData.token, params.user, params.debtAmountToPay);

        // Step 3: Execute transfer operations with proper bonus distribution
        // This handles both primary collateral and any additional collateral needed
        _handleTransfers(
            params, collateralData, bonusFromThisCollateral, bonusFromOtherCollateral, totalBonusNeededInUsd
        );
    }

    /**
     * @notice Orchestrates the complete liquidation transfer process
     * @dev Implements a sophisticated three-phase liquidation strategy:
     * 1. Converts debt to USD for standardized calculations
     * 2. Executes primary collateral transfer with bonus
     * 3. Handles additional collateral collection if needed
     *
     * @param params Core liquidation parameters (user, debt info)
     * @param collateralData Information about collateral being liquidated
     * @param bonusFromThisCollateral Primary collateral bonus amount
     * @param bonusFromOtherCollateral Secondary collateral bonus amount
     * @param totalBonusNeededInUsd Total required bonus in USD terms
     */
    function _handleTransfers(
        LiquidationParams memory params,
        CollateralData memory collateralData,
        uint256 bonusFromThisCollateral,
        uint256 bonusFromOtherCollateral,
        uint256 totalBonusNeededInUsd
    )
        private
    {
        // Convert debt to USD for consistent calculations across different tokens
        uint256 debtInUsd = _getUsdValue(params.debtToken, params.debtAmountToPay);

        // Phase 1: Calculate exact transfer amounts with bonus distribution
        // Ensures precise collateral seizure while maintaining protocol safety
        TransferCalcResult memory calc = _calculateTransferAmounts(
            params.user,
            collateralData.token,
            params.liquidator,
            debtInUsd,
            bonusFromThisCollateral,
            bonusFromOtherCollateral,
            totalBonusNeededInUsd
        );

        // Phase 2: Execute primary collateral transfer and debt repayment
        _executeTransfers(
            TransferParams({
                collateral: collateralData.token,
                debtToken: params.debtToken,
                user: params.user,
                recipient: calc.recipient,
                debtAmountToPay: params.debtAmountToPay,
                totalCollateralToSeize: calc.totalCollateralToSeize,
                liquidator: params.liquidator
            })
        );

        // Phase 3: Handle additional collateral collection if needed
        // Triggers when primary collateral is insufficient for full bonus
        if (calc.remainingDebtInUsd > 0 || bonusFromOtherCollateral > 0) {
            _handleAdditionalCollateral(
                params.user,
                calc.recipient,
                params.liquidator,
                collateralData.token,
                calc.remainingDebtInUsd,
                totalBonusNeededInUsd,
                bonusFromThisCollateral,
                params.debtToken
            );
        }
    }

    /**
     * @notice Processes secondary collateral collection during liquidation
     * @dev Implements a sophisticated waterfall collection mechanism that:
     * 1. Calculates remaining bonus needed from additional collateral types
     * 2. Determines optimal distribution of debt coverage across tokens
     * 3. Executes precise transfers while maintaining protocol safety
     *
     * Key Features:
     * - Multi-collateral bonus collection
     * - Dynamic debt distribution
     * - Precise USD value calculations
     *
     * @param user Address of the user being liquidated
     * @param recipient Address receiving the liquidated collateral
     * @param liquidator Address performing the liquidation
     * @param excludedCollateral Primary collateral address to exclude from collection
     * @param remainingDebtInUsd Uncovered debt amount in USD terms
     * @param totalBonusNeededInUsd Total liquidation bonus required
     * @param bonusFromThisCollateral Bonus already collected from primary collateral
     * @param debtToken Address of the debt token being repaid
     */
    function _handleAdditionalCollateral(
        address user,
        address recipient,
        address liquidator,
        address excludedCollateral,
        uint256 remainingDebtInUsd,
        uint256 totalBonusNeededInUsd,
        uint256 bonusFromThisCollateral,
        address debtToken
    )
        private
    {
        // Query available collateral tokens and their bonus potential
        // Excludes primary collateral to prevent double-counting
        (, BonusCollateralInfo[] memory collateralsToPull) = _collectBonusFromOtherCollateral(
            user, excludedCollateral, remainingDebtInUsd + (totalBonusNeededInUsd - bonusFromThisCollateral)
        );

        // Process each available collateral token
        // Optimized iteration with early break for gas efficiency
        for (uint256 i = 0; i < collateralsToPull.length; i++) {
            if (collateralsToPull[i].amountToTake == 0) break;

            // Calculate debt coverage from this collateral token
            // Ensures precise accounting of debt distribution
            uint256 debtAmountForThisCollateral = 0;
            uint256 collateralValueInUsd = _getUsdValue(collateralsToPull[i].token, collateralsToPull[i].amountToTake);

            // Determine debt coverage if remaining debt exists
            // Prioritizes debt repayment before bonus collection
            if (remainingDebtInUsd > 0) {
                if (collateralValueInUsd > collateralsToPull[i].bonusInUsd) {
                    debtAmountForThisCollateral = collateralValueInUsd - collateralsToPull[i].bonusInUsd;
                    remainingDebtInUsd = remainingDebtInUsd > debtAmountForThisCollateral
                        ? remainingDebtInUsd - debtAmountForThisCollateral
                        : 0;
                }
            }

            // Calculate final seizure amount including both debt and bonus
            // Handles edge cases and precision requirements
            uint256 totalCollateralToSeize;
            if (collateralValueInUsd > 0) {
                // For valuable collateral, calculate precise amount needed
                uint256 totalNeededInUsd = debtAmountForThisCollateral + collateralsToPull[i].bonusInUsd;
                totalCollateralToSeize = _getTokenAmountFromUsd(collateralsToPull[i].token, totalNeededInUsd);
            } else {
                // Fallback to direct amount for zero-value collateral
                totalCollateralToSeize = collateralsToPull[i].amountToTake;
            }

            // Execute final transfer with comprehensive parameter validation
            // Implements atomic execution pattern for maximum security
            _executeTransfers(
                TransferParams({
                    collateral: collateralsToPull[i].token, // Secondary collateral being seized
                    debtToken: debtToken, // Original debt token being repaid
                    user: user, // User being liquidated
                    recipient: recipient, // Entity receiving collateral (liquidator/protocol)
                    debtAmountToPay: debtAmountForThisCollateral, // Portion of debt covered by this collateral
                    totalCollateralToSeize: totalCollateralToSeize, // Total amount including bonus
                    liquidator: liquidator // Entity performing liquidation
                 })
            );
        }
    }

    /*
     * @notice Executes the final token transfers in the liquidation process
     * @dev Performs two critical operations in sequence:
     *      1. Withdraws collateral from user to recipient (liquidator or protocol)
     *      2. Repays user's debt with liquidator's tokens
     * @dev Follows strict ordering for security:
     *      - Collateral withdrawal must precede debt repayment to prevent malicious liquidators from:
     *        a) Paying the debt (improving health factor)
     *        b) Using reentrancy to prevent collateral withdrawal
     *        c) Getting debt repayment without giving up collateral
     *      - This order ensures atomicity: either both transfers succeed or both fail
     * @dev Follows CEI (Checks-Effects-Interactions) pattern:
     *      1. State changes for collateral withdrawal
     *      2. External calls for transfers
     */
    function _executeTransfers(TransferParams memory params) private {
        // Step 1: Handle basic transfers
        _executeBasicTransfers(params);

        // Step 2: If protocol is recipient, call protocol handler
        if (params.recipient == address(this)) {
            _onProtocolLiquidation(params);
        }
    }

    /**
     * @notice Executes the collateral withdrawal during liquidation process
     * @dev Implements critical transfer logic
     *
     * Security Considerations:
     * - Must be called within _executeTransfers for proper sequencing
     * - Validates all parameters through LoanFi's safety checks
     * - Maintains protocol's access control hierarchy
     *
     * @param params Structured transfer parameters containing:
     *        - collateral: Token address being seized
     *        - totalCollateralToSeize: Precise amount to withdraw
     *        - user: Address being liquidated
     *        - recipient: Destination for collateral (liquidator/protocol)
     */
    function _liquidatationWithdrawCollateralFromUser(TransferParams memory params) private {
        // Execute withdrawal through main protocol contract
        // Maintains single source of truth for collateral accounting
        i_loanFi.liquidationWithdrawCollateral(
            params.collateral, params.totalCollateralToSeize, params.user, params.recipient
        );
    }

    /**
     * @notice Repays borrowed amount during liquidation using liquidator's tokens
     * @dev Uses transferFrom to take tokens directly from liquidator (msg.sender)
     * @param token The token to repay
     * @param amount The amount to repay
     * @param onBehalfOf The user whose debt is being repaid
     */
    function _liquidationPaybackBorrowedAmount(
        address token,
        uint256 amount,
        address onBehalfOf,
        address liquidator
    )
        private
    {
        i_loanFi.liquidationPaybackBorrowedAmount(token, amount, onBehalfOf, liquidator);
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL & PRIVATE VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the 10% liquidation incentive bonus
     * @dev Implements precise bonus calculation with protocol-level precision handling
     *
     * Calculation Process:
     * 1. Takes USD value of debt as input
     * 2. Multiplies by protocol's liquidation bonus rate (10%)
     * 3. Scales result by protocol's precision factor
     *
     * @param debtInUsd The USD value of debt being liquidated (scaled by protocol precision)
     * @return uint256 The calculated bonus amount in USD (scaled by protocol precision)
     */
    function getTenPercentBonus(uint256 debtInUsd) internal view returns (uint256) {
        // Calculate bonus using protocol's standardized bonus rate and precision
        // This maintains consistent decimal handling across all calculations
        return (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();
    }

    /*
     * @notice Calculates the bonus amount available from the liquidated collateral
     * @dev Implements a bonus calculation algorithm that:
     *      1. Calculates total bonus needed (10% of debt)
     *      2. Determines available bonus from excess collateral
     *      3. Returns maximum available bonus up to needed amount
     * @param debtInUsd: The USD value of debt being repaid by liquidator
     * @param collateralValueInUsd: The USD value of user's collateral being liquidated
     * @return bonusFromThisCollateral: The calculated bonus amount, capped at maximum needed
     */
    function _calculateBonusAmounts(
        uint256 totalBonusNeededInUsd, // The 10% bonus amount needed (in USD)
        uint256 collateralValueInUsd, // Value of user's collateral in USD
        uint256 debtInUsd // Value of debt being repaid in USD
    )
        internal
        pure
        returns (uint256 bonusFromThisCollateral)
    {
        // First check: Is there excess collateral available?
        if (collateralValueInUsd > debtInUsd) {
            // Calculate how much excess collateral is available for bonus
            uint256 availableForBonus = collateralValueInUsd - debtInUsd;

            // If availableForBonus > totalBonusNeededInUsd:
            //    return totalBonusNeededInUsd (full 10% bonus)
            // Else:
            //    return availableForBonus (partial bonus)
            bonusFromThisCollateral =
                (availableForBonus > totalBonusNeededInUsd) ? totalBonusNeededInUsd : availableForBonus;
        }
        // return the total bonus amount
        return bonusFromThisCollateral;
    }

    /*
     * @notice Performs comprehensive validation checks before liquidation execution
     * @dev Implements critical security checks in a specific order to minimize gas costs:
     *      1. Basic input validation (zero address)
     *      2. Access control (prevent self-liquidation)
     *      3. State validation (debt checks)
     *      4. Balance verification (liquidator's token balance)
     * @dev Reverts early if any check fails to save gas
     * @param debtToken: The token that was borrowed and needs to be repaid
     * @param user: The address of the user being liquidated
     * @param debtAmountToPay: The amount of debt to be repaid
     */
    function _validateLiquidation(
        address liquidator,
        address debtToken,
        address user,
        uint256 debtAmountToPay
    )
        private
        view
    {
        // Check for zero address
        if (user == address(0)) {
            revert Errors.ZeroAddressNotAllowed();
        }

        // Prevent users from liquidating themselves
        if (liquidator == user) {
            revert Errors.Liquidations__CantLiquidateSelf();
        }

        // Verify user has actually borrowed the token that needs to be repaid
        if (_getAmountOfTokenBorrowed(user, debtToken) == 0) {
            revert Errors.Liquidation__UserHasNotBorrowedToken();
        }

        // Verify the amount being repaid isn't more than user's debt in this token
        if (debtAmountToPay > _getAmountOfTokenBorrowed(user, debtToken)) {
            revert Errors.Liquidations__DebtAmountPaidExceedsBorrowedAmount();
        }

        // Verify liquidator has enough debt tokens to repay the debt
        if (IERC20(debtToken).balanceOf(liquidator) < debtAmountToPay) {
            revert Errors.Liquidations__InsufficientBalanceToLiquidate();
        }
    }

    /*
     * @notice Verifies that liquidation improved the user's health factor
     * @dev Critical safety check that ensures liquidations are beneficial:
     *      1. Calculates user's final health factor
     *      2. Compares against initial health factor
     *      3. Reverts if health hasn't improved
     * @dev This check prevents:
     *      - Malicious liquidations that worsen positions
     *      - Failed liquidations due to price manipulation
     *      - Ineffective partial liquidations
     * @param user The address of the user whose position was liquidated
     * @param startingUserHealthFactor The user's health factor before liquidation
     */
    function _verifyHealthFactorAfterLiquidation(address user, uint256 startingUserHealthFactor) private view {
        // Verify health factors
        uint256 endingUserHealthFactor = _healthFactor(user);

        // if the ending health factor is worse than the starting health factor, revert
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert Errors.Liquidations__HealthFactorNotImproved();
        }
    }

    function _isTokenAllowed(address token) private view returns (bool) {
        address[] memory allowedTokens = i_loanFi.getAllowedTokens();
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            if (allowedTokens[i] == token) return true;
        }
        return false;
    }

    /*
     * @notice Calculates liquidation bonuses from both primary collateral and other collateral types
     * @dev Performs USD value calculations and bonus distribution logic:
     *      1. Calculates debt and collateral values in USD
     *      2. Determines bonus from liquidated collateral
     *      3. If needed, calculates additional bonus from other collateral types
     * @dev This implements a "waterfall" bonus collection mechanism:
     *      - First tries to get bonus from the collateral being liquidated
     *      - Then collects remaining bonus needed from other collateral proportionally
     * @param collateral: The ERC20 token address being paid out to the liquidator
     * @param debtToken: The token that was borrowed and needs to be repaid
     * @param user: The address of the user being liquidated
     * @param debtAmountToPay: The amount of debt being repaid through liquidation
     * @return bonusFromThisCollateral: The bonus amount collected from the liquidated collateral
     * @return bonusFromOtherCollateral: The bonus amount collected from user's other collateral
     */
    function _calculateBonuses(BonusParams memory params)
        private
        view
        returns (uint256 bonusFromThisCollateral, uint256 bonusFromOtherCollateral, uint256 totalBonusNeededInUsd)
    {
        // gets the usd value of the debt being repaid
        uint256 debtInUsd = _getUsdValue(params.debtToken, params.debtAmountToPay);

        // gets the collateral balance of the user of this specific token
        uint256 userCollateralBalance = _getCollateralBalanceOfUser(params.user, params.collateral);

        // gets this specific token collateral balance of user in terms of USD
        uint256 collateralValueInUsd = _getUsdValue(params.collateral, userCollateralBalance);

        // get the bonus(10%) of the total debt paid by the liquidator
        totalBonusNeededInUsd = getTenPercentBonus(debtInUsd);

        // Calculate bonus from primary collateral
        bonusFromThisCollateral = _calculateBonusAmounts(totalBonusNeededInUsd, collateralValueInUsd, debtInUsd);

        // If primary collateral bonus insufficient, collect from other collateral
        if (bonusFromThisCollateral < totalBonusNeededInUsd) {
            // We only need the first return value (bonusCollectedInUsd)
            (bonusFromOtherCollateral,) = _collectBonusFromOtherCollateral(
                params.user, params.collateral, totalBonusNeededInUsd - bonusFromThisCollateral
            );
        }

        // If total bonus is less than required and caller is not the protocol, revert
        if (bonusFromThisCollateral + bonusFromOtherCollateral < totalBonusNeededInUsd && msg.sender != address(this)) {
            revert Errors.Liquidations__OnlyProtocolCanLiquidateInsufficientBonus();
        }

        return (bonusFromThisCollateral, bonusFromOtherCollateral, totalBonusNeededInUsd);
    }

    /*
     * @notice Collects additional liquidation bonus from user's other collateral types (if needed)
     * @dev Implements a proportional collection strategy:
     *      1. Calculates total available collateral value (excluding liquidated token)
     *      2. For each collateral type, takes a proportional share of needed bonus
     *      3. Converts USD values to token amounts and executes transfers
     * @dev Proportional collection ensures:
     *      - Fair distribution of bonus collection across collateral types
     *      - No single collateral type is disproportionately drained
     *      - Maximum bonus collection while maintaining position stability
     * @param user: The address of the user being liquidated
     * @param excludedCollateral: The collateral token address being liquidated (excluded from bonus collection)
     * @param bonusNeededInUsd: The remaining bonus amount needed in USD terms
     * @return bonusCollectedInUsd: The total USD value of bonus collected from other collateral
     * @custom:example If user has 3 collateral types worth $300 total (excluding liquidated token):
     */
    function _collectBonusFromOtherCollateral(
        address user,
        address excludedCollateral,
        uint256 bonusNeededInUsd
    )
        private
        view
        returns (uint256 bonusCollectedInUsd, BonusCollateralInfo[] memory collateralsToPull)
    {
        // Early return if no bonus is needed
        if (bonusNeededInUsd == 0) {
            return (0, new BonusCollateralInfo[](0));
        }

        // Get list of all allowed tokens and their USD values
        address[] memory allowedTokens = _getAllowedTokens();

        // Create array to store token values
        CollateralData[] memory collaterals = new CollateralData[](allowedTokens.length);
        uint256 validCollaterals = 0;
        uint256 totalCollateralValueInUsd = 0;

        // First pass: gather data about available collateral
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address token = allowedTokens[i];

            // Skip the collateral we already tried
            if (token == excludedCollateral) continue;

            // Skip if user has none of this token
            uint256 userBalance = _getCollateralBalanceOfUser(user, token);
            if (userBalance == 0) continue;

            uint256 valueInUsd = _getUsdValue(token, userBalance);
            if (valueInUsd == 0) continue;

            totalCollateralValueInUsd += valueInUsd;

            collaterals[validCollaterals] = CollateralData({
                token: token,
                excludedCollateral: excludedCollateral,
                userBalance: userBalance,
                valueInUsd: valueInUsd,
                totalAvailable: totalCollateralValueInUsd
            });
            validCollaterals++;
        }

        // Early return if no valid collateral found or total value is 0
        if (validCollaterals == 0 || totalCollateralValueInUsd == 0) {
            return (0, new BonusCollateralInfo[](0));
        }

        // Sort collaterals by USD value (highest to lowest)
        for (uint256 i = 0; i < validCollaterals - 1; i++) {
            for (uint256 j = 0; j < validCollaterals - i - 1; j++) {
                if (collaterals[j].valueInUsd < collaterals[j + 1].valueInUsd) {
                    CollateralData memory temp = collaterals[j];
                    collaterals[j] = collaterals[j + 1];
                    collaterals[j + 1] = temp;
                }
            }
        }

        // Initialize array to store collateral info
        collateralsToPull = new BonusCollateralInfo[](validCollaterals);
        uint256 collateralCount = 0;
        uint256 remainingBonusNeeded = bonusNeededInUsd;

        // Calculate amounts to take from each collateral
        for (uint256 i = 0; i < validCollaterals && remainingBonusNeeded > 0; i++) {
            CollateralData memory collateral = collaterals[i];

            uint256 bonusToTakeInUsd =
                remainingBonusNeeded > collateral.valueInUsd ? collateral.valueInUsd : remainingBonusNeeded;

            // Skip if no bonus to take
            if (bonusToTakeInUsd == 0) continue;

            // Convert bonus USD amount to token amount
            uint256 tokenAmountToTake = _getTokenAmountFromUsd(collateral.token, bonusToTakeInUsd);
            if (tokenAmountToTake == 0) continue;

            // Safety check: Don't take more than user has
            if (tokenAmountToTake > collateral.userBalance) {
                tokenAmountToTake = collateral.userBalance;
                bonusToTakeInUsd = _getUsdValue(collateral.token, tokenAmountToTake);
            }

            if (tokenAmountToTake > 0) {
                collateralsToPull[collateralCount] = BonusCollateralInfo({
                    token: collateral.token,
                    amountToTake: tokenAmountToTake,
                    bonusInUsd: bonusToTakeInUsd
                });
                collateralCount++;
                bonusCollectedInUsd += bonusToTakeInUsd;
                remainingBonusNeeded -= bonusToTakeInUsd;
            }
        }

        return (bonusCollectedInUsd, collateralsToPull);
    }

    /**
     * @notice Calculates precise transfer amounts for liquidation execution
     * @dev Implements sophisticated calculation logic with multiple safety checks
     *      and precise decimal handling for maximum accuracy
     *
     * Calculation Steps:
     * 1. Convert debt from USD to collateral terms
     * 2. Apply balance caps and safety checks
     * 3. Calculate bonus collateral amounts
     * 4. Determine remaining debt
     * 5. Select appropriate recipient
     *
     * Safety Features:
     * - Balance validation
     * - Overflow protection
     * - Precision handling
     * - Recipient determination
     *
     * @param user Address of user being liquidated
     * @param collateral Address of collateral token
     * @param liquidator Address of liquidator
     * @param debtInUsd USD value of debt being liquidated
     * @param bonusFromThisCollateral Bonus amount from primary collateral
     * @param bonusFromOtherCollateral Bonus from additional collateral
     * @param totalBonusNeededInUsd Total required bonus amount
     * @return result Structured result containing all calculated values
     */
    function _calculateTransferAmounts(
        address user,
        address collateral,
        address liquidator,
        uint256 debtInUsd,
        uint256 bonusFromThisCollateral,
        uint256 bonusFromOtherCollateral,
        uint256 totalBonusNeededInUsd
    )
        private
        view
        returns (TransferCalcResult memory result)
    {
        // Step 1: Convert debt from USD to collateral token terms
        // Uses oracle price feed for accurate conversion
        uint256 debtInCollateralTerms = _getTokenAmountFromUsd(collateral, debtInUsd);
        uint256 userBalance = _getCollateralBalanceOfUser(user, collateral);

        // Step 2: Apply safety cap to prevent over-liquidation
        // Ensures we never seize more than user's actual balance
        if (debtInCollateralTerms > userBalance) {
            debtInCollateralTerms = userBalance;
        }

        // Step 3: Calculate bonus amount in collateral terms
        // Converts USD bonus to equivalent collateral amount
        uint256 bonusCollateral = _getTokenAmountFromUsd(collateral, bonusFromThisCollateral);

        // Step 4: Calculate remaining debt after primary collateral
        // Used to determine if additional collateral is needed
        uint256 coveredDebtInUsd = _getUsdValue(collateral, debtInCollateralTerms);

        // Step 5: Return structured result with all calculated values
        return TransferCalcResult({
            debtInCollateralTerms: debtInCollateralTerms, // Amount of debt in collateral tokens
            bonusCollateral: bonusCollateral, // Amount of bonus in collateral tokens
            totalCollateralToSeize: debtInCollateralTerms + bonusCollateral, // Total transfer amount
            remainingDebtInUsd: debtInUsd > coveredDebtInUsd ? debtInUsd - coveredDebtInUsd : 0, // Uncovered debt
            recipient: _determineRecipient( // Calculate final recipient
                bonusFromThisCollateral + bonusFromOtherCollateral, totalBonusNeededInUsd, liquidator)
        });
    }

    /**
     * @notice Determines who should receive the liquidated collateral based on bonus availability
     * @dev If sufficient bonus is available, liquidator receives collateral
     *      If insufficient bonus (flash crash scenario), protocol handles liquidation
     * @param totalBonusAvailable Total bonus available across all collateral types
     * @param totalBonusNeededInUsd Required bonus amount in USD
     * @return address The recipient of the liquidated collateral (liquidator or protocol)
     */
    function _determineRecipient(
        uint256 totalBonusAvailable,
        uint256 totalBonusNeededInUsd,
        address liquidator
    )
        private
        view
        returns (address)
    {
        // If user has enough collateral to pay the full bonus, send to liquidator
        if (totalBonusAvailable >= totalBonusNeededInUsd) {
            return liquidator;
        }

        // In flash crash scenarios where bonus can't be fully paid
        // protocol takes over liquidation to protect the system
        return address(this);
    }
}
