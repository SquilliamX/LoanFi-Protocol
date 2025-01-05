// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IStorage } from "./interfaces/IStorage.sol";

contract HealthFactor {
    error HealthFactor__BreaksHealthFactor(uint256);

    IStorage private immutable i_storage;

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address coreStorageAddress) {
        i_storage = IStorage(coreStorageAddress);
    }

    function calculateHealthFactor(
        uint256 totalAmountBorrowed,
        uint256 collateralValueInUsd
    )
        public
        view
        returns (uint256)
    {
        return _calculateHealthFactor(totalAmountBorrowed, collateralValueInUsd);
    }

    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // Loop through each token in our list of accepted collateral tokens
        // i = 0: Start with the first token in the array
        // i < length: Continue until we've checked every token
        // i++: Move to next token after each iteration
        for (uint256 i = 0; i < i_storage.getAllowedTokens().length; i++) {
            // Get the token address at the current index (i) from our array of collateral tokens
            // Example: If i = 0, might get WETH address
            // Example: If i = 1, might get WBTC address
            address token = i_storage.getAllowedTokens()[i];

            // Get how much of this specific token the user has deposited as collateral
            // Example: If user has deposited 5 WETH, amount = 5
            // Example: If user has deposited 2 WBTC, amount = 2
            uint256 amount = i_storage.getCollateralBalanceOfUser(user, token);

            // After getting the token and the amount of tokens the user has, gets the correct amount of collateral the
            // user has deposited and saves it as a variable named totalCollateralValueInUsd
            totalCollateralValueInUsd += i_storage.getUsdValue(token, amount);
        }

        // return the total amount of collateral in USD
        return totalCollateralValueInUsd;
    }

    function getAccountBorrowedValueInUsd(address user) public view returns (uint256 totalBorrowedValueInUsd) {
        // Loop through each token in our list of accepted collateral tokens
        // i = 0: Start with the first token in the array
        // i < length: Continue until we've checked every token
        // i++: Move to next token after each iteration
        for (uint256 i = 0; i < i_storage.getAllowedTokens().length; i++) {
            // Get the token address at the current index (i) from our array of collateral tokens
            // Example: If i = 0, might get WETH address
            // Example: If i = 1, might get WBTC address
            address token = i_storage.getAllowedTokens()[i];

            // Get how much of this specific token the user has deposited as collateral
            // Example: If user has deposited 5 WETH, amount = 5
            // Example: If user has deposited 2 WBTC, amount = 2
            uint256 amount = i_storage.getCollateralBalanceOfUser(user, token);

            // After getting the token and the amount of tokens the user has, gets the correct amount of collateral the
            // user has deposited and saves it as a variable named totalBorrowedValueInUsd
            totalBorrowedValueInUsd += i_storage.getUsdValue(token, amount);
        }

        // return the total amount of collateral in USD
        return totalBorrowedValueInUsd;
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalAmountBorrowed, uint256 collateralValueInUsd)
    {
        // gets the amount a user has borrowed and saves it as a variable named totalAmountBorrowed
        totalAmountBorrowed = getAccountBorrowedValueInUsd(user);
        // gets the total amount of collateral the user has deposited and saves it has a variable named
        // collateralValueInUsd
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
        // returns the users borrowed amount and the users collateral amount
        return (totalAmountBorrowed, collateralValueInUsd);
    }

    /*
     * Returns how close to liquidation a user is
     * If a user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalAmountBorrowed, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalAmountBorrowed, collateralValueInUsd);
    }

    function revertIfHealthFactorIsBroken(address user) external view {
        // grabs the user's health factor by calling _healthFactor
        uint256 userHealthFactor = _healthFactor(user);
        // if it is less than 1, revert.
        if (userHealthFactor < i_storage.getMinimumHealthFactor()) {
            revert HealthFactor__BreaksHealthFactor(userHealthFactor);
        }
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalAmountBorrowed, uint256 collateralValueInUsd)
    {
        // External wrapper for _getAccountInformation
        // Returns how much user has borrowed and their total collateral value in USD
        return _getAccountInformation(user);
    }

    function _calculateHealthFactor(
        uint256 totalAmountBorrowed,
        uint256 collateralValueInUsd
    )
        internal
        view
        returns (uint256)
    {
        // If user hasn't borrowed any value, they have perfect health factor
        if (totalAmountBorrowed == 0) return type(uint256).max;

        // Adjust collateral value by liquidation threshold
        // Example: $1000 ETH * 50/100 = $500 adjusted collateral
        uint256 collateralAdjustedForThreshold =
            (collateralValueInUsd * i_storage.getLiquidationBonus()) / i_storage.getLiquidationPrecision();

        // Calculate health factor: (adjusted collateral * PRECISION) / debt
        // Example: ($500 * 1e18) / $100 = 5e18 (health factor of 5)
        return (collateralAdjustedForThreshold * i_storage.getPrecision()) / totalAmountBorrowed;
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
