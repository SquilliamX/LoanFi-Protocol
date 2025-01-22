// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Errors } from "../src/libraries/Errors.sol";
import { Script, console } from "forge-std/Script.sol";
import { DevOpsTools } from "foundry-devops/src/DevOpsTools.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { LiquidationAutomation } from "../src/automation/LiquidationAutomation.sol";
import { AutomationRegistryInterface } from
    "@chainlink/contracts/src/v0.8/automation/interfaces/v2_0/AutomationRegistryInterface2_0.sol";
import { LinkTokenInterface } from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/**
 * @title Post-Deployment Automation Setup
 * @author William Permuy
 * @notice Configures Chainlink Automation for protocol liquidations
 * @dev Implements automated liquidation setup with the following features:
 *
 * Architecture Highlights:
 * 1. Chainlink Integration
 *    - Upkeep registration
 *    - LINK token funding
 *    - Email notifications
 *
 * 2. Security Features
 *    - Balance validation
 *    - Address verification
 *    - Error handling
 *
 * 3. Configuration Management
 *    - Network detection
 *    - State synchronization
 *    - Deployment tracking
 */
contract SetupAutomation is Script {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Gas limit for automation tasks
    uint32 private constant AUTOMATION_GAS_LIMIT = 500_000;

    /// @notice Amount of LINK to fund upkeep (5 LINK)
    uint96 private constant AUTOMATION_LINK_FUNDING = 5 * 10 ** 18;

    /// @notice Empty bytes for optional parameters
    bytes private constant EMPTY_BYTES = "";

    /// @notice Check interval in seconds
    uint32 private constant CHECK_INTERVAL = 60;

    /// @notice Admin email for notifications
    string private constant ADMIN_EMAIL = "williampermuy@gmail.com";

    /*//////////////////////////////////////////////////////////////
                             MAIN FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Main execution function for automation setup
     * @dev Orchestrates the complete automation configuration process:
     *
     * Process Flow:
     * 1. Address Retrieval
     *    - Gets deployment addresses
     *    - Validates configurations
     *    - Verifies contracts
     *
     * 2. Automation Setup
     *    - Registers upkeep
     *    - Funds with LINK
     *    - Sets check interval
     *
     * 3. Email Configuration
     *    - Sets admin contact
     *    - Enables notifications
     *    - Configures alerts
     */
    function run() external {
        // Get deployment addresses
        address liquidationAutomation = DevOpsTools.get_most_recent_deployment("LiquidationAutomation", block.chainid);
        address helperConfig = DevOpsTools.get_most_recent_deployment("HelperConfig", block.chainid);

        // Deployment tracking
        console.log("Starting automation setup...");
        console.log("Found LiquidationAutomation at:", liquidationAutomation);
        console.log("Found HelperConfig at:", helperConfig);

        // Validation
        if (liquidationAutomation == address(0)) {
            revert Errors.Automation__LiquidationAutomationNotDeployed();
        }
        if (helperConfig == address(0)) {
            revert Errors.Automation__HelperConfigNotDeployed();
        }

        // Get config data
        HelperConfig config = HelperConfig(helperConfig);
        (
            , // priceFeeds
            HelperConfig.Tokens memory tokens,
            HelperConfig.AutomationConfig memory automationConfig
        ) = config.activeNetworkConfig();

        address registryAddress = automationConfig.automationRegistry;
        address linkToken = tokens.link;
        console.log("Using Registry at:", registryAddress);
        console.log("Using LINK token at:", linkToken);

        /**
         * @dev Process Flow:
         * 1. Check LINK Balance
         * 2. Register Upkeep
         * 3. Fund Upkeep
         * 4. Update Configuration
         */

        // Start transaction broadcast
        vm.startBroadcast();

        // 1. Check LINK balance
        uint256 linkBalance = LinkTokenInterface(linkToken).balanceOf(msg.sender);
        if (linkBalance < AUTOMATION_LINK_FUNDING) {
            revert Errors.Automation__InsufficientLinkBalance(AUTOMATION_LINK_FUNDING, linkBalance);
        }

        // 2. Approve LINK transfer to Registry
        LinkTokenInterface(linkToken).approve(registryAddress, AUTOMATION_LINK_FUNDING);

        // 3. Register new upkeep
        AutomationRegistryInterface registry = AutomationRegistryInterface(registryAddress);

        try registry.registerUpkeep(
            liquidationAutomation, // target contract to monitor
            AUTOMATION_GAS_LIMIT, // gas limit for upkeep
            msg.sender, // admin address (you)
            EMPTY_BYTES, // checkData (empty for now)
            abi.encode(CHECK_INTERVAL, ADMIN_EMAIL) // Set interval and admin email
        ) returns (uint256 upkeepID) {
            console.log("Upkeep registered with ID:", upkeepID);
            console.log("Check interval set to:", CHECK_INTERVAL, "seconds");
            console.log("Admin email set to:", ADMIN_EMAIL);

            // 4. Update the upkeepId in HelperConfig
            config.setUpkeepId(upkeepID);

            // 5. Fund the upkeep
            LinkTokenInterface(linkToken).transferAndCall(
                registryAddress, AUTOMATION_LINK_FUNDING, abi.encode(upkeepID)
            );

            // 6. Update the config with automation contract address
            config.setLiquidationAutomation(liquidationAutomation);

            console.log("Upkeep funded with", AUTOMATION_LINK_FUNDING, "LINK");
            console.log("LiquidationAutomation configured at:", liquidationAutomation);
        } catch {
            revert Errors.Automation__RegistrationFailed();
        }

        vm.stopBroadcast();
    }
}
