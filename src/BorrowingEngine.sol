// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CoreStorage } from "./CoreStorage.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { HealthFactor } from "src/HealthFactor.sol";

contract BorrowingEngine is ReentrancyGuard {
    CoreStorage private immutable i_coreStorage;

    ///////////////////////////////
    //         Functions         //
    ///////////////////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address coreStorageAddress) {
        i_coreStorage = CoreStorage(coreStorageAddress);
    }

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

    ///////////////////////////////////////
    //         Private Functions         //
    //////////////////////////////////////

    function _borrowFunds(address tokenToBorrow, uint256 amountToBorrow) private nonReentrant {
        i_coreStorage.moreThanZero(amountToBorrow);
        i_coreStorage.isAllowedToken(tokenToBorrow);
        // get the amount available to borrow
        uint256 availableToBorrow = i_coreStorage.getAvailableToBorrow(tokenToBorrow);
        // if user is trying to borrow more than available, revert
        if (amountToBorrow > availableToBorrow) {
            revert CoreStorage.LendingEngine__NotEnoughAvailableTokens();
        }

        // Get USD value of borrow amount
        uint256 borrowAmountInUsd = i_coreStorage.getUsdValue(tokenToBorrow, amountToBorrow);

        // Track the specific token amounts & USD amounts borrowed
        i_coreStorage._increaseAmountOfTokenBorrowed(msg.sender, tokenToBorrow, amountToBorrow);

        // This will check if total borrowed exceeds collateral limits
        i_coreStorage.revertIfHealthFactorIsBroken(msg.sender);

        // attempt to send borrowed amount to the msg.sender
        bool success = IERC20(tokenToBorrow).transfer(msg.sender, amountToBorrow);
        if (!success) {
            revert i_coreStorage.BorrowingEngine__TransferFailed();
        }
        // emit event when msg.sender borrows funds
        emit i_coreStorage.UserBorrowed(msg.sender, tokenToBorrow, amountToBorrow);
    }

    function _paybackBorrowedAmount(
        address tokenToPayBack,
        uint256 amountToPayBack,
        address onBehalfOf
    )
        private
        nonReentrant
    {
        i_coreStorage.moreThanZero(amountToPayBack);
        i_coreStorage.isAllowedToken(tokenToPayBack);
        // if the address being paid on behalf of is the 0 address, revert
        if (onBehalfOf == address(0)) {
            revert CoreStorage.BorrowingEngine__ZeroAddressNotAllowed();
        }

        // Safety check to prevent users from overpaying their debt
        uint256 borrowedAmount = i_coreStorage.getAmountOfTokenBorrowed(onBehalfOf, tokenToPayBack);
        if (borrowedAmount < amountToPayBack) {
            revert CoreStorage.BorrowingEngine__OverpaidDebt();
        }

        // Update state BEFORE external calls (CEI pattern)
        // Decrease the user's borrowed balance in our internal accounting
        // This must happen first to prevent reentrancy attacks
        i_coreStorage._decreaseAmountOfTokenBorrowed(onBehalfOf, tokenToPayBack, amountToPayBack);

        // Check health factor after repayment
        i_coreStorage.revertIfHealthFactorIsBroken(onBehalfOf);

        // Transfer tokens from user to contract
        bool success = IERC20(tokenToPayBack).transferFrom(msg.sender, address(this), amountToPayBack);

        // Check if transfer was successful
        // This is a backup check since transferFrom would normally revert on failure
        if (!success) {
            revert CoreStorage.BorrowingEngine__TransferFailed();
        }
        // emit event
        emit CoreStorage.BorrowedAmountRepaid(msg.sender, onBehalfOf, tokenToPayBack, amountToPayBack);
    }
}
