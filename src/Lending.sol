// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Errors } from "src/libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { HealthFactor } from "./HealthFactor.sol";

/**
 * @title Lending Contract
 * @author William Permuy
 * @notice Manages collateral deposits for the lending protocol
 * @dev Implements secure collateral management system with the following features:
 *
 * Architecture Highlights:
 * 1. Deposit Management
 *    - Multi-token collateral support
 *    - Real-time position tracking
 *    - Atomic transaction handling
 *    - Event-driven state updates
 *
 * 2. Security Features
 *    - CEI (Checks-Effects-Interactions) pattern
 *    - Reentrancy protection
 *    - Balance verification
 *    - Token validation
 *    - Transfer confirmation
 *
 * 3. Risk Management
 *    - Supported asset validation
 *    - Non-zero amount enforcement
 *    - Position tracking
 *    - Health factor monitoring
 *
 * Key Components:
 * - Collateral Tracking: Maps user addresses to token balances
 * - Position Management: Tracks user deposits across multiple assets
 * - Event System: Real-time updates for external systems
 *
 * Security Considerations:
 * - All state changes occur before external calls
 * - Token transfers verified for success
 * - Access control via modifiers
 * - Comprehensive error handling
 *
 * Inherits:
 * - HealthFactor: Position health monitoring and risk assessment
 */
contract Lending is HealthFactor {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    )
        HealthFactor(tokenAddresses, priceFeedAddresses)
    { }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles user collateral deposits with comprehensive safety checks
     * @dev Implements secure deposit logic with the following features:
     *
     * Architecture Highlights:
     * 1. Security Validations
     *    - Balance verification
     *    - Token allowance checks
     *    - Supported asset validation
     *    - Non-zero amount enforcement
     *
     * 2. State Management
     *    - Atomic state updates
     *    - Event emission
     *    - User tracking
     *    - Position accounting
     *
     * 3. Transfer Safety
     *    - ERC20 compliance
     *    - Transfer confirmation
     *    - Failure handling
     *    - CEI pattern implementation
     *
     * Process Flow:
     * 1. Validate deposit parameters
     * 2. Check user balance
     * 3. Update internal accounting
     * 4. Execute token transfer
     * 5. Verify transfer success
     *
     * @param tokenCollateralAddress The ERC20 token being deposited as collateral
     * @param amountCollateralSent The amount of tokens to deposit
     */
    function _depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateralSent
    )
        internal
        moreThanZero(amountCollateralSent) // Prevents zero-value deposits
        isAllowedToken(tokenCollateralAddress) // Validates supported collateral
    {
        // STAGE 1: Balance Verification
        // Verify user has sufficient token balance before proceeding
        // This prevents unnecessary state changes and gas consumption
        if (IERC20(tokenCollateralAddress).balanceOf(msg.sender) < amountCollateralSent) {
            revert Errors.Lending__YouNeedMoreFunds();
        }

        // STAGE 2: State Updates (Following CEI Pattern)
        // Update internal accounting before external calls
        // This prevents reentrancy attacks and maintains consistent state
        updateCollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateralSent);
        _addUser(msg.sender); // Track new users for protocol analytics

        // STAGE 3: Event Emission
        // Notify external systems of deposit
        // Critical for UI updates and protocol monitoring
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateralSent);

        // STAGE 4: Token Transfer
        // Execute ERC20 transfer with safety checks
        // Uses transferFrom to respect token allowances
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender, // Token owner
            address(this), // Protocol vault
            amountCollateralSent // Deposit amount
        );

        // STAGE 5: Transfer Verification
        // Ensure transfer succeeded to maintain protocol solvency
        // Reverts entire transaction if transfer fails
        if (!success) {
            revert Errors.TransferFailed();
        }
    }
}
