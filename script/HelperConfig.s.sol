// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Script } from "forge-std/Script.sol";
import { MockV3Aggregator } from "../test/mocks/MockV3Aggregator.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { MockTimeSwapRouter } from "@uniswap/v3-periphery/contracts/test/MockTimeSwapRouter.sol";
import { MockSwapRouter } from "../test/mocks/MockSwapRouter.sol";
import { MockAutomationRegistry } from "../test/mocks/MockAutomationRegistry.sol";

/**
 * @title Network Configuration Helper
 * @author William Permuy
 * @notice Manages network-specific configurations for the LoanFi protocol
 * @dev Implements dynamic configuration management with the following features:
 *
 * Architecture Highlights:
 * 1. Network Detection
 *    - Automatic network identification
 *    - Environment-specific settings
 *    - Seamless testing support
 *
 * 2. Mock System
 *    - Local testing infrastructure
 *    - Price feed simulation
 *    - Token emulation
 *
 * 3. Configuration Management
 *    - Centralized address registry
 *    - Price feed coordination
 *    - Automation settings
 */
contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Groups price feed addresses for supported tokens
     * @dev Maintains oracle infrastructure addresses
     * @param wethUsdPriceFeed ETH/USD price feed address
     * @param wbtcUsdPriceFeed BTC/USD price feed address
     * @param linkUsdPriceFeed LINK/USD price feed address
     */
    struct PriceFeeds {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address linkUsdPriceFeed;
    }

    /**
     * @notice Groups token addresses for protocol assets
     * @dev Maintains supported token contract addresses
     * @param weth WETH token address
     * @param wbtc WBTC token address
     * @param link LINK token address
     */
    struct Tokens {
        address weth;
        address wbtc;
        address link;
    }

    /**
     * @notice Groups automation-related configurations
     * @dev Manages Chainlink Automation settings
     * @param swapRouter Uniswap V3 Router address
     * @param automationRegistry Chainlink Registry address
     * @param liquidationAutomation Automation contract address
     */
    struct AutomationConfig {
        address swapRouter;
        address automationRegistry;
        address liquidationAutomation;
    }

    /**
     * @notice Combines all network-specific configurations
     * @dev Main configuration structure for protocol deployment
     * @param priceFeeds Oracle addresses for price data
     * @param tokens Protocol-supported token addresses
     * @param automationConfig Automation system settings
     */
    struct NetworkConfig {
        PriceFeeds priceFeeds;
        Tokens tokens;
        AutomationConfig automationConfig;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    PriceFeeds public priceFeeds;
    Tokens public tokens;
    AutomationConfig public automationConfig;
    NetworkConfig public activeNetworkConfig;

    // Constants
    uint8 public constant DECIMALS = 8;
    int256 public constant WETH_USD_PRICE = 2000e8; // $2,000 Mock WETH Price
    int256 public constant BTC_USD_PRICE = 30_000e8; // $30,000 Mock BTC Price
    int256 public constant LINK_USD_PRICE = 10e8; // $10 Mock Link Price
    uint256 public constant INITIAL_BALANCE = 1000e8; // Mock Token Initial Balance
    address public constant MOCK_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // Uniswap V3 Factory

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes network-specific configuration
     * @dev Automatically detects network and sets appropriate config
     */
    constructor() {
        // If we're on Sepolia testnet
        if (block.chainid == 11_155_111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            // For local network
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates or retrieves local test configuration
     * @dev Deploys mock contracts for local testing
     * @return NetworkConfig Complete test configuration
     */
    function getOrCreateAnvilEthConfig() private returns (NetworkConfig memory) {
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

        // Deploy MockSwapRouter for local testing
        MockSwapRouter mockRouter = new MockSwapRouter();

        // Create registry with LINK token address
        MockAutomationRegistry registry = new MockAutomationRegistry(address(linkMock));

        // Mint tokens to the router for swaps
        wethMock.mint(address(mockRouter), 1_000_000e18);
        wbtcMock.mint(address(mockRouter), 1_000_000e18);
        linkMock.mint(address(mockRouter), 1_000_000e18);

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
                swapRouter: address(mockRouter),
                automationRegistry: address(registry),
                liquidationAutomation: address(0) // Will be set after deployment
             })
        });
    }

    /*//////////////////////////////////////////////////////////////
                         PRIVATE PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Provides Sepolia testnet configuration
     * @dev Returns real contract addresses for testnet deployment
     * @return NetworkConfig Complete network configuration
     */
    function getSepoliaEthConfig() private pure returns (NetworkConfig memory) {
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
                swapRouter: 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E,
                automationRegistry: 0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2,
                liquidationAutomation: address(0) // Will be set after deployment
             })
        });
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves current network name
     * @dev Used for deployment logging and verification
     * @return string Network identifier
     */
    function getNetworkName() external view returns (string memory) {
        if (block.chainid == 11_155_111) return "Sepolia";
        if (block.chainid == 31_337) return "Anvil";
        return "Unknown";
    }
}
