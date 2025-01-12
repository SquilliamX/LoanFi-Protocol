// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAutomationRegistryInterface {
    function addFunds(uint256 upkeepId, uint96 amount) external;
    function LINK() external view returns (address);
}
