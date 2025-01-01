// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Inheritance} from "./Inheritance.sol";

contract BorrowingEngine is Inheritance {
    ///////////////////////////////
    //         Functions         //
    ///////////////////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses)
        Inheritance(tokenAddresses, priceFeedAddresses)
    {}

    function borrowFunds(address tokenToBorrow, uint256 amountToBorrow)
        public
        moreThanZero(amountToBorrow)
        nonReentrant
        isAllowedToken(tokenToBorrow)
    {
        _borrowFunds(tokenToBorrow, amountToBorrow);
    }

    function paybackBorrowedAmount(address tokenToPayBack, uint256 amountToPayBack, address onBehalfOf)
        public
        moreThanZero(amountToPayBack)
        nonReentrant
        isAllowedToken(tokenToPayBack)
    {
        _paybackBorrowedAmount(tokenToPayBack, amountToPayBack, onBehalfOf);
    }

    ///////////////////////////////////////
    //         Private Functions         //
    //////////////////////////////////////

    function _borrowFunds(address tokenToBorrow, uint256 amountToBorrow)
        private
        moreThanZero(amountToBorrow)
        nonReentrant
        isAllowedToken(tokenToBorrow)
    {
        // get the amount available to borrow
        uint256 availableToBorrow = getAvailableToBorrow(tokenToBorrow);
        // if user is trying to borrow more than available, revert
        if (amountToBorrow > availableToBorrow) {
            revert LendingEngine__NotEnoughAvailableTokens();
        }

        // Get USD value of borrow amount
        uint256 borrowAmountInUsd = _getUsdValue(tokenToBorrow, amountToBorrow);

        // Track the specific token amount borrowed
        getTokenBorrowed()[msg.sender][tokenToBorrow] += amountToBorrow;
        // Track total USD borrowed
        s_AmountBorrowed[msg.sender] += borrowAmountInUsd;

        // This will check if total borrowed exceeds collateral limits
        revertIfHealthFactorIsBroken(msg.sender);

        // attempt to send borrowed amount to the msg.sender
        bool success = IERC20(tokenToBorrow).transfer(msg.sender, amountToBorrow);
        if (!success) {
            revert BorrowingEngine__TransferFailed();
        }
        // emit event when msg.sender borrows funds
        emit UserBorrowed(msg.sender, tokenToBorrow, amountToBorrow);
    }

    function _paybackBorrowedAmount(address tokenToPayBack, uint256 amountToPayBack, address onBehalfOf)
        private
        moreThanZero(amountToPayBack)
        nonReentrant
        isAllowedToken(tokenToPayBack)
    {
        // if the address being paid on behalf of is the 0 address, revert
        if (onBehalfOf == address(0)) {
            revert BorrowingEngine__ZeroAddressNotAllowed();
        }

        // Decrease the user's borrowed balance in our internal accounting
        // This must happen first to prevent reentrancy attacks
        s_AmountBorrowed[onBehalfOf] -= amountToPayBack;
        // the line above is the same as `s_AmountBorrowed[onBehalfOf] = s_AmountBorrowed[onBehalfOf] - amountToPayBack;`

        // Check if user has enough borrowed amount of this token
        uint256 borrowedAmount = getTokenBorrowed()[onBehalfOf][tokenToPayBack];
        if (borrowedAmount < amountToPayBack) {
            revert BorrowingEngine__NotEnoughBorrowedAmount();
        }

        // Get USD value of payback amount
        uint256 paybackAmountInUsd = _getUsdValue(tokenToPayBack, amountToPayBack);

        // Update state BEFORE external calls (CEI pattern)
        getTokenBorrowed()[onBehalfOf][tokenToPayBack] -= amountToPayBack;
        s_AmountBorrowed[onBehalfOf] -= paybackAmountInUsd;

        // Check health factor after repayment
        revertIfHealthFactorIsBroken(onBehalfOf);

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
}
