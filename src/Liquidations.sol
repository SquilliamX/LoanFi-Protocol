// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Withdraw } from "src/Withdraw.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Liquidations is Withdraw {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Withdraw(tokenAddresses, priceFeedAddresses)
    { }

    function liquidate(address collateral, address user, uint256 debtAmoutToPay) external nonReentrant { }

    function _liquidate(
        address collateral,
        address user,
        uint256 debtAmoutToPay
    )
        private
        isAllowedToken(collateral)
        moreThanZero(debtAmoutToPay)
    {
        // Get the user's initial health factor to:
        // 1. Verify they can be liquidated (health factor < MIN_HEALTH_FACTOR)
        // 2. Compare with their final health factor after liquidation
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= _getMinimumHealthFactor()) {
            revert Errors.Liquidations__HealthFactorOk();
        }

        // Calculate how much collateral to seize based on the debt amount
        // Example: If paying $100 of debt and ETH price is $2000, then tokenAmountFromDebtCovered = 0.05 ETH
        uint256 tokenAmountFromDebtPaid = _getTokenAmountFromUsd(collateral, debtAmoutToPay);

        // Calculate the bonus collateral for the liquidator (incentive for performing liquidation)
        // Example: If LIQUIDATION_BONUS is 10%, then bonusCollateral = 0.005 ETH
        uint256 bonusCollateral = (tokenAmountFromDebtPaid * _getLiquidationBonus()) / _getLiquidationPrecision();

        // Payback the debt from the user's account
        paybackBorrowedAmount(collateral, debtAmoutToPay, user);

        // Seize the collateral from the user plus the bonus and send it to the liquidator
        _withdrawCollateral(collateral, tokenAmountFromDebtPaid + bonusCollateral, user, msg.sender);

        // Verify that the liquidation actually helped (improved the user's health factor)
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert Errors.Liquidations__HealthFactorNotImproved();
        }

        // Make sure the liquidator's health factor is still good after liquidation
        _revertIfHealthFactorIsBroken(msg.sender);
    }
}
