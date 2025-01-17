// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Withdraw } from "./Withdraw.sol";
import { LiquidationEngine } from "./Liquidation-Operations/LiquidationEngine.sol";
import { Errors } from "./libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LoanFi is Withdraw {
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
    {
        liquidationEngine = new LiquidationEngine(address(this), swapRouter, automationRegistry, upkeepId);
    }

    // Delegate liquidation calls to LiquidationEngine
    function liquidate(address user, address collateral, address debtToken, uint256 debtAmountToPay) external {
        liquidationEngine.liquidate(msg.sender, user, collateral, debtToken, debtAmountToPay);
    }

    // payback and withdraw

    // deposit and borrow

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

    function liquidationDecreaseDebt(
        address token,
        uint256 amount,
        address user,
        address payer
    )
        external
        OnlyLiquidationEngine
    {
        // First decrease the debt (state change)
        decreaseUserDebtAndTotalDebtBorrowed(user, token, amount);

        // Then collect the payment
        bool success = IERC20(token).transferFrom(payer, address(this), amount);
        if (!success) {
            revert Errors.TransferFailed();
        }
    }
}
