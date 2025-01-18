// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { MockV3Aggregator } from "../test/mocks/MockV3Aggregator.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { SwapLiquidatedTokens } from "src/SwapLiquidatedTokens.sol";

contract HelperConfig is Script {
    // Define structs to hold all our network configuration data. We need to break up the structs because of stack too deep errors.
    // This makes it easier to pass around network-specific addresses
    struct PriceFeeds {
        address wethUsdPriceFeed; // Price feed for ETH/USD
        address wbtcUsdPriceFeed; // Price feed for BTC/USD
        address linkUsdPriceFeed; // Price feed for LINK/USD
    }

    struct Tokens {
        address weth; // WETH token address
        address wbtc; // WBTC token address
        address link; // Link token address
    }

    struct AutomationConfig {
        uint256 deployerKey; // Private key for deployment
        address swapRouter; // Uniswap V3 Router
        address automationRegistry; // Chainlink Automation Registry
        uint256 upkeepId; // Chainlink Upkeep ID
    }

    struct NetworkConfig {
        PriceFeeds priceFeeds;
        Tokens tokens;
        AutomationConfig automationConfig;
    }

    PriceFeeds public priceFeeds;
    Tokens public tokens;
    AutomationConfig public automationConfig;

    // Constants for mock price feed configuration
    uint8 public constant DECIMALS = 8; // Chainlink price feeds use 8 decimals
    int256 public constant WETH_USD_PRICE = 2000e8; // Mock ETH price of $2000
    int256 public constant BTC_USD_PRICE = 30_000e8; // Mock BTC price of $30000
    int256 public constant LINK_USD_PRICE = 10e8; // Mock Link price of $10
    uint256 public constant INITIAL_BALANCE = 1000e8; // Initial balance for mock tokens

    // Default private key for local testing (Anvil's first private key)
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // Store the active network configuration
    NetworkConfig public activeNetworkConfig;

    // Constructor determines which network config to use based on chainId
    constructor() {
        // If we're on Sepolia testnet
        if (block.chainid == 11_155_111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            // For any other network (local, mainnet, etc)
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    // Returns configuration for Sepolia testnet with real contract addresses
    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            priceFeeds: PriceFeeds({
                // pircefeeds on Sepolia
                wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
                linkUsdPriceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF
            }),
            tokens: Tokens({
                // token addresses on sepolia
                weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
                wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            }),
            automationConfig: AutomationConfig({
                // addresses for key components on sepolia
                deployerKey: vm.envUint("PRIVATE_KEY"),
                swapRouter: 0xb41b78Ce3D1BDEDE48A3d303eD2564F6d1F6fff0, //?? may need to change
                automationRegistry: 0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2,
                upkeepId: vm.envUint("UPKEEP_ID")
            })
        });
    }

    // Returns or creates configuration for local testing with mock contracts
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // If config already exists, return it
        if (activeNetworkConfig.priceFeeds.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        // Start broadcasting transactions for mock deployment
        vm.startBroadcast();

        // Deploy mock price feeds and tokens
        MockV3Aggregator wethUsdPriceFeed = new MockV3Aggregator(DECIMALS, WETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock();

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock();

        MockV3Aggregator linkUsdPriceFeed = new MockV3Aggregator(DECIMALS, LINK_USD_PRICE);
        ERC20Mock linkMock = new ERC20Mock();

        // Deploy mock SwapRouter for local testing
        SwapLiquidatedTokens swapRouter = new SwapLiquidatedTokens(address(0));

        vm.stopBroadcast();

        // Return config with mock addresses
        return NetworkConfig({
            priceFeeds: PriceFeeds({
                wethUsdPriceFeed: address(wethUsdPriceFeed),
                wbtcUsdPriceFeed: address(btcUsdPriceFeed),
                linkUsdPriceFeed: address(linkUsdPriceFeed)
            }),
            tokens: Tokens({ weth: address(wethMock), wbtc: address(wbtcMock), link: address(linkMock) }),
            automationConfig: AutomationConfig({
                deployerKey: DEFAULT_ANVIL_KEY,
                swapRouter: address(swapRouter), // Use the deployed mock SwapRouter
                automationRegistry: address(0),
                upkeepId: 0
            })
        });
    }
}
