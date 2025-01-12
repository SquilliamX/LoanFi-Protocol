// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Withdraw } from "src/Withdraw.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SwapLiquidatedTokens } from "src/SwapLiquidatedTokens.sol";
import { IAutomationRegistryInterface } from "src/interfaces/IAutomationRegistryInterface.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Liquidations Contract
 * @notice Manages the liquidation process for unhealthy positions with a dual-mode liquidation system
 *
 * @dev Liquidation Modes:
 * 1. Regular Liquidations (Market-Driven):
 *    - External liquidators repay users' debt in exchange for user's collateral + 10% bonus
 *    - Requires sufficient collateral value to pay the full bonus
 *    - Most efficient during normal market conditions
 *    - Anyone can be a liquidator
 *
 * 2. Protocol Liquidations (Emergency Mode):
 *    - Activated when positions can't provide sufficient bonus
 *    - Only the protocol (via automation) can perform these liquidations
 *    - Used during flash crashes or extreme market conditions
 *    - Protects protocol solvency when regular liquidations aren't viable
 *
 * @dev Bonus Waterfall Mechanism:
 * The bonus collection follows a waterfall pattern:
 * 1. Primary Collateral:
 *    - First attempts to pay bonus from the collateral being liquidated
 *    - Calculates maximum bonus available from this collateral
 *    - If sufficient, entire bonus comes from this source
 *
 * 2. Secondary Collateral (If Needed):
 *    - If primary collateral insufficient, checks other collateral types from user being liquidated
 *    - Collects remaining needed bonus proportionally from other collateral
 *    - Helps maintain liquidation incentives during partial collateral crashes
 *
 * 3. Protocol Intervention:
 *    - If total available bonus (primary + secondary) < required bonus:
 *      * Regular liquidators are blocked (revert)
 *      * Only protocol can liquidate the position
 *      * Automated system monitors and executes these liquidations
 *
 * @dev Example Scenarios:
 * 1. Normal Case:
 *    - User has $1000 ETH debt
 *    - Liquidator repays $1000
 *    - Liquidator receives $1000 + $100 (10% bonus) in ETH
 *
 * 2. Split Bonus Case:
 *    - User has $1000 ETH debt
 *    - ETH collateral can only provide $40 bonus
 *    - Remaining $60 bonus collected from user's WBTC collateral
 *
 * 3. Protocol Liquidation Case:
 *    - User has $1000 ETH debt
 *    - Total available bonus across all collateral = $1000
 *    - Regular liquidators blocked (insufficient bonus)
 *    - Protocol automation liquidates position
 *
 * @dev Security Considerations:
 * - Reentrancy protection on all liquidation functions
 * - Access control for protocol liquidations
 * - Health factor checks before and after liquidations
 * - Bonus calculations protected against overflow/underflow
 */
