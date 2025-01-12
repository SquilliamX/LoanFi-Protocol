// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Lending } from "src/Lending.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Errors } from "src/libraries/Errors.sol";
import { ERC20Burnable, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockBorrowing is ERC20Burnable, Ownable {
    /**
     * @notice Creates a new mock token that fails transferFrom operations
     * @dev Initializes with name "DogCoin" and symbol "Dog"
     */
    constructor() ERC20("DogCoin", "Dog") Ownable(msg.sender) { }

    function borrowFunds(address tokenToBorrow, uint256 amountToBorrow) public view {
        _borrowFunds(tokenToBorrow, amountToBorrow);
    }

    function paybackBorrowedAmount(address tokenToPayBack, uint256 amountToPayBack, address onBehalfOf) public view {
        _paybackBorrowedAmount(tokenToPayBack, amountToPayBack, onBehalfOf);
    }

    function _borrowFunds(address tokenToBorrow, uint256 amountToBorrow) private view {
        // attempt to send borrowed amount to the msg.sender
        bool success = transfer(msg.sender, amountToBorrow, tokenToBorrow);
        if (!success) {
            revert Errors.TransferFailed();
        }
    }

    function _paybackBorrowedAmount(
        address tokenToPayBack,
        uint256 amountToPayBack,
        address /* onBehalfOf */
    )
        private
        view
    {
        // Transfer tokens from user to contract
        bool success = transferFrom(msg.sender, address(this), tokenToPayBack, amountToPayBack);

        // Check if transfer was successful
        // This is a backup check since transferFrom would normally revert on failure
        if (!success) {
            revert Errors.TransferFailed();
        }
    }

    function transfer(address, /* receiver */ uint256, /* amount */ address /* token*/ ) public pure returns (bool) {
        return false;
    }

    /**
     * @notice Mock transferFrom function that always fails
     * @return false Always returns false to simulate transferFrom failure
     */
    function transferFrom(
        address, /*sender*/
        address, /*recipient*/
        address, /* token */
        uint256 /*amount*/
    )
        public
        pure
        returns (bool)
    {
        // Always return false to simulate transferFrom failure
        return false;
    }

    /**
     * @notice Mock mint function that mints tokens
     * @param account The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
