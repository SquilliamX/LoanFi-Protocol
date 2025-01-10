// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { InterestRate } from "src/InterestRate.sol";

contract LoanFi is InterestRate {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        InterestRate(tokenAddresses, priceFeedAddresses)
    { }

    // Shared Functions

    // deposit and borrow

    // payback and withdraw (should probaly be in borrow.sol)

    //
}
