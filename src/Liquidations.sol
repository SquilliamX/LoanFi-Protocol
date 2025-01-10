// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Withdraw } from "src/Withdraw.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Liquidations is Withdraw {
    struct BonusParams {
        address collateral;
        address user;
        uint256 bonusFromThisCollateral;
        uint256 bonusFromOtherCollateral;
        uint256 debtAmountToPay;
    }

    struct TransferParams {
        address collateral;
        address user;
        address recipient;
        uint256 debtAmountToPay;
        uint256 totalCollateralToSeize;
    }

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
        // First do all validation checks
        _validateLiquidation(collateral, user, debtAmountToPay);

        // Check health factor
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= _getMinimumHealthFactor()) {
            revert Errors.Liquidations__HealthFactorOk();
        }

        // Handle bonus calculation and transfers
        _handleLiquidation(collateral, user, debtAmountToPay);

        // Verify health factors after liquidation
        _verifyHealthFactorAfterLiquidation(user, startingUserHealthFactor);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _handleLiquidation(address collateral, address user, uint256 debtAmountToPay) private {
        // Calculate bonuses
        (uint256 bonusFromThisCollateral, uint256 bonusFromOtherCollateral) =
            _calculateBonuses(collateral, user, debtAmountToPay);

        // Handle distribution and transfers
        _handleDistributionAndTransfers(
            collateral, user, debtAmountToPay, bonusFromThisCollateral, bonusFromOtherCollateral
        );

        emit UserLiquidated(collateral, user, debtAmountToPay);
    }

    function _calculateBonuses(
        address collateral,
        address user,
        uint256 debtAmountToPay
    )
        private
        returns (uint256 bonusFromThisCollateral, uint256 bonusFromOtherCollateral)
    {
        uint256 debtInUsd = _getUsdValue(collateral, debtAmountToPay);
        uint256 userCollateralBalance = _getCollateralBalanceOfUser(user, collateral);
        uint256 collateralValueInUsd = _getUsdValue(collateral, userCollateralBalance);
        uint256 totalBonusNeededInUsd = (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();

        bonusFromThisCollateral = _calculateBonusAmounts(debtInUsd, collateralValueInUsd);
        bonusFromOtherCollateral =
            _collectBonusFromOtherCollateral(user, collateral, totalBonusNeededInUsd - bonusFromThisCollateral);

        return (bonusFromThisCollateral, bonusFromOtherCollateral);
    }

    function _handleDistributionAndTransfers(
        address collateral,
        address user,
        uint256 debtAmountToPay,
        uint256 bonusFromThisCollateral,
        uint256 bonusFromOtherCollateral
    )
        private
    {
        BonusParams memory bonusParams = BonusParams({
            collateral: collateral,
            user: user,
            bonusFromThisCollateral: bonusFromThisCollateral,
            bonusFromOtherCollateral: bonusFromOtherCollateral,
            debtAmountToPay: debtAmountToPay
        });

        (address recipient, uint256 totalCollateralToSeize) = _handleBonusDistribution(bonusParams);

        TransferParams memory transferParams = TransferParams({
            collateral: collateral,
            user: user,
            recipient: recipient,
            debtAmountToPay: debtAmountToPay,
            totalCollateralToSeize: totalCollateralToSeize
        });

        _executeTransfers(transferParams);
    }

    function _validateLiquidation(address collateral, address user, uint256 debtAmountToPay) private view {
        if (user == address(0)) {
            revert Errors.ZeroAddressNotAllowed();
        }
        if (msg.sender == user) {
            revert Errors.Liquidations__CantLiquidateSelf();
        }
        if (_getCollateralBalanceOfUser(user, collateral) == 0) {
            revert Errors.Liquidations__UserHasNoCollateralDeposited();
        }
        if (debtAmountToPay > _getAmountOfTokenBorrowed(user, collateral)) {
            revert Errors.Liquidations__DebtAmountExceedsBorrowedAmount();
        }
        if (IERC20(collateral).balanceOf(msg.sender) < debtAmountToPay) {
            revert Errors.Liquidations__InsufficientBalanceToLiquidate();
        }
    }

    function _calculateBonusAmounts(
        uint256 debtInUsd,
        uint256 collateralValueInUsd
    )
        private
        pure
        returns (uint256 bonusFromThisCollateral)
    {
        uint256 totalBonusNeededInUsd = (debtInUsd * _getLiquidationBonus()) / _getLiquidationPrecision();

        if (collateralValueInUsd > debtInUsd) {
            uint256 availableForBonus = collateralValueInUsd - debtInUsd;
            bonusFromThisCollateral =
                (availableForBonus > totalBonusNeededInUsd) ? totalBonusNeededInUsd : availableForBonus;
        }
        return bonusFromThisCollateral;
    }

    function _handleBonusDistribution(BonusParams memory params)
        private
        view
        returns (address recipient, uint256 totalCollateralToSeize)
    {
        uint256 bonusCollateral = _getTokenAmountFromUsd(params.collateral, params.bonusFromThisCollateral);
        uint256 totalBonusAvailable = params.bonusFromThisCollateral + params.bonusFromOtherCollateral;
        uint256 totalBonusNeededInUsd = (
            _getUsdValue(params.collateral, params.debtAmountToPay) * _getLiquidationBonus()
        ) / _getLiquidationPrecision();

        totalCollateralToSeize = params.debtAmountToPay + bonusCollateral;
        recipient = _determineRecipient(totalBonusAvailable, totalBonusNeededInUsd);

        return (recipient, totalCollateralToSeize);
    }

    function _executeTransfers(TransferParams memory params) private {
        _withdrawCollateral(params.collateral, params.totalCollateralToSeize, params.user, params.recipient);
        paybackBorrowedAmount(params.collateral, params.debtAmountToPay, params.user);
    }

    function _verifyHealthFactorAfterLiquidation(address user, uint256 startingUserHealthFactor) private view {
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert Errors.Liquidations__HealthFactorNotImproved();
        }
    }

    function _collectBonusFromOtherCollateral(
        address user,
        address excludedCollateral,
        uint256 bonusNeededInUsd
    )
        private
        returns (uint256 bonusCollectedInUsd)
    {
        uint256 totalAvailableCollateralInUsd = getAccountCollateralValueInUsd(user);
        uint256 excludedCollateralValue =
            _getUsdValue(excludedCollateral, _getCollateralBalanceOfUser(user, excludedCollateral));
        totalAvailableCollateralInUsd -= excludedCollateralValue;

        if (totalAvailableCollateralInUsd == 0) return 0;

        for (uint256 i = 0; i < _getAllowedTokens().length; i++) {
            address token = _getAllowedTokens()[i];
            if (token == excludedCollateral) continue;

            uint256 userBalance = _getCollateralBalanceOfUser(user, token);
            if (userBalance == 0) continue;

            uint256 collateralValueInUsd = _getUsdValue(token, userBalance);
            uint256 bonusToTakeInUsd =
                _calculateProportionalBonus(collateralValueInUsd, totalAvailableCollateralInUsd, bonusNeededInUsd);

            uint256 tokenAmountToTake = _getTokenAmountFromUsd(token, bonusToTakeInUsd);
            if (tokenAmountToTake > userBalance) {
                tokenAmountToTake = userBalance;
                bonusToTakeInUsd = _getUsdValue(token, tokenAmountToTake);
            }

            if (tokenAmountToTake > 0) {
                _withdrawCollateral(token, tokenAmountToTake, user, address(this));
                bonusCollectedInUsd += bonusToTakeInUsd;
            }
        }
        return bonusCollectedInUsd;
    }

    function _calculateProportionalBonus(
        uint256 collateralValueInUsd,
        uint256 totalAvailableCollateralInUsd,
        uint256 bonusNeededInUsd
    )
        private
        pure
        returns (uint256)
    {
        return (bonusNeededInUsd * collateralValueInUsd) / totalAvailableCollateralInUsd;
    }

    function _determineRecipient(
        uint256 totalBonusAvailable,
        uint256 totalBonusNeededInUsd
    )
        private
        view
        returns (address)
    {
        if (totalBonusAvailable >= totalBonusNeededInUsd) {
            return msg.sender;
        }
        return address(this);
    }
}
