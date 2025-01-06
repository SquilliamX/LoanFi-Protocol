// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ERC20Mock
 * @notice A mock ERC20 token used for testing the DSCEngine system
 * @dev Extends OpenZeppelin's ERC20 implementation with additional testing functions
 */
contract ERC20Mock is ERC20 {
    /**
     * @notice Creates a new mock ERC20 token
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialAccount The address to receive the initial token supply
     * @param initialBalance The amount of tokens to mint initially
     * @dev The constructor is payable to allow for testing scenarios involving ETH
     */
    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance
    )
        payable
        ERC20(name, symbol)
    {
        _mint(initialAccount, initialBalance);
    }

    /**
     * @notice Allows test cases to mint new tokens
     * @param account The address to receive the minted tokens
     * @param amount The amount of tokens to mint
     * @dev This function is public to allow for flexible testing scenarios
     */
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    /**
     * @notice Allows test cases to burn tokens
     * @param account The address to burn tokens from
     * @param amount The amount of tokens to burn
     * @dev This function is public to allow for testing token burning scenarios
     */
    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    /**
     * @notice Allows direct testing of internal transfer logic
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param value The amount of tokens to transfer
     * @dev Exposes the internal _transfer function for testing
     */
    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }

    /**
     * @notice Allows direct testing of internal approve logic
     * @param owner The address granting the approval
     * @param spender The address receiving the approval
     * @param value The amount of tokens being approved
     * @dev Exposes the internal _approve function for testing
     */
    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }
}
