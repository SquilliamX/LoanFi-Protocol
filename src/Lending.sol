// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Lending is ReentrancyGuard {
    error LendingEngine__NeedsMoreThanZero();
    error LendingEngine__YouNeedMoreFunds();
    error LendingEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error LendingEngine__TokenNotAllowed(address token);
    error LendingEngine__TransferFailed();

    // tracks the balances of users
    mapping(address user => uint256 amountUserHas) private s_balances;

    // maps token address to pricefeed addresses
    mapping(address token => address priceFeed) private s_priceFeeds;

    // an array of all the collateral tokens users can use.
    address[] private s_collateralTokens;

    // Tracks how much collateral each user has deposited
    // First key: user's address
    // Second key: token address they deposited
    // Value: amount of that token they have deposited
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    // Event emitted when collateral is deposited, used for:
    // 1. Off-chain tracking of deposits
    // 2. DApp frontend updates
    // 3. Cheaper storage than writing to state
    // `indexed` parameters allow efficient filtering/searching of logs
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    // modifier to make sure that the amount being passes as the input is more than 0 or the function being called will revert.
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert LendingEngine__NeedsMoreThanZero();
        }
        _;
    }

    // Modifier that checks if a token is in our list of allowed collateral tokens
    // If a token has no price feed address (equals address(0)) in our s_priceFeeds mapping,
    // it means it's not an allowed token and the transaction will revert
    // The underscore (_) means "continue with the function code if check passes"
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert LendingEngine__TokenNotAllowed(token);
        }
        _;
    }
    /* 
     * @param: tokenCollateralAddress is the token(address) users are depositing
     * @param: amountCollateral is the amount of they are depositing
     * @dev: Users main entry point to interact with the system.
    */

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses) {
        // if the amount of tokenAddresses is different from the amount of priceFeedAddresses, then revert
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert LendingEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // loop through the tokenAddresses array and count it by 1s
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            // and we set each tokenAddress equal to their respective priceFeedAddresses in the mapping.
            // we declare this in the constructor and define the variables in the deployment script
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            // push all the tokens into our tokens array/list
            s_collateralTokens.push(tokenAddresses[i]);
        }
    }

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateralSent)
        public
        moreThanZero(amountCollateralSent)
        nonReentrant
    {
        // require(s_balances[msg.sender] >= amountCollateralSent, "Not Enough"); // this is no good because string revert messages cost TOO MUCH GAS!

        // require the user to have more money in his wallet than he is sending, otherwise revert
        if (s_balances[msg.sender] < amountCollateralSent) {
            revert LendingEngine__YouNeedMoreFunds();
        }
        // we update state here, so when we update state, we must emit an event.
        // updates the user's balance in our tracking/mapping system by adding their new deposit amount to their existing balance for the specific collateral token they deposited
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateralSent;

        // emit the event of the state update
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateralSent);
        // Attempt to transfer tokens from the user to this contract
        // 1. IERC20(tokenCollateralAddress): Cast the token address to tell Solidity it's an ERC20 token
        // 2. transferFrom parameters:
        //    - msg.sender: the user who is depositing collateral
        //    - address(this): this DSCEngine contract receiving the collateral
        //    - amountCollateral: how many tokens to transfer
        // 3. This transferFrom function that we are calling returns a bool: true if transfer succeeded, false if it failed, so we capture the result
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateralSent);
        // This transferFrom will fail if there's no prior approval. The sequence must be:
        // 1. User approves DSCEngine to spend their tokens
        // User calls depositCollateral
        // DSCEngine uses transferFrom to move the tokens

        // if it is not successful, then revert.
        if (!success) {
            revert LendingEngine__TransferFailed();
        }
    }

    function borrowFunds() public {
        // make sure msg.sender health factor is greater than 1 / msg.sender must have collateral
        // make sure msg.sender is trying to borrow from the allowed tokens or throw error
        // do not allow borrowing if it makes the users health factor less than 1 or throw error
        // emit event when msg.sender borrows funds
    }

    function paybackBorrowedAmount() public {}

    function withdrawCollateral() public {
        // user must have funds deposited to withdraw
        // user can only withdraw up to the amount he deposited
        // user must pay back the amount he borrowed before withdraw
    }

    function liquidate() public {}

    function calculateHealthFactor() public {}

    function updateInterestRewardForLending() public /* onlyOwner */ {}

    function updateInterestRateForBorrowing() public /* onlyOwner */ {}
}
