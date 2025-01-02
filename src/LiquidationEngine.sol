// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Inheritance} from "./Inheritance.sol";

contract LiquidationEngine is Inheritance {
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses)
        Inheritance(tokenAddresses, priceFeedAddresses)
    {}
}
