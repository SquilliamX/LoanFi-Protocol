// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILoanFi } from "../interfaces/ILoanFi.sol";
import { Getters } from "./Getters.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    }

    struct LiquidationData {
        // Core parameters
        address collateral;
        address debtToken;
        address user;
        address recipient;
        address token; // for token processing
        uint256 debtAmountToPay;
        // Bonus related
        uint256 bonusFromThisCollateral;
        uint256 bonusFromOtherCollateral;
        uint256 totalBonusNeededInUsd;
        uint256 debtInUsd;
        uint256 bonusNeededInUsd;
        // Collateral related
        uint256 totalCollateralToSeize;
        uint256 userBalance;
        uint256 collateralValueInUsd;
        // For other collateral processing
        address excludedCollateral;
        uint256 totalAvailableCollateralInUsd;
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
    function _validateLiquidation(address debtToken, address user, uint256 debtAmountToPay) private view {
        // Check for zero address
        if (user == address(0)) {
            revert Errors.ZeroAddressNotAllowed();
        }

        // Prevent users from liquidating themselves
        if (msg.sender == user) {
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
        if (IERC20(debtToken).balanceOf(msg.sender) < debtAmountToPay) {
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
    function _calculateBonuses(LiquidationData memory data)
        internal
        view
        returns (uint256 bonusFromThisCollateral, uint256 bonusFromOtherCollateral)
    {
        data.debtInUsd = _getUsdValue(data.debtToken, data.debtAmountToPay);
        data.totalBonusNeededInUsd = _calculateTotalBonusNeeded(data.debtInUsd);

        bonusFromThisCollateral =
            _calculatePrimaryBonus(data.collateral, data.user, data.debtInUsd, data.totalBonusNeededInUsd);

        if (bonusFromThisCollateral < data.totalBonusNeededInUsd) {
            bonusFromOtherCollateral = _calculateSecondaryBonus(
                data.collateral, data.user, data.totalBonusNeededInUsd, bonusFromThisCollateral
            );
        }

        return (bonusFromThisCollateral, bonusFromOtherCollateral);
    }

    function _calculateTotalBonusNeeded(uint256 debtInUsd) private view returns (uint256) {
        return (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();
    }

    function _calculatePrimaryBonus(
        address collateral,
        address user,
        uint256 debtInUsd,
        uint256 /* totalBonusNeededInUsd */
    )
        private
        view
        returns (uint256)
    {
        uint256 collateralBalance = _getCollateralBalanceOfUser(user, collateral);
        uint256 collateralValueInUsd = _getUsdValue(collateral, collateralBalance);
        return _calculateBonusAmounts(debtInUsd, collateralValueInUsd);
    }

    function _calculateSecondaryBonus(
        address collateral,
        address user,
        uint256 totalBonusNeededInUsd,
        uint256 primaryBonus
    )
        private
        view
        returns (uint256)
    {
        uint256 remainingBonusNeeded = totalBonusNeededInUsd - primaryBonus;
        uint256 availableCollateralInUsd = _calculateAvailableCollateral(user, collateral);

        if (availableCollateralInUsd == 0) return 0;

        return _calculateProportionalBonus(
            availableCollateralInUsd, _getAccountCollateralValueInUsd(user), remainingBonusNeeded
        );
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
        uint256 debtInUsd,
        uint256 collateralValueInUsd
    )
        private
        view
        returns (uint256 bonusFromThisCollateral)
    {
        // 10% of what the liquidator paid is the total bonus needed
        uint256 totalBonusNeededInUsd = (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();

        // if user's collateral is greater than the debt the liquidator covered, then the difference is available for the 10% bonus for the liquidator
        if (collateralValueInUsd > debtInUsd) {
            uint256 availableForBonus = collateralValueInUsd - debtInUsd;
            // if the difference is greater than what the 10% bonus, then pay the bonus from this collateral
            // if the difference is smaller than the 10% bonus, then take the whole difference for the bonus
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
        // If this collateral is 30% of user's total collateral value(exlcuding crashed token), it provides 30% of the bonus paid.
        // Each token contributes proportionally to its share of the total collateral
        // The total bonus collected will equal the needed amount
        // No single token type is unfairly drained first
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
        returns (uint256 bonusCollectedInUsd)
    {
        uint256 totalAvailableCollateralInUsd = _calculateAvailableCollateral(user, excludedCollateral);
        if (totalAvailableCollateralInUsd == 0) return 0;

        LiquidationData memory data = LiquidationData({
            collateral: user,
            debtToken: excludedCollateral,
            user: user,
            recipient: address(0),
            token: address(0),
            debtAmountToPay: 0,
            bonusFromThisCollateral: 0,
            bonusFromOtherCollateral: 0,
            totalBonusNeededInUsd: 0,
            debtInUsd: 0,
            bonusNeededInUsd: bonusNeededInUsd,
            totalCollateralToSeize: 0,
            userBalance: 0,
            collateralValueInUsd: 0,
            excludedCollateral: excludedCollateral,
            totalAvailableCollateralInUsd: totalAvailableCollateralInUsd
        });

        return _processCollateralTokens(data);
    }

    function _calculateAvailableCollateral(address user, address excludedCollateral) private view returns (uint256) {
        // Get total collateral value in USD
        uint256 totalAvailableCollateralInUsd = _getAccountCollateralValueInUsd(user);

        // Subtract excluded collateral value
        uint256 excludedCollateralValue =
            _getUsdValue(excludedCollateral, _getCollateralBalanceOfUser(user, excludedCollateral));
        return totalAvailableCollateralInUsd > excludedCollateralValue
            ? totalAvailableCollateralInUsd - excludedCollateralValue
            : 0;
    }

    function _processCollateralTokens(LiquidationData memory data) private returns (uint256 bonusCollectedInUsd) {
        address[] memory allowedTokens = _getAllowedTokens();

        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address token = allowedTokens[i];
            if (token == data.excludedCollateral) continue;

            data.token = token;
            data.userBalance = _getCollateralBalanceOfUser(data.user, token);

            bonusCollectedInUsd += _processIndividualToken(data);
        }
    }

    function _processIndividualToken(LiquidationData memory data) private returns (uint256 bonusCollected) {
        if (data.userBalance == 0) return 0;

        data.collateralValueInUsd = _getUsdValue(data.token, data.userBalance);
        uint256 bonusToTakeInUsd = _calculateProportionalBonus(
            data.collateralValueInUsd, data.totalAvailableCollateralInUsd, data.bonusNeededInUsd
        );

        uint256 tokenAmountToTake = _getTokenAmountFromUsd(data.token, bonusToTakeInUsd);
        if (tokenAmountToTake > data.userBalance) {
            tokenAmountToTake = data.userBalance;
            bonusToTakeInUsd = _getUsdValue(data.token, tokenAmountToTake);
        }

        if (tokenAmountToTake > 0) {
            _withdrawCollateral(data.token, tokenAmountToTake, data.user, address(this));
            bonusCollected = bonusToTakeInUsd;
        }
    }

    /*
     * @notice Calculates final distribution parameters for liquidation rewards
     * @dev Core distribution logic that:
     *      1. Converts bonus amounts from USD to token terms
     *      2. Determines total collateral to seize (debt + bonus)
     *      3. Decides final recipient based on bonus availability
     * @dev Decision flow for recipient:
     *      - If full bonus available: Liquidator (msg.sender) receives collateral
     *      - If partial bonus: Protocol (address(this)) handles liquidation
     * @return recipient: The address that receives the liquidated collateral
     * @return totalCollateralToSeize: The total amount of collateral to transfer
     */
    function _handleBonusDistribution(BonusParams memory params)
        private
        view
        returns (address recipient, uint256 totalCollateralToSeize)
    {
        // Step 1: Calculate collateral amounts
        (uint256 debtInCollateralTerms, uint256 bonusCollateral) = _calculateCollateralAmounts(params);
        totalCollateralToSeize = debtInCollateralTerms + bonusCollateral;

        // Step 2: Determine recipient based on bonus availability
        recipient = _determineRecipientFromBonus(params);
    }

    function _calculateCollateralAmounts(BonusParams memory params)
        private
        view
        returns (uint256 debtInCollateralTerms, uint256 bonusCollateral)
    {
        // Convert bonus to collateral terms
        bonusCollateral = _getTokenAmountFromUsd(params.collateral, params.bonusFromThisCollateral);

        // Convert debt to collateral terms
        debtInCollateralTerms = _convertDebtToCollateral(params.collateral, params.debtToken, params.debtAmountToPay);
    }

    function _convertDebtToCollateral(
        address collateral,
        address debtToken,
        uint256 debtAmount
    )
        private
        view
        returns (uint256)
    {
        uint256 debtInUsd = _getUsdValue(debtToken, debtAmount);
        return _getTokenAmountFromUsd(collateral, debtInUsd);
    }

    function _determineRecipientFromBonus(BonusParams memory params) private view returns (address) {
        uint256 totalBonusNeeded = _calculateRequiredBonus(params.debtToken, params.debtAmountToPay);
        uint256 totalBonusAvailable = params.bonusFromThisCollateral + params.bonusFromOtherCollateral;

        return _determineRecipient(totalBonusAvailable, totalBonusNeeded);
    }

    function _calculateRequiredBonus(address debtToken, uint256 debtAmount) private view returns (uint256) {
        uint256 debtInUsd = _getUsdValue(debtToken, debtAmount);
        return (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();
    }

    /*
     * @notice Determines whether liquidator or protocol receives liquidated collateral
     * @dev Critical decision logic that ensures protocol solvency:
     *      1. If full bonus available: Liquidator receives collateral (incentivized liquidation)
     *      2. If partial bonus: Protocol handles liquidation (automated protection in case of flash crashes or other emergencies)
     * @dev This dual-mode system provides:
     *      - Market-driven liquidations during normal conditions
     *      - Protocol-driven liquidations during extreme market events
     * @param totalBonusAvailable: Total bonus collected from all collateral sources
     * @param totalBonusNeededInUsd: Required bonus amount for standard liquidation
     * @return address Either msg.sender (liquidator) or address(this) (protocol)
     * @custom:security-note Acts as last line of defense during flash crashes
     * @custom:market-conditions Adapts to varying market conditions:
     *      - Normal: External liquidators incentivized by bonus
     *      - Crisis: Protocol self-liquidates to maintain solvency
     */
    function _determineRecipient(
        uint256 totalBonusAvailable,
        uint256 totalBonusNeededInUsd
    )
        internal
        view
        returns (address)
    {
        // if the user has enough to pay the bonus for the liquidator, then pay the liquidator.
        if (totalBonusAvailable >= totalBonusNeededInUsd) {
            return msg.sender;
        }
        // in the event of a flash crash and the user does not have enough to pay a bonus for a liquidator, then this protocol will automatically liquidate the user
        return address(this);
    }

    /* 
     * @dev Orchestrates the entire liquidation process including validation, bonus calculation, and health factor checks
     * @dev Follows CEI (Checks-Effects-Interactions) pattern for reentrancy protection
     * @param collateral: The ERC20 token address being used as collateral
     * @param debtToken: The token that was borrowed and needs to be repaid
     * @param user: The address of the user whose position is being liquidated
     * @param debtAmountToPay: The amount of debt to be repaid in the liquidation
     */
    function _liquidate(
        address collateral,
        address debtToken,
        address user,
        uint256 debtAmountToPay
    )
        internal
        moreThanZero(debtAmountToPay)
        isAllowedToken(collateral)
        isAllowedToken(debtToken)
    {
        LiquidationData memory data = LiquidationData({
            collateral: collateral,
            debtToken: debtToken,
            user: user,
            recipient: address(0),
            token: address(0),
            debtAmountToPay: debtAmountToPay,
            bonusFromThisCollateral: 0,
            bonusFromOtherCollateral: 0,
            totalBonusNeededInUsd: 0,
            debtInUsd: 0,
            bonusNeededInUsd: 0,
            totalCollateralToSeize: 0,
            userBalance: 0,
            collateralValueInUsd: 0,
            excludedCollateral: address(0),
            totalAvailableCollateralInUsd: 0
        });

        _validateLiquidation(data.debtToken, data.user, data.debtAmountToPay);

        uint256 startingUserHealthFactor = _healthFactor(data.user);
        if (startingUserHealthFactor >= _getMinimumHealthFactor()) {
            revert Errors.Liquidations__HealthFactorIsHealthy();
        }

        _processLiquidation(data);

        _verifyHealthFactorAfterLiquidation(data.user, startingUserHealthFactor);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _processLiquidation(LiquidationData memory data) private {
        // Calculate bonuses
        (data.bonusFromThisCollateral, data.bonusFromOtherCollateral) = _calculateBonuses(data);

        emit UserLiquidated(data.collateral, data.user, data.debtAmountToPay);

        _handleTransfers(data);
    }

    function _handleTransfers(LiquidationData memory data) private {
        (data.recipient, data.totalCollateralToSeize) = _calculateDistribution(data);

        _executeTransfers(
            TransferParams({
                collateral: data.collateral,
                debtToken: data.debtToken,
                user: data.user,
                recipient: data.recipient,
                debtAmountToPay: data.debtAmountToPay,
                totalCollateralToSeize: data.totalCollateralToSeize
            })
        );
    }

    function _calculateDistribution(LiquidationData memory data)
        private
        view
        returns (address recipient, uint256 totalCollateralToSeize)
    {
        // Convert bonus amounts to collateral terms
        (uint256 debtInCollateralTerms, uint256 bonusCollateral) = _calculateCollateralAmounts(
            BonusParams({
                collateral: data.collateral,
                user: data.user,
                bonusFromThisCollateral: data.bonusFromThisCollateral,
                bonusFromOtherCollateral: data.bonusFromOtherCollateral,
                debtAmountToPay: data.debtAmountToPay,
                debtToken: data.debtToken
            })
        );

        totalCollateralToSeize = debtInCollateralTerms + bonusCollateral;
        recipient = _determineRecipient(
            data.bonusFromThisCollateral + data.bonusFromOtherCollateral,
            _calculateRequiredBonus(data.debtToken, data.debtAmountToPay)
        );
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
            _onProtocolLiquidation(params); // Virtual function to be implemented by Engine
        }
    }

    function _executeBasicTransfers(TransferParams memory params) private {
        // First withdraw collateral to liquidator
        _withdrawCollateral(params.collateral, params.totalCollateralToSeize, params.user, params.recipient);

        // Then repay user's debt with liquidator's debt tokens
        _paybackBorrowedAmount(params.debtToken, params.debtAmountToPay, params.user);
    }

    // Virtual function with default empty implementation
    function _onProtocolLiquidation(TransferParams memory /* params */ ) internal virtual {
        // Default empty implementation
    }
}
