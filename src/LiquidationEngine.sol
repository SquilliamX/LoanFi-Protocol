// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Helpers} from "./Helpers.sol";

contract LiquidationEngine is Helpers {
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses)
        Helpers(tokenAddresses, priceFeedAddresses)
    {}
}
