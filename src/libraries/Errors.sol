// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title Errors Library
 * @author William Permuy
 * @notice Custom error definitions for the LoanFi protocol
 * @dev Centralized error handling using custom errors for gas efficiency and improved debugging
 *      Each error is categorized by the component it belongs to
 */
library Errors {
    /*//////////////////////////////////////////////////////////////
                           LENDING ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when a user attempts to perform an action without sufficient funds
     * @dev Used in lending operations to prevent invalid token transfers
     */
    error Lending__YouNeedMoreFunds();

    /*//////////////////////////////////////////////////////////////
                           BORROWING ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when a user attempts to repay more than their outstanding debt
     * @dev Prevents overpayment scenarios and ensures accurate debt tracking
     */
    error Borrowing__OverpaidDebt();

    /**
     * @notice Thrown when attempting to borrow more than available protocol liquidity
     * @dev Ensures protocol always maintains sufficient liquidity for withdrawals
     */
    error Borrowing__NotEnoughAvailableCollateral();

    /**
     * @notice Thrown when a user attempts to repay debt without sufficient token balance
     * @dev Validates user has enough tokens before initiating repayment
     */
    error Borrowing__NotEnoughTokensToPayDebt();

    /*//////////////////////////////////////////////////////////////
                          CORE STORAGE ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when token and price feed arrays have mismatched lengths during initialization
     * @dev Critical for maintaining price feed integrity for all supported tokens
     */
    error CoreStorage__TokenAddressesAndPriceFeedAddressesMustBeSameLength();

    /**
     * @notice Thrown when requested batch size exceeds protocol limits
     * @dev Prevents excessive gas consumption in batch operations
     */
    error CoreStorage__BatchSizeTooLarge();

    /*//////////////////////////////////////////////////////////////
                          HEALTH FACTOR ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when an action would break the minimum health factor requirement
     * @dev Includes the resulting health factor for detailed error reporting
     * @param healthFactor The calculated health factor that would result from the action
     */
    error HealthFactor__BreaksHealthFactor(uint256 healthFactor);

    /*//////////////////////////////////////////////////////////////
                            SHARED ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when an operation requires a non-zero amount
     * @dev Common validation across multiple protocol operations
     */
    error AmountNeedsMoreThanZero();

    /**
     * @notice Thrown when attempting to use an unsupported token
     * @dev Includes token address for easier debugging
     * @param token Address of the unsupported token
     */
    error TokenNotAllowed(address token);

    /**
     * @notice Thrown when a token transfer fails
     * @dev Critical for maintaining protocol safety during token operations
     */
    error TransferFailed();

    /**
     * @notice Thrown when an operation requires a non-zero address
     * @dev Prevents operations with invalid addresses
     */
    error ZeroAddressNotAllowed();

    /*//////////////////////////////////////////////////////////////
                          LIQUIDATION ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when attempting to liquidate a healthy position
     * @dev Prevents unnecessary liquidations of safe positions
     */
    error Liquidations__HealthFactorIsHealthy();

    /**
     * @notice Thrown when a liquidation doesn't improve the position's health factor
     * @dev Ensures liquidations are beneficial to protocol health
     */
    error Liquidations__HealthFactorNotImproved();

    /**
     * @notice Thrown when liquidator has insufficient balance to repay debt
     * @dev Validates liquidator resources before initiating liquidation
     */
    error Liquidations__InsufficientBalanceToLiquidate();

    /**
     * @notice Thrown when user attempts to liquidate their own position
     * @dev Prevents potential manipulation through self-liquidation
     */
    error Liquidations__CantLiquidateSelf();

    /**
     * @notice Thrown when attempting to repay more debt than borrowed
     * @dev Maintains accurate debt accounting during liquidations
     */
    error Liquidations__DebtAmountPaidExceedsBorrowedAmount();

    /**
     * @notice Thrown when attempting to liquidate non-existent debt
     * @dev Validates liquidation targets have outstanding debt
     */
    error Liquidation__UserHasNotBorrowedToken();

    /**
     * @notice Thrown when regular liquidation attempted with insufficient bonus
     * @dev Ensures protocol safety during market stress
     */
    error Liquidations__OnlyProtocolCanLiquidateInsufficientBonus();

    /**
     * @notice Thrown when protocol liquidation fails
     * @dev Critical error requiring immediate attention
     */
    error Liquidations__ProtocolLiquidationFailed();

    /**
     * @notice Thrown when unauthorized access to protocol liquidation functions
     * @dev Access control for automated liquidation system
     */
    error Liquidations__OnlyProtocolOwnerOrAutomation();

    /**
     * @notice Thrown when setting invalid automation contract address
     * @dev Validates automation system configuration
     */
    error Liquidations__InvalidAutomationContract();

    /**
     * @notice Thrown when protocol fee calculation fails
     * @dev Ensures accurate fee handling during liquidations
     */
    error Liquidations__ProtocolFeeCalculationError();

    /**
     * @notice Thrown when collateral price feed returns invalid data
     * @dev Prevents liquidations with unreliable price data
     */
    error Liquidations__InvalidCollateralPrice();

    /**
     * @notice Thrown when no positions are available for liquidation
     * @dev Used in batch liquidation processing
     */
    error Liquidations__NoPositionsToLiquidate();

    /*//////////////////////////////////////////////////////////////
                           WITHDRAW ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when user attempts to withdraw more than their deposit
     * @dev Prevents unauthorized collateral withdrawal
     */
    error Withdraw__UserDoesNotHaveThatManyTokens();

    /**
     * @notice Thrown when user attempts to withdraw without collateral
     * @dev Validates user has deposited before withdrawal
     */
    error Withdraw__UserHasNoCollateralDeposited();

    /*//////////////////////////////////////////////////////////////
                            LOANFI ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when unauthorized access to LiquidationEngine functions
     * @dev Core protocol access control
     */
    error LoanFi__OnlyLiquidationEngine();

    /**
     * @notice Thrown when handling direct ETH transfers to the contract
     * @dev Prevents accidental ETH locks and forces use of wrapped ETH (WETH)
     */
    error LoanFi__NoDirectETHTransfers();

    /**
     * @notice Thrown when handling fallback calls to undefined functions
     * @dev Prevents unknown function calls and protects against erroneous calls
     */
    error LoanFi__FunctionNotFound();

    /*//////////////////////////////////////////////////////////////
                         AUTOMATION SETUP ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when LiquidationAutomation contract deployment verification fails
     * @dev Critical validation during automation setup process
     */
    error Automation__LiquidationAutomationNotDeployed();

    /**
     * @notice Thrown when HelperConfig contract deployment verification fails
     * @dev Critical validation during automation setup process
     */
    error Automation__HelperConfigNotDeployed();

    /**
     * @notice Thrown when upkeep registration fails with Chainlink Automation
     * @dev Critical error during automation setup process
     */
    error Automation__RegistrationFailed();

    /**
     * @notice Thrown when deployer lacks sufficient LINK tokens for upkeep
     * @dev Validates resources before attempting automation setup
     * @param required Amount of LINK tokens needed
     * @param available Current LINK balance of deployer
     */
    error Automation__InsufficientLinkBalance(uint256 required, uint256 available);

    /*//////////////////////////////////////////////////////////////
                         DEPLOYMENT ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when LoanFi contract deployment fails
     * @dev Critical validation during protocol deployment
     */
    error Deployment__LoanFiDeploymentFailed();

    /**
     * @notice Thrown when LiquidationAutomation contract deployment fails
     * @dev Critical validation during protocol deployment
     */
    error Deployment__LiquidationAutomationDeploymentFailed();

    /**
     * @notice Thrown when LiquidationEngine setup fails
     * @dev Critical validation during protocol deployment
     */
    error Deployment__LiquidationEngineSetupFailed();

    /**
     * @notice Thrown when token configuration is missing
     * @dev Validates token setup during deployment
     */
    error Deployment__TokenConfigurationFailed();

    /**
     * @notice Thrown when token and price feed arrays don't match
     * @dev Ensures proper price feed configuration for all tokens
     */
    error Deployment__TokenPriceFeedMismatch();
}
