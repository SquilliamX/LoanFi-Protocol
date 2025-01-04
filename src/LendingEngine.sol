// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { HealthFactor } from "./HealthFactor.sol";
import { Inheritance } from "./Inheritance.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { OracleLib } from "./libraries/OracleLib.sol";
import { CoreStorage } from "./CoreStorage.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingEngine is ReentrancyGuard {
    ///////////////////
    //     Type     //
    //////////////////
    using OracleLib for AggregatorV3Interface;

    CoreStorage private immutable i_coreStorage;

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address coreStorageAddress) {
        i_coreStorage = CoreStorage(coreStorageAddress);
    }

    ///////////////////////////////
    //         Functions         //
    ///////////////////////////////

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateralSent) public nonReentrant {
        _depositCollateral(tokenCollateralAddress, amountCollateralSent);
    }

    ///////////////////////////////////////
    //         Private Functions         //
    //////////////////////////////////////

    function _depositCollateral(address tokenCollateralAddress, uint256 amountCollateralSent) private nonReentrant {
        i_coreStorage.moreThanZero(amountCollateralSent);
        i_coreStorage.isAllowedToken(tokenCollateralAddress);
        // require(s_balances[msg.sender] >= amountCollateralSent, "Not Enough"); // this is no good because string
        // revert messages cost TOO MUCH GAS!

        // Check if user has enough of the token they want to deposit
        if (IERC20(tokenCollateralAddress).balanceOf(msg.sender) < amountCollateralSent) {
            revert CoreStorage.LendingEngine__YouNeedMoreFunds();
        }
        // we update state here, so when we update state, we must emit an event.
        // updates the user's balance in our tracking/mapping system by adding their new deposit amount to their existing balance for the specific collateral token they deposited
        i_coreStorage.updateCollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateralSent);

        // emit the event of the state update
        emit i_coreStorage.CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateralSent);
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
            revert CoreStorage.LendingEngine__TransferFailed();
        }
    }

    ////////////////////////////////////////////////////
    //    Private & Internal View & Pure Functions    //
    ///////////////////////////////////////////////////

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) external view returns (uint256) {
        // Get the price feed for this token from our mapping
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_coreStorage.getPriceFeeds()[token]);

        // Get the latest price from Chainlink
        // We only care about the price, so we ignore other returned values using commas
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        // Calculate how many tokens the USD amount can buy:
        // 1. Multiply usdAmount by PRECISION (1e18) for precision
        // 2. Divide by price (converted to uint) multiplied by ADDITIONAL_FEED_PRECISION (1e10)
        // Example: If price of ETH = $2000:
        // - To get 1 ETH worth: ($1000 * 1e18) / (2000 * 1e10) = 0.5 ETH
        return (usdAmountInWei * i_coreStorage.getPrecision())
            / (uint256(price) * i_coreStorage.getAdditionalFeedPrecision());
    }
}
