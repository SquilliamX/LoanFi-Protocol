// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Errors } from "./libraries/Errors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LiquidationEngine } from "./Liquidation-Operations/LiquidationEngine.sol";
import { Withdraw } from "./Withdraw.sol";

/**
 * @title LoanFi Protocol
 * @author William Permuy
 * @notice Main entry point for the lending protocol with integrated liquidation system
 * @dev Implements comprehensive lending protocol with the following features:
 *
 * Architecture Highlights:
 * 1. Core Lending Features
 *    - Multi-token collateral support
 *    - Flexible borrowing system
 *    - Cross-collateral positions
 *    - Altruistic debt repayment
 *
 * 2. Liquidation System
 *    - Automated position monitoring
 *    - Chainlink price feeds
 *    - Uniswap integration
 *    - Bonus incentives
 *
 * 3. Security Features
 *    - Reentrancy protection
 *    - Access control
 *    - CEI pattern
 *    - Health factor validation
 *
 * Protocol Actions:
 * 1. User Operations
 *    - Deposit collateral
 *    - Borrow assets
 *    - Repay debt
 *    - Withdraw collateral
 *    - Liquidate positions
 *
 * 2. Admin Operations
 *    - Configure automation
 *    - Manage liquidation parameters
 *    - Emergency controls
 *
 * Integration Points:
 * - Chainlink: Price feeds and automation
 * - Uniswap V3: Liquidation swaps
 * - ERC20: Token interactions
 *
 * Security Considerations:
 * - All state-changing functions protected against reentrancy
 * - Critical functions restricted to authorized addresses
 * - Health factor checks on all position modifications
 * - Comprehensive input validation
 */
