// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { Test, console } from "forge-std/Test.sol";
import { HealthFactor } from "src/HealthFactor.sol";
import { CoreStorage } from "src/CoreStorage.sol";
import { Lending } from "src/Lending.sol";
import { LiquidationEngine } from "src/Liquidation-Operations/LiquidationEngine.sol";
import { LiquidationCore } from "src/Liquidation-Operations/LiquidationCore.sol";
import { Getters } from "src/Liquidation-Operations/Getters.sol";
import { Withdraw } from "src/Withdraw.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeployLoanFi } from "script/DeployLoanFi.s.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";
import { LoanFi } from "src/LoanFi.sol";
import { Errors } from "src/libraries/Errors.sol";
import { MockFailedTransferFrom } from "test/mocks/MockFailedTransferFrom.sol";
import { MockBorrowing } from "test/mocks/MockBorrowing.sol";
import { OracleLib } from "src/libraries/OracleLib.sol";
import { Borrowing } from "src/Borrowing.sol";
import { MockWithdraw } from "test/mocks/MockWithdraw.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { LiquidationAutomation } from "src/automation/LiquidationAutomation.sol";
import { MockAutomationRegistry } from "test/mocks/MockAutomationRegistry.sol";

contract LoanFi_IntegrationsTest is Test {
    LoanFi loanFi;
    HelperConfig helperConfig;
    DeployLoanFi deployLoanFi;

    HelperConfig.PriceFeeds public priceFeeds;
    HelperConfig.Tokens public tokens;
    HelperConfig.AutomationConfig public automationConfig;

    uint256 public constant DEPOSIT_AMOUNT = 5 ether;
    uint256 public constant LINK_AMOUNT_TO_BORROW = 10e18; // $100 USD
    uint256 public constant WETH_AMOUNT_TO_BORROW = 2e18; // $4,000 USD
    uint256 public constant WBTC_AMOUNT_TO_BORROW = 1e18; // $30,000 USD

    address public user = makeAddr("user"); // Address of the USER
    address public liquidator = makeAddr("liquidator"); // Address of the liquidator

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant STARTING_USER_BALANCE = 10 ether; // Initial balance given to test users

    // Arrays for token setup
    address[] public tokenAddresses; // Array to store allowed collateral token addresses
    address[] public feedAddresses; // Array to store corresponding price feed addresses

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    event UserBorrowed(address indexed user, address indexed token, uint256 indexed amount);

    event BorrowedAmountRepaid(
        address indexed payer, address indexed onBehalfOf, address indexed token, uint256 amount
    );

    event CollateralWithdrawn(
        address indexed token, uint256 indexed amount, address indexed WithdrawnFrom, address WithdrawTo
    );

    event UserLiquidated(address indexed collateral, address indexed userLiquidated, uint256 amountOfDebtPaid);

    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    function setUp() external {
        deployLoanFi = new DeployLoanFi(); // Store the deployment instance
        loanFi = deployLoanFi.deployLoanFi();

        helperConfig = deployLoanFi.helperConfig();
        (priceFeeds, tokens, automationConfig) = helperConfig.activeNetworkConfig();

        // Set up arrays with direct struct access
        tokenAddresses = [tokens.weth, tokens.wbtc, tokens.link];
        feedAddresses = [priceFeeds.wethUsdPriceFeed, priceFeeds.wbtcUsdPriceFeed, priceFeeds.linkUsdPriceFeed];

        // If we're on a local Anvil chain (chainId 31337), give our test user some ETH to work with
        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }

        // Mint initial balances of tokens.weth, tokens.wbtc, tokens.link to our test user
        // This allows the user to have tokens to deposit as collateral
        ERC20Mock(tokens.weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(tokens.wbtc).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(tokens.link).mint(user, STARTING_USER_BALANCE);

        ERC20Mock(tokens.weth).mint(liquidator, STARTING_USER_BALANCE);
        ERC20Mock(tokens.wbtc).mint(liquidator, STARTING_USER_BALANCE);
        ERC20Mock(tokens.link).mint(liquidator, STARTING_USER_BALANCE);

        ERC20Mock(tokens.weth).mint(address(loanFi), WETH_AMOUNT_TO_BORROW);
        ERC20Mock(tokens.wbtc).mint(address(loanFi), WBTC_AMOUNT_TO_BORROW);
        ERC20Mock(tokens.link).mint(address(loanFi), LINK_AMOUNT_TO_BORROW);
    }

    //////////////////////////
    //  CoreStorage Tests  //
    /////////////////////////

    /**
     * @notice Tests that the constructor reverts when token and price feed arrays have different lengths
     * @dev This ensures proper initialization of collateral tokens and their price feeds
     * Test sequence:
     * 1. Push tokens.weth to token array
     * 2. Push ETH/USD and BTC/USD to price feed array
     * 3. Attempt to deploy CoreStorage with mismatched arrays
     * 4. Verify it reverts with correct error
     */
    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        // Setup: Create mismatched arrays
        tokenAddresses.push(tokens.weth); // Add only two tokens
        tokenAddresses.push(tokens.wbtc);

        feedAddresses.push(priceFeeds.wethUsdPriceFeed); // Add three price feeds
        feedAddresses.push(priceFeeds.wbtcUsdPriceFeed); // Creating a length mismatch
        feedAddresses.push(priceFeeds.linkUsdPriceFeed);

        // Expect revert when arrays don't match in length
        vm.expectRevert(Errors.CoreStorage__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new CoreStorage(tokenAddresses, feedAddresses);
    }

    function testCoreStorageConstructor() public {
        // Create test arrays
        address[] memory testTokens = new address[](3);
        testTokens[0] = tokens.weth;
        testTokens[1] = tokens.wbtc;
        testTokens[2] = tokens.link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = priceFeeds.wethUsdPriceFeed;
        testFeeds[1] = priceFeeds.wbtcUsdPriceFeed;
        testFeeds[2] = priceFeeds.linkUsdPriceFeed;

        // Deploy new CoreStorage
        CoreStorage coreStorage = new CoreStorage(testTokens, testFeeds);

        // Test initialization
        address[] memory allowedTokens = coreStorage.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], tokens.weth, "First token should be tokens.weth");
        assertEq(allowedTokens[1], tokens.wbtc, "Second token should be tokens.wbtc");
        assertEq(allowedTokens[2], tokens.link, "Third token should be tokens.link");

        // Test price feed mappings
        assertEq(
            coreStorage.getCollateralTokenPriceFeed(tokens.weth),
            priceFeeds.wethUsdPriceFeed,
            "tokens.weth price feed mismatch"
        );
        assertEq(
            coreStorage.getCollateralTokenPriceFeed(tokens.wbtc),
            priceFeeds.wbtcUsdPriceFeed,
            "tokens.wbtc price feed mismatch"
        );
        assertEq(
            coreStorage.getCollateralTokenPriceFeed(tokens.link),
            priceFeeds.linkUsdPriceFeed,
            "tokens.link price feed mismatch"
        );
    }

    function testGetCollateralBalanceOfUser() public UserDeposited {
        uint256 balance = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        assertEq(balance, DEPOSIT_AMOUNT);
    }

    function testGetCollateralTokenPriceFeed() public view {
        // Get the price feed address for tokens.weth token
        address priceFeed = loanFi.getCollateralTokenPriceFeed(tokens.weth);
        // Verify it matches the expected tokens.weth/USD price feed address
        assertEq(priceFeed, priceFeeds.wethUsdPriceFeed);
    }

    // Tests that the array of collateral tokens contains the expected tokens
    function testAllowedTokens() public view {
        // Get the array of allowed collateral tokens
        address[] memory collateralTokens = loanFi.getAllowedTokens();
        // Verify tokens.weth is at index 0 (first and only token in this test)
        assertEq(collateralTokens[0], tokens.weth);
        assertEq(collateralTokens[1], tokens.wbtc);
        assertEq(collateralTokens[2], tokens.link);
    }

    function testAdditionalFeedPrecision() public view {
        uint256 feedPrecision = 1e10;

        uint256 additionalFeedPrecision = loanFi.getAdditionalFeedPrecision();
        assertEq(additionalFeedPrecision, feedPrecision);
    }

    function testLiquidationThreshold() public view {
        uint256 liquidationThreshold = 50;
        uint256 getLiquidationThreshold = loanFi.getLiquidationThreshold();
        assertEq(getLiquidationThreshold, liquidationThreshold);
    }

    function testLiquidationPrecision() public view {
        uint256 liquidationPrecision = 100;
        assertEq(loanFi.getLiquidationPrecision(), liquidationPrecision);
    }

    function testPrecision() public view {
        uint256 presicion = 1e18;
        assertEq(loanFi.getPrecision(), presicion);
    }

    function testGetMinimumHealthFactor() public view {
        uint256 minimumHealthFactor = 1e18;
        assertEq(loanFi.getMinimumHealthFactor(), minimumHealthFactor);
    }

    function testGetLiquidationBonus() public view {
        uint256 liquidationBonus = 10;
        assertEq(loanFi.getLiquidationBonus(), liquidationBonus);
    }

    /**
     * @notice Tests the conversion from token amount to USD value
     * @dev Verifies that getUsdValue correctly calculates USD value based on price feeds
     * Test sequence:
     * 1. Set test amount to 15 ETH
     * 2. With ETH price at $2000 (from mock), expect $30,000
     * 3. Compare actual result with expected value
     */
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18; // 15 ETH
        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUsd = 30_000e18; // $30,000 in USD
        uint256 usdValue = loanFi.getUsdValue(tokens.weth, ethAmount);
        assertEq(usdValue, expectedUsd);
    }

    /**
     * @notice Tests the conversion from USD value to token amount
     * @dev Verifies that getTokenAmountFromUsd correctly calculates token amounts based on price feeds
     * Test sequence:
     * 1. Request conversion of $100 worth of tokens.weth
     * 2. With ETH price at $2000 (from mock), expect 0.05 tokens.weth
     * 3. Compare actual result with expected amount
     */
    function testGetTokenAmountFromUsd() public view {
        // If we want $100 of tokens.weth @ $2000/tokens.weth, that would be 0.05 tokens.weth
        uint256 expectedWeth = 0.05 ether;
        uint256 amountWeth = loanFi.getTokenAmountFromUsd(tokens.weth, 100 ether);
        assertEq(amountWeth, expectedWeth);
    }

    function testGetTotalTokenAmountsBorrowed() public UserDepositedAndBorrowedLink {
        uint256 totalAmountsBorrowed = loanFi.getTotalTokenAmountsBorrowed(tokens.link);
        uint256 expectedAmountBorrowed = 10e18;

        assertEq(totalAmountsBorrowed, expectedAmountBorrowed);
    }

    ///////////////////////////
    //  HealthFactor Tests  //
    //////////////////////////

    // Modifier to set up the test state with collateral deposited and user borrowed tokens.link
    modifier UserDepositedAndBorrowedLink() {
        // Start impersonating the test user
        vm.startPrank(user);
        // Approve the loanFi contract to spend user's tokens.weth
        // User deposits $10,000
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);

        // Deposit collateral and borrow tokens.link in one transaction
        // tokens.link is $10/token, user borrows 10, so thats $100 borrowed
        loanFi.borrowFunds(tokens.link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();
        _;
    }

    modifier LiquidLoanFi() {
        uint256 liquidLinkVaults = 100_000e18;
        uint256 liquidWethVaults = 100_000e18;
        uint256 liquidWbtcVaults = 100_000e18;

        ERC20Mock(tokens.weth).mint(address(loanFi), liquidLinkVaults);
        ERC20Mock(tokens.wbtc).mint(address(loanFi), liquidWbtcVaults);
        ERC20Mock(tokens.link).mint(address(loanFi), liquidLinkVaults);
        _;
    }

    function testHealthFactorConstructor() public {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = tokens.weth;
        testTokens[1] = tokens.wbtc;
        testTokens[2] = tokens.link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = priceFeeds.wethUsdPriceFeed;
        testFeeds[1] = priceFeeds.wbtcUsdPriceFeed;
        testFeeds[2] = priceFeeds.linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        HealthFactor healthFactor = new HealthFactor(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = healthFactor.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], tokens.weth, "First token should be tokens.weth");
        assertEq(allowedTokens[1], tokens.wbtc, "Second token should be tokens.wbtc");
        assertEq(allowedTokens[2], tokens.link, "Third token should be tokens.link");

        // Verify price feed mappings
        assertEq(
            healthFactor.getCollateralTokenPriceFeed(tokens.weth),
            priceFeeds.wethUsdPriceFeed,
            "tokens.weth price feed mismatch"
        );
        assertEq(
            healthFactor.getCollateralTokenPriceFeed(tokens.wbtc),
            priceFeeds.wbtcUsdPriceFeed,
            "tokens.wbtc price feed mismatch"
        );
        assertEq(
            healthFactor.getCollateralTokenPriceFeed(tokens.link),
            priceFeeds.linkUsdPriceFeed,
            "tokens.link price feed mismatch"
        );
    }

    // Tests that the health factor is calculated correctly for a user's position
    function testProperlyReportsHealthFactorWhenUserHasNotBorrowed() public UserDeposited {
        // since the user has not borrowed anything, his health score should be perfect!
        uint256 expectedHealthFactor = type(uint256).max;
        uint256 healthFactor = loanFi.getHealthFactor(user);
        // $0 borrowed with $10,000 collateral at 50% liquidation threshold
        // 10,000 * 0.5 = 5,000
        // 5,000 / 0 = prefect health factor

        // Verify that the calculated health factor matches expected value
        assertEq(healthFactor, expectedHealthFactor);
    }

    // Tests that the health factor is calculated correctly for a user's position
    function testProperlyReportsHealthFactorWhenUserHasBorrowed() public UserDepositedAndBorrowedLink {
        // since the user has borrowed $100, his health score should be 50! anything over 1 is good!
        uint256 expectedHealthFactor = 50e18;
        uint256 healthFactor = loanFi.getHealthFactor(user);
        // $100 borrowed with $10,000 collateral at 50% liquidation threshold
        // 10,000 * 0.5 = 5,000
        // 5,000 / 100 = 50 health factor

        // Verify that the calculated health factor matches expected value
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testUserHealthIsMaxWhenUserHasNotDeposited() public view {
        uint256 expectedHealthFactor = type(uint256).max;
        uint256 healthFactor = loanFi.getHealthFactor(user);

        assertEq(healthFactor, expectedHealthFactor);
    }

    function testGetAccountCollateralValueInUsd() public UserDeposited {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's tokens.weth
        ERC20Mock(tokens.wbtc).approve(address(loanFi), DEPOSIT_AMOUNT);
        ERC20Mock(tokens.link).approve(address(loanFi), DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.wbtc, DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.link, DEPOSIT_AMOUNT);
        vm.stopPrank();

        // user deposited 5tokens.link($10/Token) + 5 tokens.weth($2000/Token) + 5tokens.wbtc($30,000) = $160,050
        uint256 expectedDepositedAmountInUsd = 160_050e18;
        assertEq(loanFi.getAccountCollateralValueInUsd(user), expectedDepositedAmountInUsd);
    }

    function testGetAccountBorrowedValueInUsd() public UserDeposited {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's tokens.weth
        ERC20Mock(tokens.wbtc).approve(address(loanFi), DEPOSIT_AMOUNT);
        ERC20Mock(tokens.link).approve(address(loanFi), DEPOSIT_AMOUNT);
        // user deposited 5tokens.link($10/Token) + 5 tokens.weth($2000/Token) + 5tokens.wbtc($30,000) = $160,050
        loanFi.depositCollateral(tokens.wbtc, DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.link, DEPOSIT_AMOUNT);
        // user borrows $100 in tokens.link
        loanFi.borrowFunds(tokens.link, LINK_AMOUNT_TO_BORROW);
        // user borrows $4,000 in tokens.weth
        loanFi.borrowFunds(tokens.weth, WETH_AMOUNT_TO_BORROW);
        // user borrows $30,000 in tokens.wbtc
        loanFi.borrowFunds(tokens.wbtc, WBTC_AMOUNT_TO_BORROW);
        vm.stopPrank();

        uint256 expectedBorrowedAmountInUsd = 34_100e18;
        assertEq(loanFi.getAccountBorrowedValueInUsd(user), expectedBorrowedAmountInUsd);
    }

    function testGetAccountInformation() public UserDepositedAndBorrowedLink {
        uint256 expectedTotalAmountBorrowed = 100e18;
        uint256 expectedCollateralValueInUsd = 10_000e18;

        (uint256 totalAmountBorrowed, uint256 collateralValueInUsd) = loanFi.getAccountInformation(user);

        assertEq(totalAmountBorrowed, expectedTotalAmountBorrowed);
        assertEq(collateralValueInUsd, expectedCollateralValueInUsd);
    }

    function testRevertIfHealthFactorIsBroken() public UserDeposited LiquidLoanFi {
        uint256 link_amount_borrowed_reverts = 1000e18; // 1000 tokens.link = $10,000
        uint256 expectedHealthFactor = 5e17; // 0.5e18

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Errors.HealthFactor__BreaksHealthFactor.selector, expectedHealthFactor));
        loanFi.borrowFunds(tokens.link, link_amount_borrowed_reverts);
    }

    function testCalculateHealthFactor() public view {
        uint256 totalAmountBorrowed = 100; // $100 USD
        uint256 depositAmountInUsd = 1000; // $1000 USD
        // Health factor is 5 since we Adjust collateral value by liquidation threshold
        uint256 expectedHealthFactor = 5e18;

        // grab and save the returned healthFactor from the function call
        (uint256 healthFactor) = loanFi.calculateHealthFactor(totalAmountBorrowed, depositAmountInUsd);
        // assert the values
        assertEq(healthFactor, expectedHealthFactor);
    }

    // Tests that the health factor can go below 1 when collateral value drops
    function testHealthFactorCanGoBelowOne() public UserDepositedAndBorrowedLink {
        // Set new ETH price to $18 (significant drop from original price)
        int256 wethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        // we need $200 at all times if we have $100 of debt
        // Update the ETH/USD price feed with new lower price
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(wethUsdUpdatedPrice);

        // Get user's new health factor after price drop
        uint256 userHealthFactor = loanFi.getHealthFactor(user);

        // Health factor calculation explanation:
        // 180 (ETH price) * 50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION)
        // / 100 (PRECISION) = 90 / 100 (totalAmountBorrowed) = 0.9

        // Verify health factor is now below 1 (0.45)
        assertEq(userHealthFactor, 45e16); // 0.45 ether
    }

    ///////////////////////////
    //  LendingEngine Tests  //
    //////////////////////////

    function testLendingConstructor() public {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = tokens.weth;
        testTokens[1] = tokens.wbtc;
        testTokens[2] = tokens.link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = priceFeeds.wethUsdPriceFeed;
        testFeeds[1] = priceFeeds.wbtcUsdPriceFeed;
        testFeeds[2] = priceFeeds.linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        Lending lending = new Lending(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = lending.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], tokens.weth, "First token should be tokens.weth");
        assertEq(allowedTokens[1], tokens.wbtc, "Second token should be tokens.wbtc");
        assertEq(allowedTokens[2], tokens.link, "Third token should be tokens.link");

        // Verify price feed mappings
        assertEq(
            lending.getCollateralTokenPriceFeed(tokens.weth),
            priceFeeds.wethUsdPriceFeed,
            "tokens.weth price feed mismatch"
        );
        assertEq(
            lending.getCollateralTokenPriceFeed(tokens.wbtc),
            priceFeeds.wbtcUsdPriceFeed,
            "tokens.wbtc price feed mismatch"
        );
        assertEq(
            lending.getCollateralTokenPriceFeed(tokens.link),
            priceFeeds.linkUsdPriceFeed,
            "tokens.link price feed mismatch"
        );
    }

    // testing deposit function
    function testDepositWorks() public {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's tokens.weth
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        // Deposit the collateral
        loanFi.depositCollateral(address(tokens.weth), DEPOSIT_AMOUNT);
        vm.stopPrank();
        uint256 expectedDepositedAmount = 5 ether;
        assertEq(loanFi.getCollateralBalanceOfUser(user, tokens.weth), expectedDepositedAmount);
    }

    function testDepositRevertsWhenDepositingZero() public {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's tokens.weth
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        vm.expectRevert(Errors.AmountNeedsMoreThanZero.selector);
        // Deposit the collateral
        loanFi.depositCollateral(address(tokens.weth), 0);
        vm.stopPrank();
    }

    function testDepositRevertsWithUnapprovedCollateral() public {
        // Create a new random ERC20 token
        ERC20Mock dogToken = new ERC20Mock("DOG", "DOG", user, 100e18);

        // Start impersonating our test user
        vm.startPrank(user);

        // Expect revert with TokenNotAllowed error when trying to deposit unapproved token
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenNotAllowed.selector, address(dogToken)));
        // Attempt to deposit unapproved token as collateral (this should fail)
        loanFi.depositCollateral(address(dogToken), DEPOSIT_AMOUNT);

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testRevertsIfUserHasLessThanDeposit() public {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's tokens.weth
        ERC20Mock(tokens.weth).approve(address(loanFi), 100 ether);
        vm.expectRevert(abi.encodeWithSelector(Errors.Lending__YouNeedMoreFunds.selector));
        loanFi.depositCollateral(tokens.weth, 100 ether);
        vm.stopPrank();
    }

    modifier UserDeposited() {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's tokens.weth
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testUpdatesUsersBalanceMappingWhenUserDeposits() public UserDeposited {
        assertEq(loanFi.getCollateralBalanceOfUser(user, tokens.weth), DEPOSIT_AMOUNT);
    }

    function testDepositEmitsEventWhenUserDeposits() public {
        // Set up the transaction that will emit the event
        vm.startPrank(user);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        // Set up the event expectation immediately before the emitting call
        vm.expectEmit(true, true, true, false, address(loanFi));
        emit CollateralDeposited(user, tokens.weth, DEPOSIT_AMOUNT);

        // Make the call that should emit the event
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testTokenTransferFromWorksWhenDepositing() public {
        // Record balances before deposit
        uint256 userBalanceBefore = ERC20Mock(tokens.weth).balanceOf(user);
        uint256 contractBalanceBefore = ERC20Mock(tokens.weth).balanceOf(address(loanFi));

        // Prank User and approve deposit
        vm.startPrank(user);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        // Make deposit
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Check balances after deposit
        uint256 userBalanceAfter = ERC20Mock(tokens.weth).balanceOf(user);
        uint256 contractBalanceAfter = ERC20Mock(tokens.weth).balanceOf(address(loanFi));

        // Verify balances changed correctly
        assertEq(userBalanceBefore - userBalanceAfter, DEPOSIT_AMOUNT, "User balance should decrease by deposit amount");
        assertEq(
            contractBalanceAfter - contractBalanceBefore,
            DEPOSIT_AMOUNT,
            "Contract balance should increase by deposit amount"
        );
    }

    function testDepositRevertsOnFailedTransfer() public {
        // Setup - Get the owner's address (msg.sender in this context)
        address owner = msg.sender;

        // Create new mock token contract that will fail transfers, deployed by owner
        vm.prank(owner);
        MockFailedTransferFrom mockDeposit = new MockFailedTransferFrom();

        // Setup array with mock token as only allowed collateral
        tokenAddresses = [address(mockDeposit)];
        // Setup array with tokens.weth price feed for the mock token
        feedAddresses = [priceFeeds.wethUsdPriceFeed];

        // Deploy new LoanFi instance with mock token as allowed collateral
        vm.prank(owner);
        LoanFi mockLoanFi = new LoanFi(
            tokenAddresses,
            feedAddresses,
            address(0), // Mock swap router
            address(0) // Mock automation registry
        );

        // Mint some mock tokens to our test user
        mockDeposit.mint(user, DEPOSIT_AMOUNT);

        // Transfer ownership of mock token to LoanFi
        vm.prank(owner);
        mockDeposit.transferOwnership(address(mockLoanFi));

        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LoanFi to spend user's tokens
        mockDeposit.approve(address(mockLoanFi), DEPOSIT_AMOUNT);

        // Expect the transaction to revert with TransferFailed error
        vm.expectRevert(Errors.TransferFailed.selector);
        // Attempt to deposit collateral (this should fail)
        mockLoanFi.depositCollateral(address(mockDeposit), DEPOSIT_AMOUNT);

        // Stop impersonating the user
        vm.stopPrank();
    }

    /////////////////////////////
    //     Borrowing Tests    //
    ////////////////////////////

    function testBorrowingConstructor() public {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = tokens.weth;
        testTokens[1] = tokens.wbtc;
        testTokens[2] = tokens.link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = priceFeeds.wethUsdPriceFeed;
        testFeeds[1] = priceFeeds.wbtcUsdPriceFeed;
        testFeeds[2] = priceFeeds.linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        Borrowing borrowing = new Borrowing(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = borrowing.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], tokens.weth, "First token should be tokens.weth");
        assertEq(allowedTokens[1], tokens.wbtc, "Second token should be tokens.wbtc");
        assertEq(allowedTokens[2], tokens.link, "Third token should be tokens.link");

        // Verify price feed mappings
        assertEq(
            borrowing.getCollateralTokenPriceFeed(tokens.weth),
            priceFeeds.wethUsdPriceFeed,
            "tokens.weth price feed mismatch"
        );
        assertEq(
            borrowing.getCollateralTokenPriceFeed(tokens.wbtc),
            priceFeeds.wbtcUsdPriceFeed,
            "tokens.wbtc price feed mismatch"
        );
        assertEq(
            borrowing.getCollateralTokenPriceFeed(tokens.link),
            priceFeeds.linkUsdPriceFeed,
            "tokens.link price feed mismatch"
        );
    }

    function testBorrowingWorksProperly() public UserDeposited {
        // get the amount the user borrowed before (which is 0)
        uint256 amountBorrowedBefore = loanFi.getAmountOfTokenBorrowed(user, tokens.link);
        // how much the user should be borrowing
        uint256 expectedAmountBorrowed = 10e18;
        // the next call comes from the user
        vm.prank(user);
        // borrow funds
        loanFi.borrowFunds(tokens.link, LINK_AMOUNT_TO_BORROW);

        // get the amount the user borrowed
        uint256 amountBorrowedAfter = loanFi.getAmountOfTokenBorrowed(user, tokens.link);

        // assert that the amount the user borrowed after the borrow call is more than before
        assert(amountBorrowedAfter > amountBorrowedBefore);
        // assert that the expected amount to borrow is what was borrowed
        assertEq(amountBorrowedAfter, expectedAmountBorrowed);
    }

    function testRevertIfUserBorrowsZero() public UserDeposited {
        uint8 borrowZeroAmount = 0;
        vm.prank(user);
        vm.expectRevert(Errors.AmountNeedsMoreThanZero.selector);
        loanFi.borrowFunds(tokens.link, borrowZeroAmount);
    }

    function testBorrowRevertsWithUnapprovedToken() public UserDeposited {
        // Create a new random ERC20 token
        ERC20Mock dogToken = new ERC20Mock("DOG", "DOG", user, 100e18);

        // Start impersonating our test user
        vm.startPrank(user);

        // Expect revert with TokenNotAllowed error when trying to borrow unapproved token
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenNotAllowed.selector, address(dogToken)));
        // Attempt to borrow unapproved token as collateral (this should fail)
        loanFi.borrowFunds(address(dogToken), LINK_AMOUNT_TO_BORROW);

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testRevertsWhenThereIsNoCollateral() public UserDepositedAndBorrowedLink {
        address otherUser = makeAddr("otherUser");
        ERC20Mock(tokens.weth).mint(otherUser, STARTING_USER_BALANCE);

        // Start impersonating the test user
        vm.startPrank(otherUser);
        // Approve the loanFi contract to spend user's tokens.weth
        // User deposits $10,000
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);

        // test should revert since there is no tokens.link in the contract
        vm.expectRevert(Errors.Borrowing__NotEnoughAvailableCollateral.selector);
        // Deposit collateral and borrow tokens.link
        loanFi.borrowFunds(tokens.link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();

        uint256 actualAmountOfLinkInContract = loanFi.getTotalCollateralOfToken(tokens.link);
        uint256 expectedAmountOfLinkInContract = 0;
        assertEq(actualAmountOfLinkInContract, expectedAmountOfLinkInContract);
    }

    function testRevertsWhenThereIsNotEnoughCollateral() public UserDepositedAndBorrowedLink {
        uint256 twoLinkTokensAvailable = 2e18;
        ERC20Mock(tokens.link).mint(address(loanFi), twoLinkTokensAvailable);

        address otherUser = makeAddr("otherUser");
        ERC20Mock(tokens.weth).mint(otherUser, STARTING_USER_BALANCE);

        // Start impersonating the test user
        vm.startPrank(otherUser);
        // Approve the loanFi contract to spend user's tokens.weth
        // User deposits $10,000
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);

        // test should revert since there is no tokens.link in the contract
        vm.expectRevert(Errors.Borrowing__NotEnoughAvailableCollateral.selector);
        // Deposit collateral and borrow tokens.link
        loanFi.borrowFunds(tokens.link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();

        uint256 actualAmountOfLinkInContract = loanFi.getTotalCollateralOfToken(tokens.link);
        uint256 expectedAmountOfLinkInContract = 2e18;
        assertEq(actualAmountOfLinkInContract, expectedAmountOfLinkInContract);
    }

    function testMappingsAreCorrectlyUpdatedAfterBorrowing() public UserDepositedAndBorrowedLink {
        uint256 amountBorrowed = loanFi.getAmountOfTokenBorrowed(user, tokens.link);
        uint256 expectedAmountBorrowedInMapping = 10e18;

        uint256 amountBorrowedInUsd = loanFi.getAccountBorrowedValueInUsd(user);
        uint256 expectedAmountBorrowedInUsd = 100e18;

        assertEq(amountBorrowed, expectedAmountBorrowedInMapping);
        assertEq(amountBorrowedInUsd, expectedAmountBorrowedInUsd);
    }

    function testBorrowTransfersAreWorkProperly() public UserDeposited {
        uint256 userLinkBalanceBefore = ERC20Mock(tokens.link).balanceOf(user);
        // Start impersonating the test user
        vm.startPrank(user);
        // Approve the loanFi contract to spend user's tokens.weth
        // User deposits $10,000
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);

        // Deposit collateral and borrow tokens.link in one transaction
        // tokens.link is $10/token, user borrows 10, so thats $100 borrowed
        loanFi.borrowFunds(tokens.link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();
        uint256 userLinkBalanceAfter = ERC20Mock(tokens.link).balanceOf(user);

        assert(userLinkBalanceAfter > userLinkBalanceBefore);
        assertEq(
            userLinkBalanceAfter - userLinkBalanceBefore,
            LINK_AMOUNT_TO_BORROW,
            "User should receive borrowed tokens.link tokens"
        );
    }

    function testRevertsIfBorrowTransferFailed() public {
        // Setup - Get the owner's address (msg.sender in this context)
        address owner = msg.sender;

        // Create new mock token contract that will fail transfers, deployed by owner
        vm.prank(owner);
        MockBorrowing mockBorrowing = new MockBorrowing();

        // Setup array with mock token as only allowed collateral
        tokenAddresses = [address(mockBorrowing)];
        // Setup array with tokens.weth price feed for the mock token
        feedAddresses = [priceFeeds.wethUsdPriceFeed];

        // Deploy new LoanFi instance with mock token as allowed collateral
        vm.prank(owner);
        LoanFi mockLoanFi = new LoanFi(
            tokenAddresses,
            feedAddresses,
            address(0), // Mock swap router
            address(0) // Mock automation registry
        );

        // Mint some mock tokens to our test user
        mockBorrowing.mint(user, DEPOSIT_AMOUNT);

        // Transfer ownership of mock token to LoanFi
        vm.prank(owner);
        mockBorrowing.transferOwnership(address(mockLoanFi));

        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LoanFi to spend user's tokens
        mockBorrowing.approve(address(mockLoanFi), DEPOSIT_AMOUNT);

        // deposit collateral
        mockLoanFi.depositCollateral(address(mockBorrowing), DEPOSIT_AMOUNT);

        // Expect the transaction to revert with TransferFailed error
        vm.expectRevert(Errors.TransferFailed.selector);
        mockBorrowing.borrowFunds(tokens.link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();
    }

    function testBorrowingFundsEmitsEvent() public UserDeposited {
        // Set up the transaction that will emit the event
        vm.prank(user);
        // Set up the event expectation immediately before the emitting call
        vm.expectEmit(true, true, true, false, address(loanFi));
        emit UserBorrowed(user, tokens.link, LINK_AMOUNT_TO_BORROW);
        loanFi.borrowFunds(tokens.link, LINK_AMOUNT_TO_BORROW);
    }

    function testPaybackBorrowedAmountWorksProperly() public UserDepositedAndBorrowedLink {
        vm.startPrank(user);
        ERC20Mock(tokens.link).approve(address(loanFi), LINK_AMOUNT_TO_BORROW);

        loanFi.paybackBorrowedAmount(tokens.link, LINK_AMOUNT_TO_BORROW, user);
        vm.stopPrank();

        uint256 amountBorrowedAfterPayingBackDebt = loanFi.getAmountOfTokenBorrowed(user, tokens.link);

        assertEq(amountBorrowedAfterPayingBackDebt, 0, "Debt should be fully paid back");
    }

    function testPaybackBorrowedAmountRevertsIfAmountIsZero() public UserDepositedAndBorrowedLink {
        uint256 amountPaidBackZero = 0;
        vm.prank(user);
        vm.expectRevert(Errors.AmountNeedsMoreThanZero.selector);
        loanFi.paybackBorrowedAmount(tokens.link, amountPaidBackZero, user);
    }

    function testPaybackBorrowedAmountRevertsWithUnapprovedToken() public UserDepositedAndBorrowedLink {
        // Create a new random ERC20 token
        ERC20Mock dogToken = new ERC20Mock("DOG", "DOG", user, 100e18);

        // Start impersonating our test user
        vm.startPrank(user);

        // Expect revert with TokenNotAllowed error when trying to borrow unapproved token
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenNotAllowed.selector, address(dogToken)));
        // Attempt to borrow unapproved token  (this should fail)
        loanFi.paybackBorrowedAmount(address(dogToken), LINK_AMOUNT_TO_BORROW, user);

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testPaybackBorrowedAmountRevertsWithZeroAddress() public UserDepositedAndBorrowedLink {
        // Start impersonating our test user
        vm.startPrank(user);

        // Expect revert with TokenNotAllowed error when trying to deposit unapproved token
        vm.expectRevert(Errors.ZeroAddressNotAllowed.selector);
        // Attempt to payback on behalf of the zero address (this should fail)
        loanFi.paybackBorrowedAmount(tokens.link, LINK_AMOUNT_TO_BORROW, address(0));

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testBorrowing__NotEnoughTokensToPayDebt() public UserDepositedAndBorrowedLink {
        uint256 overpayAmountToPayBack = 10_000e18;

        // Start impersonating our test user
        vm.startPrank(user);

        // Expect revert with Borrowing__NotEnoughTokensToPayDebt error when trying to deposit unapproved token
        vm.expectRevert(Errors.Borrowing__NotEnoughTokensToPayDebt.selector);
        // Attempt to payback too much (this should fail)
        loanFi.paybackBorrowedAmount(tokens.link, overpayAmountToPayBack, user);

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testPaybackBorrowedAmountRevertsWhenUserOverPaysDebt() public UserDepositedAndBorrowedLink {
        uint256 overpayAmountToPayBack = 10_000e18;

        ERC20Mock(tokens.link).mint(user, overpayAmountToPayBack);

        // Start impersonating our test user
        vm.startPrank(user);

        // Expect revert with Borrowing__OverpaidDebt error when trying to deposit unapproved token
        vm.expectRevert(Errors.Borrowing__OverpaidDebt.selector);
        // Attempt to payback too much (this should fail)
        loanFi.paybackBorrowedAmount(tokens.link, overpayAmountToPayBack, user);

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testBorrowedAmountMappingDecreasesWhenUserPayDebts() public UserDepositedAndBorrowedLink {
        uint256 amountBorrowed = loanFi.getAmountOfTokenBorrowed(user, tokens.link);

        vm.startPrank(user);
        ERC20Mock(tokens.link).approve(address(loanFi), LINK_AMOUNT_TO_BORROW);

        loanFi.paybackBorrowedAmount(tokens.link, LINK_AMOUNT_TO_BORROW, user);
        vm.stopPrank();

        uint256 amountBorrowedAfterDebtPaid = loanFi.getAmountOfTokenBorrowed(user, tokens.link);

        assert(amountBorrowed > amountBorrowedAfterDebtPaid);
        assertEq(amountBorrowedAfterDebtPaid, 0);
    }

    function testHealthFactorImprovesAfterRepayment() public UserDepositedAndBorrowedLink {
        uint256 healthFactorWhileBorrowing = loanFi.getHealthFactor(user);

        vm.startPrank(user);
        ERC20Mock(tokens.link).approve(address(loanFi), LINK_AMOUNT_TO_BORROW);

        loanFi.paybackBorrowedAmount(tokens.link, LINK_AMOUNT_TO_BORROW, user);
        vm.stopPrank();

        uint256 healthFactorAfterRepayment = loanFi.getHealthFactor(user);

        uint256 perfectHealthScoreAfterRepayment = type(uint256).max;

        assert(healthFactorWhileBorrowing < healthFactorAfterRepayment);
        assertEq(healthFactorAfterRepayment, perfectHealthScoreAfterRepayment);
    }

    function testUserCanRepayAPortionOfDebtInsteadOfFullDebt() public UserDepositedAndBorrowedLink {
        uint256 amountBorrowedBeforeRepayment = loanFi.getAmountOfTokenBorrowed(user, tokens.link);
        uint256 smallRepayment = 4e18;
        vm.startPrank(user);
        ERC20Mock(tokens.link).approve(address(loanFi), smallRepayment);

        loanFi.paybackBorrowedAmount(tokens.link, smallRepayment, user);
        vm.stopPrank();

        uint256 amountBorrowedAfterRepayment = loanFi.getAmountOfTokenBorrowed(user, tokens.link);
        uint256 expectedDebtLeft = 6e18;

        assert(amountBorrowedBeforeRepayment > amountBorrowedAfterRepayment);
        assertEq(amountBorrowedBeforeRepayment - smallRepayment, expectedDebtLeft);
    }

    function testUsersHealthFactorImprovesAfterPartialRepayment() public UserDepositedAndBorrowedLink {
        uint256 healthFactorBeforeRepayment = loanFi.getHealthFactor(user);
        uint256 smallRepayment = 5e18;
        vm.startPrank(user);
        ERC20Mock(tokens.link).approve(address(loanFi), smallRepayment);

        loanFi.paybackBorrowedAmount(tokens.link, smallRepayment, user);
        vm.stopPrank();
        uint256 healthFactorAfterRepayment = loanFi.getHealthFactor(user);

        uint256 expectedHealthFactor = 100e18;

        assert(healthFactorBeforeRepayment < healthFactorAfterRepayment);
        assertEq(healthFactorAfterRepayment, expectedHealthFactor);
    }

    function testOtherUsersCanRepayOnHalfOfOthers() public UserDepositedAndBorrowedLink {
        uint256 amountToRepay = 10e18;
        // Setup: User2 who will attempt the repayment
        address user2 = makeAddr("user2");
        vm.startPrank(user2);

        ERC20Mock(tokens.link).mint(user2, 100e18);
        ERC20Mock(tokens.link).approve(address(loanFi), amountToRepay);

        loanFi.paybackBorrowedAmount(tokens.link, amountToRepay, user);

        vm.stopPrank();

        assertEq(loanFi.getAmountOfTokenBorrowed(user, tokens.link), 0);
    }

    function testRevertsIfUsersRepaymentFails() public {
        uint256 amountToRepay = 10e18;

        // Setup - Get the owner's address (msg.sender in this context)
        address owner = msg.sender;

        // Create new mock token contract that will fail transfers, deployed by owner
        vm.prank(owner);
        MockBorrowing mockBorrowing = new MockBorrowing();

        // Setup array with mock token as only allowed collateral
        tokenAddresses = [address(mockBorrowing)];
        // Setup array with tokens.weth price feed for the mock token
        feedAddresses = [priceFeeds.wethUsdPriceFeed];

        // Deploy new LoanFi instance with mock token as allowed collateral
        vm.prank(owner);
        LoanFi mockLoanFi = new LoanFi(
            tokenAddresses,
            feedAddresses,
            address(0), // Mock swap router
            address(0) // Mock automation registry
        );

        // Mint some mock tokens to our test user
        mockBorrowing.mint(user, DEPOSIT_AMOUNT);

        // Transfer ownership of mock token to LoanFi
        vm.prank(owner);
        mockBorrowing.transferOwnership(address(mockLoanFi));

        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LoanFi to spend user's tokens
        mockBorrowing.approve(address(mockLoanFi), DEPOSIT_AMOUNT);

        // deposit collateral
        mockLoanFi.depositCollateral(address(mockBorrowing), DEPOSIT_AMOUNT);

        // Try to borrow the mock token
        mockLoanFi.borrowFunds(address(mockBorrowing), WETH_AMOUNT_TO_BORROW);

        // Expect the transaction to revert with TransferFailed error
        vm.expectRevert(Errors.TransferFailed.selector);
        mockBorrowing.paybackBorrowedAmount(address(mockBorrowing), amountToRepay, user);

        vm.stopPrank();
    }

    function testRepaymentEmitsEvent() public UserDepositedAndBorrowedLink {
        uint256 amountToRepay = 10e18;
        vm.startPrank(user);
        ERC20Mock(tokens.link).approve(address(loanFi), amountToRepay);

        vm.expectEmit(true, true, true, true, address(loanFi));
        emit BorrowedAmountRepaid(user, user, tokens.link, amountToRepay);

        loanFi.paybackBorrowedAmount(tokens.link, amountToRepay, user);
        vm.stopPrank();
    }

    function testGetTotalCollateralOfToken() public view {
        uint256 expectedCollateralAmount = 10e18;

        uint256 actualCollateralAmount = loanFi.getTotalCollateralOfToken(tokens.link);

        assertEq(actualCollateralAmount, expectedCollateralAmount);
    }

    function testGetAvailableToBorrow() public view {
        uint256 expectedCollateral = 10e18;
        uint256 actualCollateral = loanFi.getAvailableToBorrow(tokens.link);

        assertEq(actualCollateral, expectedCollateral);
    }

    ///////////////////////////
    //     Withdraw Tests    //
    //////////////////////////

    function testWithdrawConstructor() public {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = tokens.weth;
        testTokens[1] = tokens.wbtc;
        testTokens[2] = tokens.link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = priceFeeds.wethUsdPriceFeed;
        testFeeds[1] = priceFeeds.wbtcUsdPriceFeed;
        testFeeds[2] = priceFeeds.linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        Withdraw withdraw = new Withdraw(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = withdraw.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], tokens.weth, "First token should be tokens.weth");
        assertEq(allowedTokens[1], tokens.wbtc, "Second token should be tokens.wbtc");
        assertEq(allowedTokens[2], tokens.link, "Third token should be tokens.link");

        // Verify price feed mappings
        assertEq(
            withdraw.getCollateralTokenPriceFeed(tokens.weth),
            priceFeeds.wethUsdPriceFeed,
            "tokens.weth price feed mismatch"
        );
        assertEq(
            withdraw.getCollateralTokenPriceFeed(tokens.wbtc),
            priceFeeds.wbtcUsdPriceFeed,
            "tokens.wbtc price feed mismatch"
        );
        assertEq(
            withdraw.getCollateralTokenPriceFeed(tokens.link),
            priceFeeds.linkUsdPriceFeed,
            "tokens.link price feed mismatch"
        );
    }

    modifier UserBorrowedAndRepaidDebt() {
        // Start impersonating the test user
        vm.startPrank(user);
        // Approve the loanFi contract to spend user's tokens.weth
        // User deposits $10,000
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);

        // Deposit collateral and borrow tokens.link in one transaction
        // tokens.link is $10/token, user borrows 10, so thats $100 borrowed
        loanFi.borrowFunds(tokens.link, LINK_AMOUNT_TO_BORROW);
        ERC20Mock(tokens.link).approve(address(loanFi), LINK_AMOUNT_TO_BORROW);

        loanFi.paybackBorrowedAmount(tokens.link, LINK_AMOUNT_TO_BORROW, user);
        // Stop impersonating the user
        vm.stopPrank();
        _;
    }

    function testUserCanDepositAndWithdrawImmediately() public UserDeposited {
        uint256 expectedWithdrawAmount = 5 ether;
        uint256 balanceBeforeWithdrawal = ERC20Mock(tokens.weth).balanceOf(user);
        vm.startPrank(user);

        loanFi.withdrawCollateral(tokens.weth, DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 balanceAfterWithdrawal = ERC20Mock(tokens.weth).balanceOf(user);

        assert(balanceAfterWithdrawal > balanceBeforeWithdrawal);
        assertEq(balanceAfterWithdrawal - balanceBeforeWithdrawal, expectedWithdrawAmount);
    }

    function testWithdrawRevertsIfAmountIsZero() public UserBorrowedAndRepaidDebt {
        uint256 zeroAmountWithdraw = 0;
        vm.startPrank(user);
        vm.expectRevert(Errors.AmountNeedsMoreThanZero.selector);
        loanFi.withdrawCollateral(tokens.weth, zeroAmountWithdraw);
        vm.stopPrank();
    }

    function testRevertsIfTokenIsNotAllowed() public UserBorrowedAndRepaidDebt {
        // Create a new random ERC20 token
        ERC20Mock dogToken = new ERC20Mock("DOG", "DOG", user, 100e18);

        // Start impersonating our test user
        vm.startPrank(user);

        // Expect revert with TokenNotAllowed error when trying to borrow unapproved token
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenNotAllowed.selector, address(dogToken)));
        // Attempt to withdraw unapproved token  (this should fail)
        loanFi.withdrawCollateral(address(dogToken), DEPOSIT_AMOUNT);

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testRevertsWhenWithdrawingFromZeroAddress() public {
        // Try to withdraw from address(0)
        vm.startPrank(address(0));
        vm.expectRevert(Errors.ZeroAddressNotAllowed.selector);
        loanFi.withdrawCollateral(tokens.weth, DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testRevertsIfUserHasNoCollateralDeposited() public {
        vm.startPrank(user);
        vm.expectRevert(Errors.Withdraw__UserHasNoCollateralDeposited.selector);
        loanFi.withdrawCollateral(tokens.weth, DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testRevertsIfUserWithdrawsMoreThanDeposited() public UserBorrowedAndRepaidDebt {
        uint256 moreThanDeposited = 20 ether;
        vm.startPrank(user);
        vm.expectRevert(Errors.Withdraw__UserDoesNotHaveThatManyTokens.selector);
        loanFi.withdrawCollateral(tokens.weth, moreThanDeposited);
        vm.stopPrank();
    }

    function testDecreaseCollateralDepositedWhenWithdrawing() public UserBorrowedAndRepaidDebt {
        uint256 usersCollateralBalanceBeforeWithdraw = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        vm.startPrank(user);

        loanFi.withdrawCollateral(tokens.weth, DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 usersCollateralBalanceAfterWithdraw = loanFi.getCollateralBalanceOfUser(user, tokens.weth);

        assert(usersCollateralBalanceAfterWithdraw < usersCollateralBalanceBeforeWithdraw);

        assertEq(usersCollateralBalanceAfterWithdraw, 0);
    }

    function testWithdrawsEmitEvent() public UserBorrowedAndRepaidDebt {
        vm.startPrank(user);
        vm.expectEmit(true, true, true, false, address(loanFi));
        emit CollateralWithdrawn(tokens.weth, DEPOSIT_AMOUNT, user, user);
        loanFi.withdrawCollateral(tokens.weth, DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testWithdrawCollateralAfterRepayingDebt() public UserBorrowedAndRepaidDebt {
        uint256 expectedWithdrawAmount = 5 ether;
        uint256 balanceBeforeWithdrawal = ERC20Mock(tokens.weth).balanceOf(user);
        vm.startPrank(user);

        loanFi.withdrawCollateral(tokens.weth, DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 balanceAfterWithdrawal = ERC20Mock(tokens.weth).balanceOf(user);

        assert(balanceAfterWithdrawal > balanceBeforeWithdrawal);
        assertEq(balanceAfterWithdrawal - balanceBeforeWithdrawal, expectedWithdrawAmount);
    }

    function testRevertsIfWithdrawFails() public {
        // Setup - Get the owner's address (msg.sender in this context)
        address owner = msg.sender;

        // Create new mock token contract that will fail transfers, deployed by owner
        vm.prank(owner);
        MockWithdraw mockWithdraw = new MockWithdraw();

        // Setup array with mock token as only allowed collateral
        tokenAddresses = [address(mockWithdraw)];
        // Setup array with tokens.weth price feed for the mock token
        feedAddresses = [priceFeeds.wethUsdPriceFeed];

        // Deploy new LoanFi instance with mock token as allowed collateral
        vm.prank(owner);
        LoanFi mockLoanFi = new LoanFi(
            tokenAddresses,
            feedAddresses,
            address(0), // Mock swap router
            address(0) // Mock automation registry
        );

        // Mint some mock tokens to our test user
        mockWithdraw.mint(user, DEPOSIT_AMOUNT);

        // Transfer ownership of mock token to LoanFi
        vm.prank(owner);
        mockWithdraw.transferOwnership(address(mockLoanFi));

        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LoanFi to spend user's tokens
        mockWithdraw.approve(address(mockLoanFi), DEPOSIT_AMOUNT);

        // deposit collateral
        mockLoanFi.depositCollateral(address(mockWithdraw), DEPOSIT_AMOUNT);

        // Expect the transaction to revert with TransferFailed error
        vm.expectRevert(Errors.TransferFailed.selector);
        mockWithdraw.withdrawCollateral(tokens.link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();
    }

    function testRevertsIfWithdrawBreaksHealthFactor() public LiquidLoanFi {
        uint256 amountToBorrow = 500e18;
        uint256 thisWithdrawAmountBreaksHealthFactor = 1 ether;
        uint256 expectedHealthFactor = 8e17; // 0.8 ether (health factor of 0.8)

        // Start impersonating the test user
        vm.startPrank(user);
        // Approve the loanFi contract to spend user's tokens.weth
        // User deposits $10,000
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);

        // Deposit collateral and borrow tokens.link in one transaction
        // tokens.link is $10/token, user borrows 10, so thats $100 borrowed
        loanFi.borrowFunds(tokens.link, amountToBorrow);
        // Stop impersonating the user
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Errors.HealthFactor__BreaksHealthFactor.selector, expectedHealthFactor));
        loanFi.withdrawCollateral(tokens.weth, thisWithdrawAmountBreaksHealthFactor);
        vm.stopPrank();
    }

    /////////////////////////
    //  Liquidation Tests  //
    /////////////////////////

    function testLiquidationsConstructor() public LiquidLoanFi {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = tokens.weth;
        testTokens[1] = tokens.wbtc;
        testTokens[2] = tokens.link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = priceFeeds.wethUsdPriceFeed;
        testFeeds[1] = priceFeeds.wbtcUsdPriceFeed;
        testFeeds[2] = priceFeeds.linkUsdPriceFeed;

        // Deploy new LoanFi instance
        LoanFi newLoanFi = new LoanFi(
            testTokens,
            testFeeds,
            address(0), // Mock swap router
            address(0) // Mock automation registry
        );

        // Deploy new LiquidationCore instance
        LiquidationCore liquidationCore = new LiquidationCore(address(newLoanFi));

        // Verify LoanFi address is set correctly by checking a getter function
        uint256 minimumHealthFactor = liquidationCore.getHealthFactor(user);
        assertEq(minimumHealthFactor, newLoanFi.getHealthFactor(user));

        // Verify owner is set correctly (inherited from Ownable)
        assertEq(liquidationCore.owner(), address(this));
    }

    modifier UserCanBeLiquidatedWithBonusFromOtherCollaterals() {
        // Mint tokens for liquidator
        ERC20Mock(tokens.link).mint(liquidator, 5000e18);

        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);

        vm.startPrank(user);
        // User deposits all three collateral types
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT); // 5 WETH = $10,000
        ERC20Mock(tokens.wbtc).approve(address(loanFi), 1e18); // 1 WBTC = $30,000
        ERC20Mock(tokens.link).approve(address(loanFi), DEPOSIT_AMOUNT); // 5 LINK = $50

        // Deposit all collaterals
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT); // $10,000
        loanFi.depositCollateral(tokens.wbtc, 1e18); // $30k
        loanFi.depositCollateral(tokens.link, DEPOSIT_AMOUNT); // $50

        // Borrow LINK tokens
        loanFi.borrowFunds(tokens.link, 2000e18); // Borrow 2000 LINK = $20,000
        vm.stopPrank();

        // Crash WETH price to make user liquidatable, but keep other collateral valuable
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(10e8); // WETH = $10 (massive crash)
        _;
    }

    function testLiquidationsRevertsIfAmountIsZero() public {
        vm.prank(liquidator);
        vm.expectRevert(Errors.AmountNeedsMoreThanZero.selector);
        loanFi.liquidate(user, tokens.weth, tokens.link, 0);
    }

    function testLiquidationsRevertsIfCollateralTokenIsNotAllowed() public {
        // Create a new random ERC20 token
        ERC20Mock dogToken = new ERC20Mock("DOG", "DOG", user, 100e18);

        // Start impersonating our test user
        vm.startPrank(liquidator);

        // Expect revert with TokenNotAllowed error when trying to borrow unapproved token
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenNotAllowed.selector, address(dogToken)));
        // Attempt to liquidate user with unapproved token  (this should fail)
        loanFi.liquidate(user, address(dogToken), tokens.link, DEPOSIT_AMOUNT);

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testLiquidationsRevertsIfBorrowedTokenIsNotAllowed() public {
        // Create a new random ERC20 token
        ERC20Mock dogToken = new ERC20Mock("DOG", "DOG", user, 100e18);

        // Start impersonating our test user
        vm.startPrank(liquidator);

        // Expect revert with TokenNotAllowed error when trying to borrow unapproved token
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenNotAllowed.selector, address(dogToken)));
        // Attempt to liquidate user with unapproved token  (this should fail)
        loanFi.liquidate(user, tokens.weth, address(dogToken), DEPOSIT_AMOUNT);

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testLiquidationRevertsIfUserIsZeroAddress() public {
        vm.prank(liquidator);
        vm.expectRevert(Errors.ZeroAddressNotAllowed.selector);
        loanFi.liquidate(address(0), tokens.weth, tokens.link, DEPOSIT_AMOUNT);
    }

    function testLiquidationRevertsIfUserSelfLiquidates() public {
        vm.prank(user);
        vm.expectRevert(Errors.Liquidations__CantLiquidateSelf.selector);
        loanFi.liquidate(user, tokens.weth, tokens.link, DEPOSIT_AMOUNT);
    }

    function testLiquidationRevertsIfUserHasNotBorrowedToken() public {
        vm.prank(liquidator);
        vm.expectRevert(Errors.Liquidation__UserHasNotBorrowedToken.selector);
        loanFi.liquidate(user, tokens.weth, tokens.link, DEPOSIT_AMOUNT);
    }

    function testLiquidationRevertsIfDebtAmountPaidExceedsCollateralAmount()
        public
        UserCanBeLiquidatedWithBonusFromOtherCollaterals
    {
        uint256 tooMuchToLiquidate = 3000e18;

        // Need to approve LoanFi to spend liquidator's LINK tokens
        vm.startPrank(liquidator);
        ERC20Mock(tokens.link).approve(address(loanFi), tooMuchToLiquidate);

        vm.expectRevert(Errors.Liquidations__DebtAmountPaidExceedsBorrowedAmount.selector);
        loanFi.liquidate(user, tokens.weth, tokens.link, tooMuchToLiquidate);
        vm.stopPrank();
    }

    function testLiquidationRevertsIfLiquidatorDoesNothaveEnoughTokens() public LiquidLoanFi {
        uint256 tooMuchForLiquidator = 100e18;
        // Start impersonating the test user
        vm.startPrank(user);
        // Approve the loanFi contract to spend user's tokens.weth
        // User deposits $10,000
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);

        // Deposit collateral and borrow tokens.link in one transaction
        // tokens.link is $10/token, user borrows 10, so thats $100 borrowed
        loanFi.borrowFunds(tokens.link, tooMuchForLiquidator);
        // Stop impersonating the user
        vm.stopPrank();

        vm.prank(liquidator);
        vm.expectRevert(Errors.Liquidations__InsufficientBalanceToLiquidate.selector);
        loanFi.liquidate(user, tokens.weth, tokens.link, tooMuchForLiquidator);
    }

    function testLiquidationRevertsIfHealthFactorIsAboveOne() public UserDepositedAndBorrowedLink {
        vm.prank(liquidator);
        vm.expectRevert(Errors.Liquidations__HealthFactorIsHealthy.selector);
        loanFi.liquidate(user, tokens.weth, tokens.link, DEPOSIT_AMOUNT);
    }

    modifier UserCanBeLiquidatedWithBonus() {
        ERC20Mock(tokens.link).mint(liquidator, 5000e18);

        // Start impersonating the test user
        vm.startPrank(user);
        // Approve the loanFi contract to spend user's tokens.weth
        // User deposits $10,000
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);

        // Deposit collateral and borrow tokens.link in one transaction
        // tokens.link is $10/token, user borrows 100, so thats $1000 borrowed
        loanFi.borrowFunds(tokens.link, 100e18);
        // Stop impersonating the user
        vm.stopPrank();

        // Set new ETH price to $300 (significant drop from original price)
        int256 wethUsdUpdatedPrice = 300e8; // 1 ETH = $300

        // we need $200 of collateral at all times if we have $100 of debt
        // Update the ETH/USD price feed with new lower price
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(wethUsdUpdatedPrice);

        uint256 liquidatorBalanceBefore = ERC20Mock(tokens.weth).balanceOf(liquidator);

        // user deposits are now worth 5 x 300 = 1500 USD
        _;
    }

    function testLiquidationPaysLiquidatorBonusFromSelectedCollateral()
        public
        LiquidLoanFi
        UserCanBeLiquidatedWithBonus
    {
        uint256 liquidatorBalanceBefore = ERC20Mock(tokens.weth).balanceOf(liquidator);

        uint256 expectedDebtAmountToPay = 100e18;
        uint256 expectedBonus = loanFi.getTokenAmountFromUsd(tokens.weth, loanFi.getUsdValue(tokens.link, 110e18));

        vm.startPrank(liquidator);
        ERC20Mock(tokens.link).approve(address(loanFi), expectedDebtAmountToPay);
        loanFi.liquidate(user, tokens.weth, tokens.link, expectedDebtAmountToPay);
        vm.stopPrank();

        uint256 liquidatorBalanceAfter = ERC20Mock(tokens.weth).balanceOf(liquidator);

        uint256 actualBonus = liquidatorBalanceAfter - liquidatorBalanceBefore;

        assertEq(actualBonus, expectedBonus);
    }

    function testLiquidationPaysLiquidatorBonusFromOtherCollateralBTC()
        public
        UserCanBeLiquidatedWithBonusFromOtherCollaterals
    {
        // Track liquidator's WBTC balance
        uint256 liquidatorWbtcBalanceBefore =
            loanFi.getUsdValue(tokens.wbtc, ERC20Mock(tokens.wbtc).balanceOf(liquidator));
        console.log("Liquidator WBTC balance before:", liquidatorWbtcBalanceBefore);

        // Track liquidator's WETH balance
        uint256 liquidatorWethBalanceBefore =
            loanFi.getUsdValue(tokens.weth, ERC20Mock(tokens.weth).balanceOf(liquidator));
        console.log("Liquidator WETH balance before:", liquidatorWethBalanceBefore);

        // Track user's WETH balance before
        uint256 userWethBalanceBefore = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        console.log("User deposited WETH balance before:", userWethBalanceBefore);

        // Track user's WBTC balance
        uint256 userWbtcBalanceBefore = loanFi.getUsdValue(tokens.wbtc, ERC20Mock(tokens.wbtc).balanceOf(user));
        console.log("User WBTC balance before:", userWbtcBalanceBefore);

        // Calculate expected bonus (10% of $20,000 debt = $2000 USD)
        uint256 debtAmountToPay = 2000e18; // 2000 LINK
        uint256 expectedBonus = loanFi.getUsdValue(tokens.link, 2200e18); // 110% of debt value for 10% bonus / the amount is 2200e18 because we are expect to receive 2200 as the reward in a different collateral token
        console.log("Expected bonus:", expectedBonus);

        // Perform liquidation
        vm.startPrank(liquidator);
        ERC20Mock(tokens.link).approve(address(loanFi), debtAmountToPay);
        loanFi.liquidate(user, tokens.weth, tokens.link, debtAmountToPay);
        vm.stopPrank();

        // Verify liquidator received the bonus
        // Track liquidator's WBTC balance
        uint256 liquidatorWbtcBalanceAfter =
            loanFi.getUsdValue(tokens.wbtc, ERC20Mock(tokens.wbtc).balanceOf(liquidator));
        console.log("Liquidator WBTC balance after:", liquidatorWbtcBalanceAfter);

        // Track liquidator's WETH balance
        uint256 liquidatorWethBalanceAfter =
            loanFi.getUsdValue(tokens.weth, ERC20Mock(tokens.weth).balanceOf(liquidator));
        console.log("Liquidator WETH balance after:", liquidatorWethBalanceAfter);

        // Track user's WETH balance after
        uint256 userWethBalanceAfter = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        console.log("User deposited WETH balance after:", userWethBalanceAfter);

        // Track user's WBTC balance
        uint256 userWbtcBalanceAfter = loanFi.getUsdValue(tokens.wbtc, ERC20Mock(tokens.wbtc).balanceOf(user));
        console.log("User WBTC balance after:", userWbtcBalanceAfter);

        // Calculate bonus received in each token
        uint256 wbtcBonusInUsd = liquidatorWbtcBalanceAfter - liquidatorWbtcBalanceBefore;
        uint256 wethBonusInUsd = liquidatorWethBalanceAfter - liquidatorWethBalanceBefore;

        uint256 actualBonus = wbtcBonusInUsd + wethBonusInUsd;
        console.log("Actual bonus received:", actualBonus);

        // Allow for a small rounding difference (0.00000000000009% difference)
        uint256 tolerance = 20_000; // 20,000 wei tolerance
        assertApproxEqAbs(
            actualBonus, expectedBonus, tolerance, "Liquidator should receive bonus from other collaterals"
        );

        // Check that user's deposited WETH balance decreased to 0 after liquidation
        assertEq(userWethBalanceAfter, 0, "User being liquidated's deposited WETH balance should be 0");

        // Check that the balance actually decreased
        assert(userWethBalanceBefore > userWethBalanceAfter);
    }

    function testLiquidationPaysLiquidatorBonusFromOtherCollateralLINK() public {
        // Mint tokens for liquidator
        ERC20Mock(tokens.link).mint(liquidator, 5000e18);

        // Mint tokens for user
        ERC20Mock(tokens.link).mint(user, 3000e18);

        uint256 amountOfLinkToDeposit = 3000e18;

        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);

        vm.startPrank(user);
        // User deposits all two collateral types
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT); // 5 WETH = $10,000
        ERC20Mock(tokens.link).approve(address(loanFi), amountOfLinkToDeposit); // 5 LINK = $50

        // Deposit collaterals
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT); // $10,000
        loanFi.depositCollateral(tokens.link, amountOfLinkToDeposit); // $50

        // Borrow LINK tokens
        loanFi.borrowFunds(tokens.link, 2000e18); // Borrow 2000 LINK = $20,000
        vm.stopPrank();

        // Crash WETH price to make user liquidatable, but keep other collateral valuable
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(10e8); // WETH = $10 (massive crash)

        // Track liquidator's LINK balance
        uint256 liquidatorLinkBalanceBefore =
            loanFi.getUsdValue(tokens.link, ERC20Mock(tokens.link).balanceOf(liquidator));
        console.log("Liquidator LINK balance before:", liquidatorLinkBalanceBefore);

        // Track liquidator's WETH balance
        uint256 liquidatorWethBalanceBefore =
            loanFi.getUsdValue(tokens.weth, ERC20Mock(tokens.weth).balanceOf(liquidator));
        console.log("Liquidator WETH balance before:", liquidatorWethBalanceBefore);

        // Track user's WETH balance before
        uint256 userWethBalanceBefore = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        console.log("User deposited WETH balance before:", userWethBalanceBefore);

        // Track user's LINK balance
        uint256 userLinkBalanceBefore = loanFi.getUsdValue(tokens.link, ERC20Mock(tokens.link).balanceOf(user));
        console.log("User WBTC balance before:", userLinkBalanceBefore);

        // Calculate expected bonus (10% of $20,000 debt = $2000 USD)
        uint256 debtAmountToPay = 2000e18; // 2000 LINK
        uint256 expectedBonus = loanFi.getUsdValue(tokens.link, 200e18); // 10% bonus - we expect 200 because this is the 10% reward
        console.log("Expected bonus:", expectedBonus);

        // Perform liquidation
        vm.startPrank(liquidator);
        ERC20Mock(tokens.link).approve(address(loanFi), debtAmountToPay);
        loanFi.liquidate(user, tokens.weth, tokens.link, debtAmountToPay);
        vm.stopPrank();

        // Verify liquidator received the bonus
        // Track liquidator's LINK balance
        uint256 liquidatorLinkBalanceAfter =
            loanFi.getUsdValue(tokens.link, ERC20Mock(tokens.link).balanceOf(liquidator));
        console.log("Liquidator LINK balance after:", liquidatorLinkBalanceAfter);

        // Track liquidator's WETH balance
        uint256 liquidatorWethBalanceAfter =
            loanFi.getUsdValue(tokens.weth, ERC20Mock(tokens.weth).balanceOf(liquidator));
        console.log("Liquidator WETH balance after:", liquidatorWethBalanceAfter);

        // Track user's WETH balance after
        uint256 userWethBalanceAfter = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        console.log("User deposited WETH balance after:", userWethBalanceAfter);

        // Track user's LINK balance
        uint256 userLinkBalanceAfter = loanFi.getUsdValue(tokens.link, ERC20Mock(tokens.link).balanceOf(user));
        console.log("User LINK balance after:", userLinkBalanceAfter);

        // Calculate bonus received in each token
        uint256 linkBonusInUsd = liquidatorLinkBalanceAfter - liquidatorLinkBalanceBefore;
        uint256 wethBonusInUsd = liquidatorWethBalanceAfter - liquidatorWethBalanceBefore;

        uint256 actualBonus = linkBonusInUsd + wethBonusInUsd;
        console.log("Actual bonus received:", actualBonus);

        assertEq(actualBonus, expectedBonus, "Liquidator should receive bonus from other collaterals");

        // Check that user's deposited WETH balance decreased to 0 after liquidation
        assertEq(userWethBalanceAfter, 0, "User being liquidated's deposited WETH balance should be 0");

        // Check that the balance actually decreased
        assert(userWethBalanceBefore > userWethBalanceAfter);
    }

    function testLiquidationByLiquidatorRevertsIfNoBonusAvailable() public {
        uint256 debtAmountToPay = 50e18; // 100 LINK

        // Mint tokens for liquidator
        ERC20Mock(tokens.link).mint(liquidator, 5000e18);

        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);

        vm.startPrank(user);
        // User deposits all three collateral types
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT); // 5 WETH = $10,000

        // Deposit all collaterals
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT); // $10,000

        // Borrow LINK tokens
        loanFi.borrowFunds(tokens.link, 50e18); // Borrow 2000 LINK = $500
        vm.stopPrank();

        // Crash WETH price to make user liquidatable, but keep other collateral valuable
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(10e8); // WETH = $10 (massive crash)

        // Perform liquidation
        vm.startPrank(liquidator);
        ERC20Mock(tokens.link).approve(address(loanFi), debtAmountToPay);
        vm.expectRevert(Errors.Liquidations__OnlyProtocolCanLiquidateInsufficientBonus.selector);
        loanFi.liquidate(user, tokens.weth, tokens.link, debtAmountToPay);
        vm.stopPrank();
    }

    function testLiquidationEmitsEvent() public LiquidLoanFi UserCanBeLiquidatedWithBonus {
        uint256 liquidatorBalanceBefore = ERC20Mock(tokens.weth).balanceOf(liquidator);

        uint256 debtAmountToPay = 100e18;
        uint256 expectedBonus = loanFi.getTokenAmountFromUsd(tokens.weth, loanFi.getUsdValue(tokens.link, 110e18));

        vm.startPrank(liquidator);
        ERC20Mock(tokens.link).approve(address(loanFi), debtAmountToPay);

        // Set up the event expectation with LiquidationEngine's address
        vm.expectEmit(true, true, true, false, address(loanFi.liquidationEngine()));
        emit UserLiquidated(tokens.weth, user, debtAmountToPay);
        loanFi.liquidate(user, tokens.weth, tokens.link, debtAmountToPay);
        vm.stopPrank();

        uint256 liquidatorBalanceAfter = ERC20Mock(tokens.weth).balanceOf(liquidator);

        uint256 actualBonus = liquidatorBalanceAfter - liquidatorBalanceBefore;

        assertEq(actualBonus, expectedBonus);
    }

    function testLiquidationDecreasesUsersBorrowedAmount() public LiquidLoanFi UserCanBeLiquidatedWithBonus {
        uint256 liquidatorBalanceBefore = ERC20Mock(tokens.weth).balanceOf(liquidator);

        uint256 debtAmountToPay = 100e18;
        uint256 expectedBonus = loanFi.getTokenAmountFromUsd(tokens.weth, loanFi.getUsdValue(tokens.link, 110e18));

        vm.startPrank(liquidator);
        ERC20Mock(tokens.link).approve(address(loanFi), debtAmountToPay);

        loanFi.liquidate(user, tokens.weth, tokens.link, debtAmountToPay);
        vm.stopPrank();

        uint256 liquidatorBalanceAfter = ERC20Mock(tokens.weth).balanceOf(liquidator);

        uint256 actualBonus = liquidatorBalanceAfter - liquidatorBalanceBefore;

        assertEq(actualBonus, expectedBonus);
        assertEq(loanFi.getAmountOfTokenBorrowed(user, tokens.link), 0);
    }

    function testLiquidationDecreasesUsersCollateral() public LiquidLoanFi UserCanBeLiquidatedWithBonus {
        uint256 liquidatorBalanceBefore = ERC20Mock(tokens.weth).balanceOf(liquidator);

        uint256 debtAmountToPay = 100e18;
        uint256 expectedBonus = loanFi.getTokenAmountFromUsd(tokens.weth, loanFi.getUsdValue(tokens.link, 110e18));
        uint256 usersCollateralBefore = loanFi.getCollateralBalanceOfUser(user, tokens.weth);

        uint256 expectedAmountOfCollateralLeft = usersCollateralBefore - expectedBonus;

        vm.startPrank(liquidator);
        ERC20Mock(tokens.link).approve(address(loanFi), debtAmountToPay);

        loanFi.liquidate(user, tokens.weth, tokens.link, debtAmountToPay);
        vm.stopPrank();

        uint256 liquidatorBalanceAfter = ERC20Mock(tokens.weth).balanceOf(liquidator);

        uint256 actualBonus = liquidatorBalanceAfter - liquidatorBalanceBefore;

        uint256 usersCollateralAfter = loanFi.getCollateralBalanceOfUser(user, tokens.weth);

        assertEq(actualBonus, expectedBonus);
        assertEq(usersCollateralAfter, expectedAmountOfCollateralLeft);
    }

    function testLiquidationRevertsLiquidationMakesHealthFactorWorse() public LiquidLoanFi {
        // 1. Setup: User deposits collateral and borrows
        vm.startPrank(user);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);

        // Borrow a smaller amount so we can test health factor break
        uint256 borrowAmount = 50e18; // 50 LINK = $500 USD
        loanFi.borrowFunds(tokens.link, borrowAmount);
        vm.stopPrank();

        // 2. Drop ETH price to make health factor < 1 but not too low
        // Original ETH price is $2000, drop to $1000
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(100e8); // $1000 per ETH

        // 3. Setup liquidator with full amount to repay
        vm.startPrank(liquidator);
        ERC20Mock(tokens.link).mint(liquidator, 1000e18);
        ERC20Mock(tokens.link).approve(address(loanFi), borrowAmount);

        // 4. Try to liquidate almost all collateral, which would leave user with:
        // - Very little collateral but still some debt
        // This should make health factor worse
        vm.expectRevert(Errors.Liquidations__HealthFactorNotImproved.selector);

        // Try to liquidate a small amount that would leave user in worse position
        uint256 debtToRepay = borrowAmount / 10; // Only repay 10% of debt
        loanFi.liquidate(user, tokens.weth, tokens.link, debtToRepay);
        vm.stopPrank();
    }

    ////////////////////////////////////
    //    LiquidationEngine Tests    //
    ///////////////////////////////////

    modifier UserCanBeLiquidatedByProtocol() {
        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);

        vm.startPrank(user);
        // User deposits all three collateral types
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT); // 5 WETH = $10,000

        // Deposit all collaterals
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT); // $10,000

        // Borrow LINK tokens
        loanFi.borrowFunds(tokens.link, 50e18); // Borrow 50 LINK = $500
        vm.stopPrank();

        // Crash WETH price to make user liquidatable, but keep other collateral valuable
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(100e8); // WETH = $100 (massive crash)

        // the user's collateral will no be worth 5 x 100 = 500
        _;
    }

    function testProtocolLiquidateRevertsIfCalledByNonOwner() public UserCanBeLiquidatedByProtocol {
        uint256 debtToPay = 2e18;

        // Get liquidationEngine instance from LoanFi
        LiquidationEngine liquidationEngine = loanFi.liquidationEngine();

        vm.startPrank(liquidator);

        vm.expectRevert(Errors.Liquidations__OnlyProtocolOwnerOrAutomation.selector);

        // Attempt to call protocolLiquidate as non-owner
        liquidationEngine.protocolLiquidate(user, tokens.link, debtToPay);

        vm.stopPrank();
    }

    function testGetInsufficientBonusPositionsRevertsIfCalledByNonOwner() public {
        // Get liquidationEngine instance from LoanFi
        LiquidationEngine liquidationEngine = loanFi.liquidationEngine();

        vm.startPrank(liquidator);

        // The error should be OwnableUnauthorizedAccount(account)
        vm.expectRevert(Errors.Liquidations__OnlyProtocolOwnerOrAutomation.selector);

        // Attempt to call protocolLiquidate as non-owner
        liquidationEngine.getInsufficientBonusPositions(user);

        vm.stopPrank();
    }

    function testGetInsufficientBonusPositionsWorksProperlyCheck() public UserCanBeLiquidatedByProtocol {
        // Get liquidationEngine instance
        LiquidationEngine liquidationEngine = loanFi.liquidationEngine();

        // Get the owner of LoanFi (not LiquidationEngine)
        address loanFiOwner = loanFi.owner();

        // Call getInsufficientBonusPositions as LoanFi owner
        vm.startPrank(loanFiOwner);
        (address[] memory debtTokens, address[] memory collaterals, uint256[] memory debtAmounts) =
            liquidationEngine.getInsufficientBonusPositions(user);
        vm.stopPrank();

        // Assertions
        assertEq(debtTokens.length, 1, "Should have one debt position");
        assertEq(collaterals.length, 1, "Should have one collateral position");
        assertEq(debtAmounts.length, 1, "Should have one debt amount");

        assertEq(debtTokens[0], address(tokens.link), "Debt token should be LINK");
        assertEq(collaterals[0], address(tokens.weth), "Collateral should be WETH");
        assertEq(debtAmounts[0], 50e18, "Debt amount should match borrowed amount");

        // Verify position is actually unhealthy
        uint256 healthFactor = loanFi.getHealthFactor(user); // Changed from liquidationEngine to loanFi
        assertTrue(healthFactor < loanFi.getMinimumHealthFactor(), "Position should be unhealthy");
    }

    function testGetInsufficientBonusPositionsWorksProperlyMultiplePositions() public {
        // Setup initial balances
        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);
        ERC20Mock(tokens.wbtc).mint(address(loanFi), 10_000e18);

        vm.startPrank(user);
        // User deposits both WETH and WBTC as collateral
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT); // 5 WETH
        ERC20Mock(tokens.wbtc).approve(address(loanFi), DEPOSIT_AMOUNT); // 5 WBTC

        // Deposit both collaterals
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.wbtc, DEPOSIT_AMOUNT);

        // Borrow both LINK and WETH
        loanFi.borrowFunds(tokens.link, 50e18); // Borrow 50 LINK
        loanFi.borrowFunds(tokens.wbtc, 1e18); // Borrow 1 WBTC
        vm.stopPrank();

        // Crash both WETH and WBTC prices to make positions liquidatable
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(10e8); // WETH = $10 (massive crash)
        MockV3Aggregator(priceFeeds.wbtcUsdPriceFeed).updateAnswer(100e8); // WBTC = $100 (massive crash)

        // Get liquidationEngine instance
        LiquidationEngine liquidationEngine = loanFi.liquidationEngine();
        address loanFiOwner = loanFi.owner();

        // Call getInsufficientBonusPositions as LoanFi owner
        vm.startPrank(loanFiOwner);
        (address[] memory debtTokens, address[] memory collaterals, uint256[] memory debtAmounts) =
            liquidationEngine.getInsufficientBonusPositions(user);
        vm.stopPrank();

        // Assert array lengths
        assertEq(debtTokens.length, 2, "Should have two debt positions");
        assertEq(collaterals.length, 2, "Should have two collateral positions");
        assertEq(debtAmounts.length, 2, "Should have two debt amounts");

        // Assert first position (WBTC debt)
        assertEq(debtTokens[0], address(tokens.wbtc), "First debt token should be WBTC");
        assertEq(collaterals[0], address(tokens.weth), "First position collateral should be WETH");
        assertEq(debtAmounts[0], 1e18, "First position debt amount should be 1 WBTC");

        // Assert second position (LINK debt)
        assertEq(debtTokens[1], address(tokens.link), "Second debt token should be LINK");
        assertEq(collaterals[1], address(tokens.weth), "Second position collateral should be WETH");
        assertEq(debtAmounts[1], 50e18, "Second position debt amount should be 50 LINK");

        // Verify positions are actually unhealthy
        uint256 healthFactor = loanFi.getHealthFactor(user);
        assertTrue(healthFactor < loanFi.getMinimumHealthFactor(), "Positions should be unhealthy");
    }

    function testGetInsufficientBonusPositionsWorksProperlyMultiplePeopleWithMultiplePositions() public {
        address user2 = makeAddr("user2");

        // Setup initial balances for both users
        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);
        ERC20Mock(tokens.wbtc).mint(address(loanFi), 10_000e18);

        // Give user2 initial tokens
        deal(address(tokens.weth), user2, 10_000e18);
        deal(address(tokens.wbtc), user2, 10_000e18);
        deal(address(tokens.link), user2, 10_000e18);

        // Setup User 1's positions
        vm.startPrank(user);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        ERC20Mock(tokens.wbtc).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT); // 5 WETH
        loanFi.depositCollateral(tokens.wbtc, DEPOSIT_AMOUNT); // 5 WBTC

        loanFi.borrowFunds(tokens.link, 50e18); // Borrow 50 LINK
        loanFi.borrowFunds(tokens.wbtc, 1e18); // Borrow 1 WBTC
        vm.stopPrank();

        // Setup User 2's positions
        vm.startPrank(user2);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        ERC20Mock(tokens.wbtc).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT); // 5 WETH
        loanFi.depositCollateral(tokens.wbtc, DEPOSIT_AMOUNT); // 5 WBTC

        loanFi.borrowFunds(tokens.link, 40e18); // Borrow 40 LINK
        loanFi.borrowFunds(tokens.wbtc, 2e18); // Borrow 2 WBTC
        vm.stopPrank();

        // Crash prices to make all positions liquidatable
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(10e8); // WETH = $10 (massive crash)
        MockV3Aggregator(priceFeeds.wbtcUsdPriceFeed).updateAnswer(100e8); // WBTC = $100 (massive crash)

        // Get liquidationEngine instance and owner
        LiquidationEngine liquidationEngine = loanFi.liquidationEngine();
        address loanFiOwner = loanFi.owner();

        // Check User 1's positions
        vm.startPrank(loanFiOwner);
        (address[] memory debtTokens1, address[] memory collaterals1, uint256[] memory debtAmounts1) =
            liquidationEngine.getInsufficientBonusPositions(user);

        // Assert User 1's positions
        assertEq(debtTokens1.length, 2, "User1 should have two debt positions");
        assertEq(debtTokens1[0], address(tokens.wbtc), "User1 first debt token should be WBTC");
        assertEq(debtTokens1[1], address(tokens.link), "User1 second debt token should be LINK");
        assertEq(debtAmounts1[0], 1e18, "User1 WBTC debt amount incorrect");
        assertEq(debtAmounts1[1], 50e18, "User1 LINK debt amount incorrect");
        assertEq(collaterals1[0], address(tokens.weth), "User1 first collateral should be WETH");
        assertEq(collaterals1[1], address(tokens.weth), "User1 second collateral should be WETH");

        // Check User 2's positions
        (address[] memory debtTokens2, address[] memory collaterals2, uint256[] memory debtAmounts2) =
            liquidationEngine.getInsufficientBonusPositions(user2);
        vm.stopPrank();

        // Assert User 2's positions
        assertEq(debtTokens2.length, 2, "User2 should have two debt positions");
        assertEq(debtTokens2[0], address(tokens.wbtc), "User2 first debt token should be WBTC");
        assertEq(debtTokens2[1], address(tokens.link), "User2 second debt token should be LINK");
        assertEq(debtAmounts2[0], 2e18, "User2 WBTC debt amount incorrect");
        assertEq(debtAmounts2[1], 40e18, "User2 LINK debt amount incorrect");
        assertEq(collaterals2[0], address(tokens.weth), "User2 first collateral should be WETH");
        assertEq(collaterals2[1], address(tokens.weth), "User2 second collateral should be WETH");

        // Verify both positions are unhealthy
        uint256 healthFactor1 = loanFi.getHealthFactor(user);
        uint256 healthFactor2 = loanFi.getHealthFactor(user2);
        assertTrue(healthFactor1 < loanFi.getMinimumHealthFactor(), "User1 positions should be unhealthy");
        assertTrue(healthFactor2 < loanFi.getMinimumHealthFactor(), "User2 positions should be unhealthy");
    }

    ////////////////////////////////////
    //  LiquidationAutomation Tests  //
    ///////////////////////////////////

    function testLiquidationCompletedByProtocolWithSmallBonus() public {
        console.log("-------- Starting Protocol Liquidation Test --------");
        // Setup initial balances
        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);
        console.log("Initial LoanFi LINK balance:", ERC20Mock(tokens.link).balanceOf(address(loanFi)));

        // Setup user's position
        vm.startPrank(user);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT); // 5 WETH
        console.log("User deposited WETH amount:", DEPOSIT_AMOUNT);
        console.log("User WETH collateral balance:", loanFi.getCollateralBalanceOfUser(user, tokens.weth));

        loanFi.borrowFunds(tokens.link, 50e18); // Borrow 50 LINK at $10 = $500
        vm.stopPrank();

        // Record initial balances
        uint256 initialUserCollateral = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 initialProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));
        console.log("Initial user collateral:", initialUserCollateral);
        console.log("Initial protocol LINK balance:", initialProtocolLinkBalance);

        // Crash WETH price to create insufficient bonus scenario
        // At $105/WETH: 5 WETH = $525, debt = $500
        // Available for bonus = $25, which is only 5% (less than required 10%)
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(105e8);
        console.log("Updated WETH price:", MockV3Aggregator(priceFeeds.wethUsdPriceFeed).latestAnswer());
        console.log("LINK price:", MockV3Aggregator(priceFeeds.linkUsdPriceFeed).latestAnswer());

        // Get automation contract directly from deployment
        LiquidationAutomation automation = deployLoanFi.liquidationAutomation();

        // Call checkUpkeep (this would normally be done by Chainlink)
        (bool upkeepNeeded, bytes memory performData) = automation.checkUpkeep("");
        console.log("Upkeep needed:", upkeepNeeded);
        assertTrue(upkeepNeeded, "Upkeep should be needed");

        console.log("-------- Before Liquidation --------");
        console.log("User WETH collateral:", loanFi.getCollateralBalanceOfUser(user, tokens.weth));
        console.log("User LINK debt:", loanFi.getAmountOfTokenBorrowed(user, tokens.link));

        // Perform the upkeep (liquidation)
        automation.performUpkeep(performData);

        console.log("-------- After Liquidation --------");
        console.log("User WETH collateral:", loanFi.getCollateralBalanceOfUser(user, tokens.weth));
        console.log("User LINK debt:", loanFi.getAmountOfTokenBorrowed(user, tokens.link));

        // Get final balances
        uint256 finalUserCollateral = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 finalProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));
        console.log("Final user collateral:", finalUserCollateral);
        console.log("Final protocol LINK balance:", finalProtocolLinkBalance);

        // Calculate actual amounts
        uint256 collateralLiquidated = initialUserCollateral - finalUserCollateral;
        uint256 debtPaid = finalProtocolLinkBalance - initialProtocolLinkBalance;
        console.log("Collateral liquidated:", collateralLiquidated);
        console.log("Debt paid:", debtPaid);

        // Verify liquidation occurred
        assertEq(debtPaid, 50e18, "Entire debt should be paid");
        assertEq(finalUserCollateral, 0, "User should have no collateral left"); // Protocol takes all collateral

        // Verify protocol received all remaining value as bonus
        uint256 collateralValueInUsd = loanFi.getUsdValue(tokens.weth, collateralLiquidated);
        uint256 debtValueInUsd = loanFi.getUsdValue(tokens.link, debtPaid);
        uint256 actualBonus = collateralValueInUsd - debtValueInUsd;
        uint256 expectedBonus = 25e18; // $25 worth of bonus (5% instead of 10%), scaled to price feed decimals

        console.log("Collateral value in USD:", collateralValueInUsd);
        console.log("Debt value in USD:", debtValueInUsd);
        console.log("Actual bonus:", actualBonus);
        console.log("Expected bonus:", expectedBonus);
        assertEq(actualBonus, expectedBonus, "Protocol should receive the small bonus");
        assertTrue(
            actualBonus < (debtValueInUsd * loanFi.getLiquidationBonus()) / loanFi.getLiquidationPrecision(),
            "Bonus should be less than 10%"
        );
    }

    function testLiquidationCompletedByProtocolWithNoBonus() public {
        // Setup initial balances
        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);

        // Setup user's position
        vm.startPrank(user);
        ERC20Mock(tokens.weth).mint(user, 5e18);
        ERC20Mock(tokens.weth).approve(address(loanFi), 5e18);
        loanFi.depositCollateral(tokens.weth, 5e18);
        loanFi.borrowFunds(tokens.link, 50e18);
        vm.stopPrank();

        // Store initial balances
        uint256 initialUserCollateral = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 initialProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));

        // Update price to make position liquidatable with collateral exactly equal to debt
        // 50 LINK at $10 = $500 debt
        // Need WETH at $100 so 5 WETH = $500
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(100e8); // $100 per ETH

        // Get automation contract
        LiquidationAutomation automation = deployLoanFi.liquidationAutomation();

        // Check and perform upkeep
        (bool upkeepNeeded, bytes memory performData) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed");
        automation.performUpkeep(performData);

        // Get final balances
        uint256 finalUserCollateral = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 finalProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));

        // Calculate actual amounts
        uint256 collateralLiquidated = initialUserCollateral - finalUserCollateral;
        uint256 debtPaid = finalProtocolLinkBalance - initialProtocolLinkBalance;

        // Verify liquidation occurred
        assertEq(debtPaid, 50e18, "Entire debt should be paid");
        assertEq(finalUserCollateral, 0, "User should have no collateral left");

        // Verify protocol received no bonus (collateral value exactly covers debt)
        uint256 collateralValueInUsd = loanFi.getUsdValue(tokens.weth, collateralLiquidated);
        uint256 debtValueInUsd = loanFi.getUsdValue(tokens.link, debtPaid);
        uint256 actualBonus = collateralValueInUsd - debtValueInUsd;

        assertEq(actualBonus, 0, "Protocol should receive no bonus");
    }

    function testLiquidationRevertsIfUsersTotalCollateralCanPayBonus()
        public
        LiquidLoanFi
        UserCanBeLiquidatedWithBonus
    {
        // Get automation contract
        LiquidationAutomation automation = deployLoanFi.liquidationAutomation();

        // Check upkeep
        (bool upkeepNeeded, bytes memory performData) = automation.checkUpkeep("");

        // Upkeep should be needed (we'll check that it reverts with no positions)
        assertTrue(upkeepNeeded, "Upkeep should be needed");

        // Try to force liquidation - should revert since no positions need protocol liquidation
        vm.expectRevert(Errors.Liquidations__NoPositionsToLiquidate.selector);
        automation.performUpkeep(performData);

        // Verify position remains unchanged
        assertEq(loanFi.getCollateralBalanceOfUser(user, tokens.weth), 5e18, "WETH collateral should remain unchanged");
        assertEq(loanFi.getAmountOfTokenBorrowed(user, tokens.link), 100e18, "LINK debt should remain unchanged");

        // Calculate total collateral value
        uint256 wethValue = loanFi.getUsdValue(tokens.weth, 5e18);
        uint256 wbtcValue = loanFi.getUsdValue(tokens.wbtc, 1e18);
        uint256 totalCollateralValue = wethValue + wbtcValue;

        // Calculate required bonus
        uint256 debtValue = loanFi.getUsdValue(tokens.link, 50e18);
        uint256 requiredBonus = (debtValue * loanFi.getLiquidationBonus()) / loanFi.getLiquidationPrecision();

        // Verify user has enough total collateral to cover debt + full bonus
        assertTrue(
            totalCollateralValue >= debtValue + requiredBonus, "User should have enough collateral for full bonus"
        );
    }

    function testIfBonusIsLessTenPercentCheckUpLiquidates() public UserCanBeLiquidatedByProtocol {
        // Store initial balances
        uint256 initialUserCollateral = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 initialProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));

        // Get automation contract
        LiquidationAutomation automation = deployLoanFi.liquidationAutomation();

        // Check upkeep
        (bool upkeepNeeded, bytes memory performData) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed");

        console.log("-------- Before Liquidation --------");
        console.log("User WETH collateral:", loanFi.getCollateralBalanceOfUser(user, tokens.weth));
        console.log("User LINK debt:", loanFi.getAmountOfTokenBorrowed(user, tokens.link));

        // Perform the upkeep (liquidation)
        automation.performUpkeep(performData);

        console.log("-------- After Liquidation --------");
        console.log("User WETH collateral:", loanFi.getCollateralBalanceOfUser(user, tokens.weth));
        console.log("User LINK debt:", loanFi.getAmountOfTokenBorrowed(user, tokens.link));

        // Get final balances
        uint256 finalUserCollateral = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 finalProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));

        // Calculate actual amounts
        uint256 collateralLiquidated = initialUserCollateral - finalUserCollateral;
        uint256 debtPaid = finalProtocolLinkBalance - initialProtocolLinkBalance;

        // Verify liquidation occurred
        assertEq(debtPaid, 50e18, "Entire debt should be paid"); // 50 LINK
        assertEq(finalUserCollateral, 0, "User should have no collateral left"); // Protocol takes all collateral

        // Calculate and verify bonus is less than 10%
        uint256 collateralValueInUsd = loanFi.getUsdValue(tokens.weth, collateralLiquidated);
        uint256 debtValueInUsd = loanFi.getUsdValue(tokens.link, debtPaid);
        uint256 actualBonus = collateralValueInUsd - debtValueInUsd;
        uint256 requiredBonus = (debtValueInUsd * loanFi.getLiquidationBonus()) / loanFi.getLiquidationPrecision();

        assertTrue(actualBonus < requiredBonus, "Available bonus should be less than required 10%");
        assertTrue(
            actualBonus < (debtValueInUsd * loanFi.getLiquidationBonus()) / loanFi.getLiquidationPrecision(),
            "Bonus should be less than required 10%"
        );
    }

    modifier manyUsersAreLiquidatable() {
        // Setup initial protocol balance
        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);

        // Set initial prices
        MockV3Aggregator(priceFeeds.linkUsdPriceFeed).updateAnswer(10e8); // $10 per LINK
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(2000e8); // $2000 per ETH

        // Setup user's position: 5 WETH ($10,000) collateral, 50 LINK ($500) debt
        vm.startPrank(user);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);
        loanFi.borrowFunds(tokens.link, 50e18);
        vm.stopPrank();

        // Setup alice's position: 5 WETH ($10,000) collateral, 80 LINK ($800) debt
        vm.startPrank(alice);
        ERC20Mock(tokens.weth).mint(alice, STARTING_USER_BALANCE);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);
        loanFi.borrowFunds(tokens.link, 80e18);
        vm.stopPrank();

        // Setup bob's position: 5 WETH ($10,000) collateral, 90 LINK ($900) debt
        vm.startPrank(bob);
        ERC20Mock(tokens.weth).mint(bob, STARTING_USER_BALANCE);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT);
        loanFi.borrowFunds(tokens.link, 90e18);
        vm.stopPrank();

        // Make all positions liquidatable by dropping WETH price by 95%
        // At $100/ETH:
        // User: 5 WETH = $500 collateral, $500 debt (+ 10% bonus = $550 needed)
        // Alice: 5 WETH = $500 collateral, $800 debt (+ 10% bonus = $880 needed)
        // Bob: 5 WETH = $500 collateral, $900 debt (+ 10% bonus = $990 needed)
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(100e8); // $100 per ETH

        _;
    }

    function testLiquitionAutomationLiquidatesMulipleUsersAtOnce() public manyUsersAreLiquidatable {
        // Store initial balances before liquidation
        uint256 initialProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));

        // Get automation contract
        LiquidationAutomation automation = deployLoanFi.liquidationAutomation();

        // Check upkeep
        (bool upkeepNeeded, bytes memory performData) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed");

        // Perform the liquidations
        automation.performUpkeep(performData);

        // Get final balances
        uint256 userFinalCollateral = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 aliceFinalCollateral = loanFi.getCollateralBalanceOfUser(alice, tokens.weth);
        uint256 bobFinalCollateral = loanFi.getCollateralBalanceOfUser(bob, tokens.weth);
        uint256 finalProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));

        // Verify all users were liquidated
        assertEq(userFinalCollateral, 0, "User should have no collateral left");
        assertEq(aliceFinalCollateral, 0, "Alice should have no collateral left");
        assertEq(bobFinalCollateral, 0, "Bob should have no collateral left");

        // Verify all debts were paid
        assertEq(loanFi.getAmountOfTokenBorrowed(user, tokens.link), 0, "User should have no remaining debt");
        assertEq(loanFi.getAmountOfTokenBorrowed(alice, tokens.link), 0, "Alice should have no remaining debt");
        assertEq(loanFi.getAmountOfTokenBorrowed(bob, tokens.link), 0, "Bob should have no remaining debt");

        // Calculate total debt paid
        uint256 totalDebtPaid = finalProtocolLinkBalance - initialProtocolLinkBalance;
        assertEq(totalDebtPaid, 220e18, "Total debt paid should be 220 LINK"); // 50 + 80 + 90 = 220 LINK

        // Verify health factors improved
        assertTrue(
            loanFi.getHealthFactor(user) >= loanFi.getMinimumHealthFactor(), "User health factor should be improved"
        );
        assertTrue(
            loanFi.getHealthFactor(alice) >= loanFi.getMinimumHealthFactor(), "Alice health factor should be improved"
        );
        assertTrue(
            loanFi.getHealthFactor(bob) >= loanFi.getMinimumHealthFactor(), "Bob health factor should be improved"
        );

        // Protocol solvency
        assertTrue(
            ERC20Mock(tokens.link).balanceOf(address(loanFi)) >= 0, "Protocol should maintain positive LINK balance"
        );
    }

    ////////////////////////////////////
    //   UniswapV3 TokenSwap Tests   //
    //////////////////////////////////

    function testTokenSwapsAfterProtocolLiquidates() public UserCanBeLiquidatedByProtocol {
        // Get initial balances
        uint256 initialProtocolWethBalance = ERC20Mock(tokens.weth).balanceOf(address(loanFi));
        uint256 initialProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));

        // Get user's initial position
        uint256 userInitialDebt = loanFi.getAmountOfTokenBorrowed(user, tokens.link);
        uint256 userInitialCollateral = loanFi.getCollateralBalanceOfUser(user, tokens.weth);

        // Trigger liquidation
        vm.startPrank(address(loanFi));
        loanFi.liquidationEngine().protocolLiquidate(user, tokens.link, userInitialDebt);
        vm.stopPrank();

        // Get final balances and verify results
        uint256 finalProtocolWethBalance = ERC20Mock(tokens.weth).balanceOf(address(loanFi));
        uint256 finalProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));

        // Verify liquidation basics
        assertEq(loanFi.getCollateralBalanceOfUser(user, tokens.weth), 0, "User should have no collateral left");
        assertEq(loanFi.getAmountOfTokenBorrowed(user, tokens.link), 0, "User should have no debt left");

        // Verify token movements for debt repayment
        assertTrue(
            finalProtocolLinkBalance >= initialProtocolLinkBalance + userInitialDebt,
            "Protocol should receive at least the debt amount in LINK"
        );

        // Verify all WETH was used (debt repayment + automation funding)
        assertEq(
            finalProtocolWethBalance, initialProtocolWethBalance - userInitialCollateral, "All WETH should be used"
        );

        // Verify health factor is improved
        assertTrue(loanFi.getHealthFactor(user) >= loanFi.getMinimumHealthFactor(), "Health factor should be improved");

        // Verify protocol maintains solvency
        assertTrue(
            ERC20Mock(tokens.link).balanceOf(address(loanFi)) >= loanFi.getTotalTokenAmountsBorrowed(tokens.link),
            "Protocol should maintain sufficient LINK balance"
        );

        // Verify link amount increased by the amount the user borrowed
        assertEq(
            finalProtocolLinkBalance - initialProtocolLinkBalance,
            userInitialDebt,
            "Protocol LINK balance should increase by the borrowed amount"
        );
    }

    function testTokenSwapsAndFundsAutomation() public {
        // Mint initial LINK to protocol
        ERC20Mock(tokens.link).mint(address(loanFi), 10_000e18);

        vm.startPrank(user);
        // User deposits 5 WETH as collateral
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT); // 5 WETH = $10,000

        // Deposit collateral
        loanFi.depositCollateral(tokens.weth, DEPOSIT_AMOUNT); // $10,000

        // Borrow LINK tokens
        loanFi.borrowFunds(tokens.link, 50e18); // Borrow 50 LINK = $500
        vm.stopPrank();

        // Crash WETH price to make user liquidatable
        MockV3Aggregator(priceFeeds.wethUsdPriceFeed).updateAnswer(120e8);

        // Get initial balances
        uint256 initialAutomationLinkBalance =
            ERC20Mock(tokens.link).balanceOf(address(automationConfig.automationRegistry));
        uint256 initialProtocolWethBalance = ERC20Mock(tokens.weth).balanceOf(address(loanFi));
        uint256 initialProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));

        // Get user's initial position
        uint256 userInitialDebt = loanFi.getAmountOfTokenBorrowed(user, tokens.link);
        uint256 userInitialCollateral = loanFi.getCollateralBalanceOfUser(user, tokens.weth);

        // Calculate expected LINK from protocol fee
        // 0.75 WETH * $120 = $90
        // $90 worth of LINK at $10 per LINK = 9 LINK
        // Apply 2% slippage: 9 * 0.98 = 8.82 LINK
        uint256 expectedLinkFunding = 8.82e18;

        // Trigger liquidation
        vm.startPrank(address(loanFi));
        loanFi.liquidationEngine().protocolLiquidate(user, tokens.link, userInitialDebt);
        vm.stopPrank();

        // Get final balances
        uint256 finalAutomationLinkBalance =
            ERC20Mock(tokens.link).balanceOf(address(automationConfig.automationRegistry));
        uint256 finalProtocolWethBalance = ERC20Mock(tokens.weth).balanceOf(address(loanFi));
        uint256 finalProtocolLinkBalance = ERC20Mock(tokens.link).balanceOf(address(loanFi));
        uint256 finalLiquidationEngineLinkBalance =
            ERC20Mock(tokens.link).balanceOf(address(loanFi.liquidationEngine()));

        uint256 actualAutomationFunding = finalAutomationLinkBalance - initialAutomationLinkBalance;

        // Verify automation funding
        assertEq(actualAutomationFunding, expectedLinkFunding, "Automation should receive expected LINK funding");

        // 1. Verify LiquidationEngine has no leftover LINK
        assertEq(
            finalLiquidationEngineLinkBalance, 0, "LiquidationEngine should not hold any LINK after funding automation"
        );

        // 2. Verify user's position is properly liquidated
        assertEq(loanFi.getCollateralBalanceOfUser(user, tokens.weth), 0, "User should have no WETH collateral left");
        assertEq(loanFi.getAmountOfTokenBorrowed(user, tokens.link), 0, "User should have no LINK debt left");

        // 3. Verify protocol's WETH balance decreased by full collateral amount
        assertEq(
            finalProtocolWethBalance,
            initialProtocolWethBalance - userInitialCollateral,
            "Protocol should use all WETH collateral"
        );

        // 4. Verify protocol's LINK balance increased by debt amount
        assertEq(
            finalProtocolLinkBalance - initialProtocolLinkBalance,
            userInitialDebt,
            "Protocol should receive full debt amount in LINK"
        );

        // 5. Verify health factor is above minimum
        assertTrue(
            loanFi.getHealthFactor(user) >= loanFi.getMinimumHealthFactor(),
            "User health factor should be improved after liquidation"
        );

        // 6. Verify automation registry received the funds
        assertTrue(
            address(automationConfig.automationRegistry).balance >= 0,
            "Automation registry should maintain positive balance"
        );
    }

    /////////////////////
    //  LoanFi Tests  //
    ///////////////////

    /**
     * @notice Tests that the constructor properly initializes tokens and their price feeds
     * @dev This test verifies:
     * 1. The correct number of tokens are initialized
     * 2. Each token is properly mapped to its corresponding price feed
     * 3. All three tokens (tokens.weth, tokens.wbtc, tokens.link) are registered with correct price feeds
     * Test sequence:
     * 1. Get array of allowed tokens
     * 2. Verify array length
     * 3. For each token, verify its price feed mapping
     */
    function testLoanFiConstructor() public view {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = tokens.weth;
        testTokens[1] = tokens.wbtc;
        testTokens[2] = tokens.link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = priceFeeds.wethUsdPriceFeed;
        testFeeds[1] = priceFeeds.wbtcUsdPriceFeed;
        testFeeds[2] = priceFeeds.linkUsdPriceFeed;

        // Verify initialization
        address[] memory allowedTokens = loanFi.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], tokens.weth, "First token should be tokens.weth");
        assertEq(allowedTokens[1], tokens.wbtc, "Second token should be tokens.wbtc");
        assertEq(allowedTokens[2], tokens.link, "Third token should be tokens.link");

        // Verify price feed mappings
        assertEq(
            loanFi.getCollateralTokenPriceFeed(tokens.weth),
            priceFeeds.wethUsdPriceFeed,
            "tokens.weth price feed mismatch"
        );
        assertEq(
            loanFi.getCollateralTokenPriceFeed(tokens.wbtc),
            priceFeeds.wbtcUsdPriceFeed,
            "tokens.wbtc price feed mismatch"
        );
        assertEq(
            loanFi.getCollateralTokenPriceFeed(tokens.link),
            priceFeeds.linkUsdPriceFeed,
            "tokens.link price feed mismatch"
        );
    }

    function testliquidationWithdrawCollateralRevertsIfCalledByUser() public { 
        vm.prank(liquidator);
        vm.expectRevert(Errors.LoanFi__OnlyLiquidationEngine.selector);
        loanFi.liquidationWithdrawCollateral(tokens.weth, DEPOSIT_AMOUNT, user, liquidator);
    }

    function testliquidationPaybackBorrowedAmountRevertsIfCalledByUser() public { 
        vm.prank(liquidator);
        vm.expectRevert(Errors.LoanFi__OnlyLiquidationEngine.selector);
        loanFi.liquidationPaybackBorrowedAmount(tokens.weth, DEPOSIT_AMOUNT, user, liquidator);
    }

    function testSetAutomationContractRevertsIfCalledByNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        loanFi.setAutomationContract(user);
    }

    function testDepositAndBorrow() public { 
        uint256 linkAmountToBorrow = 10e18;
        uint256 userCollateralDepositedBefore = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 userAmountOfTokenBorrowedBefore = loanFi.getAmountOfTokenBorrowed(user, tokens.link);

        // First approve LoanFi to spend user's WETH
        vm.startPrank(user);
        ERC20Mock(tokens.weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        
        // Then deposit and borrow
        loanFi.DepositAndBorrow(tokens.weth, DEPOSIT_AMOUNT, tokens.link, linkAmountToBorrow);
        vm.stopPrank();

        uint256 userCollateralDepositedAfter = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 userAmountOfTokenBorrowedAfter = loanFi.getAmountOfTokenBorrowed(user, tokens.link);

        assertEq(userCollateralDepositedBefore, 0);
        assertEq(userCollateralDepositedAfter, DEPOSIT_AMOUNT);
        assertEq(userAmountOfTokenBorrowedBefore, 0);
        assertEq(userAmountOfTokenBorrowedAfter, linkAmountToBorrow);
    }

    function testPaybackandWithdraw() public UserDepositedAndBorrowedLink { 
        uint256 amountToPayback = 10e18;
        uint256 userCollateralDepositedBefore = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 userAmountOfTokenBorrowedBefore = loanFi.getAmountOfTokenBorrowed(user, tokens.link);

       vm.startPrank(user);
        ERC20Mock(tokens.link).approve(address(loanFi), amountToPayback);

        loanFi.paybackDebtAndWithdraw(tokens.link, amountToPayback, user, tokens.weth, DEPOSIT_AMOUNT);

        vm.stopPrank();

        uint256 userCollateralDepositedAfter = loanFi.getCollateralBalanceOfUser(user, tokens.weth);
        uint256 userAmountOfTokenBorrowedAfter = loanFi.getAmountOfTokenBorrowed(user, tokens.link);   

        assertEq(userCollateralDepositedBefore, DEPOSIT_AMOUNT);
        assertEq(userCollateralDepositedAfter, 0);
        assertEq(userAmountOfTokenBorrowedBefore, LINK_AMOUNT_TO_BORROW);
        assertEq(userAmountOfTokenBorrowedAfter, 0);
    }
}
