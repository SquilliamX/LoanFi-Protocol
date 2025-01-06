// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { LoanFi } from "src/LoanFi.sol";

contract DeployLoanFi is Script {
    // Only deploy the final contract in the inheritance chain since the final contract in the inheritance chian inherits all functionality and contracts
    LoanFi public loanFi;
    HelperConfig public helperConfig;

    // deployerKey changes depending on which network we are on
    uint256 private s_deployerKey;

    // Declaring Arrays to store allowed collateral token addresses and their corresponding price feeds
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    // main function we call when we deploy the protocol through this script.
    function run() external {
        deployLoanFi();
    }

    /*
    * @dev runs deployTokenConfig & deployContracts
    * @dev returns the Contracts struct for integration tests
    */
    function deployLoanFi() public returns (LoanFi) {
        deployTokenConfig();
        deployContracts();
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
        ) = helperConfig.activeNetworkConfig();

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
        loanFi = new LoanFi(tokenAddresses, priceFeedAddresses);
        vm.stopBroadcast();
    }
}