// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import { IAutomationRegistryInterface } from "src/interfaces/IAutomationRegistryInterface.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockAutomationRegistry {
    address public immutable LINK;

    constructor(address linkToken) {
        LINK = linkToken;
    }

    function addFunds(uint256, /* id */ uint96 amount) external {
        // Mock implementation - just transfer LINK tokens from sender to this contract
        IERC20(LINK).transferFrom(msg.sender, address(this), amount);
    }
}
