    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Borrowing } from "src/Borrowing.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Withdraw is Borrowing {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Borrowing(tokenAddresses, priceFeedAddresses)
    { }
    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're withdrawing
     * @param amountCollateral: The amount of collateral you're withdrawing
     * @notice This function will withdraw your collateral.
     * @notice If you have borrowed funds, you will not be able to redeem until you pay back borrowed funds
     */

    function withdrawCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        _withdrawCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _withdrawCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateralToWithdraw,
        address from,
        address to
    )
        internal
    {
        // user must have funds deposited to withdraw
        if (_getCollateralBalanceOfUser(from, tokenCollateralAddress) == 0) {
            revert Errors.Withdraw__UserHasCollateralDeposited();
        }
        // user can only withdraw up to the amount he deposited
        if (_getCollateralBalanceOfUser(from, tokenCollateralAddress) < amountCollateralToWithdraw) {
            revert Errors.Withdraw__UserDoesNotHaveThatManyTokens();
        }
        // user must pay back the amount he borrowed before withdraw

        // Decrease the user's collateral balance in our internal accounting
        // This must happen before the transfer to prevent reentrancy attacks
        decreaseUserDebtAndTotalDebtBorrowed(from, tokenCollateralAddress, amountCollateralToWithdraw);

        // Emit event for off-chain tracking and transparency since we are updating state
        emit CollateralWithdrawn(from, to, tokenCollateralAddress, amountCollateralToWithdraw);

        // Transfer the collateral tokens from this contract back to the user
        // Using ERC20's transfer instead of transferFrom since the tokens are already in this contract
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateralToWithdraw);

        // If the transfer fails, revert the transaction
        if (!success) {
            revert Errors.TransferFailed();
        }
    }
}
