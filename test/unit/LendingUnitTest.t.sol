// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BorrowingEngine} from "../../src/BorrowingEngine.sol";
import {HealthFactor} from "../../src/HealthFactor.sol";
import {CoreStorage} from "../../src/CoreStorage.sol";
import {Inheritance} from "../../src/Inheritance.sol";
import {InterestRateEngine} from "../../src/InterestRateEngine.sol";
import {LendingEngine} from "../../src/LendingEngine.sol";
import {LiquidationEngine} from "../../src/LiquidationEngine.sol";
import {WithdrawEngine} from "../../src/WithdrawEngine.sol";
import {MockERC20} from "lib/openzeppelin-contracts/lib/forge-std/src/mocks/MockERC20.sol";
import {MockV3Aggregator} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract LendingUnitTest is Test {
    // Main contracts
    BorrowingEngine public borrowingEngine;
    LendingEngine public lendingEngine;
    WithdrawEngine public withdrawEngine;
    InterestRateEngine public interestRateEngine;
    LiquidationEngine public liquidationEngine;
    CoreStorage public coreStorage;

    // Mock tokens
    MockERC20 public weth;
    MockERC20 public wbtc;
    MockERC20 public usdc;

    // Mock price feeds
    MockV3Aggregator public wethUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    MockV3Aggregator public usdcUsdPriceFeed;

    // Test accounts
    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");

    // Constants for testing
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 30000e8;
    int256 public constant USDC_USD_PRICE = 1e8;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant DEPOSIT_AMOUNT = 5 ether;

    function setUp() external {
        // Deploy mock tokens with initialize instead of constructor
        weth = new MockERC20();
        weth.initialize("Wrapped Ether", "WETH", 18);
        wbtc = new MockERC20();
        wbtc.initialize("Wrapped Bitcoin", "WBTC", 18);
        usdc = new MockERC20();
        usdc.initialize("USD Coin", "USDC", 18);

        // Mint tokens to this contract first
        weth.mint(address(this), STARTING_ERC20_BALANCE);
        wbtc.mint(address(this), STARTING_ERC20_BALANCE);
        usdc.mint(address(this), STARTING_ERC20_BALANCE);

        // Deploy mock price feeds
        wethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        wbtcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        usdcUsdPriceFeed = new MockV3Aggregator(DECIMALS, USDC_USD_PRICE);

        // Create arrays for constructor
        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = address(weth);
        tokenAddresses[1] = address(wbtc);
        tokenAddresses[2] = address(usdc);

        address[] memory priceFeedAddresses = new address[](3);
        priceFeedAddresses[0] = address(wethUsdPriceFeed);
        priceFeedAddresses[1] = address(wbtcUsdPriceFeed);
        priceFeedAddresses[2] = address(usdcUsdPriceFeed);

        // Deploy main contracts
        borrowingEngine = new BorrowingEngine(tokenAddresses, priceFeedAddresses);
        lendingEngine = new LendingEngine(tokenAddresses, priceFeedAddresses);
        withdrawEngine = new WithdrawEngine(tokenAddresses, priceFeedAddresses);
        interestRateEngine = new InterestRateEngine(tokenAddresses, priceFeedAddresses);
        liquidationEngine = new LiquidationEngine(tokenAddresses, priceFeedAddresses);
        coreStorage = new CoreStorage(tokenAddresses, priceFeedAddresses);

        // Fund user with ETH and tokens
        vm.deal(USER, STARTING_USER_BALANCE);

        // Transfer tokens to USER
        weth.mint(USER, STARTING_ERC20_BALANCE);
        wbtc.mint(USER, STARTING_ERC20_BALANCE);
        usdc.mint(USER, STARTING_ERC20_BALANCE);

        // Label addresses for better trace output
        vm.label(address(weth), "WETH");
        vm.label(address(wbtc), "WBTC");
        vm.label(address(usdc), "USDC");
        vm.label(USER, "USER");
        vm.label(LIQUIDATOR, "LIQUIDATOR");
    }

    function testDepositWorks() public {
        vm.prank(USER);
        lendingEngine.depositCollateral(address(wethUsdPriceFeed), DEPOSIT_AMOUNT);

        uint256 expectedDepositedAmount = 5 ether;
        assertEq(coreStorage.balanceOf(USER), expectedDepositedAmount);
    }
}
