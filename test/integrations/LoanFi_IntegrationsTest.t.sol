// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { HealthFactor } from "src/HealthFactor.sol";
import { CoreStorage } from "src/CoreStorage.sol";
import { InterestRate } from "src/InterestRate.sol";
import { Lending } from "src/Lending.sol";
import { Liquidations } from "src/Liquidations.sol";
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

contract LoanFi_IntegrationsTest is Test {
    LoanFi loanFi;
    HelperConfig helperConfig;

    // Price feed and token addresses from helper config
    address public wethUsdPriceFeed; // Chainlink ETH/USD price feed address
    address public btcUsdPriceFeed; // Chainlink BTC/USD price feed address
    address public linkUsdPriceFeed; // Chainlink LINK/USD price feed address
    address public weth; // Wrapped ETH token address
    address public wbtc; // Wrapped BTC token address
    address public link; // LINK token address
    uint256 public deployerKey; // Private key of the deployer

    uint256 public constant DEPOSIT_AMOUNT = 5 ether;
    uint256 public constant LINK_AMOUNT_TO_BORROW = 10e18; // $100 USD
    uint256 public constant WETH_AMOUNT_TO_BORROW = 2e18; // $4,000 USD
    uint256 public constant WBTC_AMOUNT_TO_BORROW = 1e18; // $30,000 USD

    address public user = makeAddr("user"); // Address of the USER

    uint256 public constant STARTING_USER_BALANCE = 10 ether; // Initial balance given to test users

    // Arrays for token setup
    address[] public tokenAddresses; // Array to store allowed collateral token addresses
    address[] public feedAddresses; // Array to store corresponding price feed addresses

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    event UserBorrowed(address indexed user, address indexed token, uint256 indexed amount);

    event BorrowedAmountRepaid(
        address indexed payer, address indexed onBehalfOf, address indexed token, uint256 amount
    );

    function setUp() external {
        // Create a new instance of the deployment script
        DeployLoanFi deployer = new DeployLoanFi();

        // Deploy protocol (this will create its own HelperConfig)
        loanFi = deployer.deployLoanFi();

        helperConfig = deployer.helperConfig();

        // Get the network configuration values from the helper:
        // - ETH/USD price feed address
        // - BTC/USD price feed address
        // - LINK/USD price feed address
        // - WETH token address
        // - WBTC token address
        // - LINK token address
        // - Deployer's private key
        (wethUsdPriceFeed, btcUsdPriceFeed, linkUsdPriceFeed, weth, wbtc, link, deployerKey) =
            helperConfig.activeNetworkConfig();

        // Set up token and price feed arrays
        tokenAddresses = [weth, wbtc, link];
        feedAddresses = [wethUsdPriceFeed, btcUsdPriceFeed, linkUsdPriceFeed];

        // If we're on a local Anvil chain (chainId 31337), give our test user some ETH to work with
        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }

        // Mint initial balances of WETH, WBTC, LINK to our test user
        // This allows the user to have tokens to deposit as collateral
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(link).mint(user, STARTING_USER_BALANCE);

        ERC20Mock(weth).mint(address(loanFi), WETH_AMOUNT_TO_BORROW);
        ERC20Mock(wbtc).mint(address(loanFi), WBTC_AMOUNT_TO_BORROW);
        ERC20Mock(link).mint(address(loanFi), LINK_AMOUNT_TO_BORROW);
    }

    //////////////////////////
    //  CoreStorage Tests  //
    /////////////////////////

    /**
     * @notice Tests that the constructor reverts when token and price feed arrays have different lengths
     * @dev This ensures proper initialization of collateral tokens and their price feeds
     * Test sequence:
     * 1. Push WETH to token array
     * 2. Push ETH/USD and BTC/USD to price feed array
     * 3. Attempt to deploy CoreStorage with mismatched arrays
     * 4. Verify it reverts with correct error
     */
    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        // Setup: Create mismatched arrays
        tokenAddresses.push(weth); // Add only two tokens
        tokenAddresses.push(wbtc);

        feedAddresses.push(wethUsdPriceFeed); // Add three price feeds
        feedAddresses.push(btcUsdPriceFeed); // Creating a length mismatch
        feedAddresses.push(linkUsdPriceFeed);

        // Expect revert when arrays don't match in length
        vm.expectRevert(Errors.CoreStorage__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new CoreStorage(tokenAddresses, feedAddresses);
    }

    function testCoreStorageConstructor() public {
        // Create test arrays
        address[] memory testTokens = new address[](3);
        testTokens[0] = weth;
        testTokens[1] = wbtc;
        testTokens[2] = link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = wethUsdPriceFeed;
        testFeeds[1] = btcUsdPriceFeed;
        testFeeds[2] = linkUsdPriceFeed;

        // Deploy new CoreStorage
        CoreStorage coreStorage = new CoreStorage(testTokens, testFeeds);

        // Test initialization
        address[] memory allowedTokens = coreStorage.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], weth, "First token should be WETH");
        assertEq(allowedTokens[1], wbtc, "Second token should be WBTC");
        assertEq(allowedTokens[2], link, "Third token should be LINK");

        // Test price feed mappings
        assertEq(coreStorage.getCollateralTokenPriceFeed(weth), wethUsdPriceFeed, "WETH price feed mismatch");
        assertEq(coreStorage.getCollateralTokenPriceFeed(wbtc), btcUsdPriceFeed, "WBTC price feed mismatch");
        assertEq(coreStorage.getCollateralTokenPriceFeed(link), linkUsdPriceFeed, "LINK price feed mismatch");
    }

    function testGetCollateralBalanceOfUser() public UserDeposited {
        uint256 balance = loanFi.getCollateralBalanceOfUser(user, weth);
        assertEq(balance, DEPOSIT_AMOUNT);
    }

    function testGetCollateralTokenPriceFeed() public view {
        // Get the price feed address for WETH token
        address priceFeed = loanFi.getCollateralTokenPriceFeed(weth);
        // Verify it matches the expected WETH/USD price feed address
        assertEq(priceFeed, wethUsdPriceFeed);
    }

    // Tests that the array of collateral tokens contains the expected tokens
    function testAllowedTokens() public view {
        // Get the array of allowed collateral tokens
        address[] memory collateralTokens = loanFi.getAllowedTokens();
        // Verify WETH is at index 0 (first and only token in this test)
        assertEq(collateralTokens[0], weth);
        assertEq(collateralTokens[1], wbtc);
        assertEq(collateralTokens[2], link);
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
        uint256 usdValue = loanFi.getUsdValue(weth, ethAmount);
        assertEq(usdValue, expectedUsd);
    }

    /**
     * @notice Tests the conversion from USD value to token amount
     * @dev Verifies that getTokenAmountFromUsd correctly calculates token amounts based on price feeds
     * Test sequence:
     * 1. Request conversion of $100 worth of WETH
     * 2. With ETH price at $2000 (from mock), expect 0.05 WETH
     * 3. Compare actual result with expected amount
     */
    function testGetTokenAmountFromUsd() public view {
        // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
        uint256 expectedWeth = 0.05 ether;
        uint256 amountWeth = loanFi.getTokenAmountFromUsd(weth, 100 ether);
        assertEq(amountWeth, expectedWeth);
    }

    function testGetTotalTokenAmountsBorrowed() public UserDepositedAndBorrowedLink {
        uint256 totalAmountsBorrowed = loanFi.getTotalTokenAmountsBorrowed(link);
        uint256 expectedAmountBorrowed = 10e18;

        assertEq(totalAmountsBorrowed, expectedAmountBorrowed);
    }

    ///////////////////////////
    //  HealthFactor Tests  //
    //////////////////////////

    // Modifier to set up the test state with collateral deposited and user borrowed link
    modifier UserDepositedAndBorrowedLink() {
        // Start impersonating the test user
        vm.startPrank(user);
        // Approve the loanFi contract to spend user's WETH
        // User deposits $10,000
        ERC20Mock(weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(weth, DEPOSIT_AMOUNT);

        // Deposit collateral and borrow link in one transaction
        // link is $10/token, user borrows 10, so thats $100 borrowed
        loanFi.borrowFunds(link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();
        _;
    }

    modifier LiquidLoanFi() {
        uint256 liquidLinkVaults = 100_000e18;
        uint256 liquidWethVaults = 100_000e18;
        uint256 liquidWbtcVaults = 100_000e18;

        ERC20Mock(weth).mint(address(loanFi), 100_000e18);
        ERC20Mock(wbtc).mint(address(loanFi), 100_000e18);
        ERC20Mock(link).mint(address(loanFi), liquidLinkVaults);
        _;
    }

    function testHealthFactorConstructor() public {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = weth;
        testTokens[1] = wbtc;
        testTokens[2] = link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = wethUsdPriceFeed;
        testFeeds[1] = btcUsdPriceFeed;
        testFeeds[2] = linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        HealthFactor healthFactor = new HealthFactor(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = healthFactor.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], weth, "First token should be WETH");
        assertEq(allowedTokens[1], wbtc, "Second token should be WBTC");
        assertEq(allowedTokens[2], link, "Third token should be LINK");

        // Verify price feed mappings
        assertEq(healthFactor.getCollateralTokenPriceFeed(weth), wethUsdPriceFeed, "WETH price feed mismatch");
        assertEq(healthFactor.getCollateralTokenPriceFeed(wbtc), btcUsdPriceFeed, "WBTC price feed mismatch");
        assertEq(healthFactor.getCollateralTokenPriceFeed(link), linkUsdPriceFeed, "LINK price feed mismatch");
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

    function testGetAccountCollateralValueInUsd() public UserDeposited {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's WETH
        ERC20Mock(wbtc).approve(address(loanFi), DEPOSIT_AMOUNT);
        ERC20Mock(link).approve(address(loanFi), DEPOSIT_AMOUNT);
        loanFi.depositCollateral(wbtc, DEPOSIT_AMOUNT);
        loanFi.depositCollateral(link, DEPOSIT_AMOUNT);
        vm.stopPrank();

        // user deposited 5Link($10/Token) + 5 WETH($2000/Token) + 5WBTC($30,000) = $160,050
        uint256 expectedDepositedAmountInUsd = 160_050e18;
        assertEq(loanFi.getAccountCollateralValueInUsd(user), expectedDepositedAmountInUsd);
    }

    function testGetAccountBorrowedValueInUsd() public UserDeposited {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's WETH
        ERC20Mock(wbtc).approve(address(loanFi), DEPOSIT_AMOUNT);
        ERC20Mock(link).approve(address(loanFi), DEPOSIT_AMOUNT);
        // user deposited 5Link($10/Token) + 5 WETH($2000/Token) + 5WBTC($30,000) = $160,050
        loanFi.depositCollateral(wbtc, DEPOSIT_AMOUNT);
        loanFi.depositCollateral(link, DEPOSIT_AMOUNT);
        // user borrows $100 in link
        loanFi.borrowFunds(link, LINK_AMOUNT_TO_BORROW);
        // user borrows $4,000 in WETH
        loanFi.borrowFunds(weth, WETH_AMOUNT_TO_BORROW);
        // user borrows $30,000 in WBTC
        loanFi.borrowFunds(wbtc, WBTC_AMOUNT_TO_BORROW);
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
        uint256 link_amount_borrowed_reverts = 1000e18; // 1000 LINK = $10,000
        uint256 expectedHealthFactor = 5e17; // 0.5e18

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Errors.HealthFactor__BreaksHealthFactor.selector, expectedHealthFactor));
        loanFi.borrowFunds(link, link_amount_borrowed_reverts);
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
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(wethUsdUpdatedPrice);

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
        testTokens[0] = weth;
        testTokens[1] = wbtc;
        testTokens[2] = link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = wethUsdPriceFeed;
        testFeeds[1] = btcUsdPriceFeed;
        testFeeds[2] = linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        Lending lending = new Lending(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = lending.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], weth, "First token should be WETH");
        assertEq(allowedTokens[1], wbtc, "Second token should be WBTC");
        assertEq(allowedTokens[2], link, "Third token should be LINK");

        // Verify price feed mappings
        assertEq(lending.getCollateralTokenPriceFeed(weth), wethUsdPriceFeed, "WETH price feed mismatch");
        assertEq(lending.getCollateralTokenPriceFeed(wbtc), btcUsdPriceFeed, "WBTC price feed mismatch");
        assertEq(lending.getCollateralTokenPriceFeed(link), linkUsdPriceFeed, "LINK price feed mismatch");
    }

    // testing deposit function
    function testDepositWorks() public {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's WETH
        ERC20Mock(weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        // Deposit the collateral
        loanFi.depositCollateral(address(weth), DEPOSIT_AMOUNT);
        vm.stopPrank();
        uint256 expectedDepositedAmount = 5 ether;
        assertEq(loanFi.getCollateralBalanceOfUser(user, weth), expectedDepositedAmount);
    }

    function testDepositRevertsWhenDepositingZero() public {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's WETH
        ERC20Mock(weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        vm.expectRevert(Errors.AmountNeedsMoreThanZero.selector);
        // Deposit the collateral
        loanFi.depositCollateral(address(weth), 0);
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
        // Approve LendingEngine to spend user's WETH
        ERC20Mock(weth).approve(address(loanFi), 100 ether);
        vm.expectRevert(abi.encodeWithSelector(Errors.Lending__YouNeedMoreFunds.selector));
        loanFi.depositCollateral(weth, 100 ether);
        vm.stopPrank();
    }

    modifier UserDeposited() {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve LendingEngine to spend user's WETH
        ERC20Mock(weth).approve(address(loanFi), DEPOSIT_AMOUNT);
        loanFi.depositCollateral(weth, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testUpdatesUsersBalanceMappingWhenUserDeposits() public UserDeposited {
        assertEq(loanFi.getCollateralBalanceOfUser(user, weth), DEPOSIT_AMOUNT);
    }

    function testDepositEmitsEventWhenUserDeposits() public {
        // Set up the transaction that will emit the event
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        // Set up the event expectation immediately before the emitting call
        vm.expectEmit(true, true, true, false, address(loanFi));
        emit CollateralDeposited(user, weth, DEPOSIT_AMOUNT);

        // Make the call that should emit the event
        loanFi.depositCollateral(weth, DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testTokenTransferFromWorksWhenDepositing() public {
        // Record balances before deposit
        uint256 userBalanceBefore = ERC20Mock(weth).balanceOf(user);
        uint256 contractBalanceBefore = ERC20Mock(weth).balanceOf(address(loanFi));

        // Prank User and approve deposit
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        // Make deposit
        loanFi.depositCollateral(weth, DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Check balances after deposit
        uint256 userBalanceAfter = ERC20Mock(weth).balanceOf(user);
        uint256 contractBalanceAfter = ERC20Mock(weth).balanceOf(address(loanFi));

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
        // Setup array with WETH price feed for the mock token
        feedAddresses = [wethUsdPriceFeed];

        // Deploy new LoanFi instance with mock token as allowed collateral
        vm.prank(owner);
        LoanFi mockLoanFi = new LoanFi(tokenAddresses, feedAddresses);

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
        vm.expectRevert(Errors.Lending__TransferFailed.selector);
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
        testTokens[0] = weth;
        testTokens[1] = wbtc;
        testTokens[2] = link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = wethUsdPriceFeed;
        testFeeds[1] = btcUsdPriceFeed;
        testFeeds[2] = linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        Borrowing borrowing = new Borrowing(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = borrowing.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], weth, "First token should be WETH");
        assertEq(allowedTokens[1], wbtc, "Second token should be WBTC");
        assertEq(allowedTokens[2], link, "Third token should be LINK");

        // Verify price feed mappings
        assertEq(borrowing.getCollateralTokenPriceFeed(weth), wethUsdPriceFeed, "WETH price feed mismatch");
        assertEq(borrowing.getCollateralTokenPriceFeed(wbtc), btcUsdPriceFeed, "WBTC price feed mismatch");
        assertEq(borrowing.getCollateralTokenPriceFeed(link), linkUsdPriceFeed, "LINK price feed mismatch");
    }

    function testBorrowingWorksProperly() public UserDeposited {
        // get the amount the user borrowed before (which is 0)
        uint256 amountBorrowedBefore = loanFi.getAmountOfTokenBorrowed(user, link);
        // how much the user should be borrowing
        uint256 expectedAmountBorrowed = 10e18;
        // the next call comes from the user
        vm.prank(user);
        // borrow funds
        loanFi.borrowFunds(link, LINK_AMOUNT_TO_BORROW);

        // get the amount the user borrowed
        uint256 amountBorrowedAfter = loanFi.getAmountOfTokenBorrowed(user, link);

        // assert that the amount the user borrowed after the borrow call is more than before
        assert(amountBorrowedAfter > amountBorrowedBefore);
        // assert that the expected amount to borrow is what was borrowed
        assertEq(amountBorrowedAfter, expectedAmountBorrowed);
    }

    function testRevertIfUserBorrowsZero() public UserDeposited {
        uint8 borrowZeroAmount = 0;
        vm.prank(user);
        vm.expectRevert(Errors.AmountNeedsMoreThanZero.selector);
        loanFi.borrowFunds(link, borrowZeroAmount);
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
        ERC20Mock(weth).mint(otherUser, STARTING_USER_BALANCE);

        // Start impersonating the test user
        vm.startPrank(otherUser);
        // Approve the loanFi contract to spend user's WETH
        // User deposits $10,000
        ERC20Mock(weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(weth, DEPOSIT_AMOUNT);

        // test should revert since there is no link in the contract
        vm.expectRevert(Errors.Borrowing__NotEnoughAvailableCollateral.selector);
        // Deposit collateral and borrow link
        loanFi.borrowFunds(link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();

        uint256 actualAmountOfLinkInContract = loanFi.getTotalCollateralOfToken(link);
        uint256 expectedAmountOfLinkInContract = 0;
        assertEq(actualAmountOfLinkInContract, expectedAmountOfLinkInContract);
    }

    function testRevertsWhenThereIsNotEnoughCollateral() public UserDepositedAndBorrowedLink {
        uint256 twoLinkTokensAvailable = 2e18;
        ERC20Mock(link).mint(address(loanFi), twoLinkTokensAvailable);

        address otherUser = makeAddr("otherUser");
        ERC20Mock(weth).mint(otherUser, STARTING_USER_BALANCE);

        // Start impersonating the test user
        vm.startPrank(otherUser);
        // Approve the loanFi contract to spend user's WETH
        // User deposits $10,000
        ERC20Mock(weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(weth, DEPOSIT_AMOUNT);

        // test should revert since there is no link in the contract
        vm.expectRevert(Errors.Borrowing__NotEnoughAvailableCollateral.selector);
        // Deposit collateral and borrow link
        loanFi.borrowFunds(link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();

        uint256 actualAmountOfLinkInContract = loanFi.getTotalCollateralOfToken(link);
        uint256 expectedAmountOfLinkInContract = 2e18;
        assertEq(actualAmountOfLinkInContract, expectedAmountOfLinkInContract);
    }

    function testMappingsAreCorrectlyUpdatedAfterBorrowing() public UserDepositedAndBorrowedLink {
        uint256 amountBorrowed = loanFi.getAmountOfTokenBorrowed(user, link);
        uint256 expectedAmountBorrowedInMapping = 10e18;

        uint256 amountBorrowedInUsd = loanFi.getAccountBorrowedValueInUsd(user);
        uint256 expectedAmountBorrowedInUsd = 100e18;

        assertEq(amountBorrowed, expectedAmountBorrowedInMapping);
        assertEq(amountBorrowedInUsd, expectedAmountBorrowedInUsd);
    }

    function testBorrowTransfersAreWorkProperly() public UserDeposited {
        uint256 userLinkBalanceBefore = ERC20Mock(link).balanceOf(user);
        // Start impersonating the test user
        vm.startPrank(user);
        // Approve the loanFi contract to spend user's WETH
        // User deposits $10,000
        ERC20Mock(weth).approve(address(loanFi), DEPOSIT_AMOUNT);

        loanFi.depositCollateral(weth, DEPOSIT_AMOUNT);

        // Deposit collateral and borrow link in one transaction
        // link is $10/token, user borrows 10, so thats $100 borrowed
        loanFi.borrowFunds(link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();
        uint256 userLinkBalanceAfter = ERC20Mock(link).balanceOf(user);

        assert(userLinkBalanceAfter > userLinkBalanceBefore);
        assertEq(
            userLinkBalanceAfter - userLinkBalanceBefore,
            LINK_AMOUNT_TO_BORROW,
            "User should receive borrowed LINK tokens"
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
        // Setup array with WETH price feed for the mock token
        feedAddresses = [wethUsdPriceFeed];

        // Deploy new LoanFi instance with mock token as allowed collateral
        vm.prank(owner);
        LoanFi mockLoanFi = new LoanFi(tokenAddresses, feedAddresses);

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
        vm.expectRevert(Errors.Borrowing__TransferFailed.selector);
        mockBorrowing.borrowFunds(link, LINK_AMOUNT_TO_BORROW);
        // Stop impersonating the user
        vm.stopPrank();
    }

    function testBorrowingFundsEmitsEvent() public UserDeposited {
        // Set up the transaction that will emit the event
        vm.prank(user);
        // Set up the event expectation immediately before the emitting call
        vm.expectEmit(true, true, true, false, address(loanFi));
        emit UserBorrowed(user, link, LINK_AMOUNT_TO_BORROW);
        loanFi.borrowFunds(link, LINK_AMOUNT_TO_BORROW);
    }

    function testPaybackBorrowedAmountWorksProperly() public UserDepositedAndBorrowedLink {
        vm.startPrank(user);
        ERC20Mock(link).approve(address(loanFi), LINK_AMOUNT_TO_BORROW);

        loanFi.paybackBorrowedAmount(link, LINK_AMOUNT_TO_BORROW, user);
        vm.stopPrank();

        uint256 amountBorrowedAfterPayingBackDebt = loanFi.getAmountOfTokenBorrowed(user, link);

        assertEq(amountBorrowedAfterPayingBackDebt, 0, "Debt should be fully paid back");
    }

    function testPaybackBorrowedAmountRevertsIfAmountIsZero() public UserDepositedAndBorrowedLink {
        uint256 amountPaidBackZero = 0;
        vm.prank(user);
        vm.expectRevert(Errors.AmountNeedsMoreThanZero.selector);
        loanFi.paybackBorrowedAmount(link, amountPaidBackZero, user);
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
        vm.expectRevert(Errors.Borrowing__ZeroAddressNotAllowed.selector);
        // Attempt to payback on behalf of the zero address (this should fail)
        loanFi.paybackBorrowedAmount(link, LINK_AMOUNT_TO_BORROW, address(0));

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testPaybackBorrowedAmountRevertsWhenUserOverPaysDebt() public UserDepositedAndBorrowedLink {
        uint256 overpayAmountToPayBack = 10_000e18;
        // Start impersonating our test user
        vm.startPrank(user);

        // Expect revert with Borrowing__OverpaidDebt error when trying to deposit unapproved token
        vm.expectRevert(Errors.Borrowing__OverpaidDebt.selector);
        // Attempt to payback too much (this should fail)
        loanFi.paybackBorrowedAmount(link, overpayAmountToPayBack, user);

        // Stop impersonating the user
        vm.stopPrank();
    }

    function testBorrowedAmountMappingDecreasesWhenUserPayDebts() public UserDepositedAndBorrowedLink {
        uint256 amountBorrowed = loanFi.getAmountOfTokenBorrowed(user, link);

        vm.startPrank(user);
        ERC20Mock(link).approve(address(loanFi), LINK_AMOUNT_TO_BORROW);

        loanFi.paybackBorrowedAmount(link, LINK_AMOUNT_TO_BORROW, user);
        vm.stopPrank();

        uint256 amountBorrowedAfterDebtPaid = loanFi.getAmountOfTokenBorrowed(user, link);

        assert(amountBorrowed > amountBorrowedAfterDebtPaid);
        assertEq(amountBorrowedAfterDebtPaid, 0);
    }

    function testHealthFactorImprovesAfterRepayment() public UserDepositedAndBorrowedLink {
        uint256 healthFactorWhileBorrowing = loanFi.getHealthFactor(user);

        vm.startPrank(user);
        ERC20Mock(link).approve(address(loanFi), LINK_AMOUNT_TO_BORROW);

        loanFi.paybackBorrowedAmount(link, LINK_AMOUNT_TO_BORROW, user);
        vm.stopPrank();

        uint256 healthFactorAfterRepayment = loanFi.getHealthFactor(user);

        uint256 perfectHealthScoreAfterRepayment = type(uint256).max;

        assert(healthFactorWhileBorrowing < healthFactorAfterRepayment);
        assertEq(healthFactorAfterRepayment, perfectHealthScoreAfterRepayment);
    }

    function testUserCanRepayAPortionOfDebtInsteadOfFullDebt() public UserDepositedAndBorrowedLink {
        uint256 amountBorrowedBeforeRepayment = loanFi.getAmountOfTokenBorrowed(user, link);
        uint256 smallRepayment = 4e18;
        vm.startPrank(user);
        ERC20Mock(link).approve(address(loanFi), smallRepayment);

        loanFi.paybackBorrowedAmount(link, smallRepayment, user);
        vm.stopPrank();

        uint256 amountBorrowedAfterRepayment = loanFi.getAmountOfTokenBorrowed(user, link);
        uint256 expectedDebtLeft = 6e18;

        assert(amountBorrowedBeforeRepayment > amountBorrowedAfterRepayment);
        assertEq(amountBorrowedBeforeRepayment - smallRepayment, expectedDebtLeft);
    }

    function testUsersHealthFactorImprovesAfterPartialRepayment() public UserDepositedAndBorrowedLink {
        uint256 healthFactorBeforeRepayment = loanFi.getHealthFactor(user);
        uint256 smallRepayment = 5e18;
        vm.startPrank(user);
        ERC20Mock(link).approve(address(loanFi), smallRepayment);

        loanFi.paybackBorrowedAmount(link, smallRepayment, user);
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

        ERC20Mock(link).mint(user2, 100e18);
        ERC20Mock(link).approve(address(loanFi), amountToRepay);

        loanFi.paybackBorrowedAmount(link, amountToRepay, user);

        vm.stopPrank();

        assertEq(loanFi.getAmountOfTokenBorrowed(user, link), 0);
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
        // Setup array with WETH price feed for the mock token
        feedAddresses = [wethUsdPriceFeed];

        // Deploy new LoanFi instance with mock token as allowed collateral
        vm.prank(owner);
        LoanFi mockLoanFi = new LoanFi(tokenAddresses, feedAddresses);

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
        vm.expectRevert(Errors.Borrowing__TransferFailed.selector);
        mockBorrowing.paybackBorrowedAmount(address(mockBorrowing), amountToRepay, user);

        vm.stopPrank();
    }

    function testRepaymentEmitsEvent() public UserDepositedAndBorrowedLink {
        uint256 amountToRepay = 10e18;
        vm.startPrank(user);
        ERC20Mock(link).approve(address(loanFi), amountToRepay);

        vm.expectEmit(true, true, true, true, address(loanFi));
        emit BorrowedAmountRepaid(user, user, link, amountToRepay);

        loanFi.paybackBorrowedAmount(link, amountToRepay, user);
        vm.stopPrank();
    }

    function testGetTotalCollateralOfToken() public view {
        uint256 expectedCollateralAmount = 10e18;

        uint256 actualCollateralAmount = loanFi.getTotalCollateralOfToken(link);

        assertEq(actualCollateralAmount, expectedCollateralAmount);
    }

    function testGetAvailableToBorrow() public view {
        uint256 expectedCollateral = 10e18;
        uint256 actualCollateral = loanFi.getAvailableToBorrow(link);

        assertEq(actualCollateral, expectedCollateral);
    }

    /////////////////////////
    //  Liquidation Tests  //
    /////////////////////////

    function testLiquidationsConstructor() public {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = weth;
        testTokens[1] = wbtc;
        testTokens[2] = link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = wethUsdPriceFeed;
        testFeeds[1] = btcUsdPriceFeed;
        testFeeds[2] = linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        Liquidations liquidations = new Liquidations(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = liquidations.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], weth, "First token should be WETH");
        assertEq(allowedTokens[1], wbtc, "Second token should be WBTC");
        assertEq(allowedTokens[2], link, "Third token should be LINK");

        // Verify price feed mappings
        assertEq(liquidations.getCollateralTokenPriceFeed(weth), wethUsdPriceFeed, "WETH price feed mismatch");
        assertEq(liquidations.getCollateralTokenPriceFeed(wbtc), btcUsdPriceFeed, "WBTC price feed mismatch");
        assertEq(liquidations.getCollateralTokenPriceFeed(link), linkUsdPriceFeed, "LINK price feed mismatch");
    }

    ///////////////////////////
    //     Withdraw Tests    //
    //////////////////////////

    function testWithdrawConstructor() public {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = weth;
        testTokens[1] = wbtc;
        testTokens[2] = link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = wethUsdPriceFeed;
        testFeeds[1] = btcUsdPriceFeed;
        testFeeds[2] = linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        Withdraw withdraw = new Withdraw(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = withdraw.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], weth, "First token should be WETH");
        assertEq(allowedTokens[1], wbtc, "Second token should be WBTC");
        assertEq(allowedTokens[2], link, "Third token should be LINK");

        // Verify price feed mappings
        assertEq(withdraw.getCollateralTokenPriceFeed(weth), wethUsdPriceFeed, "WETH price feed mismatch");
        assertEq(withdraw.getCollateralTokenPriceFeed(wbtc), btcUsdPriceFeed, "WBTC price feed mismatch");
        assertEq(withdraw.getCollateralTokenPriceFeed(link), linkUsdPriceFeed, "LINK price feed mismatch");
    }

    //////////////////////////
    //  InterestRate Tests  //
    //////////////////////////

    function testInterestRateConstructor() public {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = weth;
        testTokens[1] = wbtc;
        testTokens[2] = link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = wethUsdPriceFeed;
        testFeeds[1] = btcUsdPriceFeed;
        testFeeds[2] = linkUsdPriceFeed;

        // Deploy new HealthFactor instance
        InterestRate interestRate = new InterestRate(testTokens, testFeeds);

        // Verify initialization
        address[] memory allowedTokens = interestRate.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], weth, "First token should be WETH");
        assertEq(allowedTokens[1], wbtc, "Second token should be WBTC");
        assertEq(allowedTokens[2], link, "Third token should be LINK");

        // Verify price feed mappings
        assertEq(interestRate.getCollateralTokenPriceFeed(weth), wethUsdPriceFeed, "WETH price feed mismatch");
        assertEq(interestRate.getCollateralTokenPriceFeed(wbtc), btcUsdPriceFeed, "WBTC price feed mismatch");
        assertEq(interestRate.getCollateralTokenPriceFeed(link), linkUsdPriceFeed, "LINK price feed mismatch");
    }

    /////////////////////
    //  LoanFi Tests  //
    ///////////////////

    /**
     * @notice Tests that the constructor properly initializes tokens and their price feeds
     * @dev This test verifies:
     * 1. The correct number of tokens are initialized
     * 2. Each token is properly mapped to its corresponding price feed
     * 3. All three tokens (WETH, WBTC, LINK) are registered with correct price feeds
     * Test sequence:
     * 1. Get array of allowed tokens
     * 2. Verify array length
     * 3. For each token, verify its price feed mapping
     */
    function testLoanFiConstructor() public view {
        // Create new arrays for tokens and price feeds
        address[] memory testTokens = new address[](3);
        testTokens[0] = weth;
        testTokens[1] = wbtc;
        testTokens[2] = link;

        address[] memory testFeeds = new address[](3);
        testFeeds[0] = wethUsdPriceFeed;
        testFeeds[1] = btcUsdPriceFeed;
        testFeeds[2] = linkUsdPriceFeed;

        // Verify initialization
        address[] memory allowedTokens = loanFi.getAllowedTokens();
        assertEq(allowedTokens.length, 3, "Should have 3 allowed tokens");
        assertEq(allowedTokens[0], weth, "First token should be WETH");
        assertEq(allowedTokens[1], wbtc, "Second token should be WBTC");
        assertEq(allowedTokens[2], link, "Third token should be LINK");

        // Verify price feed mappings
        assertEq(loanFi.getCollateralTokenPriceFeed(weth), wethUsdPriceFeed, "WETH price feed mismatch");
        assertEq(loanFi.getCollateralTokenPriceFeed(wbtc), btcUsdPriceFeed, "WBTC price feed mismatch");
        assertEq(loanFi.getCollateralTokenPriceFeed(link), linkUsdPriceFeed, "LINK price feed mismatch");
    }
}
