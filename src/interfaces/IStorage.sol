// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStorage {
    function getUsdValue(address token, uint256 amount) external view returns (uint256);
    function getAllowedTokens() external view returns (address[] memory);
    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256);
    function getMinimumHealthFactor() external pure returns (uint256);
    function getLiquidationBonus() external pure returns (uint256);
    function getLiquidationPrecision() external pure returns (uint256);
    function getPrecision() external pure returns (uint256);
}
