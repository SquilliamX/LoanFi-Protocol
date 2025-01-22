// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Errors } from "src/libraries/Errors.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { OracleLib } from "./libraries/OracleLib.sol";

/**
 * @title CoreStorage Contract
 * @author William Permuy
 * @notice Core storage and state management for the lending protocol
 * @dev Implements foundational storage patterns with the following features:
 *
 * Architecture Highlights:
 * 1. State Management
 *    - Secure token tracking
 *    - User position management
 *    - Protocol-wide accounting
 *    - Price feed integration
 *
 * 2. Security Features
 *    - Reentrancy protection
 *    - Safe math operations
 *    - Access control
 *    - Input validation
 *
 * 3. Oracle Integration
 *    - Chainlink price feeds
 *    - Stale price protection
 *    - Precision handling
 *    - USD value calculations
 *
 * 4. Protocol Parameters
 *    - Liquidation thresholds
 *    - Health factors
 *    - Precision scalars
 *    - Bonus incentives
 *
 * Storage Layout:
 * - Collateral mappings
 * - Debt tracking
 * - User management
 * - Protocol configuration
 *
 * Inherits:
 * - ReentrancyGuard: Protection against reentrancy attacks
 */
contract CoreStorage is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Applies OracleLib functions to Chainlink price feed interface
    /// @dev Library extension pattern for enhanced oracle functionality:
    /// - Adds stale price checking
    /// - Provides safe price retrieval methods
    /// - Standardizes oracle interactions
    /// Prevents usage of outdated or manipulated prices
    using OracleLib for AggregatorV3Interface;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Additional precision for price feed calculations (10 decimals)
    /// @dev Chainlink feeds return 8 decimals, we add 10 more for higher precision
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

    /// @notice Percentage of collateral that can be borrowed against (50%)
    /// @dev Used in health factor calculations to maintain protocol safety margin
    /// @dev 50 means users can borrow up to 50% of their collateral value
    uint256 private constant LIQUIDATION_THRESHOLD = 50;

    /// @notice Scalar for liquidation calculations (100 = 100%)
    /// @dev Used to convert liquidation threshold to percentage
    /// @dev Example: 50/100 = 0.5 = 50%
    uint256 private constant LIQUIDATION_PRECISION = 100;

    /// @notice Standard precision scalar for protocol calculations
    /// @dev Used for consistent decimal handling across all value calculations
    /// @dev Matches ETH's 18 decimals for seamless integration
    uint256 private constant PRECISION = 1e18;

    /// @notice Minimum health factor before liquidation (1.0 = 1e18)
    /// @dev Positions below this threshold are eligible for liquidation
    /// @dev Scaled by PRECISION for decimal handling
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    /// @notice Bonus percentage for liquidators (10%)
    /// @dev Incentivizes liquidators to maintain protocol solvency
    /// @dev Example: 10% bonus on $1000 liquidation = $100 profit
    uint256 private constant LIQUIDATION_BONUS = 10;

    /// @notice Array of supported collateral and borrowing tokens
    /// @dev Controlled by protocol governance
    /// @dev Used for iterating supported assets and validation
    address[] private s_AllowedTokens;

    /// @notice Array of all users who have interacted with protocol
    /// @dev Used for protocol analytics and batch processing
    /// @dev Critical for liquidation monitoring system
    address[] private s_users;

    /// @notice Maps user addresses to their collateral deposits per token
    /// @dev Double mapping pattern for efficient collateral tracking
    /// First key: User's address (depositor)
    /// Second key: Token address (collateral type)
    /// Value: Amount deposited in token's native decimals
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    /// @notice Maps user addresses to their borrowed amounts per token
    /// @dev Critical for tracking user debt positions
    /// First key: User's address (borrower)
    /// Second key: Token address (borrowed asset)
    /// Value: Amount borrowed in token's native decimals
    mapping(address user => mapping(address token => uint256 amount)) private s_TokenAmountsBorrowed;

    /// @notice Maps token addresses to their respective price feed contracts
    /// @dev Used for real-time USD value calculations
    /// Key: Token address
    /// Value: Chainlink price feed address
    mapping(address token => address priceFeed) private s_priceFeeds;

    /// @notice Tracks total borrowed amounts per token across all users
    /// @dev Essential for protocol-wide risk assessment and liquidity management
    /// Key: Token address
    /// Value: Total amount borrowed in token's native decimals
    mapping(address token => uint256 amount) private s_TotalTokenAmountsBorrowed;

    /// @notice Tracks whether a user has ever deposited collateral
    /// @dev Used for user array management and protocol analytics
    /// Key: User address
    /// Value: Boolean indicating deposit history
    mapping(address userAddress => bool hasDepositedCollateral) private s_userHasDepositedCollateral;

    // Chainlink price feeds return prices with 8 decimal places
    // To maintain precision when working with USD values, we add 10 more decimal places

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user deposits collateral into the protocol
    /// @dev Indexed parameters optimize event filtering for off-chain services
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    /// @notice Emitted when a user borrows tokens from the protocol
    /// @dev Tracks borrowing activity for risk monitoring
    event UserBorrowed(address indexed user, address indexed token, uint256 indexed amount);

    /// @notice Emitted when borrowed tokens are repaid
    /// @dev Supports altruistic repayments (payer != onBehalfOf)
    event BorrowedAmountRepaid(
        address indexed payer, address indexed onBehalfOf, address indexed token, uint256 amount
    );

    /// @notice Emitted when collateral is withdrawn from the protocol
    /// @dev Tracks both partial and full withdrawals
    event CollateralWithdrawn(
        address indexed token, uint256 indexed amount, address indexed WithdrawnFrom, address WithdrawTo
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures input amount is greater than zero
    /// @dev Prevents zero-value transactions that waste gas
    /// @param amount The value to validate
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert Errors.AmountNeedsMoreThanZero();
        }
        _;
    }

    /// @notice Validates token is supported by protocol
    /// @dev Checks token has associated price feed
    /// @param token The token address to validate
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert Errors.TokenNotAllowed(token);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Tracks new users when they first deposit collateral
    /// @dev Updates user array and deposit status atomically
    function _addUser(address user) internal {
        if (!s_userHasDepositedCollateral[user]) {
            s_users.push(user);
            s_userHasDepositedCollateral[user] = true;
        }
    }

    /// @notice Increases user's collateral balance for a specific token
    /// @dev Updates collateral tracking, handles arithmetic overflow
    function updateCollateralDeposited(address user, address tokenDeposited, uint256 amount) internal {
        s_collateralDeposited[user][tokenDeposited] += amount;
    }

    /// @notice Decreases user's collateral balance for a specific token
    /// @dev Updates collateral tracking, handles arithmetic underflow
    function decreaseCollateralDeposited(address user, address tokenDeposited, uint256 amount) internal {
        s_collateralDeposited[user][tokenDeposited] -= amount;
    }

    /// @notice Updates both user and protocol-wide debt tracking
    /// @dev Atomic update of related debt states
    function increaseUserDebtAndTotalDebtBorrowed(address user, address token, uint256 amount) internal {
        increaseAmountOfTokenBorrowed(user, token, amount);
        increaseTotalTokenAmountsBorrowed(token, amount);
    }

    /// @notice Decreases both user and protocol-wide debt tracking
    /// @dev Atomic update of related debt states
    function decreaseUserDebtAndTotalDebtBorrowed(address user, address token, uint256 amount) internal {
        decreaseAmountOfTokenBorrowed(user, token, amount);
        decreaseTotalTokenAmountsBorrowed(token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates user's borrowed amount for a specific token
    /// @dev Safe math handles overflow protection
    function increaseAmountOfTokenBorrowed(address user, address token, uint256 amount) private {
        s_TokenAmountsBorrowed[user][token] += amount;
    }

    /// @notice Reduces user's borrowed amount for a specific token
    /// @dev Safe math handles underflow protection
    function decreaseAmountOfTokenBorrowed(address user, address token, uint256 amount) private {
        s_TokenAmountsBorrowed[user][token] -= amount;
    }

    /// @notice Updates protocol's total borrowed amount for a token
    /// @dev Maintains global debt tracking
    function increaseTotalTokenAmountsBorrowed(address token, uint256 amount) private {
        s_TotalTokenAmountsBorrowed[token] += amount;
    }

    /// @notice Reduces protocol's total borrowed amount for a token
    /// @dev Maintains global debt tracking
    function decreaseTotalTokenAmountsBorrowed(address token, uint256 amount) private {
        s_TotalTokenAmountsBorrowed[token] -= amount;
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL & PRIVATE VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /// @notice Returns array of protocol-supported tokens
    /// @dev Used for token validation and iteration
    function _getAllowedTokens() internal view returns (address[] memory) {
        return s_AllowedTokens;
    }

    /// @notice Gets user's collateral balance for specific token
    /// @dev Direct state access for internal calculations
    function _getCollateralBalanceOfUser(address user, address token) internal view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    /// @notice Retrieves user's borrowed amount for token
    /// @dev Used in debt calculations and validations
    function _getAmountOfTokenBorrowed(address user, address token) internal view returns (uint256) {
        return s_TokenAmountsBorrowed[user][token];
    }

    /// @notice Gets total protocol-wide borrows for token
    /// @dev Critical for liquidity calculations
    function _getTotalTokenAmountsBorrowed(address token) internal view returns (uint256) {
        return s_TotalTokenAmountsBorrowed[token];
    }

    /// @notice Returns minimum health factor threshold
    /// @dev Used in liquidation eligibility checks
    function _getMinimumHealthFactor() internal pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    /// @notice Returns protocol's precision scalar
    /// @dev Used for consistent decimal handling
    function _getPrecision() internal pure returns (uint256) {
        return PRECISION;
    }

    /// @notice Returns collateral usage threshold
    /// @dev Determines maximum borrowing capacity
    function _getLiquidationThreshold() internal pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    /// @notice Returns liquidator's bonus percentage
    /// @dev Used to calculate liquidation incentives
    function _getLiquidationBonus() internal pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    /// @notice Returns liquidation precision scalar
    /// @dev Used for percentage calculations in liquidations
    function _getLiquidationPrecision() internal pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    /// @notice Returns price feed precision adjustment
    /// @dev Aligns Chainlink's 8 decimals with protocol's 18
    function _getAdditionalFeedPrecision() private pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                EXTERNAL & PUBLIC VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves a batch of protocol users for efficient processing
     * @dev Implements pagination pattern with the following features:
     * - Gas-efficient batch processing
     * - Size limits for DoS protection
     * - Safe array handling
     *
     * @param batchSize Number of users to retrieve (max 100)
     * @param offset Starting position in user list
     * @return users Array of user addresses in requested batch
     * @return totalUsers Total number of protocol users
     */
    function getUserBatch(
        uint256 batchSize,
        uint256 offset
    )
        external
        view
        returns (address[] memory users, uint256 totalUsers)
    {
        // Prevent excessive gas consumption with batch size limit
        if (batchSize > 100) {
            revert Errors.CoreStorage__BatchSizeTooLarge();
        }

        // Get total user count for pagination
        uint256 length = s_users.length;
        if (offset >= length) {
            return (new address[](0), length);
        }

        // Calculate actual batch size based on remaining users
        uint256 endIndex = offset + batchSize;
        if (endIndex > length) {
            endIndex = length;
        }

        // Initialize array with exact size needed
        uint256 batchLength = endIndex - offset;
        users = new address[](batchLength);

        // Fill array with user addresses from storage
        for (uint256 i = 0; i < batchLength; i++) {
            users[i] = s_users[offset + i];
        }

        return (users, length);
    }

    /**
     * @notice Calculates USD value of token amount using Chainlink oracle
     * @dev External wrapper for USD value calculation
     * @param token The token address to value
     * @param amount The amount in token's native decimals
     * @return uint256 USD value with protocol precision
     */
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

    // Returns the array of all allowed collateral token addresses
    // This is useful for:
    // 1. UI interfaces to know which tokens can be used as collateral
    // 2. Other contracts that need to interact with the system
    // 3. Checking which tokens are supported without accessing state variables directly
    function getAllowedTokens() external view returns (address[] memory) {
        // Returns array of all accepted collateral token addresses
        return _getAllowedTokens();
    }

    /**
     * @notice Returns Chainlink price feed for a given token
     * @dev Used for external price verification and integration
     */
    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    /**
     * @notice Returns user's collateral balance for a token
     * @dev External wrapper for collateral balance queries
     */
    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return _getCollateralBalanceOfUser(user, token);
    }

    /**
     * @notice Converts USD amount to equivalent token amount
     * @dev Uses Chainlink price feed for conversion
     */
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) external view returns (uint256) {
        return _getTokenAmountFromUsd(token, usdAmountInWei);
    }

    /**
     * @notice Returns user's borrowed amount for a token
     * @dev External access to debt position data
     */
    function getAmountOfTokenBorrowed(address user, address token) external view returns (uint256) {
        return _getAmountOfTokenBorrowed(user, token);
    }

    /**
     * @notice Returns total protocol borrows for a token
     * @dev Used for protocol-wide debt monitoring
     */
    function getTotalTokenAmountsBorrowed(address token) external view returns (uint256) {
        return _getTotalTokenAmountsBorrowed(token);
    }

    /**
     * @notice Returns minimum health factor threshold
     * @dev Used to determine liquidation eligibility
     */
    function getMinimumHealthFactor() external pure returns (uint256) {
        return _getMinimumHealthFactor();
    }

    /**
     * @notice Returns protocol's precision scalar
     * @dev Used for decimal standardization
     */
    function getPrecision() external pure returns (uint256) {
        return _getPrecision();
    }

    /**
     * @notice Returns price feed precision adjustment
     * @dev Aligns Chainlink and protocol decimals
     */
    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return _getAdditionalFeedPrecision();
    }

    /**
     * @notice Returns protocol's collateral utilization limit
     * @dev Defines maximum borrowing capacity (50% of collateral)
     */
    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    /**
     * @notice Returns liquidator's incentive percentage
     * @dev Incentivizes timely liquidations (10% bonus)
     */
    function getLiquidationBonus() external pure returns (uint256) {
        return _getLiquidationBonus();
    }

    /**
     * @notice Returns liquidation calculation precision
     * @dev Standardizes percentage calculations (100 = 100%)
     */
    function getLiquidationPrecision() external pure returns (uint256) {
        return _getLiquidationPrecision();
    }
}
