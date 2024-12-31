// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OracleLib} from "./libraries/OracleLib.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Lending is ReentrancyGuard {
    ///////////////////////////////
    //           Errors          //
    ///////////////////////////////
    error LendingEngine__NeedsMoreThanZero();
    error LendingEngine__YouNeedMoreFunds();
    error LendingEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error LendingEngine__TokenNotAllowed(address token);
    error LendingEngine__TransferFailed();
    error Lending__BreaksHealthFactor(uint256);

    ///////////////////
    //     Type     //
    //////////////////
    using OracleLib for AggregatorV3Interface;

    ///////////////////////////////
    //      State Variables      //
    ///////////////////////////////

    // Chainlink price feeds return prices with 8 decimal places
    // To maintain precision when working with USD values, we add 10 more decimal places
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

    uint256 private constant LIQUIDATION_THRESHOLD = 50;

    uint256 private constant LIQUIDATION_PRECISION = 100;

    uint256 private constant PRECISION = 1;

    uint256 private constant MIN_HEALTH_FACTOR = 1;

    uint256 private constant LIQUIDATION_BONUS = 10;

    // tracks the balances of users
    mapping(address user => uint256 amountUserHas) private s_balances;

    // maps token address to pricefeed addresses
    mapping(address token => address priceFeed) private s_priceFeeds;

    mapping(address user => uint256 amountBorrowed) private s_AmountBorrowed;

    // an array of all the collateral tokens users can use.
    address[] private s_collateralTokens;

    // Tracks how much collateral each user has deposited
    // First key: user's address
    // Second key: token address they deposited
    // Value: amount of that token they have deposited
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    ///////////////////////////////
    //           Events          //
    ///////////////////////////////

    // Event emitted when collateral is deposited, used for:
    // 1. Off-chain tracking of deposits
    // 2. DApp frontend updates
    // 3. Cheaper storage than writing to state
    // `indexed` parameters allow efficient filtering/searching of logs
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    ///////////////////////////////
    //         Modifiers         //
    ///////////////////////////////

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

    ///////////////////////////////
    //         Functions         //
    ///////////////////////////////

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
        isAllowedToken(tokenCollateralAddress)
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
        //    - address(this): this Lending Engine contract receiving the collateral
        //    - amountCollateral: how many tokens to transfer
        // 3. This transferFrom function that we are calling returns a bool: true if transfer succeeded, false if it failed, so we capture the result
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateralSent);
        // This transferFrom will fail if there's no prior approval. The sequence must be:
        // 1. User approves Lending Engine to spend their tokens
        // User calls depositCollateral
        // Lending Engine uses transferFrom to move the tokens

        // if it is not successful, then revert.
        if (!success) {
            revert LendingEngine__TransferFailed();
        }
    }

    function borrowFunds() public {
        // make sure msg.sender health factor is greater than 1 / msg.sender must have collateral
        // make sure msg.sender is trying to borrow from the allowed tokens or throw error
        // do not allow borrowing if it makes the users health factor less than 1 or throw error
        // update
        // emit event when msg.sender borrows funds
    }

    function paybackBorrowedAmount() public {}

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will withdraw your collateral.
     * @notice If you have borrowed funds, you will not be able to redeem until you pay back borrowed funds
     */
    function withdrawCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        // user must have funds deposited to withdraw
        // user can only withdraw up to the amount he deposited
        // user must pay back the amount he borrowed before withdraw
        // withdraw
        // emit event
    }

    function liquidate() public {}

    function updateInterestRewardForLending() public /* onlyOwner */ {}

    function updateInterestRateForBorrowing() public /* onlyOwner */ {}

    function calculateHealthFactor(uint256 totalAmountBorrowed, uint256 collateralValueInUsd)
        public
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalAmountBorrowed, collateralValueInUsd);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // Loop through each token in our list of accepted collateral tokens
        // i = 0: Start with the first token in the array
        // i < length: Continue until we've checked every token
        // i++: Move to next token after each iteration
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            // Get the token address at the current index (i) from our array of collateral tokens
            // Example: If i = 0, might get WETH address
            // Example: If i = 1, might get WBTC address
            address token = s_collateralTokens[i];

            // Get how much of this specific token the user has deposited as collateral
            // Example: If user has deposited 5 WETH, amount = 5
            // Example: If user has deposited 2 WBTC, amount = 2
            uint256 amount = s_collateralDeposited[user][token];

            // After getting the token and the amount of tokens the user has, gets the correct amount of collateral the user has deposited and saves it as a variable named totalCollateralValueInUsd
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }

        // return the total amount of collateral in USD
        return totalCollateralValueInUsd;
    }

    ////////////////////////////////////////////////////
    //    Private & Internal View & Pure Functions    //
    ///////////////////////////////////////////////////

    function _calculateHealthFactor(uint256 totalAmountBorrowed, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        // If user hasn't borrowed any value, they have perfect health factor
        if (totalAmountBorrowed == 0) return type(uint256).max;

        // Adjust collateral value by liquidation threshold
        // Example: $1000 ETH * 50/100 = $500 adjusted collateral
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        // Calculate health factor: (adjusted collateral * PRECISION) / debt
        // Example: ($500 * 1e18) / $100 = 5e18 (health factor of 5)
        return (collateralAdjustedForThreshold * PRECISION) / totalAmountBorrowed;
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalAmountBorrowed, uint256 collateralValueInUsd)
    {
        // gets the amount a user has borrowed and saves it as a variable named totalAmountBorrowed
        totalAmountBorrowed = s_AmountBorrowed[user];
        // gets the total amount of collateral the user has deposited and saves it has a variable named collateralValueInUsd
        collateralValueInUsd = getAccountCollateralValue(user);
        // returns the users borrowed amount and the users collateral amount
        return (totalAmountBorrowed, collateralValueInUsd);
    }

    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        // gets the priceFeed of the token inputted by the user and saves it as a variable named priceFeed of type AggregatorV3Interface
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        // out of all the data that is returned by the pricefeed, we only want to save the price
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // Calculate USD value while handling decimal precision:
        // 1. Convert price to uint256 and multiply by ADDITIONAL_FEED_PRECISION(1e10(add 10 zeros for precision)) to match token decimals
        // 2. Multiply by the token amount
        // 3. Divide by PRECISION(1e18(for precision)) to get the final USD value with correct decimal places
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    /*
     * Returns how close to liquidation a user is
     * If a user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalAmountBorrowed, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalAmountBorrowed, collateralValueInUsd);
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        // grabs the user's health factor by calling _healthFactor
        uint256 userHealthFactor = _healthFactor(user);
        // if it is less than 1, revert.
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert Lending__BreaksHealthFactor(userHealthFactor);
        }
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalAmountBorrowed, uint256 collateralValueInUsd)
    {
        // External wrapper for _getAccountInformation
        // Returns how much DSC user has minted and their total collateral value in USD
        return _getAccountInformation(user);
    }

    function getUsdValue(
        address token,
        uint256 amount // in WEI
    ) external view returns (uint256) {
        return _getUsdValue(token, amount);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        // Returns how much of a specific token a user has deposited as collateral
        return s_collateralDeposited[user][token];
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        // Get the price feed for this token from our mapping
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);

        // Get the latest price from Chainlink
        // We only care about the price, so we ignore other returned values using commas
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        // Calculate how many tokens the USD amount can buy:
        // 1. Multiply usdAmount by PRECISION (1e18) for precision
        // 2. Divide by price (converted to uint) multiplied by ADDITIONAL_FEED_PRECISION (1e10)
        // Example: If price of ETH = $2000:
        // - To get 1 ETH worth: ($1000 * 1e18) / (2000 * 1e10) = 0.5 ETH
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getPrecision() external pure returns (uint256) {
        // Returns the precision scalar used for calculations (1e18)
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        // Returns additional precision scalar for price feeds (1e10)
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        // Returns the liquidation threshold (50 = 50% of collateral value used for health factor)
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        // Returns bonus percentage liquidators get when liquidating (10 = 10% bonus)
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        // Returns precision scalar for liquidation calculations (100)
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        // Returns minimum health factor before liquidation (1e18 = 1)
        return MIN_HEALTH_FACTOR;
    }

    // Returns the array of all allowed collateral token addresses
    // This is useful for:
    // 1. UI interfaces to know which tokens can be used as collateral
    // 2. Other contracts that need to interact with the system
    // 3. Checking which tokens are supported without accessing state variables directly
    function getCollateralTokens() external view returns (address[] memory) {
        // Returns array of all accepted collateral token addresses
        return s_collateralTokens;
    }

    // Returns the Chainlink price feed address for a given collateral token
    // Used for:
    // 1. Verifying price feed sources
    // 2. External systems that need to access the same price data
    // 3. Debugging and auditing price feed configurations
    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        // Returns Chainlink price feed address for given collateral token
        return s_priceFeeds[token];
    }

    // Returns the current health factor for a specific user
    // Health factor is a key metric that:
    // 1. Determines if a user can be liquidated (if < MIN_HEALTH_FACTOR)
    // 2. Shows how close to liquidation a user is
    // 3. Helps users monitor their position's safety
    function getHealthFactor(address user) external view returns (uint256) {
        // External wrapper to get a user's current health factor
        return _healthFactor(user);
    }
}
