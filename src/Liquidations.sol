// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Withdraw } from "src/Withdraw.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Liquidations is Withdraw {
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

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Withdraw(tokenAddresses, priceFeedAddresses)
    { }

    /* 
     * @notice Liquidates an unhealthy position
     * @param collateral: The liquidator can choose collateral token address he wants as a reward for liquidating the user. 
     * @param debtToken: The token that was borrowed and needs to be repaid
     * @param user: The user whose position is being liquidated
     * @param debtAmountToPay: The amount of debt to repay
     * @dev This function allows liquidators to repay some of a user's debt and receive their collateral at a discount (bonus).
     * @dev In events of flash crashes and the user does not have enough of the collateral token that the liquidator chose as a reward, the protocol will split the reward from the user's other collateral types deposited, to incentivize liquidators. If the user still does not have enough collateral to incentivize liquidators, the protocol will liquidate users to cover the losses.
    */
    function liquidate(
        address user,
        address collateral,
        address debtToken,
        uint256 debtAmountToPay
    )
        external
        nonReentrant
    {
        _liquidate(collateral, debtToken, user, debtAmountToPay);
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
        private
        moreThanZero(debtAmountToPay)
        isAllowedToken(collateral)
        isAllowedToken(debtToken)
    {
        // First do all validation checks
        _validateLiquidation(debtToken, user, debtAmountToPay);

        // Get the user's initial health factor to:
        // 1. Verify they can be liquidated (health factor < MIN_HEALTH_FACTOR)
        // 2. Compare with their final health factor after liquidation
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= _getMinimumHealthFactor()) {
            revert Errors.Liquidations__HealthFactorIsHealthy();
        }

        // Handle bonus calculation and transfers (liquidate user and reward liquidator)
        _handleLiquidation(collateral, debtToken, user, debtAmountToPay);

        // Verify health factors after liquidation
        _verifyHealthFactorAfterLiquidation(user, startingUserHealthFactor);

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*  
     * @notice Handles the core liquidation logic after validation checks
     * @dev Follows CEI (Checks-Effects-Interactions) pattern:
     *      1. Calculates bonuses (pure calculation)
     *      2. Emits event (effect)
     *      3. Performs transfers (interactions)
     * @dev This function is called by _liquidate after all validation checks pass
     * @param collateral: The ERC20 token address being paid out to the liquidator
     * @param debtToken: The token that was borrowed and needs to be repaid
     * @param user: The address of the user whose position is being liquidated
     * @param debtAmountToPay: The amount of debt being repaid through liquidation
    */
    function _handleLiquidation(address collateral, address debtToken, address user, uint256 debtAmountToPay) private {
        // Calculate and return the bonus
        (uint256 bonusFromThisCollateral, uint256 bonusFromOtherCollateral) =
            _calculateBonuses(collateral, debtToken, user, debtAmountToPay);

        // emit event before external interactions
        emit UserLiquidated(collateral, user, debtAmountToPay);

        // Handle distribution and transfers (liquidate user and reward liquidator)
        _handleDistributionAndTransfers(
            collateral, debtToken, user, debtAmountToPay, bonusFromThisCollateral, bonusFromOtherCollateral
        );
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
    function _calculateBonuses(
        address collateral,
        address debtToken,
        address user,
        uint256 debtAmountToPay
    )
        private
        returns (uint256 bonusFromThisCollateral, uint256 bonusFromOtherCollateral)
    {
        // gets the usd value of the amount the liquidator is paying
        uint256 debtInUsd = _getUsdValue(debtToken, debtAmountToPay);
        // gets the collateral balance of the user of this specific token
        uint256 userCollateralBalance = _getCollateralBalanceOfUser(user, collateral);

        // gets this specific token collateral balance of of user in terms of USD
        uint256 collateralValueInUsd = _getUsdValue(collateral, userCollateralBalance);

        // get the bonus(10%) of the total debt paid by the liquidator
        uint256 totalBonusNeededInUsd = (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();

        // get the total bonus amount and save it as a variable named `bonusFromThisCollateral`
        bonusFromThisCollateral = _calculateBonusAmounts(debtInUsd, collateralValueInUsd);

        // Checks to see if the user has other collateral to cover for the bonus of the liquidator if the user's collateral that is being liquidated is not enough to cover the bonus. (Safety to avoid Insolvency in case of flash crashes)
        bonusFromOtherCollateral =
            _collectBonusFromOtherCollateral(user, collateral, totalBonusNeededInUsd - bonusFromThisCollateral);

        return (bonusFromThisCollateral, bonusFromOtherCollateral);
    }

    /*
     * @notice Manages the distribution of liquidation rewards and executes token transfers
     * @dev Orchestrates the final phase of liquidation:
     *      1. Packages bonus parameters for distribution calculation
     *      2. Determines recipient (liquidator or protocol) based on available bonus
     *      3. Executes collateral transfers and debt repayment
     * @dev Uses structs to avoid stack too deep errors and improve readability:
     *      - BonusParams: Groups bonus calculation parameters
     *      - TransferParams: Groups transfer execution parameters
     * @param collateral: The ERC20 token address being liquidated
     * @param debtToken: The token that was borrowed and needs to be repaid
     * @param user: The address of the user being liquidated
     * @param debtAmountToPay: The amount of debt being repaid
     * @param bonusFromThisCollateral: Bonus amount from the liquidated collateral
     * @param bonusFromOtherCollateral: Additional bonus from other collateral types
     * @custom:CEI-pattern Follows Checks-Effects-Interactions:
     *      - Checks: Bonus calculations in _handleBonusDistribution
     *      - Effects: State updates in _withdrawCollateral
     *      - Interactions: Token transfers in _executeTransfers
     */
    function _handleDistributionAndTransfers(
        address collateral,
        address debtToken,
        address user,
        uint256 debtAmountToPay,
        uint256 bonusFromThisCollateral,
        uint256 bonusFromOtherCollateral
    )
        private
    {
        // initialize
        BonusParams memory bonusParams = BonusParams({
            collateral: collateral,
            user: user,
            bonusFromThisCollateral: bonusFromThisCollateral,
            bonusFromOtherCollateral: bonusFromOtherCollateral,
            debtAmountToPay: debtAmountToPay,
            debtToken: debtToken
        });

        // return the liquidator's address and the amount of collateral the liquidator should be rewarded
        (address recipient, uint256 totalCollateralToSeize) = _handleBonusDistribution(bonusParams);

        // initialize
        TransferParams memory transferParams = TransferParams({
            collateral: collateral,
            debtToken: debtToken,
            user: user,
            recipient: recipient,
            debtAmountToPay: debtAmountToPay,
            totalCollateralToSeize: totalCollateralToSeize
        });

        // liquidate the user (withdraw & pay debts)
        _executeTransfers(transferParams);
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
        pure
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
        // gets the token amount of the bonus USD amount
        uint256 bonusCollateral = _getTokenAmountFromUsd(params.collateral, params.bonusFromThisCollateral);

        // Convert debt amount to collateral terms
        uint256 debtInUsd = _getUsdValue(params.debtToken, params.debtAmountToPay);
        uint256 debtInCollateralTerms = _getTokenAmountFromUsd(params.collateral, debtInUsd);

        // adds the debt amount (in collateral terms) and the bonus
        totalCollateralToSeize = debtInCollateralTerms + bonusCollateral;

        // adds the bonus amount from one collateral and bonus amount from other collaterals
        uint256 totalBonusAvailable = params.bonusFromThisCollateral + params.bonusFromOtherCollateral;

        // gets the usd value of the bonus needed
        uint256 totalBonusNeededInUsd = (
            _getUsdValue(params.debtToken, params.debtAmountToPay) * _getLiquidationBonus()
        ) / _getLiquidationPrecision();

        // determine who is doing the liquidating (liquidator or protocol)
        recipient = _determineRecipient(totalBonusAvailable, totalBonusNeededInUsd);

        // return the liquidator's address and the amount of collateral the liquidator should be rewarded
        return (recipient, totalCollateralToSeize);
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
        // First withdraw collateral to liquidator
        _withdrawCollateral(params.collateral, params.totalCollateralToSeize, params.user, params.recipient);

        // Then repay user's debt with liquidator's debt tokens
        _paybackBorrowedAmount(params.debtToken, params.debtAmountToPay, params.user);
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
        // get total collateral value in terms of USD of all of the user's deposited collateral
        uint256 totalAvailableCollateralInUsd = getAccountCollateralValueInUsd(user);

        // Subtract the excluded collateral's value
        uint256 excludedCollateralValue =
            _getUsdValue(excludedCollateral, _getCollateralBalanceOfUser(user, excludedCollateral));
        totalAvailableCollateralInUsd -= excludedCollateralValue;

        // If no collateral available, return 0
        if (totalAvailableCollateralInUsd == 0) return 0;

        // Take proportional amount from each collateral type
        for (uint256 i = 0; i < _getAllowedTokens().length; i++) {
            address token = _getAllowedTokens()[i];
            if (token == excludedCollateral) continue;

            uint256 userBalance = _getCollateralBalanceOfUser(user, token);
            if (userBalance == 0) continue;

            uint256 collateralValueInUsd = _getUsdValue(token, userBalance);

            // Calculate proportional bonus to take from this collateral
            uint256 bonusToTakeInUsd =
                _calculateProportionalBonus(collateralValueInUsd, totalAvailableCollateralInUsd, bonusNeededInUsd);

            // Convert USD amount to token amount
            uint256 tokenAmountToTake = _getTokenAmountFromUsd(token, bonusToTakeInUsd);

            // Safety check in case of rounding
            if (tokenAmountToTake > userBalance) {
                tokenAmountToTake = userBalance;
                bonusToTakeInUsd = _getUsdValue(token, tokenAmountToTake);
            }

            // Take the tokens if there's any to take
            if (tokenAmountToTake > 0) {
                _withdrawCollateral(token, tokenAmountToTake, user, address(this));
                bonusCollectedInUsd += bonusToTakeInUsd;
            }
        }
        return bonusCollectedInUsd;
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
        private
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
}
