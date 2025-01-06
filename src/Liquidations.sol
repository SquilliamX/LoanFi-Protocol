// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Withdraw } from "src/Withdraw.sol";

contract Liquidations is Withdraw {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Withdraw(tokenAddresses, priceFeedAddresses)
    { }
}
