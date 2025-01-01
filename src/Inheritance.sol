// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HealthFactor} from "./HealthFactor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Inheritance is HealthFactor {
    ///////////////////
    //     Type     //
    //////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses)
        HealthFactor(tokenAddresses, priceFeedAddresses)
    {}
}
