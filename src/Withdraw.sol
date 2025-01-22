    // SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Borrowing } from "src/Borrowing.sol";

/**
 * @title Withdraw Contract
 * @author William Permuy
 * @notice Manages secure collateral withdrawals from the lending protocol
 * @dev Implements withdrawal system with the following features:
 *
 * Architecture Highlights:
 * 1. Security Features
 *    - CEI (Checks-Effects-Interactions) pattern
 *    - Balance verification
 *    - Address validation
 *    - Transfer confirmation
 *    - Reentrancy protection
 *
 * 2. Withdrawal Controls
 *    - Balance sufficiency checks
 *    - Token validation
 *    - Health factor maintenance
 *    - Position solvency verification
 *
 * 3. State Management
 *    - Atomic operations
 *    - Event emission
 *    - Position tracking
 *    - Balance accounting
 *
 * Key Components:
 * - Balance Tracking: Real-time position monitoring
 * - Transfer Logic: Secure token movements
 * - Event System: Transparent state updates
 *
 * Security Considerations:
 * - State updates before transfers
 * - Comprehensive balance checks
 * - Zero address protection
 * - Failed transfer handling
 */
contract Withdraw is Borrowing {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        Borrowing(tokenAddresses, priceFeedAddresses)
    { }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function for secure collateral withdrawal
     * @dev Implements withdrawal logic with the following safety features:
     * - Balance verification
     * - Address validation
     * - CEI pattern compliance
     * - Event emission
     * - Transfer confirmation
     */
    function _withdrawCollateral(
        address tokenCollateralAddress, // Token being withdrawn
        uint256 amountCollateralToWithdraw, // Amount to withdraw
        address from, // Source address of collateral
        address to // Destination address for withdrawal
    )
        internal
        moreThanZero(amountCollateralToWithdraw) // Prevents zero-value withdrawals
        isAllowedToken(tokenCollateralAddress) // Validates supported collateral
    {
        // STAGE 1: Address Validation
        // Only validate 'from' address as 'to' is controlled internally
        if (from == address(0)) {
            revert Errors.ZeroAddressNotAllowed();
        }

        // STAGE 2: Balance Verification
        // Ensure user has collateral deposited
        if (_getCollateralBalanceOfUser(from, tokenCollateralAddress) == 0) {
            revert Errors.Withdraw__UserHasNoCollateralDeposited();
        }

        // Verify sufficient withdrawal balance
        if (_getCollateralBalanceOfUser(from, tokenCollateralAddress) < amountCollateralToWithdraw) {
            revert Errors.Withdraw__UserDoesNotHaveThatManyTokens();
        }

        // STAGE 3: State Updates (Following CEI Pattern)
        // Update internal accounting before transfer
        decreaseCollateralDeposited(from, tokenCollateralAddress, amountCollateralToWithdraw);

        // STAGE 4: Event Emission
        // Notify external systems of withdrawal
        emit CollateralWithdrawn(tokenCollateralAddress, amountCollateralToWithdraw, from, to);

        // STAGE 5: Token Transfer
        // Execute ERC20 transfer with safety check
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateralToWithdraw);
        if (!success) {
            revert Errors.TransferFailed();
        }
    }
}
