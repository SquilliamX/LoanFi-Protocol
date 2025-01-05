// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { HealthFactor } from "./HealthFactor.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { OracleLib } from "./libraries/OracleLib.sol";
import { Errors } from "./Errors.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";

contract LendingPool is ReentrancyGuard, Errors, ILendingPool {
    // Tracks how much collateral of each specific token a user has deposited
    // First key: user's address
    // Second key: token address they deposited
    // Value: amount of that token they have deposited
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    // tracks the total balances of users
    // should only be used to check a specific token balance of an address
    mapping(address account => uint256 amount) private s_balances;

    // Track borrowed amounts per user per token
    mapping(address user => mapping(address token => uint256 amount)) private s_TokenAmountsBorrowed;

    // maps token address to pricefeed addresses
    mapping(address token => address priceFeed) private s_priceFeeds;

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

    uint256 private constant PRECISION = 1;

    uint256 private constant MIN_HEALTH_FACTOR = 1;

    uint256 private constant LIQUIDATION_BONUS = 10;

    HealthFactor private immutable i_healthFactor;

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
            s_AllowedTokens.push(tokenAddresses[i]);
        }

        i_healthFactor = new HealthFactor(tokenAddresses, priceFeedAddresses, address(this));
    }

    /////////////////////////////////////
    //        Public Functions         //
    ////////////////////////////////////

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateralSent) public nonReentrant {
        _depositCollateral(tokenCollateralAddress, amountCollateralSent);
    }

    function borrowFunds(address tokenToBorrow, uint256 amountToBorrow) public nonReentrant {
        _borrowFunds(tokenToBorrow, amountToBorrow);
    }

    function paybackBorrowedAmount(
        address tokenToPayBack,
        uint256 amountToPayBack,
        address onBehalfOf
    )
        public
        nonReentrant
    {
        _paybackBorrowedAmount(tokenToPayBack, amountToPayBack, onBehalfOf);
    }

    ///////////////////////////////////////
    //         Private Functions         //
    //////////////////////////////////////

    function _depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateralSent
    )
        private
        moreThanZero(amountCollateralSent)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // require(s_balances[msg.sender] >= amountCollateralSent, "Not Enough"); // this is no good because string
        // revert messages cost TOO MUCH GAS!

        // Check if user has enough of the token they want to deposit
        if (IERC20(tokenCollateralAddress).balanceOf(msg.sender) < amountCollateralSent) {
            revert LendingEngine__YouNeedMoreFunds();
        }
        // we update state here, so when we update state, we must emit an event.
        // updates the user's balance in our tracking/mapping system by adding their new deposit amount to their existing balance for the specific collateral token they deposited
        updateCollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateralSent);

        // emit the event of the state update
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateralSent);
        // Attempt to transfer tokens from the user to this contract
        // 1. IERC20(tokenCollateralAddress): Cast the token address to tell Solidity it's an ERC20 token
        // 2. transferFrom parameters:
        //    - msg.sender: the user who is depositing collateral
        //    - address(this): this Lending Engine contract receiving the collateral
        //    - amountCollateral: how many tokens to transfer
        // 3. This transferFrom function that we are calling returns a bool: true if transfer succeeded, false if it
        // failed, so we capture the result
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

    function _borrowFunds(
        address tokenToBorrow,
        uint256 amountToBorrow
    )
        private
        moreThanZero(amountToBorrow)
        isAllowedToken(tokenToBorrow)
        nonReentrant
    {
        // get the amount available to borrow
        uint256 availableToBorrow = getAvailableToBorrow(tokenToBorrow);
        // if user is trying to borrow more than available, revert
        if (amountToBorrow > availableToBorrow) {
            revert LendingEngine__NotEnoughAvailableTokens();
        }

        // Get USD value of borrow amount
        uint256 borrowAmountInUsd = getUsdValue(tokenToBorrow, amountToBorrow);

        // Track the specific token amounts & USD amounts borrowed
        increaseAmountOfTokenBorrowed(msg.sender, tokenToBorrow, amountToBorrow);

        // This will check if total borrowed exceeds collateral limits
        i_healthFactor.revertIfHealthFactorIsBroken(msg.sender);

        // attempt to send borrowed amount to the msg.sender
        bool success = IERC20(tokenToBorrow).transfer(msg.sender, amountToBorrow);
        if (!success) {
            revert BorrowingEngine__TransferFailed();
        }
        // emit event when msg.sender borrows funds
        emit UserBorrowed(msg.sender, tokenToBorrow, amountToBorrow);
    }

    function _paybackBorrowedAmount(
        address tokenToPayBack,
        uint256 amountToPayBack,
        address onBehalfOf
    )
        private
        moreThanZero(amountToPayBack)
        isAllowedToken(tokenToPayBack)
        nonReentrant
    {
        // if the address being paid on behalf of is the 0 address, revert
        if (onBehalfOf == address(0)) {
            revert BorrowingEngine__ZeroAddressNotAllowed();
        }

        // Safety check to prevent users from overpaying their debt
        uint256 borrowedAmount = getAmountOfTokenBorrowed(onBehalfOf, tokenToPayBack);
        if (borrowedAmount < amountToPayBack) {
            revert BorrowingEngine__OverpaidDebt();
        }

        // Update state BEFORE external calls (CEI pattern)
        // Decrease the user's borrowed balance in our internal accounting
        // This must happen first to prevent reentrancy attacks
        decreaseAmountOfTokenBorrowed(onBehalfOf, tokenToPayBack, amountToPayBack);

        // Check health factor after repayment
        i_healthFactor.revertIfHealthFactorIsBroken(onBehalfOf);

        // Transfer tokens from user to contract
        bool success = IERC20(tokenToPayBack).transferFrom(msg.sender, address(this), amountToPayBack);

        // Check if transfer was successful
        // This is a backup check since transferFrom would normally revert on failure
        if (!success) {
            revert BorrowingEngine__TransferFailed();
        }
        // emit event
        emit BorrowedAmountRepaid(msg.sender, onBehalfOf, tokenToPayBack, amountToPayBack);
    }

    ////////////////////////////////////////////////////
    //    Private & Internal View & Pure Functions    //
    ///////////////////////////////////////////////////

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) external view returns (uint256) {
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
        return (usdAmountInWei * getPrecision()) / (uint256(price) * getAdditionalFeedPrecision());
    }

    ///////////////////////////////////////
    //         Lending Functions         //
    //////////////////////////////////////

    function updateCollateralDeposited(address user, address tokenDeposited, uint256 amount) private {
        s_collateralDeposited[user][tokenDeposited] += amount;
    }

    /////////////////////////////////////
    //        Borrow Functions         //
    ////////////////////////////////////

    function getAmountOfTokenBorrowed(address user, address token) public view returns (uint256) {
        return s_TokenAmountsBorrowed[user][token];
    }

    function increaseAmountOfTokenBorrowed(address user, address token, uint256 amount) private {
        s_TokenAmountsBorrowed[user][token] += amount;
    }

    function decreaseAmountOfTokenBorrowed(address user, address token, uint256 amount) private {
        s_TokenAmountsBorrowed[user][token] -= amount;
    }

    function getTotalCollateralOfToken(address token) private view returns (uint256 totalCollateral) {
        // loop through the allowed collateral tokens
        for (uint256 i = 0; i < s_AllowedTokens.length; i++) {
            // if the token inputted by the caller is in the loop, then
            if (s_AllowedTokens[i] == token) {
                // Get actual token balance of contract
                totalCollateral = IERC20(token).balanceOf(address(this));
                // exit loop immediately
                break;
            }
        }
        // return the total amount of collateral of these tokens
        return totalCollateral;
    }

    function getAvailableToBorrow(address token) private view returns (uint256) {
        // Get total amount of this token deposited as collateral
        uint256 totalCollateral = getTotalCollateralOfToken(token);

        // Get total amount already borrowed of this token
        uint256 totalBorrowed = getTotalBorrowedOfToken(token);

        // Available = Total Collateral - Total Borrowed
        return totalCollateral - totalBorrowed;
    }

    function getTotalBorrowedOfToken(address token) private view returns (uint256 totalBorrowed) {
        // loop through the allowed collateral tokens
        for (uint256 i = 0; i < s_AllowedTokens.length; i++) {
            // if the token inputted by the caller is in the loop, then
            if (s_AllowedTokens[i] == token) {
                // Sum up all borrowed amounts of this token across users
                for (uint256 j = 0; j < s_AllowedTokens.length; j++) {
                    totalBorrowed += getAmountOfTokenBorrowed(msg.sender, token);
                }
                // exit loop immediately
                break;
            }
        }
        // return the total amount borrowed of these tokens
        return totalBorrowed;
    }
    /////////////////////////////////////
    //         Helper Functions         //
    /////////////////////////////////////

    function getUsdValue(
        address token,
        uint256 amount // in WEI
    )
        public
        view
        returns (uint256)
    {
        return _getUsdValue(token, amount);
    }

    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
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

    function getMinimumHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getPrecision() public pure returns (uint256) {
        // Returns the precision scalar used for calculations (1e18)
        return PRECISION;
    }

    function getAdditionalFeedPrecision() private pure returns (uint256) {
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
    function getAllowedTokens() external view returns (address[] memory) {
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

    function balanceOf(address account) private view returns (uint256) {
        return s_balances[account];
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        // Returns how much of a specific token a user has deposited as collateral
        return s_collateralDeposited[user][token];
    }
}
