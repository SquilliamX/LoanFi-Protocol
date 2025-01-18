// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILoanFi } from "../interfaces/ILoanFi.sol";
import { Getters } from "./Getters.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console } from "forge-std/Test.sol";

contract LiquidationCore is Getters {
    /* 
     * @notice Groups parameters related to bonus calculations during liquidation
     * @dev Used to avoid stack too deep errors when passing multiple parameters
     */

    struct BonusParams {
        /// The collateral token address being liquidated
        address collateral;
        /// The address of the user being liquidated
        address user;
        /// Amount of bonus calculated from the liquidated collateral
        uint256 bonusFromThisCollateral;
        /// Additional bonus amount collected from user's other collateral types
        uint256 bonusFromOtherCollateral;
        /// Amount of debt being repaid through liquidation
        uint256 debtAmountToPay;
        /// The token that was borrowed and needs to be repaid
        address debtToken;
    }

    /*
     * @notice Groups parameters related to transfer execution during liquidation
     * @dev Used to avoid stack too deep errors and maintain clean function signatures
     */
    struct TransferParams {
        /// The collateral token address being transferred
        address collateral;
        /// The token that was borrowed and needs to be repaid
        address debtToken;
        /// The address of the user whose collateral is being transferred
        address user;
        /// The address receiving the liquidated collateral
        address recipient;
        /// Amount of debt being repaid
        uint256 debtAmountToPay;
        /// Total amount of collateral being seized
        uint256 totalCollateralToSeize;
        /// The address of the liquidator
        address liquidator;
    }

    struct CollateralData {
        address token; // The collateral token being processed
        address excludedCollateral; // Collateral to exclude from bonus calculations
        uint256 userBalance; // User's balance of this collateral
        uint256 valueInUsd; // USD value of the collateral
        uint256 totalAvailable; // Total available collateral in USD (excluding specific token)
    }

    struct LiquidationParams {
        address user; // The user being liquidated
        address liquidator; // The address performing the liquidation
        address recipient; // The recipient of the liquidated collateral
        address debtToken; // The borrowed token to be repaid
        uint256 debtAmountToPay; // Amount of debt to repay
        uint256 debtInUsd; // USD value of the debt
    }

    struct BonusCollateralInfo {
        address token;
        uint256 amountToTake;
        uint256 bonusInUsd;
    }

    event UserLiquidated(address indexed collateral, address indexed userLiquidated, uint256 amountOfDebtPaid);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert Errors.AmountNeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (!_isTokenAllowed(token)) {
            revert Errors.TokenNotAllowed(token);
        }
        _;
    }

    constructor(address loanFiAddress) Getters(loanFiAddress) { }

    /* 
     * @dev Orchestrates the entire liquidation process including validation, bonus calculation, and health factor checks
     * @dev Follows CEI (Checks-Effects-Interactions) pattern for reentrancy protection
     * @param collateral: The ERC20 token address being used as collateral
     * @param debtToken: The token that was borrowed and needs to be repaid
     * @param user: The address of the user whose position is being liquidated
     * @param debtAmountToPay: The amount of debt to be repaid in the liquidation
     */
    function _liquidate(
        address liquidator,
        address user,
        address collateral,
        address debtToken,
        uint256 debtAmountToPay
    )
        internal
        moreThanZero(debtAmountToPay)
        isAllowedToken(collateral)
        isAllowedToken(debtToken)
    {
        _validateLiquidation(liquidator, debtToken, user, debtAmountToPay);

        // Initialize core liquidation parameters
        LiquidationParams memory params = LiquidationParams({
            user: user, // user is the user being liquidated passed in parameter
            liquidator: liquidator, // liquidator is the liquidator's address passed in parameter
            recipient: address(0), // Will be set during process
            debtToken: debtToken, // debtToken is the debtToken passed in parameter
            debtAmountToPay: debtAmountToPay, // debt token amount user being liquidated has
            debtInUsd: _getUsdValue(debtToken, debtAmountToPay) // get the usdValue of the debt
         });

        // get user health factor
        uint256 startingUserHealthFactor = _healthFactor(params.user);
        // if user's health factor is above 1, revert
        if (startingUserHealthFactor >= _getMinimumHealthFactor()) {
            revert Errors.Liquidations__HealthFactorIsHealthy();
        }

        // Initialize collateral data
        CollateralData memory collateralData = CollateralData({
            token: collateral, // collateral token
            excludedCollateral: address(0),
            userBalance: _getCollateralBalanceOfUser(user, collateral), // amount of collateral tokens user being liquidated has
            valueInUsd: 0, // Will be calculated during process
            totalAvailable: 0 // Will be calculated if needed
         });

        _processLiquidation(params, collateralData);

        _verifyHealthFactorAfterLiquidation(params.user, startingUserHealthFactor);

        // Safety check
        _revertIfHealthFactorIsBroken(msg.sender);
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

    function getTenPercentBonus(uint256 debtInUsd) internal view returns (uint256) {
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
     * @notice Calculates proportional bonus amount for each collateral type during multi-collateral liquidation
     * @dev Implements fair distribution algorithm using the formula
     * @dev This ensures:
     *      1. Each collateral contributes proportionally to its value
     *      2. Total collected bonus equals exactly the needed amount
     *      3. Fair distribution across all collateral types
     * @param collateralValueInUsd: The USD value of the specific collateral being calculated
     * @param totalAvailableCollateralInUsd: Total USD value of all available collateral
     * @param bonusNeededInUsd: Total remaining bonus needed in USD
     * @return The proportional bonus amount to take from this specific collateral
     * @custom:math-explanation If collateral is 30% of total value, it provides 30% of needed bonus
     */
    function _calculateProportionalBonus(
        uint256 collateralValueInUsd,
        uint256 totalAvailableCollateralInUsd,
        uint256 bonusNeededInUsd
    )
        private
        pure
        returns (uint256)
    {
        // Calculate proportional bonus to take from this collateral
        // If this collateral is 30% of user's total collateral value, it provides 30% of the bonus
        return (bonusNeededInUsd * collateralValueInUsd) / totalAvailableCollateralInUsd;
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

        console.log("=== _collectBonusFromOtherCollateral ===");
        console.log("Bonus needed in USD:", bonusNeededInUsd);

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

            console.log("Token:", uint256(uint160(token)));
            console.log("User balance:", userBalance);
            console.log("USD value:", valueInUsd);

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

    function _calculateAvailableCollateral(
        address user,
        address excludedCollateral /* the excluded collateral is the collateral we have already done calculations for */
    )
        private
        view
        returns (uint256)
    {
        // Get total collateral value in USD for all tokens from the user
        uint256 totalAvailableCollateralInUsd = _getAccountCollateralValueInUsd(user);

        // Subtract excluded collateral value in usd
        uint256 excludedCollateralValue =
            _getUsdValue(excludedCollateral, _getCollateralBalanceOfUser(user, excludedCollateral));

        // if the total collateral value in use is greater than the excluded collateral value, then return the total amount of collateral minus the excluded, otherwise, return zero. checks to see if the user has any other collateral available other than the collateral being used for the bonus
        return totalAvailableCollateralInUsd > excludedCollateralValue
            ? totalAvailableCollateralInUsd - excludedCollateralValue
            : 0;
    }

    function _processLiquidation(LiquidationParams memory params, CollateralData memory collateralData) private {
        (uint256 bonusFromThisCollateral, uint256 bonusFromOtherCollateral, uint256 totalBonusNeededInUsd) =
        _calculateBonuses(
            BonusParams({
                collateral: collateralData.token,
                user: params.user,
                bonusFromThisCollateral: 0,
                bonusFromOtherCollateral: 0,
                debtAmountToPay: params.debtAmountToPay,
                debtToken: params.debtToken
            })
        );

        emit UserLiquidated(collateralData.token, params.user, params.debtAmountToPay);

        _handleTransfers(
            params, collateralData, bonusFromThisCollateral, bonusFromOtherCollateral, totalBonusNeededInUsd
        );
    }

    // New struct to handle transfer calculations
    struct TransferCalcResult {
        uint256 debtInCollateralTerms;
        uint256 bonusCollateral;
        uint256 totalCollateralToSeize;
        uint256 remainingDebtInUsd;
        address recipient;
    }

    // Split calculation logic into a separate function
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
        // Convert debt to collateral terms
        uint256 debtInCollateralTerms = _getTokenAmountFromUsd(collateral, debtInUsd);
        uint256 userBalance = _getCollateralBalanceOfUser(user, collateral);

        // Cap at user's balance
        if (debtInCollateralTerms > userBalance) {
            debtInCollateralTerms = userBalance;
        }

        // Calculate bonus
        uint256 bonusCollateral = _getTokenAmountFromUsd(collateral, bonusFromThisCollateral);

        // Calculate remaining debt
        uint256 coveredDebtInUsd = _getUsdValue(collateral, debtInCollateralTerms);

        return TransferCalcResult({
            debtInCollateralTerms: debtInCollateralTerms,
            bonusCollateral: bonusCollateral,
            totalCollateralToSeize: debtInCollateralTerms + bonusCollateral,
            remainingDebtInUsd: debtInUsd > coveredDebtInUsd ? debtInUsd - coveredDebtInUsd : 0,
            recipient: _determineRecipient(
                bonusFromThisCollateral + bonusFromOtherCollateral, totalBonusNeededInUsd, liquidator
            )
        });
    }

    // Main transfer handling function - now more concise
    function _handleTransfers(
        LiquidationParams memory params,
        CollateralData memory collateralData,
        uint256 bonusFromThisCollateral,
        uint256 bonusFromOtherCollateral,
        uint256 totalBonusNeededInUsd
    )
        private
    {
        uint256 debtInUsd = _getUsdValue(params.debtToken, params.debtAmountToPay);

        // Get transfer amounts
        TransferCalcResult memory calc = _calculateTransferAmounts(
            params.user,
            collateralData.token,
            params.liquidator,
            debtInUsd,
            bonusFromThisCollateral,
            bonusFromOtherCollateral,
            totalBonusNeededInUsd
        );

        // Execute primary transfer
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

        // Handle additional collateral if needed
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

    // Add this struct to track debt repayment
    struct DebtRepayment {
        uint256 debtAmountPaid;
        uint256 debtValueInUsd;
    }

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
        (, BonusCollateralInfo[] memory collateralsToPull) = _collectBonusFromOtherCollateral(
            user, excludedCollateral, remainingDebtInUsd + (totalBonusNeededInUsd - bonusFromThisCollateral)
        );

        for (uint256 i = 0; i < collateralsToPull.length; i++) {
            if (collateralsToPull[i].amountToTake == 0) break;

            // Calculate how much debt this collateral is covering
            uint256 debtAmountForThisCollateral = 0;
            uint256 collateralValueInUsd = _getUsdValue(collateralsToPull[i].token, collateralsToPull[i].amountToTake);

            // If this collateral covers some debt, calculate the amount
            if (remainingDebtInUsd > 0) {
                if (collateralValueInUsd > collateralsToPull[i].bonusInUsd) {
                    debtAmountForThisCollateral = collateralValueInUsd - collateralsToPull[i].bonusInUsd;
                    remainingDebtInUsd = remainingDebtInUsd > debtAmountForThisCollateral
                        ? remainingDebtInUsd - debtAmountForThisCollateral
                        : 0;
                }
            }

            // Calculate total amount to seize including bonus
            uint256 totalCollateralToSeize;
            if (collateralValueInUsd > 0) {
                // If this collateral has value, calculate how much we need for debt+bonus
                uint256 totalNeededInUsd = debtAmountForThisCollateral + collateralsToPull[i].bonusInUsd;
                totalCollateralToSeize = _getTokenAmountFromUsd(collateralsToPull[i].token, totalNeededInUsd);
            } else {
                totalCollateralToSeize = collateralsToPull[i].amountToTake;
            }

            _executeTransfers(
                TransferParams({
                    collateral: collateralsToPull[i].token,
                    debtToken: debtToken,
                    user: user,
                    recipient: recipient,
                    debtAmountToPay: debtAmountForThisCollateral,
                    totalCollateralToSeize: totalCollateralToSeize,
                    liquidator: liquidator
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

        // Step 3: If protocol is recipient, call protocol handler
        if (params.recipient == address(this)) {
            _onProtocolLiquidation(params);
        }
    }

    function _executeBasicTransfers(TransferParams memory params) private {
        // First withdraw collateral
        _liquidatationWithdrawCollateralFromUser(params);

        // Then repay user's debt with liquidator's debt tokens
        _liquidationPaybackBorrowedAmount(params.debtToken, params.debtAmountToPay, params.user, params.liquidator);
    }

    function _liquidatationWithdrawCollateralFromUser(TransferParams memory params) private {
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

    // Virtual function with default empty implementation
    function _onProtocolLiquidation(TransferParams memory /* params */ ) internal virtual {
        // Default empty implementation
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
