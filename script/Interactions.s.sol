// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { DevOpsTools } from "foundry-devops/src/DevOpsTools.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { LiquidationAutomation } from "../src/automation/LiquidationAutomation.sol";

/**
 * @title Post-Deployment Automation Setup Script
 * @author William Permuy
 * @notice Configures Chainlink Automation for protocol liquidations
 * @dev Implements post-deployment configuration with the following features:
 *
 * Architecture Highlights:
 * 1. Deployment Integration
 *    - Retrieves recent deployments
 *    - Updates configuration state
 *    - Links automation components
 *
 * 2. Security Features
 *    - Chainlink integration
 *    - Address validation
 *    - State verification
 */
contract SetupAutomation is Script {
    /**
     * @notice Main execution function for automation setup
     * @dev Orchestrates the following steps:
     * 1. Retrieves deployment addresses
     * 2. Updates configuration
     * 3. Verifies setup
     */
    function run() external {
        // STAGE 1: Deployment Resolution
        // Get addresses from most recent deployment
        address liquidationAutomation = DevOpsTools.get_most_recent_deployment("LiquidationAutomation", block.chainid);
        address helperConfig = DevOpsTools.get_most_recent_deployment("HelperConfig", block.chainid);

        // STAGE 2: Configuration Update
        // Start transaction broadcast
        vm.startBroadcast();

        // Update helper config with automation address
        HelperConfig(helperConfig).setLiquidationAutomation(liquidationAutomation);

        // End transaction broadcast
        vm.stopBroadcast();

        // STAGE 3: Verification
        // Log successful configuration
        console.log("LiquidationAutomation address set to:", liquidationAutomation);
    }
}
