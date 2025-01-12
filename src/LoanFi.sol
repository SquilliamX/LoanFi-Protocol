// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { InterestRate } from "src/InterestRate.sol";

contract LoanFi is InterestRate {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address swapRouter,
        address automationRegistry,
        uint256 upkeepId
    )
        InterestRate(tokenAddresses, priceFeedAddresses, swapRouter, automationRegistry, upkeepId)
    { }

    // Shared Functions

    // deposit and borrow

    // payback and withdraw
}