contract LoanFi is Withdraw, Ownable {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Core liquidation engine for protocol solvency management
     * @dev Handles position liquidations and automated health monitoring
     */
    LiquidationEngine public liquidationEngine;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts critical liquidation functions to authorized engine
     */
    modifier OnlyLiquidationEngine() {
        if (msg.sender != address(liquidationEngine)) {
            revert Errors.LoanFi__OnlyLiquidationEngine();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes protocol with supported assets and automation infrastructure
     * @dev Sets up core protocol components with the following features:
     * - Multi-token collateral support via token addresses
     * - Price feed integration for real-time valuation
     * - Automated liquidation system with Chainlink
     * - Uniswap integration for liquidation swaps
     *
     * @param tokenAddresses Array of supported collateral token addresses
     * @param priceFeedAddresses Corresponding Chainlink price feeds
     * @param swapRouter Uniswap router for liquidation swaps
     * @param automationRegistry Chainlink automation registry
     * @param upkeepId Chainlink upkeep identifier
     */
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address swapRouter,
        address automationRegistry,
        uint256 upkeepId
    )
        Withdraw(tokenAddresses, priceFeedAddresses)
        Ownable(msg.sender)
    {
        liquidationEngine = new LiquidationEngine(
            address(this), // Protocol address
            swapRouter, // DEX integration
            automationRegistry, // Chainlink automation
            upkeepId // Upkeep identifier
        );
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits collateral tokens into the lending protocol
     * @dev Protected against reentrancy, validates token support
     * @param tokenCollateralAddress Address of token to deposit
     * @param amountCollateralSent Amount of tokens to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateralSent) external nonReentrant {
        _depositCollateral(tokenCollateralAddress, amountCollateralSent);
    }

    /**
     * @notice Borrows tokens against deposited collateral
     * @dev Enforces health factor requirements and collateral ratios. Protected against reentrancy
     * @param tokenToBorrow Address of token to borrow
     * @param amountToBorrow Amount of tokens requested
     */
    function borrowFunds(address tokenToBorrow, uint256 amountToBorrow) external nonReentrant {
        _borrowFunds(tokenToBorrow, amountToBorrow);
    }

    /**
     * @notice Repays borrowed tokens with support for altruistic repayment
     * @dev Updates debt accounting and validates final position health. Protected against reentrancy
     * @param tokenToPayBack Token address being repaid
     * @param amountToPayBack Amount to repay
     * @param onBehalfOf Address whose debt is being repaid
     */
    function paybackBorrowedAmount(
        address tokenToPayBack,
        uint256 amountToPayBack,
        address onBehalfOf
    )
        external
        nonReentrant
    {
        _paybackBorrowedAmount(tokenToPayBack, amountToPayBack, onBehalfOf);
    }

    /**
     * @notice Withdraws collateral tokens from the protocol
     * @dev Ensures remaining position maintains minimum health factor. Protected against reentrancy
     * @param tokenCollateralAddress Token to withdraw
     * @param amountCollateralToWithdraw Amount to withdraw
     */
    function withdrawCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateralToWithdraw
    )
        external
        nonReentrant
    {
        _withdrawCollateral(tokenCollateralAddress, amountCollateralToWithdraw, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Executes user-initiated liquidations of unhealthy positions
     * @dev Delegates to specialized engine for collateral seizure and debt repayment
     * @param user Address of position to liquidate
     * @param collateral Token address being liquidated
     * @param debtToken Token address being repaid
     * @param debtAmountToPay Amount of debt to repay
     */
    function liquidate(
        address user,
        address collateral,
        address debtToken,
        uint256 debtAmountToPay
    )
        external
        nonReentrant
    {
        liquidationEngine.liquidate(msg.sender, user, collateral, debtToken, debtAmountToPay);
    }

    /**
     * @notice Atomic operation combining deposit and borrow actions
     * @dev Optimizes gas usage and improves UX with single transaction. Protected against reentrancy
     */
    function DepositAndBorrow(
        address tokenCollateralAddressToDeposit, // Collateral token address
        uint256 amountOfCollateralToDeposit, // Amount to deposit
        address tokenToBorrow, // Token to borrow
        uint256 amountToBorrow // Amount to borrow
    )
        external
        nonReentrant
    {
        _depositCollateral(tokenCollateralAddressToDeposit, amountOfCollateralToDeposit);
        _borrowFunds(tokenToBorrow, amountToBorrow);
    }

    /**
     * @notice Atomic operation combining debt repayment and collateral withdrawal
     * @dev Ensures safe position closure with health factor validation
     */
    function paybackDebtAndWithdraw(
        address tokenToPayback, // Token being repaid
        uint256 amountToPayback, // Amount to repay
        address onBehalfOf, // Address whose debt is being repaid
        address tokenCollateralAddressToWithdraw, // Collateral to withdraw
        uint256 amountCollateralToWithdraw // Amount to withdraw
    )
        external
        nonReentrant
    {
        _paybackBorrowedAmount(tokenToPayback, amountToPayback, onBehalfOf);
        _withdrawCollateral(tokenCollateralAddressToWithdraw, amountCollateralToWithdraw, msg.sender, msg.sender);
    }

    /**
     * @notice Protected collateral withdrawal for liquidation engine
     * @dev Access restricted to liquidation engine, follows CEI pattern
     */
    function liquidationWithdrawCollateral(
        address collateral,
        uint256 amount,
        address user,
        address recipient
    )
        external
        OnlyLiquidationEngine
    {
        _withdrawCollateral(collateral, amount, user, recipient);
    }

    /**
     * @notice Protected debt repayment for liquidation engine
     * @dev Updates state before transfers, enforces CEI pattern
     */
    function liquidationPaybackBorrowedAmount(
        address token,
        uint256 amount,
        address user,
        address liquidator
    )
        external
        OnlyLiquidationEngine
    {
        decreaseUserDebtAndTotalDebtBorrowed(user, token, amount);
        bool success = IERC20(token).transferFrom(liquidator, address(this), amount);
        if (!success) {
            revert Errors.TransferFailed();
        }
    }

    /**
     * @notice Updates automation contract address
     * @dev Owner-restricted configuration for liquidation automation
     */
    function setAutomationContract(address automationContract) external onlyOwner {
        liquidationEngine.setAutomationContract(automationContract);
    }

    /**
     * @notice Handles direct ETH transfers to the contract
     * @dev Reverts direct ETH transfers for security:
     * - Prevents accidental ETH locks
     * - Forces use of wrapped ETH (WETH)
     * - Maintains clear accounting
     */
    receive() external payable {
        revert Errors.LoanFi__NoDirectETHTransfers();
    }

    /**
     * @notice Handles fallback calls to undefined functions
     * @dev Reverts unknown function calls:
     * - Prevents undefined behavior
     * - Protects against erroneous calls
     * - Maintains protocol security
     */
    fallback() external payable {
        revert Errors.LoanFi__FunctionNotFound();
    }
}
