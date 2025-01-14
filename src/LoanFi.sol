// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Withdraw } from "./Withdraw.sol";
import { LiquidationEngine } from "./Liquidation-Operations/LiquidationEngine.sol";

contract LoanFi is Withdraw {
    LiquidationEngine public liquidationEngine;

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
        liquidationEngine.liquidate(user, collateral, debtToken, debtAmountToPay);
    }

    // payback and withdraw

    // deposit and borrow
}
