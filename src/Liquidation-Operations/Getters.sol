// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILoanFi } from "../interfaces/ILoanFi.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Getters is Ownable {
    ILoanFi internal immutable i_loanFi;

    constructor(address loanFiAddress) Ownable(msg.sender) {
        i_loanFi = ILoanFi(loanFiAddress);
    }

    function _healthFactor(address user) internal view returns (uint256) {
        return i_loanFi.getHealthFactor(user);
    }

    function _getMinimumHealthFactor() internal view returns (uint256) {
        return i_loanFi.getMinimumHealthFactor();
    }

    function _getUsdValue(address token, uint256 amount) internal view returns (uint256) {
        return i_loanFi.getUsdValue(token, amount);
    }

    function _getAllowedTokens() internal view returns (address[] memory) {
        return i_loanFi.getAllowedTokens();
    }

    function _getCollateralBalanceOfUser(address user, address token) internal view returns (uint256) {
        return i_loanFi.getCollateralBalanceOfUser(user, token);
    }

    function _withdrawCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateralToWithdraw,
        address, /* from */
        address /* to */
    )
        internal
    {
        // Remove unused parameters warning by commenting them
        // from and to are handled internally by LoanFi's withdrawCollateral
        i_loanFi.withdrawCollateral(tokenCollateralAddress, amountCollateralToWithdraw);
    }

    function _paybackBorrowedAmount(address tokenToPayBack, uint256 amountToPayBack, address onBehalfOf) internal {
        i_loanFi.paybackBorrowedAmount(tokenToPayBack, amountToPayBack, onBehalfOf);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        i_loanFi.revertIfHealthFactorIsBroken(user);
    }

    function _getAmountOfTokenBorrowed(address user, address token) internal view returns (uint256) {
        return i_loanFi.getAmountOfTokenBorrowed(user, token);
    }

    function _getLiquidationBonus() internal view returns (uint256) {
        return i_loanFi.getLiquidationBonus();
    }

    function _getLiquidationPrecision() internal view returns (uint256) {
        return i_loanFi.getLiquidationPrecision();
    }

    function _getPrecision() internal view returns (uint256) {
        return i_loanFi.getPrecision();
    }

    function _getTokenAmountFromUsd(address token, uint256 usdAmountInWei) internal view returns (uint256) {
        return i_loanFi.getTokenAmountFromUsd(token, usdAmountInWei);
    }

    function _getAccountCollateralValueInUsd(address user) internal view returns (uint256) {
        return i_loanFi.getAccountCollateralValueInUsd(user);
    }

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

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
