// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Lending } from "src/Lending.sol";

contract InterestRate is Lending {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Lending(tokenAddresses, priceFeedAddresses)
    { }

    function updateInterestRewardForLending() public /* onlyOwner */ { }

    function updateInterestRateForBorrowing() public /* onlyOwner */ { }
}
