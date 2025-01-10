// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { OracleLib } from "./libraries/OracleLib.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Errors } from "src/libraries/Errors.sol";

contract CoreStorage is ReentrancyGuard {
    // Tracks how much collateral of each specific token a user has deposited
    // First key: user's address
    // Second key: token address they deposited
    // Value: amount of that token they have deposited
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    // Track borrowed amounts per user per token
    mapping(address user => mapping(address token => uint256 amount)) private s_TokenAmountsBorrowed;

    // maps token address to pricefeed addresses
    mapping(address token => address priceFeed) private s_priceFeeds;

    // Track total borrowed amounts per token
    mapping(address token => uint256 amount) private s_TotalTokenAmountsBorrowed;

    // an array of all the collateral & Borrowing tokens users can use.
    address[] private s_AllowedTokens;

    ///////////////////////////////
    //      State Variables      //
    ///////////////////////////////

    // Chainlink price feeds return prices with 8 decimal places
    // To maintain precision when working with USD values, we add 10 more decimal places
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

    uint256 private constant LIQUIDATION_THRESHOLD = 50;

    uint256 private constant LIQUIDATION_PRECISION = 100;

    uint256 private constant PRECISION = 1e18;

    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    uint256 private constant LIQUIDATION_BONUS = 10;

    ///////////////////////////////
    //           Events          //
    ///////////////////////////////

    // Event emitted when collateral is deposited, used for:
    // 1. Off-chain tracking of deposits
    // 2. DApp frontend updates
    // 3. Cheaper storage than writing to state
    // `indexed` parameters allow efficient filtering/searching of logs
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    event UserBorrowed(address indexed user, address indexed token, uint256 indexed amount);

    event BorrowedAmountRepaid(
        address indexed payer, address indexed onBehalfOf, address indexed token, uint256 amount
    );

    event CollateralWithdrawn(address indexed WithdrawnFrom, address WithdrawTo, address indexed token, uint256 amount);

    event UserLiquidated(address indexed collateral, address indexed userLiquidated, uint256 amountOfDebtPaid);

    ///////////////////
    //     Type     //
    //////////////////
    using OracleLib for AggregatorV3Interface;

    ///////////////////////////////
    //         Modifiers         //
    ///////////////////////////////

    // modifier to make sure that the amount being passes as the input is more than 0 or the function being called will
    // revert.
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert Errors.AmountNeedsMoreThanZero();
        }
        _;
    }

    // Modifier that checks if a token is in our list of allowed collateral tokens
    // If a token has no price feed address (equals address(0)) in our s_priceFeeds mapping,
    // it means it's not an allowed token and the transaction will revert
    // The underscore (_) means "continue with the function code if check passes"
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert Errors.TokenNotAllowed(token);
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
            revert Errors.CoreStorage__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // loop through the tokenAddresses array and count it by 1s
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            // and we set each tokenAddress equal to their respective priceFeedAddresses in the mapping.
            // we declare this in the constructor and define the variables in the deployment script
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            // push all the tokens into our tokens array/list
            s_AllowedTokens.push(tokenAddresses[i]);
        }
    }

    function getUsdValue(
        address token,
        uint256 amount // in WEI
    )
        external
        view
        returns (uint256)
    {
        return _getUsdValue(token, amount);
    }

    function _getUsdValue(address token, uint256 amount) internal view returns (uint256) {
        // gets the priceFeed of the token inputted by the user and saves it as a variable named priceFeed of type
        // AggregatorV3Interface
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        // out of all the data that is returned by the pricefeed, we only want to save the price
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // Calculate USD value while handling decimal precision:
        // 1. Convert price to uint256 and multiply by ADDITIONAL_FEED_PRECISION(1e10(add 10 zeros for precision)) to
        // match token decimals
        // 2. Multiply by the token amount
        // 3. Divide by PRECISION(1e18(for precision)) to get the final USD value with correct decimal places
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    /////////////////////////////////////
    //         Helper Functions         //
    /////////////////////////////////////

    function getMinimumHealthFactor() external pure returns (uint256) {
        // Returns minimum health factor before liquidation (1e18 = 1)
        return _getMinimumHealthFactor();
    }

    function _getMinimumHealthFactor() internal pure returns (uint256) {
        // Returns minimum health factor before liquidation (1e18 = 1)
        return MIN_HEALTH_FACTOR;
    }

    function getPrecision() external pure returns (uint256) {
        // Returns the precision scalar used for calculations (1e18)
        return _getPrecision();
    }

    function _getPrecision() internal pure returns (uint256) {
        // Returns the precision scalar used for calculations (1e18)
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        // Returns additional precision scalar for price feeds (1e10)
        return _getAdditionalFeedPrecision();
    }

    function _getAdditionalFeedPrecision() private pure returns (uint256) {
        // Returns additional precision scalar for price feeds (1e10)
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        // Returns the liquidation threshold (50 = 50% of collateral value used for health factor)
        return LIQUIDATION_THRESHOLD;
    }

    function _getLiquidationThreshold() internal pure returns (uint256) {
        // Returns the liquidation threshold (50 = 50% of collateral value used for health factor)
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        // Returns bonus percentage liquidators get when liquidating (10 = 10% bonus)
        return _getLiquidationBonus();
    }

    function _getLiquidationBonus() internal pure returns (uint256) {
        // Returns bonus percentage liquidators get when liquidating (10 = 10% bonus)
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        // Returns precision scalar for liquidation calculations (100)
        return _getLiquidationPrecision();
    }

    function _getLiquidationPrecision() internal pure returns (uint256) {
        // Returns precision scalar for liquidation calculations (100)
        return LIQUIDATION_PRECISION;
    }

    // Returns the array of all allowed collateral token addresses
    // This is useful for:
    // 1. UI interfaces to know which tokens can be used as collateral
    // 2. Other contracts that need to interact with the system
    // 3. Checking which tokens are supported without accessing state variables directly
    function getAllowedTokens() external view returns (address[] memory) {
        // Returns array of all accepted collateral token addresses
        return _getAllowedTokens();
    }

    function _getAllowedTokens() internal view returns (address[] memory) {
        // Returns array of all accepted collateral token addresses
        return s_AllowedTokens;
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

    function _getCollateralBalanceOfUser(address user, address token) internal view returns (uint256) {
        // Returns how much of a specific token a user has deposited as collateral
        return s_collateralDeposited[user][token];
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        // Returns how much of a specific token a user has deposited as collateral
        return _getCollateralBalanceOfUser(user, token);
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) external view returns (uint256) {
        return _getTokenAmountFromUsd(token, usdAmountInWei);
    }

    function _getTokenAmountFromUsd(address token, uint256 usdAmountInWei) internal view returns (uint256) {
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
        return (usdAmountInWei * _getPrecision()) / (uint256(price) * _getAdditionalFeedPrecision());
    }

    function updateCollateralDeposited(address user, address tokenDeposited, uint256 amount) internal {
        s_collateralDeposited[user][tokenDeposited] += amount;
    }

    function decreaseCollateralDeposited(address user, address tokenDeposited, uint256 amount) internal {
        s_collateralDeposited[user][tokenDeposited] -= amount;
    }

    function getAmountOfTokenBorrowed(address user, address token) external view returns (uint256) {
        return _getAmountOfTokenBorrowed(user, token);
    }

    function _getAmountOfTokenBorrowed(address user, address token) internal view returns (uint256) {
        return s_TokenAmountsBorrowed[user][token];
    }

    function increaseAmountOfTokenBorrowed(address user, address token, uint256 amount) private {
        s_TokenAmountsBorrowed[user][token] += amount;
    }

    function decreaseAmountOfTokenBorrowed(address user, address token, uint256 amount) private {
        s_TokenAmountsBorrowed[user][token] -= amount;
    }

    function getTotalTokenAmountsBorrowed(address token) external view returns (uint256) {
        return _getTotalTokenAmountsBorrowed(token);
    }

    function _getTotalTokenAmountsBorrowed(address token) internal view returns (uint256) {
        return s_TotalTokenAmountsBorrowed[token];
    }

    function increaseTotalTokenAmountsBorrowed(address token, uint256 amount) private {
        s_TotalTokenAmountsBorrowed[token] += amount;
    }

    function decreaseTotalTokenAmountsBorrowed(address token, uint256 amount) private {
        s_TotalTokenAmountsBorrowed[token] -= amount;
    }

    function increaseUserDebtAndTotalDebtBorrowed(address user, address token, uint256 amount) internal {
        increaseAmountOfTokenBorrowed(user, token, amount);
        increaseTotalTokenAmountsBorrowed(token, amount);
    }

    function decreaseUserDebtAndTotalDebtBorrowed(address user, address token, uint256 amount) internal {
        decreaseAmountOfTokenBorrowed(user, token, amount);
        decreaseTotalTokenAmountsBorrowed(token, amount);
    }
}
