// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { Errors } from "src/Errors.sol";
import { HealthFactor } from "src/HealthFactor.sol";
import { InterestRateEngine } from "src/InterestRateEngine.sol";
import { LendingPool } from "src/LendingPool.sol";
import { LiquidationEngine } from "src/LiquidationEngine.sol";
import { WithdrawEngine } from "src/WithdrawEngine.sol";

contract DeployProtocol is Script {
    // struct that holds all of the protocol's contracts
    struct Contracts {
        Errors errors;
        HealthFactor healthFactor;
        LendingPool lendingPool;
        WithdrawEngine withdrawEngine;
        InterestRateEngine interestRateEngine;
        LiquidationEngine liquidationEngine;
        HelperConfig helperConfig;
    }

    // deployerKey changes depending on which network we are one
    uint256 private s_deployerKey;
    // defining the contracts struct as a variable named s_contracts
    Contracts private s_contracts;

    // Declaring Arrays to store allowed collateral token addresses and their corresponding price feeds
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    // main function we call when we deploy the protocol through this script.
    function run() external {
        deployProtocol();
    }

    /*
    * @dev runs deployTokenConfig & deployEngines
    * @dev returns the Contracts struct for integration tests
    */
    function deployProtocol() public returns (Contracts memory) {
        deployTokenConfig();
        deployEngines();
        return s_contracts;
    }

    /*
     * @notice Configures token and price feed addresses for the protocol deployment
     * @dev Initializes HelperConfig and sets up token addresses and their corresponding price feeds
     * @dev This function must be called before deployEngines() as it sets up required configuration
     * @dev The arrays tokenAddresses and priceFeedAddresses are used by all protocol contracts
     */
    function deployTokenConfig() private {
        // Create new instance of HelperConfig to get network-specific addresses through the s_contracts struct variable
        // This will either return mock addresses for local testing or real addresses for testnet
        s_contracts.helperConfig = new HelperConfig();
        // Get all the network configuration values using the destructuring syntax
        (
            // wethUsdPriceFeed: Price feed for ETH/USD
            address wethUsdPriceFeed,
            // wbtcUsdPriceFeed: Price feed for BTC/USD
            address wbtcUsdPriceFeed,
            // linkUsdPriceFeed: price feed for LINK/USD
            address linkUsdPriceFeed,
            // weth: WETH token address
            address weth,
            // wbtc: WBTC token address
            address wbtc,
            // link: LINK token address
            address link,
            // deployerKey: Private key for deployment depending on chain we deploy to
            uint256 _deployerKey
        ) = s_contracts.helperConfig.activeNetworkConfig();

        // set the private key from the helperConfig equal to the private key declared at contract level
        s_deployerKey = _deployerKey;

        // Set up our arrays with the token addresses and their corresponding price feeds
        tokenAddresses = [weth, wbtc, link];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed, linkUsdPriceFeed];
    }

    /*
     * @notice Deploys all core protocol contracts with configured token and price feed addresses
     * @dev Must be called after deployTokenConfig() as it relies on tokenAddresses and priceFeedAddresses being set
     * @dev Uses vm.startBroadcast/stopBroadcast with the deployerKey depending on the chain deployed on
     */
    function deployEngines() private {
        vm.startBroadcast(s_deployerKey);
        s_contracts.errors = new Errors();
        s_contracts.lendingPool = new LendingPool(tokenAddresses, priceFeedAddresses);
        s_contracts.healthFactor =
            new HealthFactor(tokenAddresses, priceFeedAddresses, address(s_contracts.lendingPool));
        s_contracts.withdrawEngine = new WithdrawEngine(tokenAddresses, priceFeedAddresses);
        s_contracts.liquidationEngine = new LiquidationEngine(tokenAddresses, priceFeedAddresses);
        s_contracts.interestRateEngine = new InterestRateEngine(tokenAddresses, priceFeedAddresses);
        vm.stopBroadcast();
    }
}
