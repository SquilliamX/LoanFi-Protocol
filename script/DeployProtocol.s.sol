// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { CoreStorage } from "src/CoreStorage.sol";
import { HealthFactor } from "src/HealthFactor.sol";
import { InterestRate } from "src/InterestRate.sol";
import { Lending } from "src/Lending.sol";
import { Liquidations } from "src/Liquidations.sol";
import { Withdraw } from "src/Withdraw.sol";
import { Borrowing } from "src/Borrowing.sol";

contract DeployProtocol is Script {
    // struct that holds all of the protocol's contracts
    // Only deploy the final contracts in the inheritance chain
    struct Contracts {
        Borrowing borrowing;
        Withdraw withdraw;
        InterestRate interestRate;
        Liquidations liquidations;
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
    * @dev runs deployTokenConfig & deployContracts
    * @dev returns the Contracts struct for integration tests
    */
    function deployProtocol() public returns (Contracts memory) {
        deployTokenConfig();
        deployContracts();
        return s_contracts;
    }

    /*
     * @notice Configures token and price feed addresses for the protocol deployment
     * @dev Initializes HelperConfig and sets up token addresses and their corresponding price feeds
     * @dev This function must be called before deployContracts() as it sets up required configuration
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
    function deployContracts() private {
        vm.startBroadcast(s_deployerKey);
        s_contracts.borrowing = new Borrowing(tokenAddresses, priceFeedAddresses);
        s_contracts.withdraw = new Withdraw(tokenAddresses, priceFeedAddresses);
        s_contracts.liquidations = new Liquidations(tokenAddresses, priceFeedAddresses);
        s_contracts.interestRate = new InterestRate(tokenAddresses, priceFeedAddresses);
        vm.stopBroadcast();
    }
}
