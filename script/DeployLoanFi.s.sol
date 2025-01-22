// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Script, console } from "forge-std/Script.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { LiquidationEngine } from "../src/Liquidation-Operations/LiquidationEngine.sol";
import { LiquidationAutomation } from "../src/automation/LiquidationAutomation.sol";
import { SetupAutomation } from "./Interactions.s.sol";
import { LoanFi } from "../src/LoanFi.sol";

/**
 * @title LoanFi Deployment Script
 * @author William Permuy
 * @notice Script for deploying and configuring the LoanFi lending protocol
 * @dev Implements comprehensive deployment process with the following features:
 *
 * Architecture Highlights:
 * 1. Deployment Phases
 *    - Token configuration setup
 *    - Core contract deployment
 *    - Automation integration
 *    - Post-deployment verification
 *
 * 2. Network Support
 *    - Sepolia testnet deployment
 *    - Local Anvil testing
 *    - Network-specific configurations
 *
 * 3. Security Features
 *    - Deployment verification
 *    - Address validation
 *    - Configuration checks
 */
contract DeployLoanFi is Script {
    // Main contract instances that will be deployed
    LoanFi public loanFi; // Main protocol contract that handles lending, borrowing, and core functionality
    HelperConfig public helperConfig; // Configuration contract that provides network-specific addresses and settings
    LiquidationAutomation public liquidationAutomation; // Contract that interfaces with Chainlink Automation for automated liquidations

    // State variables for network-specific deployment configuration
    address private s_swapRouter; // Address of the Uniswap V3 SwapRouter contract for token swaps during liquidations
    address private s_automationRegistry; // Address of the Chainlink Automation Registry for managing automated liquidations
    uint256 private s_upkeepId; // Unique identifier for the Chainlink Automation upkeep task

    // Declaring Arrays to store allowed collateral token addresses and their corresponding price feeds
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    /**
     * @notice Main entry point for protocol deployment
     * @dev Orchestrates the complete deployment process:
     * 1. Deploys core contracts
     * 2. Sets up automation
     * 3. Verifies deployment
     */
    function run() external {
        deployLoanFi();
    }

    /**
     * @notice Comprehensive deployment function for the LoanFi protocol
     * @dev Executes deployment in sequential phases:
     * 1. Token Configuration
     *    - Sets up supported tokens
     *    - Configures price feeds
     *
     * 2. Contract Deployment
     *    - Deploys LoanFi core
     *    - Sets up liquidation system
     *    - Configures automation
     *
     * 3. Verification
     *    - Validates all deployments
     *    - Checks configurations
     *    - Ensures system readiness
     *
     * @return LoanFi Main protocol contract instance
     */
    function deployLoanFi() public returns (LoanFi) {
        deployTokenConfig();

        console.log("Deploying LoanFi protocol on %s", helperConfig.getNetworkName());
        console.log("Deployer address:", msg.sender);
        console.log("Token configuration deployed");

        deployContracts();
        console.log("Core contracts deployed:");
        console.log("- LoanFi:", address(loanFi));
        console.log("- LiquidationAutomation:", address(liquidationAutomation));

        // Add verification step
        verifyDeployment();
        console.log("Deployment verification completed");

        setupAutomation();
        console.log("Automation setup completed");

        return loanFi;
    }

    /**
     * @notice Configures Chainlink Automation based on network
     * @dev Implements network-specific automation setup:
     * - Live Networks: Full Chainlink integration
     * - Local: Direct configuration for testing
     *
     * Security Features:
     * - Network detection
     * - Proper automation linking
     * - Access control setup
     */
    function setupAutomation() private {
        // Only run SetupAutomation if we're on a real network
        if (block.chainid != 31_337) {
            // 31337 is Anvil's chain ID
            SetupAutomation automationSetup = new SetupAutomation(); // Create new instance of automation setup contract
            automationSetup.run(); // Execute the automation setup process
        } else {
            // For local testing, just set the automation contract in LiquidationEngine
            vm.startBroadcast();
            loanFi.setAutomationContract(address(liquidationAutomation));
            vm.stopBroadcast();
        }
    }

    /**
     * @notice Initializes token and price feed configurations
     * @dev Sets up protocol's supported assets:
     * 1. Token Configuration
     *    - WETH, WBTC, LINK support
     *    - Network-specific addresses
     *
     * 2. Price Feeds
     *    - Chainlink oracle integration
     *    - USD denomination
     *    - Price update frequency
     *
     * 3. Automation Setup
     *    - SwapRouter configuration
     *    - Registry integration
     *    - Upkeep management
     */
    function deployTokenConfig() private {
        // Create new instance of HelperConfig to get network-specific addresses
        // This will either return mock addresses for local testing or real addresses for testnet
        helperConfig = new HelperConfig();

        (
            HelperConfig.PriceFeeds memory priceFeeds,
            HelperConfig.Tokens memory tokens,
            HelperConfig.AutomationConfig memory automationConfig
        ) = helperConfig.activeNetworkConfig();

        // set the private key from the helperConfig equal to the private key declared at contract level
        s_swapRouter = automationConfig.swapRouter;
        s_automationRegistry = automationConfig.automationRegistry;
        s_upkeepId = automationConfig.upkeepId;

        // Set up our arrays with the token addresses and their corresponding price feeds
        tokenAddresses = [tokens.weth, tokens.wbtc, tokens.link];
        priceFeedAddresses = [priceFeeds.wethUsdPriceFeed, priceFeeds.wbtcUsdPriceFeed, priceFeeds.linkUsdPriceFeed];
    }

    /**
     * @notice Deploys core protocol contracts
     * @dev Implements atomic deployment process:
     * 1. Core Protocol
     *    - LoanFi deployment
     *    - Token integration
     *    - Price feed linking
     *
     * 2. Automation System
     *    - LiquidationAutomation setup
     *    - Engine configuration
     *    - System linking
     */
    function deployContracts() private {
        vm.startBroadcast();

        // Deploy main protocol with SwapRouter
        loanFi = new LoanFi(tokenAddresses, priceFeedAddresses, s_swapRouter, s_automationRegistry, s_upkeepId);

        // Deploy automation with LiquidationEngine from LoanFi
        liquidationAutomation = new LiquidationAutomation(address(loanFi.liquidationEngine()));

        vm.stopBroadcast();
    }

    /**
     * @notice Validates deployment success and configuration
     * @dev Implements comprehensive verification:
     * 1. Contract Validation
     *    - Address checks
     *    - Component linking
     *    - State verification
     *
     * 2. Configuration Checks
     *    - Token setup
     *    - Price feed matching
     *    - System readiness
     *
     * @custom:security Uses custom errors for precise failure identification
     */
    function verifyDeployment() private view {
        if (address(loanFi) == address(0)) {
            revert Errors.Deployment__LoanFiDeploymentFailed();
        }
        if (address(liquidationAutomation) == address(0)) {
            revert Errors.Deployment__LiquidationAutomationDeploymentFailed();
        }
        if (address(loanFi.liquidationEngine()) == address(0)) {
            revert Errors.Deployment__LiquidationEngineSetupFailed();
        }
        if (tokenAddresses.length == 0 || priceFeedAddresses.length == 0) {
            revert Errors.Deployment__TokenConfigurationFailed();
        }
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert Errors.Deployment__TokenPriceFeedMismatch();
        }
    }
}
