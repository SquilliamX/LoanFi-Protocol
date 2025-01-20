// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { LoanFi } from "../src/LoanFi.sol";
import { LiquidationEngine } from "../src/Liquidation-Operations/LiquidationEngine.sol";
import { LiquidationAutomation } from "../src/automation/LiquidationAutomation.sol";
import { SetupAutomation } from "./Interactions.s.sol";

contract DeployLoanFi is Script {
    // Only deploy the final contract in the inheritance chain since the final contract in the inheritance chian inherits all functionality and contracts
    LoanFi public loanFi;
    HelperConfig public helperConfig;
    LiquidationAutomation public liquidationAutomation;

    // deployerKey changes depending on which network we are on
    uint256 private s_deployerKey;
    address private s_swapRouter;
    address private s_automationRegistry;
    uint256 private s_upkeepId;

    // Declaring Arrays to store allowed collateral token addresses and their corresponding price feeds
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    // main function we call when we deploy the protocol through this script.
    function run() external {
        // Deploy contracts
        deployLoanFi();
    }

    /*
    * @dev runs deployTokenConfig & deployContracts
    * @dev returns the Contracts struct for integration tests
    */
    function deployLoanFi() public returns (LoanFi) {
        deployTokenConfig();
        deployContracts();

        // Only run SetupAutomation if we're on a real network
        if (block.chainid != 31_337) {
            // 31337 is Anvil's chain ID
            SetupAutomation setupAutomation = new SetupAutomation();
            setupAutomation.run();
        } else {
            // For local testing, just set the automation contract in LiquidationEngine
            vm.startBroadcast(s_deployerKey);
            loanFi.setAutomationContract(address(liquidationAutomation));
            vm.stopBroadcast();
        }

        return loanFi;
    }

    /*
     * @notice Configures token and price feed addresses for the protocol deployment
     * @dev Initializes HelperConfig and sets up token addresses and their corresponding price feeds
     * @dev This function must be called before deployContracts() as it sets up required configuration
     * @dev The arrays tokenAddresses and priceFeedAddresses are used by all protocol contracts
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
        s_deployerKey = automationConfig.deployerKey;
        s_swapRouter = automationConfig.swapRouter;
        s_automationRegistry = automationConfig.automationRegistry;
        s_upkeepId = automationConfig.upkeepId;

        // Set up our arrays with the token addresses and their corresponding price feeds
        tokenAddresses = [tokens.weth, tokens.wbtc, tokens.link];
        priceFeedAddresses = [priceFeeds.wethUsdPriceFeed, priceFeeds.wbtcUsdPriceFeed, priceFeeds.linkUsdPriceFeed];
    }

    /*
     * @notice Deploys all core protocol contracts with configured token and price feed addresses
     * @dev Must be called after deployTokenConfig() as it relies on tokenAddresses and priceFeedAddresses being set
     * @dev Uses vm.startBroadcast/stopBroadcast with the deployerKey depending on the chain deployed on
     */
    function deployContracts() private {
        vm.startBroadcast(s_deployerKey);

        // Deploy main protocol with SwapRouter
        loanFi = new LoanFi(tokenAddresses, priceFeedAddresses, s_swapRouter, s_automationRegistry, s_upkeepId);

        // Deploy automation with LiquidationEngine from LoanFi
        liquidationAutomation = new LiquidationAutomation(address(loanFi.liquidationEngine()));

        vm.stopBroadcast();
    }
}
