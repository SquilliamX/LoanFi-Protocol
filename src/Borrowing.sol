// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Lending } from "src/Lending.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Errors } from "src/libraries/Errors.sol";

contract Borrowing is Lending {
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Lending(tokenAddresses, priceFeedAddresses)
    { }

    function borrowFunds(address tokenToBorrow, uint256 amountToBorrow) public nonReentrant {
        _borrowFunds(tokenToBorrow, amountToBorrow);
    }

    function paybackBorrowedAmount(
        address tokenToPayBack,
        uint256 amountToPayBack,
        address onBehalfOf
    )
        public
        nonReentrant
    {
        _paybackBorrowedAmount(tokenToPayBack, amountToPayBack, onBehalfOf);
    }

    function _borrowFunds(
        address tokenToBorrow,
        uint256 amountToBorrow
    )
        private
        moreThanZero(amountToBorrow)
        isAllowedToken(tokenToBorrow)
    {
        // 1. Physical Token Check
        // Verify the contract actually has enough tokens in its possession
        // This prevents attempts to transfer tokens that don't exist in the contract
        if (IERC20(tokenToBorrow).balanceOf(address(this)) < amountToBorrow) {
            revert Errors.Borrowing__NotEnoughAvailableCollateral();
        }

        // 2. Protocol Accounting Check
        // Get how many tokens are available according to protocol's accounting
        // This considers all existing loans and ensures we're not lending tokens
        // that are already promised to other borrowers
        uint256 availableToBorrow = _getAvailableToBorrow(tokenToBorrow);
        // if user is trying to borrow more than available, revert
        if (amountToBorrow > availableToBorrow) {
            revert Errors.Borrowing__NotEnoughAvailableCollateral();
        }

        // Track the specific token amounts & USD amounts borrowed
        increaseUserDebtAndTotalDebtBorrowed(msg.sender, tokenToBorrow, amountToBorrow);

        // This will check if total borrowed exceeds collateral limits
        _revertIfHealthFactorIsBroken(msg.sender);

        // attempt to send borrowed amount to the msg.sender
        bool success = IERC20(tokenToBorrow).transfer(msg.sender, amountToBorrow);
        if (!success) {
            revert Errors.Borrowing__TransferFailed();
        }
        // emit event when msg.sender borrows funds
        emit UserBorrowed(msg.sender, tokenToBorrow, amountToBorrow);
    }

    function _paybackBorrowedAmount(
        address tokenToPayBack,
        uint256 amountToPayBack,
        address onBehalfOf
    )
        private
        moreThanZero(amountToPayBack)
        isAllowedToken(tokenToPayBack)
    {
        // if the address being paid on behalf of is the 0 address, revert
        if (onBehalfOf == address(0)) {
            revert Errors.Borrowing__ZeroAddressNotAllowed();
        }

        // Safety check to prevent users from overpaying their debt
        uint256 borrowedAmount = _getAmountOfTokenBorrowed(onBehalfOf, tokenToPayBack);
        if (borrowedAmount < amountToPayBack) {
            revert Errors.Borrowing__OverpaidDebt();
        }

        // Update state BEFORE external calls (CEI pattern)
        // Decrease the user's borrowed balance in our internal accounting
        // This must happen first to prevent reentrancy attacks
        decreaseUserDebtAndTotalDebtBorrowed(onBehalfOf, tokenToPayBack, amountToPayBack);

        // Check health factor after repayment just in case
        _revertIfHealthFactorIsBroken(onBehalfOf);

        // Transfer tokens from user to contract
        bool success = IERC20(tokenToPayBack).transferFrom(msg.sender, address(this), amountToPayBack);

        // Check if transfer was successful
        // This is a backup check since transferFrom would normally revert on failure
        if (!success) {
            revert Errors.Borrowing__TransferFailed();
        }
        // emit event
        emit BorrowedAmountRepaid(msg.sender, onBehalfOf, tokenToPayBack, amountToPayBack);
    }

    function _getTotalCollateralOfToken(address token) private view returns (uint256 totalCollateral) {
        // loop through the allowed collateral tokens
        for (uint256 i = 0; i < _getAllowedTokens().length; i++) {
            // if the token inputted by the caller is in the loop, then
            if (_getAllowedTokens()[i] == token) {
                // Get actual token balance of contract
                totalCollateral = IERC20(token).balanceOf(address(this));
                // exit loop immediately
                break;
            }
        }
        // return the total amount of collateral of these tokens
        return totalCollateral;
    }

    function getTotalCollateralOfToken(address token) external view returns (uint256 totalCollateral) {
        return _getTotalCollateralOfToken(token);
    }

    function _getAvailableToBorrow(address token) private view returns (uint256) {
        // Get total amount of this token deposited as collateral
        uint256 totalCollateral = _getTotalCollateralOfToken(token);

        // Get total amount already borrowed of this token
        uint256 totalBorrowed = _getTotalTokenAmountsBorrowed(token);

        // Available = Total Collateral - Total Borrowed
        return totalCollateral - totalBorrowed;
    }

    function getAvailableToBorrow(address token) external view returns (uint256) {
        return _getAvailableToBorrow(token);
    }
}
