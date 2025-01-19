// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Withdraw } from "./Withdraw.sol";
import { LiquidationEngine } from "./Liquidation-Operations/LiquidationEngine.sol";
import { Errors } from "./libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract LoanFi is Withdraw, Ownable {
    LiquidationEngine public liquidationEngine;

    modifier OnlyLiquidationEngine() {
        // Only LiquidationEngine can call this
        if (msg.sender != address(liquidationEngine)) {
            revert Errors.LoanFi__OnlyLiquidationEngine();
        }
        _;
    }

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address swapRouter,
        address automationRegistry,
        uint256 upkeepId
    )
        Withdraw(tokenAddresses, priceFeedAddresses)
        Ownable(msg.sender)
    {
        liquidationEngine = new LiquidationEngine(address(this), swapRouter, automationRegistry, upkeepId);
    }

    // Delegate liquidation calls to LiquidationEngine
    function liquidate(address user, address collateral, address debtToken, uint256 debtAmountToPay) external {
        liquidationEngine.liquidate(msg.sender, user, collateral, debtToken, debtAmountToPay);
    }

    // deposit and borrow
    function lendAndBorrow(
        address tokenToLend,
        uint256 amountOfCollateralToSend,
        address tokenToBorrow,
        uint256 amountToBorrow
    )
        external
    {
        depositCollateral(tokenToLend, amountOfCollateralToSend);

        borrowFunds(tokenToBorrow, amountToBorrow);
    }

    // payback and withdraw
    function paybackDebtAndWithdraw(
        address tokenToPayback,
        uint256 amountToPayback,
        address onBehalfOf,
        address collateralDepositedToWithdraw,
        uint256 amountCollateralToWithdraw
    )
        external
    {
        paybackBorrowedAmount(tokenToPayback, amountToPayback, onBehalfOf);

        withdrawCollateral(collateralDepositedToWithdraw, amountCollateralToWithdraw);
    }

    function liquidationWithdrawCollateral(
        address collateral,
        uint256 amount,
        address user,
        address recipient
    )
        external
        OnlyLiquidationEngine
    {
        _withdrawCollateral(collateral, amount, user, recipient);
    }

    function liquidationPaybackBorrowedAmount(
        address token,
        uint256 amount,
        address user,
        address liquidator
    )
        external
        OnlyLiquidationEngine
    {
        // Update state BEFORE external calls (CEI pattern)
        decreaseUserDebtAndTotalDebtBorrowed(user, token, amount);

        // Transfer tokens from liquidator to contract
        bool success = IERC20(token).transferFrom(liquidator, address(this), amount);
        if (!success) {
            revert Errors.TransferFailed();
        }
    }
}
