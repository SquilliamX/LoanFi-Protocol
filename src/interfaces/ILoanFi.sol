// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILoanFi {
    // Core functions we need from LoanFi
    function getHealthFactor(address user) external view returns (uint256);
    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256);
    function getUsdValue(address token, uint256 amount) external view returns (uint256);
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) external view returns (uint256);
    function getAccountCollateralValueInUsd(address user) external view returns (uint256);
    function getAllowedTokens() external view returns (address[] memory);
    function getMinimumHealthFactor() external view returns (uint256);
    function getLiquidationThreshold() external view returns (uint256);
    function getLiquidationPrecision() external pure returns (uint256);
    function getLiquidationBonus() external pure returns (uint256);
    function getPrecision() external pure returns (uint256);

    // State changing functions
    function withdrawCollateral(address tokenCollateralAddress, uint256 amountCollateralToWithdraw) external;
    function paybackBorrowedAmount(address tokenToPayBack, uint256 amountToPayBack, address onBehalfOf) external;

    // Add this function to the interface
    function revertIfHealthFactorIsBroken(address user) external view;

    function getAmountOfTokenBorrowed(address user, address token) external view returns (uint256);

    // Add this function
    function getUserBatch(
        uint256 batchSize,
        uint256 offset
    )
        external
        view
        returns (address[] memory users, uint256 totalUsers);
}