contract Liquidations is Withdraw, Ownable {
    using SafeERC20 for IERC20;

    SwapLiquidatedTokens private immutable i_swapRouter;
    IAutomationRegistryInterface private immutable i_automationRegistry;
    uint256 private immutable i_upkeepId;

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address swapRouterAddress,
        address automationRegistry,
        uint256 upkeepId
    )
        Withdraw(tokenAddresses, priceFeedAddresses)
        Ownable(msg.sender)
    {
        i_swapRouter = SwapLiquidatedTokens(swapRouterAddress);
        i_automationRegistry = IAutomationRegistryInterface(automationRegistry);
        i_upkeepId = upkeepId;
    }

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

        // If total bonus is less than required and caller is not the protocol, revert
        if (bonusFromThisCollateral + bonusFromOtherCollateral < totalBonusNeededInUsd && msg.sender != address(this)) {
            revert Errors.Liquidations__OnlyProtocolCanLiquidateInsufficientBonus();
        }

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

        // If protocol is liquidating
        if (params.recipient == address(this)) {
            // Calculate what bonus was actually available vs needed
            uint256 debtInUsd = _getUsdValue(params.debtToken, params.debtAmountToPay);
            uint256 totalBonusNeededInUsd = (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();
            uint256 actualBonusInUsd = _getUsdValue(params.collateral, params.totalCollateralToSeize) - debtInUsd;

            // Calculate protocol fee (whatever bonus was available)
            uint256 protocolFeeAmount = params.totalCollateralToSeize - params.debtAmountToPay;

            emit ProtocolFeeCollected(params.collateral, protocolFeeAmount, totalBonusNeededInUsd - actualBonusInUsd);

            // First swap collateral to debt token to cover the debt
            IERC20(params.collateral).approve(address(i_swapRouter), 0);
            IERC20(params.collateral).approve(address(i_swapRouter), params.debtAmountToPay);
            uint256 minAmountOutDebt =
                _calculateMinAmountOut(params.collateral, params.debtToken, params.debtAmountToPay);
            i_swapRouter.swapExactInputSingle(
                params.collateral, params.debtToken, params.debtAmountToPay, minAmountOutDebt
            );

            // Then swap protocol fee to LINK for automation funding
            address linkToken = i_automationRegistry.LINK();
            IERC20(params.collateral).approve(address(i_swapRouter), 0);
            IERC20(params.collateral).approve(address(i_swapRouter), protocolFeeAmount);
            uint256 minAmountOutLink = _calculateMinAmountOut(params.collateral, linkToken, protocolFeeAmount);
            uint256 linkReceived =
                i_swapRouter.swapExactInputSingle(params.collateral, linkToken, protocolFeeAmount, minAmountOutLink);

            // Fund Chainlink Automation with received LINK
            IERC20(linkToken).approve(address(i_automationRegistry), 0);
            IERC20(linkToken).approve(address(i_automationRegistry), linkReceived);
            i_automationRegistry.addFunds(i_upkeepId, uint96(linkReceived));
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

    /**
     * @notice Finds ALL positions that need protocol liquidation due to insufficient bonus
     * @dev Returns arrays of matching debt tokens, collateral tokens, and amounts
     * @dev This function is critical for protocol safety during market stress events
     *
     * Key Features:
     * - Comprehensive position scanning
     * - Gas-optimized array handling
     * - Protection against flash crash scenarios
     * - Supports multi-collateral positions
     */
    function getInsufficientBonusPositions(address user)
        external
        view
        returns (
            address[] memory debtTokens, // Array of tokens the user has borrowed
            address[] memory collaterals, // Array of corresponding collateral tokens
            uint256[] memory debtAmounts // Array of debt amounts to be repaid
        )
    {
        // Step 1: Initialize arrays with maximum possible size
        // Get list of all tokens supported by the protocol (e.g., [WETH, WBTC, DAI])
        address[] memory allowedTokens = _getAllowedTokens();
        uint256 allowedTokensLength = allowedTokens.length;

        // Calculate maximum possible number of debt/collateral combinations
        // Example: If we have 3 tokens, max combinations = 3 * 3 = 9
        uint256 maxPositions = allowedTokensLength * allowedTokensLength;

        // Create arrays to store all possible positions
        // These will be resized at the end to match actual number found
        debtTokens = new address[](maxPositions);
        collaterals = new address[](maxPositions);
        debtAmounts = new uint256[](maxPositions);
        uint256 positionCount = 0; // Tracks how many positions we've found

        // Step 2: Check each possible debt token
        for (uint256 i = 0; i < allowedTokensLength; i++) {
            // Get the current token we're checking as potential debt
            address potentialDebtToken = allowedTokens[i];
            // Check how much of this token the user has borrowed
            uint256 userDebt = _getAmountOfTokenBorrowed(user, potentialDebtToken);

            // Only proceed if user has borrowed this token
            if (userDebt > 0) {
                // Convert debt amount to USD for consistent comparisons
                // Example: If debt is 1 ETH and ETH = $2000, debtInUsd = $2000
                uint256 debtInUsd = _getUsdValue(potentialDebtToken, userDebt);

                // Calculate required liquidation bonus (typically 10%)
                // Example: For $2000 debt, bonus needed = $200
                uint256 totalBonusNeededInUsd = (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();

                // Step 3: For each debt, check every possible collateral token
                for (uint256 j = 0; j < allowedTokensLength; j++) {
                    address potentialCollateral = allowedTokens[j];

                    // Get user's balance of this collateral token
                    uint256 collateralBalance = _getCollateralBalanceOfUser(user, potentialCollateral);
                    // Convert collateral to USD value
                    // Example: If collateral is 1 ETH and ETH = $2000, value = $2000
                    uint256 collateralValueInUsd = _getUsdValue(potentialCollateral, collateralBalance);

                    // Step 4: Calculate available bonus from this collateral
                    // This complex calculation handles three cases:
                    // 1. Collateral value <= Debt: No bonus possible (returns 0)
                    // 2. Excess collateral < Needed bonus: Partial bonus available
                    // 3. Excess collateral >= Needed bonus: Full bonus available
                    uint256 bonusFromThisCollateral = (collateralValueInUsd > debtInUsd)
                        ? (
                            (collateralValueInUsd - debtInUsd) > totalBonusNeededInUsd
                                ? totalBonusNeededInUsd // Can pay full bonus
                                : (collateralValueInUsd - debtInUsd)
                        ) // Can only pay partial bonus
                        : 0; // Can't pay any bonus

                    // Step 5: If this position can't provide full bonus, it needs protocol liquidation
                    if (bonusFromThisCollateral < totalBonusNeededInUsd) {
                        // Store this position's details
                        debtTokens[positionCount] = potentialDebtToken;
                        collaterals[positionCount] = potentialCollateral;
                        debtAmounts[positionCount] = userDebt;
                        positionCount++;
                    }
                }
            }
        }

        // Step 6: Optimize memory usage by resizing arrays to actual number of positions found
        // This uses assembly for gas efficiency
        assembly {
            mstore(debtTokens, positionCount) // Update debtTokens array length
            mstore(collaterals, positionCount) // Update collaterals array length
            mstore(debtAmounts, positionCount) // Update debtAmounts array length
        }
    }

    function protocolLiquidate(
        address user,
        address collateral,
        address debtToken,
        uint256 debtAmountToPay
    )
        external
        onlyOwner
        nonReentrant
    {
        // Use delegatecall to execute the liquidate function in the context of this contract
        // delegatecall means the liquidation will happen as if the protocol itself is the liquidator
        // This is useful when positions need liquidation but external liquidators aren't incentivized enough (during flash crashes when the user cannot afford the 10% bonus)
        (bool success,) = address(this).delegatecall(
            // Encode the function call to "liquidate" with all its parameters
            // The signature "liquidate(address,address,address,uint256)" identifies which function to call
            // The parameters (user, collateral, debtToken, debtAmountToPay) are the actual values to use
            abi.encodeWithSignature(
                "liquidate(address,address,address,uint256)",
                user, // The user to liquidate
                collateral, // The collateral token to seize
                debtToken, // The debt token to repay
                debtAmountToPay // How much debt to repay
            )
        );

        // If the delegatecall failed for any reason, revert the transaction
        // This ensures we don't partially liquidate or leave the system in an inconsistent state
        if (!success) {
            revert Errors.Liquidations__ProtocolLiquidationFailed();
        }
    }

    // Add event for tracking protocol fees
    event ProtocolFeeCollected(address indexed collateralToken, uint256 feeAmount, uint256 bonusShortfall);

    function _calculateMinAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        private
        view
        returns (uint256)
    {
        // Get USD value of input amount
        uint256 valueInUsd = _getUsdValue(tokenIn, amountIn);

        // Allow 2% slippage
        uint256 minValueInUsd = (valueInUsd * 98) / 100;

        // Convert USD value back to token amount using output token's price
        return (minValueInUsd * _getPrecision()) / _getUsdValue(tokenOut, _getPrecision());
    }
}
