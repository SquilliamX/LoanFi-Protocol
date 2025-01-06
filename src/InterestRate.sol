// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Liquidations } from "src/Liquidations.sol";

contract InterestRate is Liquidations {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Liquidations(tokenAddresses, priceFeedAddresses)
    { }

    function updateInterestRewardForLending() public /* onlyOwner */ { }

    function updateInterestRateForBorrowing() public /* onlyOwner */ { }
}
