// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { HealthFactor } from "./HealthFactor.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Lending is HealthFactor {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        HealthFactor(tokenAddresses, priceFeedAddresses)
    { }

    /////////////////////////////////////
    //        Public Functions         //
    ////////////////////////////////////

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateralSent) public nonReentrant {
        _depositCollateral(tokenCollateralAddress, amountCollateralSent);
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
    {
        // require(s_balances[msg.sender] >= amountCollateralSent, "Not Enough"); // this is no good because string
        // revert messages cost TOO MUCH GAS!

        // Check if user has enough of the token they want to deposit
        if (IERC20(tokenCollateralAddress).balanceOf(msg.sender) < amountCollateralSent) {
            revert Errors.Lending__YouNeedMoreFunds();
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
        //    - address(this): this Lending contract receiving the collateral
        //    - amountCollateral: how many tokens to transfer
        // 3. This transferFrom function that we are calling returns a bool: true if transfer succeeded, false if it
        // failed, so we capture the result
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateralSent);
        // This transferFrom will fail if there's no prior approval. The sequence must be:
        // 1. User approves Lending.sol to spend their tokens
        // 2. User calls depositCollateral
        // 3. Lending.sol uses transferFrom to move the tokens

        // if it is not successful, then revert.
        if (!success) {
            revert Errors.TransferFailed();
        }
    }
}
