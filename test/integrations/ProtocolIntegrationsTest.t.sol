// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { BorrowingEngine } from "src/BorrowingEngine.sol";
import { HealthFactor } from "src/HealthFactor.sol";
import { CoreStorage } from "src/CoreStorage.sol";
import { Inheritance } from "src/Inheritance.sol";
import { InterestRateEngine } from "src/InterestRateEngine.sol";
import { LendingEngine } from "src/LendingEngine.sol";
import { LiquidationEngine } from "src/LiquidationEngine.sol";
import { WithdrawEngine } from "src/WithdrawEngine.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeployProtocol } from "script/DeployProtocol.s.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";

contract LendingIntegrationsTest is Test {
    // Price feed and token addresses from helper config
    address public wethUsdPriceFeed; // Chainlink ETH/USD price feed address
    address public btcUsdPriceFeed; // Chainlink BTC/USD price feed address
    address public linkUsdPriceFeed; // Chainlink LINK/USD price feed address
    address public weth; // Wrapped ETH token address
    address public wbtc; // Wrapped BTC token address
    address public link; // LINK token address
    uint256 public deployerKey; // Private key of the deployer

    uint256 public constant DEPOSIT_AMOUNT = 5 ether;

    // This gives access to the struct `Contracts` and saves it as a variable named contracts
    // declare at contract level so the whole test file can have access to it
    DeployProtocol.Contracts public contracts;

    address public user = makeAddr("user"); // Address of the USER

    uint256 public constant STARTING_USER_BALANCE = 10 ether; // Initial balance given to test users

    function setUp() external {
        // Create a new instance of the deployment script
        DeployProtocol deployer = new DeployProtocol();

        // saves all the contracts to this variable `contracts` since the `deployProtocol` function returns all the
        // contracts
        contracts = deployer.deployProtocol();

        // Get the network configuration values from the helper:
        // - ETH/USD price feed address
        // - BTC/USD price feed address
        // - LINK/USD price feed address
        // - WETH token address
        // - WBTC token address
        // - LINK token address
        // - Deployer's private key
        (wethUsdPriceFeed, btcUsdPriceFeed, linkUsdPriceFeed, weth, wbtc, link, deployerKey) =
            contracts.helperConfig.activeNetworkConfig();

        // If we're on a local Anvil chain (chainId 31337)
        // Give our test user some ETH to work with
        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }

        // Mint initial balances of WETH, WBTC, LINK to our test user
        // This allows the user to have tokens to deposit as collateral
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(link).mint(user, STARTING_USER_BALANCE);
    }

    function testDepositWorks() public {
        // Start impersonating our test user
        vm.startPrank(user);
        // Approve DSCEngine to spend user's WETH
        ERC20Mock(weth).approve(address(contracts.lendingEngine), DEPOSIT_AMOUNT);

        // Deposit the collateral
        contracts.lendingEngine.depositCollateral(address(weth), DEPOSIT_AMOUNT);
        vm.stopPrank();
        uint256 expectedDepositedAmount = 5 ether;
        assertEq(contracts.coreStorage.balanceOf(user), expectedDepositedAmount);
    }
}
