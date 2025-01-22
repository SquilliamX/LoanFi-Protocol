    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/**
 * @title MockSwapRouter
 * @notice A simplified mock of Uniswap V3 SwapRouter for testing
 * @dev Simulates token swaps without complex pricing logic
 */
contract MockSwapRouter is ISwapRouter {
    // Mock swap function that simulates exact input swaps
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum
    )
        external
        returns (uint256 amountOut)
    {
        // Transfer input tokens from sender to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Return exactly the minimum amount requested
        IERC20(tokenOut).transfer(msg.sender, amountOutMinimum);

        return amountOutMinimum;
    }

    // Implement required interface functions
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut) {
        // Transfer input tokens from sender to this contract
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);

        // Mock the swap by transferring the minimum amount of output tokens
        IERC20(params.tokenOut).transfer(params.recipient, params.amountOutMinimum);

        return params.amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut) {
        return params.amountOutMinimum; // Mock implementation
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn) {
        // Transfer maximum input tokens from sender to this contract
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountInMaximum);

        // Mock the swap by transferring the exact output amount
        IERC20(params.tokenOut).transfer(params.recipient, params.amountOut);

        return params.amountInMaximum;
    }

    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn) {
        return params.amountInMaximum; // Mock implementation
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        // Mock callback implementation
    }
}
