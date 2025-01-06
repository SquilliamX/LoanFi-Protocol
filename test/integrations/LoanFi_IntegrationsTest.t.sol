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

    address public user = makeAddr("user"); // Address of the USER

    uint256 public constant STARTING_USER_BALANCE = 10 ether; // Initial balance given to test users

    // Arrays for token setup
    address[] public tokenAddresses; // Array to store allowed collateral token addresses
    address[] public feedAddresses; // Array to store corresponding price feed addresses

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

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

    ///////////////////////////
    //  HealthFactor Tests  //
    //////////////////////////

    ///////////////////////////
    //  LendingEngine Tests  //
    //////////////////////////

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

        vm.expectRevert(Errors.Lending__NeedsMoreThanZero.selector);
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
        vm.expectRevert(abi.encodeWithSelector(Errors.Lending__TokenNotAllowed.selector, address(dogToken)));
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
    //  BorrowingEngine Tests  //
    ////////////////////////////
}
