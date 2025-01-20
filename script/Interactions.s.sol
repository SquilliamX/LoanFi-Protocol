// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { DevOpsTools } from "foundry-devops/src/DevOpsTools.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { LiquidationAutomation } from "../src/automation/LiquidationAutomation.sol";

contract SetupAutomation is Script {
    function run() external {
        // Get the most recent deployments
        address liquidationAutomation = DevOpsTools.get_most_recent_deployment("LiquidationAutomation", block.chainid);
        address helperConfig = DevOpsTools.get_most_recent_deployment("HelperConfig", block.chainid);

        // Start broadcast
        vm.startBroadcast();

        // Update the helper config with the automation address
        HelperConfig(helperConfig).setLiquidationAutomation(liquidationAutomation);

        vm.stopBroadcast();

        console.log("LiquidationAutomation address set to:", liquidationAutomation);
    }
}
