// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IAutomationRegistryInterface
 * @notice Interface for interacting with Chainlink Automation Registry
 * @dev Used for managing upkeep funding and retrieving network-specific LINK addresses
 */
interface IAutomationRegistryInterface {
    /**
     * @notice Adds LINK tokens to fund an upkeep
     * @param upkeepId The ID of the upkeep to fund
     * @param amount The amount of LINK tokens to add
     */
    function addFunds(uint256 upkeepId, uint96 amount) external;

    /**
     * @notice Gets the address of the LINK token used for payments
     * @return address The address of the LINK token contract
     */
    function LINK() external view returns (address);
}
