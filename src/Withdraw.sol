    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Lending } from "src/Lending.sol";

contract Withdraw is Lending {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Lending(tokenAddresses, priceFeedAddresses)
    { }
    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will withdraw your collateral.
     * @notice If you have borrowed funds, you will not be able to redeem until you pay back borrowed funds
     */
    function withdrawCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
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
}
