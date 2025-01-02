// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CoreStorage} from "src/CoreStorage.sol";
import {HealthFactor} from "src/HealthFactor.sol";
import {Inheritance} from "src/Inheritance.sol";
import {InterestRateEngine} from "src/InterestRateEngine.sol";
import {LendingEngine} from "src/LendingEngine.sol";
import {LiquidationEngine} from "src/LiquidationEngine.sol";
import {WithdrawEngine} from "src/WithdrawEngine.sol";
import {BorrowingEngine} from "src/BorrowingEngine.sol";

contract DeployProtocol is Script {
    // Declaring Arrays to store allowed collateral token addresses and their corresponding price feeds
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run()
        external
        returns (
            CoreStorage,
            HealthFactor,
            LendingEngine,
            BorrowingEngine,
            WithdrawEngine,
            InterestRateEngine,
            LiquidationEngine,
            HelperConfig
        )
    {
        // Create new instance of HelperConfig to get network-specific addresses
        // This will either return mock addresses for local testing or real addresses for testnet
        HelperConfig config = new HelperConfig();

        // Get all the network configuration values using the destructuring syntax
        // wethUsdPriceFeed: Price feed for ETH/USD
        // wbtcUsdPriceFeed: Price feed for BTC/USD
        // weth: WETH token address
        // wbtc: WBTC token address
        // deployerKey: Private key for deployment (different for local vs testnet)
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address linkUsdPriceFeed,
            address weth,
            address wbtc,
            address link,
            uint256 deployerKey
        ) = config.activeNetworkConfig();

        // Set up our arrays with the token addresses and their corresponding price feeds
        // Set up arrays
        tokenAddresses[0] = weth;
        tokenAddresses[1] = wbtc;
        tokenAddresses[2] = link;

        priceFeedAddresses[0] = wethUsdPriceFeed;
        priceFeedAddresses[1] = wbtcUsdPriceFeed;
        priceFeedAddresses[2] = linkUsdPriceFeed;

        // Start broadcasting our transactions
        vm.startBroadcast(deployerKey);

        // Deploy contracts
        CoreStorage coreStorage = new CoreStorage(tokenAddresses, priceFeedAddresses);
        HealthFactor healthFactor = new HealthFactor(tokenAddresses, priceFeedAddresses);
        LendingEngine lendingEngine = new LendingEngine(tokenAddresses, priceFeedAddresses);
        BorrowingEngine borrowingEngine = new BorrowingEngine(tokenAddresses, priceFeedAddresses);
        WithdrawEngine withdrawEngine = new WithdrawEngine(tokenAddresses, priceFeedAddresses);
        LiquidationEngine liquidationEngine = new LiquidationEngine(tokenAddresses, priceFeedAddresses);
        InterestRateEngine interestRateEngine = new InterestRateEngine(tokenAddresses, priceFeedAddresses);

        vm.stopBroadcast();

        return (
            coreStorage,
            healthFactor,
            lendingEngine,
            borrowingEngine,
            withdrawEngine,
            interestRateEngine,
            liquidationEngine,
            config
        );
    }
}
