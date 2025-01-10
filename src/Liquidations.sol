// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Withdraw } from "src/Withdraw.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Liquidations is Withdraw {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Withdraw(tokenAddresses, priceFeedAddresses)
    { }

    /* @notice Liquidates an unhealthy position
     * @param collateral The collateral token address to liquidate
     * @param user The user whose position is being liquidated
     * @param debtAmountToPay The amount of debt to repay
     * @dev This function allows liquidators to repay some of a user's debt and  receive their collateral at a discount (bonus)
     * @dev In events of flash crashes and the user does not have enough collateral to incentivize liquidators, the protocol will liquidate users to cover the losses.
    */
    function liquidate(address collateral, address user, uint256 debtAmountToPay) external nonReentrant {
        _liquidate(collateral, user, debtAmountToPay);
    }

    function _liquidate(
        address collateral,
        address user,
        uint256 debtAmountToPay
    )
        private
        isAllowedToken(collateral)
        moreThanZero(debtAmountToPay)
    {
        // First do all checks that might revert
        // This way we don't waste gas allocating variables if we're going to revert

        // Check for zero address
        if (user == address(0)) {
            revert Errors.ZeroAddressNotAllowed();
        }

        // Prevent users from liquidating themselves
        if (msg.sender == user) {
            revert Errors.Liquidations__CantLiquidateSelf();
        }

        // Verify user has actually borrowed the token being liquidated
        if (_getCollateralBalanceOfUser(user, collateral) == 0) {
            revert Errors.Liquidations__UserHasNoCollateralDeposited();
        }

        // Verify liquidation amount isn't larger than borrowed amount
        if (debtAmountToPay > _getAmountOfTokenBorrowed(user, collateral)) {
            revert Errors.Liquidations__DebtAmountExceedsBorrowedAmount();
        }

        // Verify liquidator has enough tokens to repay the debt
        if (IERC20(collateral).balanceOf(msg.sender) < debtAmountToPay) {
            revert Errors.Liquidations__InsufficientBalanceToLiquidate();
        }

        // Get the user's initial health factor to:
        // 1. Verify they can be liquidated (health factor < MIN_HEALTH_FACTOR)
        // 2. Compare with their final health factor after liquidation
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= _getMinimumHealthFactor()) {
            revert Errors.Liquidations__HealthFactorOk();
        }

        // Local Variables declared in function to save gas as they do not need to persist between function calls.
        address recipient; // Determine who gets the collateral and bonus based on if there's FULL bonus available
        uint256 bonusFromThisCollateral = 0;
        uint256 bonusFromOtherCollateral = 0;

        // gets the amount of tokens the user has of this token deposited in this protocol
        uint256 userCollateralBalance = _getCollateralBalanceOfUser(user, collateral);
        // get the amount this token deposited in this protocol in terms of USD
        uint256 collateralValueInUsd = _getUsdValue(collateral, userCollateralBalance);
        // get the amount of all tokens the user borrowed in USD

        // First convert debt amount to USD
        uint256 debtInUsd = _getUsdValue(collateral, debtAmountToPay);

        // Calculate total bonus needed in USD (10% of debt USD value)
        uint256 totalBonusNeededInUsd = (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();

        // Try to get bonus from this specific collateral first
        // if user's collateral is greater than the debt the liquidator covered, then the difference is available for the 10% for the liquidator
        if (collateralValueInUsd > debtInUsd) {
            uint256 availableForBonus = collateralValueInUsd - debtInUsd;
            // if the difference is greater than what the 10% bonus, then pay the bonus from this collateral
            // if the difference is smaller than the 10% bonus, then take the whole difference for the bonus
            bonusFromThisCollateral =
                (availableForBonus > totalBonusNeededInUsd) ? totalBonusNeededInUsd : availableForBonus;
        }

        // If we couldn't get full bonus from this collateral, try other collateral types
        // total bonus minus the amount we already have for the bonus is the remaining amount of bonus that we need for the liquidator
        uint256 remainingBonusNeeded = totalBonusNeededInUsd - bonusFromThisCollateral;
        // if the remaining Bonus amount needed is greater than 0, then collect the remaining bonus fairly from user's other collateral types
        if (remainingBonusNeeded > 0) {
            bonusFromOtherCollateral = _collectBonusFromOtherCollateral(user, collateral, remainingBonusNeeded);
        }

        // Convert bonus amount to token amounts
        uint256 bonusCollateral = _getTokenAmountFromUsd(collateral, bonusFromThisCollateral);
        // add up all the bonus amounts
        uint256 totalBonusAvailable = bonusFromThisCollateral + bonusFromOtherCollateral;

        uint256 totalCollateralToSeize = debtAmountToPay + bonusCollateral; // Always seize debt + available bonus

        // if the user has enough to pay the bonus (greater than or equal to bonus)
        if (totalBonusAvailable >= totalBonusNeededInUsd) {
            // If full 10% bonus is available, send to liquidator
            recipient = msg.sender;
        } else {
            // If bonus is incomplete, protocol takes both debt amount and any available bonus as a fee
            recipient = address(this);
        }

        // emit event
        emit UserLiquidated(collateral, user, debtAmountToPay);

        // Withdraw collateral to either liquidator or protocol
        _withdrawCollateral(collateral, totalCollateralToSeize, user, recipient);

        // Pay back the debt
        paybackBorrowedAmount(collateral, debtAmountToPay, user);

        // Verify health factors
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert Errors.Liquidations__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // Helper function to collect bonus from other collateral types
    function _collectBonusFromOtherCollateral(
        address user,
        address excludedCollateral,
        uint256 bonusNeededInUsd
    )
        private
        returns (uint256 bonusCollectedInUsd)
    {
        // get total collateral value
        uint256 totalAvailableCollateralInUsd = getAccountCollateralValueInUsd(user);

        // Subtract the excluded collateral's value
        uint256 excludedCollateralValue =
            _getUsdValue(excludedCollateral, _getCollateralBalanceOfUser(user, excludedCollateral));
        totalAvailableCollateralInUsd -= excludedCollateralValue;

        // If no collateral available, return 0
        if (totalAvailableCollateralInUsd == 0) return 0;

        // Second pass: Take proportional amount from each collateral type
        for (uint256 i = 0; i < _getAllowedTokens().length; i++) {
            address token = _getAllowedTokens()[i];
            if (token == excludedCollateral) continue;

            uint256 userBalance = _getCollateralBalanceOfUser(user, token);
            if (userBalance == 0) continue;

            uint256 collateralValueInUsd = _getUsdValue(token, userBalance);

            // Calculate proportional bonus to take from this collateral
            // If this collateral is 30% of user's total collateral value(exlcuding crashed token), it provides 30% of the bonus paid.
            // Each token contributes proportionally to its share of the total collateral
            // The total bonus collected will equal the needed amount
            // No single token type is unfairly drained first
            uint256 bonusToTakeInUsd = (bonusNeededInUsd * collateralValueInUsd) / totalAvailableCollateralInUsd;

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
}
