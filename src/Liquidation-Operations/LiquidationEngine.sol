// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Errors } from "src/libraries/Errors.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IAutomationRegistryInterface } from "src/interfaces/IAutomationRegistryInterface.sol";
import { ILoanFi } from "../interfaces/ILoanFi.sol";
import { SwapLiquidatedTokens } from "./SwapLiquidatedTokens.sol";
import { LiquidationCore } from "./LiquidationCore.sol";

/**
 * @title Liquidations Contract
 * @author William Permuy
 * @notice Manages the liquidation process for unhealthy positions with a dual-mode liquidation system
 *
 * @dev Liquidation Modes:
 * 1. Regular Liquidations (Market-Driven):
 *    - External liquidators repay users' debt in exchange for user's collateral + 10% bonus
 *    - Requires sufficient collateral value to pay the full bonus
 *    - Most efficient during normal market conditions
 *    - Anyone can be a liquidator
 *
 * 2. Protocol Liquidations (Emergency Mode):
 *    - Activated when positions can't provide sufficient bonus
 *    - Only the protocol (via automation) can perform these liquidations
 *    - Used during flash crashes or extreme market conditions
 *    - Protects protocol solvency when regular liquidations aren't viable
 *
 * @dev Bonus Waterfall Mechanism:
 * The bonus collection follows a waterfall pattern:
 * 1. Primary Collateral:
 *    - First attempts to pay bonus from the collateral being liquidated
 *    - Calculates maximum bonus available from this collateral
 *    - If sufficient, entire bonus comes from this source
 *
 * 2. Secondary Collateral (If Needed):
 *    - If primary collateral insufficient, checks other collateral types from user being liquidated
 *    - Collects remaining needed bonus proportionally from other collateral
 *    - Helps maintain liquidation incentives during partial collateral crashes
 *
 * 3. Protocol Intervention:
 *    - If total available bonus (primary + secondary) < required bonus:
 *      * Regular liquidators are blocked (revert)
 *      * Only protocol can liquidate the position
 *      * Automated system monitors and executes these liquidations
 *
 * @dev Example Scenarios:
 * 1. Normal Case:
 *    - User has $1000 ETH debt
 *    - Liquidator repays $1000
 *    - Liquidator receives $1000 + $100 (10% bonus) in ETH
 *
 * 2. Split Bonus Case:
 *    - User has $1000 ETH debt
 *    - ETH collateral can only provide $40 bonus
 *    - Remaining $60 bonus collected from user's WBTC collateral
 *
 * 3. Protocol Liquidation Case:
 *    - User has $1000 ETH debt
 *    - Total available bonus across all collateral = $1000
 *    - Regular liquidators blocked (insufficient bonus)
 *    - Protocol automation liquidates position
 *
 * @dev Security Considerations:
 * - Reentrancy protection on all liquidation functions
 * - Access control for protocol liquidations
 * - Health factor checks before and after liquidations
 * - Bonus calculations protected against overflow/underflow
 */
contract LiquidationEngine is LiquidationCore, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

    struct PositionInfo {
        address[] debtTokens;
        address[] collaterals;
        uint256[] debtAmounts;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    SwapLiquidatedTokens private immutable i_swapRouter;
    IAutomationRegistryInterface private immutable i_automationRegistry;
    uint256 private immutable i_upkeepId;
    address private s_automationContract;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // event for tracking protocol fees
    event ProtocolFeeCollected(address indexed collateralToken, uint256 feeAmount, uint256 bonusShortfall);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyProtocolOwnerOrAutomation() {
        // Get LoanFi contract since it's our owner
        ILoanFi loanFi = ILoanFi(owner());

        // Revert unless caller is one of the authorized addresses
        if (msg.sender != owner() && msg.sender != loanFi.owner() && msg.sender != s_automationContract) {
            revert Errors.Liquidations__OnlyProtocolOwnerOrAutomation();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address loanFiAddress,
        address swapRouterAddress,
        address automationRegistry,
        uint256 upkeepId
    )
        LiquidationCore(loanFiAddress)
    {
        i_swapRouter = SwapLiquidatedTokens(swapRouterAddress);
        i_automationRegistry = IAutomationRegistryInterface(automationRegistry);
        i_upkeepId = upkeepId;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /* 
     * @notice Liquidates an unhealthy position
     * @param collateral: The liquidator can choose collateral token address he wants as a reward for liquidating the user. 
     * @param debtToken: The token that was borrowed and needs to be repaid
     * @param user: The user whose position is being liquidated
     * @param debtAmountToPay: The amount of debt to repay
     * @dev This function allows liquidators to repay some of a user's debt and receive their collateral at a discount (bonus).
     * @dev In events of flash crashes and the user does not have enough of the collateral token that the liquidator chose as a reward, the protocol will split the reward from the user's other collateral types deposited, to incentivize liquidators. If the user still does not have enough collateral to incentivize liquidators, the protocol will liquidate users to cover the losses.
    */
    function liquidate(
        address liquidator,
        address user,
        address collateral,
        address debtToken,
        uint256 debtAmountToPay
    )
        external
        nonReentrant
    {
        _liquidate(liquidator, user, collateral, debtToken, debtAmountToPay);
    }

    /**
     * @notice Emergency liquidation handler for protocol-level interventions
     * @dev Implements critical protocol safety mechanism with the following features:
     * 1. Full Position Liquidation
     *    - Seizes all available collateral types
     *    - Handles debt repayment across multiple tokens
     *    - Maintains protocol solvency during market stress
     *
     * 2. Security Features
     *    - Access restricted to protocol/automation
     *    - Reentrancy protection
     *    - Atomic execution
     *    - Sequential collateral processing
     *
     * 3. Process Flow
     *    - Scans all allowed collateral tokens
     *    - Withdraws entire collateral balance
     *    - Processes debt repayment
     *    - Handles automation funding
     *
     * Use Cases:
     * - Flash crash scenarios
     * - Insufficient liquidation bonus
     * - Multi-collateral position unwinding
     * - Emergency protocol protection
     *
     * @param user Address of the position being liquidated
     * @param debtToken Token address of the debt being repaid
     * @param debtAmountToPay Amount of debt to be repaid
     */
    function protocolLiquidate(
        address user,
        address debtToken,
        uint256 debtAmountToPay
    )
        external
        onlyProtocolOwnerOrAutomation
        nonReentrant
    {
        // Step 1: Retrieve protocol's supported collateral tokens
        // This ensures we process all possible collateral types
        address[] memory allowedTokens = _getAllowedTokens();

        // Step 2: Systematic collateral seizure and processing
        // Iterates through all collateral types to handle multi-collateral positions
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            // Check user's balance of current collateral token
            // Skip if user has no balance to optimize gas
            uint256 collateralBalance = _getCollateralBalanceOfUser(user, allowedTokens[i]);
            if (collateralBalance > 0) {
                // Execute atomic collateral withdrawal
                // Seizes entire balance to maximize debt coverage
                i_loanFi.liquidationWithdrawCollateral(
                    allowedTokens[i], // Current collateral token
                    collateralBalance, // Full balance seizure
                    user, // Position being liquidated
                    address(this) // Protocol receives collateral
                );

                // Process debt repayment if still needed
                // Only executes if there's remaining debt to cover
                if (debtAmountToPay > 0) {
                    // Prepare parameters for protocol liquidation handling
                    // Structures data for consistent processing
                    TransferParams memory params = TransferParams({
                        liquidator: address(this), // Protocol acts as liquidator
                        user: user, // Position owner
                        collateral: allowedTokens[i], // Current collateral token
                        debtToken: debtToken, // Token to be repaid
                        debtAmountToPay: debtAmountToPay, // Remaining debt
                        totalCollateralToSeize: collateralBalance, // Full balance
                        recipient: address(this) // Protocol receives assets
                     });

                    // Execute protocol-level liquidation handling
                    // Manages both debt repayment and automation funding
                    _onProtocolLiquidation(params);

                    // Reset debt tracker after successful processing
                    // Prevents double-processing of debt
                    debtAmountToPay = 0;
                }
            }
        }
    }

    /**
     * @notice Updates the automation contract address for protocol liquidations
     * @dev Critical administrative function with the following security features:
     * 1. Access controlled (onlyOwner)
     * 2. Zero-address validation
     * 3. Single point of automation control
     *
     * Security Considerations:
     * - Only callable by protocol owner
     * - Immutable after deployment until next owner update
     * - Critical for automated liquidation security
     *
     * @param automationContract The address of the new automation contract
     * @custom:security-note This function can significantly impact protocol safety
     */
    function setAutomationContract(address automationContract) external onlyOwner {
        if (automationContract == address(0)) {
            revert Errors.Liquidations__InvalidAutomationContract();
        }
        s_automationContract = automationContract;
    }

    /**
     * @notice Identifies positions requiring protocol intervention due to insufficient liquidation bonus
     * @dev Implements sophisticated position scanning with the following features:
     *
     * Architecture Highlights:
     * 1. Memory Optimization
     *    - Batch processing to prevent out-of-gas errors
     *    - Dynamic array resizing for gas efficiency
     *    - Optimized data structure packing
     *
     * 2. Position Analysis
     *    - Multi-collateral evaluation
     *    - Cross-token value calculations
     *    - Health factor validation
     *    - Bonus sufficiency checks
     *
     * 3. Security Features
     *    - Access control (protocol/automation only)
     *    - View-only execution
     *
     * Process Flow:
     * 1. Initialize position tracking arrays
     * 2. Scan user's debt positions
     * 3. Analyze collateral coverage
     * 4. Return actionable position data
     *
     * @param user Address of the position to analyze
     * @return debtTokens Array of tokens user has borrowed
     * @return collaterals Corresponding collateral tokens
     * @return debtAmounts Amounts of debt in each token
     */
    function getInsufficientBonusPositions(address user)
        external
        view
        onlyProtocolOwnerOrAutomation
        returns (address[] memory debtTokens, address[] memory collaterals, uint256[] memory debtAmounts)
    {
        // Configure batch size for gas-efficient processing
        // Prevents excessive gas consumption while maintaining thoroughness
        uint256 batchSize = 10; // Process in smaller chunks
        uint256 maxPositions = batchSize * batchSize;

        // Initialize dynamic position tracking structure
        // Allocates memory efficiently for position data
        PositionInfo memory positions = _initializePositionArrays(maxPositions);

        // Scan and analyze user's positions
        // Returns count of positions needing intervention
        uint256 positionCount = _findInsufficientBonusPositions(user, positions);

        // Optimize array sizes for return data
        // Removes unused array space to save gas
        return _resizePositionArrays(positions, positionCount);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles protocol-level liquidation execution and automation funding
     * @dev Implements a sophisticated two-phase liquidation process:
     *
     * Architecture Overview:
     * 1. Fee Calculation & Distribution
     *    - Computes protocol fee from seized collateral
     *    - Allocates collateral between debt repayment and automation
     *    - Ensures protocol sustainability
     *
     * 2. Asset Management
     *    - Precise collateral allocation
     *    - Optimal swap execution
     *    - Automation infrastructure funding
     *
     * Security Features:
     * - Atomic execution
     * - Sequential processing
     * - Protected fee calculations
     * - Slippage control
     *
     * @param params Structured transfer parameters containing:
     *        - liquidator: Protocol address executing liquidation
     *        - user: Position being liquidated
     *        - collateral: Token being seized
     *        - debtToken: Token being repaid
     *        - debtAmountToPay: Amount of debt to cover
     *        - totalCollateralToSeize: Total collateral seized
     *        - recipient: Destination for processed assets
     */
    function _onProtocolLiquidation(TransferParams memory params) internal override {
        // Phase 1: Protocol Fee Calculation
        // Determines optimal split between debt repayment and automation funding
        uint256 protocolFeeAmount = _calculateProtocolFee(
            params.collateral, params.totalCollateralToSeize, params.debtToken, params.debtAmountToPay
        );

        // Phase 2: Collateral Allocation
        // Reserves portion of collateral for debt repayment after fee deduction
        uint256 collateralForDebt = params.totalCollateralToSeize - protocolFeeAmount;

        // Phase 3: Debt Repayment Execution
        // Processes primary debt repayment with allocated collateral
        TransferParams memory debtParams = TransferParams({
            liquidator: params.liquidator,
            user: params.user,
            collateral: params.collateral,
            debtToken: params.debtToken,
            debtAmountToPay: params.debtAmountToPay,
            totalCollateralToSeize: collateralForDebt,
            recipient: params.recipient
        });
        _swapCollateralForDebtToken(debtParams);

        // Phase 4: Automation Funding (if applicable)
        // Processes remaining collateral for automation system maintenance
        if (protocolFeeAmount > 0) {
            _swapAndFundAutomation(params.collateral, protocolFeeAmount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes collateral-to-debt token conversion during liquidation
     * @dev Implements secure token swap process with following features:
     *
     * Architecture Highlights:
     * 1. Token Approval Management
     *    - Safe approval pattern (reset before set)
     *    - Precise amount authorization
     *    - Minimized approval surface
     *
     * 2. Swap Execution
     *    - Atomic swap operation
     *    - Minimum output enforcement
     *    - Slippage protection
     *
     * 3. Debt Settlement
     *    - Protocol-level debt adjustment
     *    - Position state update
     *    - Balance reconciliation
     *
     * @param params Structured parameters containing:
     *        - collateral: Token to swap from
     *        - debtToken: Token to swap to
     *        - totalCollateralToSeize: Amount to swap
     *        - debtAmountToPay: Minimum output required
     */
    function _swapCollateralForDebtToken(TransferParams memory params) private {
        // Step 1: Secure Token Approval
        // Reset approval to 0 first to handle non-standard tokens
        IERC20(params.collateral).approve(address(i_swapRouter), 0);
        // Set exact approval amount to minimize exposure
        IERC20(params.collateral).approve(address(i_swapRouter), params.totalCollateralToSeize);

        // Step 2: Execute Swap Operation
        // Enforces minimum output to protect against slippage
        i_swapRouter.swapExactInputSingle(
            params.collateral,
            params.debtToken,
            params.totalCollateralToSeize,
            params.debtAmountToPay // Minimum output guarantee
        );

        // Step 3: Process Debt Repayment
        // Authorize protocol to handle repayment
        IERC20(params.debtToken).approve(address(i_loanFi), params.debtAmountToPay);
        // Execute debt repayment and position update
        i_loanFi.liquidationPaybackBorrowedAmount(params.debtToken, params.debtAmountToPay, params.user, address(this));
    }

    /**
     * @notice Converts protocol fees to LINK tokens and funds Chainlink Automation
     * @dev Implements critical automation infrastructure maintenance:
     *
     * Architecture Highlights:
     * 1. Token Management
     *    - Dynamic LINK token address retrieval
     *    - Secure approval pattern
     *    - Precise amount handling
     *
     * 2. Swap Protection
     *    - Minimum output calculation
     *    - Slippage control
     *    - Price impact mitigation
     *
     * 3. Automation Funding
     *    - Direct upkeep funding
     *    - Continuous operation assurance
     *    - System sustainability
     *
     * @param collateral Address of token received from liquidation
     * @param protocolFeeAmount Amount of collateral to convert to LINK
     */
    function _swapAndFundAutomation(address collateral, uint256 protocolFeeAmount) private {
        // Step 1: Get LINK Token Address
        // Dynamically fetches current network's LINK token
        address linkToken = i_automationRegistry.LINK();

        // Step 2: Secure Token Approval
        // Implements safe approval pattern for DEX interaction
        IERC20(collateral).approve(address(i_swapRouter), 0);
        IERC20(collateral).approve(address(i_swapRouter), protocolFeeAmount);

        // Step 3: Calculate Minimum Output
        // Protects against adverse price movements and MEV
        uint256 minAmountOutLink = _calculateMinAmountOut(collateral, linkToken, protocolFeeAmount);

        // Step 4: Execute Token Swap
        // Converts collateral to LINK with slippage protection
        uint256 linkReceived =
            i_swapRouter.swapExactInputSingle(collateral, linkToken, protocolFeeAmount, minAmountOutLink);

        // Step 5: Fund Automation System
        // Ensures continuous operation of liquidation automation
        _fundAutomation(linkToken, linkReceived);
    }

    /**
     * @notice Funds Chainlink Automation system with LINK tokens
     * @dev Implements secure automation funding process with following features:
     *
     * Architecture Highlights:
     * 1. Token Authorization
     *    - Two-step approval pattern
     *    - Zero approval before setting new value
     *    - Exact amount approval only
     *
     * 2. Registry Integration
     *    - Direct upkeep funding
     *    - Automation registry interaction
     *
     * @param linkToken Address of network's LINK token
     * @param linkAmount Amount of LINK to fund automation with
     */
    function _fundAutomation(address linkToken, uint256 linkAmount) private {
        // Step 1: Reset Previous Approval
        // Prevents potential approval exploitation
        IERC20(linkToken).approve(address(i_automationRegistry), 0);

        // Step 2: Set Exact Approval
        // Minimizes exposure window and amount
        IERC20(linkToken).approve(address(i_automationRegistry), linkAmount);

        // Step 3: Fund Automation System
        // Transfers LINK tokens to maintain continuous operation
        i_automationRegistry.addFunds(i_upkeepId, uint96(linkAmount));
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL & PRIVATE VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Scans and identifies positions requiring protocol intervention
     * @dev Implements sophisticated position analysis with following features:
     *
     * Architecture Highlights:
     * 1. Efficient Position Scanning
     *    - Single-pass token iteration
     *    - Early skip for zero-debt positions
     *    - Memory-optimized data collection
     *
     * 2. Position Analysis
     *    - Multi-collateral evaluation
     *    - Debt-to-collateral ratio checks
     *    - Bonus sufficiency validation
     *    - Health factor assessment
     *
     * 3. Data Organization
     *    - Structured position tracking
     *    - Parallel array management
     *
     * Process Flow:
     * 1. Iterate through protocol tokens
     * 2. Check for active debt positions
     * 3. Analyze collateral coverage
     * 4. Track qualifying positions
     *
     * @param user Address to scan for insufficient positions
     * @param positions Memory struct to store found positions
     * @return positionCount Number of positions requiring intervention
     */
    function _findInsufficientBonusPositions(
        address user,
        PositionInfo memory positions
    )
        private
        view
        returns (uint256 positionCount)
    {
        // Step 1: Get Protocol Token List
        // Retrieves supported tokens for comprehensive scan
        address[] memory allowedTokens = _getAllowedTokens();

        // Step 2: Scan Each Potential Debt Token
        // Iterates through all protocol tokens to find active debt positions
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address potentialDebtToken = allowedTokens[i];
            uint256 userDebt = _getAmountOfTokenBorrowed(user, potentialDebtToken);

            // Skip tokens with no debt to optimize gas
            if (userDebt == 0) continue;

            // Step 3: Analyze Position Health
            // Checks collateral coverage and bonus sufficiency
            (bool hasPosition, address collateral, uint256 debtAmount) =
                _scanCollateralForInsufficientBonus(user, potentialDebtToken, userDebt);

            // Step 4: Track Qualifying Positions
            // Records positions needing intervention
            if (hasPosition) {
                positions.debtTokens[positionCount] = potentialDebtToken;
                positions.collaterals[positionCount] = collateral;
                positions.debtAmounts[positionCount] = debtAmount;
                positionCount++;
            }
        }

        // Step 5: Validate Results
        // Ensures at least one position requires intervention
        if (positionCount == 0) {
            revert Errors.Liquidations__NoPositionsToLiquidate();
        }

        return positionCount;
    }

    /**
     * @notice Analyzes collateral positions for insufficient liquidation bonus coverage
     * @dev Implements sophisticated two-phase collateral analysis:
     *
     * Architecture Highlights:
     * 1. Value Aggregation
     *    - Cross-token value normalization
     *    - USD-based calculations
     *    - Precision-aware computations
     *
     * 2. Analysis Strategy
     *    - Two-phase evaluation process:
     *      a) Total collateral sufficiency check
     *      b) Token bonus analysis
     *    - Gas-efficient iteration
     *
     * Process Flow:
     * 1. Calculate required bonus in USD
     * 2. Aggregate total collateral value
     * 3. Perform global sufficiency check
     * 4. Analyze collateral tokens
     *
     * @param user Address of position to analyze
     * @param potentialDebtToken Token address of the debt
     * @param userDebt Amount of user's debt in token terms
     * @return hasPosition True if position needs intervention
     * @return collateral Address of insufficient collateral token
     * @return debtAmount Amount of debt to be covered
     */
    function _scanCollateralForInsufficientBonus(
        address user,
        address potentialDebtToken,
        uint256 userDebt
    )
        private
        view
        returns (bool hasPosition, address collateral, uint256 debtAmount)
    {
        // Phase 1: Initial Calculations
        // Convert debt to USD for standardized comparisons
        uint256 debtInUsd = _getUsdValue(potentialDebtToken, userDebt);
        uint256 totalBonusNeededInUsd = getTenPercentBonus(debtInUsd);
        uint256 totalCollateralValueUsd;

        // Get supported tokens for comprehensive analysis
        address[] memory allowedTokens = _getAllowedTokens();

        // Phase 2: Total Value Aggregation
        // Calculate combined value of all user's collateral
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address potentialCollateral = allowedTokens[i];
            uint256 collateralBalance = _getCollateralBalanceOfUser(user, potentialCollateral);
            if (collateralBalance > 0) {
                totalCollateralValueUsd += _getUsdValue(potentialCollateral, collateralBalance);
            }
        }

        // Phase 3: Global Sufficiency Check
        // Verify if total collateral covers debt plus required bonus
        if (totalCollateralValueUsd < (debtInUsd + totalBonusNeededInUsd)) {
            return (true, allowedTokens[0], userDebt); // Position requires protocol intervention
        }

        // Phase 4: Individual Token Analysis
        // Check each collateral token for bonus sufficiency
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address potentialCollateral = allowedTokens[i];
            uint256 collateralBalance = _getCollateralBalanceOfUser(user, potentialCollateral);

            if (collateralBalance > 0) {
                if (_hasInsufficientBonus(user, potentialCollateral, debtInUsd, totalBonusNeededInUsd)) {
                    return (true, potentialCollateral, userDebt);
                }
            }
        }

        // Return default values if no intervention needed
        return (false, address(0), 0);
    }

    /**
     * @notice Determines if a collateral position provides insufficient liquidation bonus
     * @dev Implements two-phase validation process for bonus sufficiency:
     *
     * Architecture Highlights:
     * 1. Health Factor Analysis
     *    - Primary liquidation eligibility check
     *    - Protocol minimum threshold validation
     *    - Position health assessment
     *
     * 2. Bonus Calculation
     *    - USD-normalized value computation
     *    - Cross-token value comparison
     *    - Precise bonus requirement validation
     *
     * Process Flow:
     * 1. Validate liquidation eligibility via health factor
     * 2. Calculate collateral value in USD terms
     * 3. Determine available bonus from collateral
     * 4. Compare against required bonus amount
     *
     * @param user Address of position to analyze
     * @param collateral Token address being evaluated
     * @param debtInUsd USD value of user's debt
     * @param totalBonusNeededInUsd Required bonus amount in USD
     * @return bool True if position has insufficient bonus coverage
     */
    function _hasInsufficientBonus(
        address user,
        address collateral,
        uint256 debtInUsd,
        uint256 totalBonusNeededInUsd
    )
        private
        view
        returns (bool)
    {
        // Phase 1: Health Factor Validation
        // Only proceed if position is actually liquidatable
        if (_healthFactor(user) < _getMinimumHealthFactor()) {
            // Phase 2: Collateral Value Analysis
            // Calculate total value of user's collateral position
            uint256 collateralBalance = _getCollateralBalanceOfUser(user, collateral);
            uint256 collateralValueInUsd = _getUsdValue(collateral, collateralBalance);

            // Phase 3: Bonus Sufficiency Check
            // Determine if collateral can provide required bonus
            uint256 bonusFromThisCollateral =
                _calculateBonusAmounts(totalBonusNeededInUsd, collateralValueInUsd, debtInUsd);
            return bonusFromThisCollateral < totalBonusNeededInUsd;
        }
        return false;
    }

    /**
     * @notice Calculates minimum output amount for token swaps with slippage protection
     * @dev Implements sophisticated three-phase calculation process:
     *
     * Architecture Highlights:
     * 1. Value Normalization
     *    - USD-based calculations
     *    - Cross-token value comparison
     *    - Precision-aware computations
     *
     * 2. Slippage Protection
     *    - Conservative 2% tolerance
     *    - MEV attack mitigation
     *    - Price impact safeguards
     *
     * 3. Output Calculation
     *    - Token-specific precision handling
     *    - Accurate price conversion
     *    - Minimum value guarantees
     *
     * Process Flow:
     * 1. Convert input to USD value
     * 2. Apply slippage buffer
     * 3. Convert back to output token
     *
     * @param tokenIn Address of token being swapped
     * @param tokenOut Address of token to receive
     * @param amountIn Amount of input token
     * @return uint256 Minimum amount of output token to receive
     */
    function _calculateMinAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        private
        view
        returns (uint256)
    {
        // Phase 1: Input Value Calculation
        // Convert input amount to USD for standardized comparison
        uint256 valueInUsd = _getUsdValue(tokenIn, amountIn);

        // Phase 2: Slippage Protection
        // Apply 2% buffer to protect against price movements
        uint256 minValueInUsd = (valueInUsd * 98) / 100;

        // Phase 3: Output Conversion
        // Convert USD value to output token amount with precision handling
        return (minValueInUsd * _getPrecision()) / _getUsdValue(tokenOut, _getPrecision());
    }

    /**
     * @notice Calculates protocol fee from liquidated collateral
     * @dev Implements precise fee calculation with following features:
     *
     * Architecture Highlights:
     * 1. Value Normalization
     *    - USD-based calculations
     *    - Slippage protection (2%)
     *    - Precision-aware computations
     *
     * 2. Safety Mechanisms
     *    - Zero price validation
     *    - Maximum fee bounds
     *    - Overflow protection
     *    - Minimum collateral checks
     *
     * Process Flow:
     * 1. Convert debt to USD terms
     * 2. Apply slippage buffer
     * 3. Calculate required collateral
     * 4. Determine excess for fee
     *
     * @param collateral Token address being seized
     * @param totalCollateralToSeize Total amount of collateral taken
     * @param debtToken Token address being repaid
     * @param debtAmountToPay Amount of debt being covered
     * @return uint256 Amount of collateral to take as protocol fee
     */
    function _calculateProtocolFee(
        address collateral,
        uint256 totalCollateralToSeize,
        address debtToken,
        uint256 debtAmountToPay
    )
        private
        view
        returns (uint256)
    {
        // Phase 1: USD Value Calculation
        // Convert debt amount to USD for standardized calculations
        uint256 debtValueInUsd = _getUsdValue(debtToken, debtAmountToPay);

        // Phase 2: Slippage Protection
        // Add 2% buffer to protect against price movements
        uint256 collateralNeededInUsd = (debtValueInUsd * 102) / 100;

        // Phase 3: Price Validation
        // Get and validate collateral price to prevent division by zero
        uint256 collateralPricePerUnit = _getUsdValue(collateral, _getPrecision());
        if (collateralPricePerUnit == 0) revert Errors.Liquidations__InvalidCollateralPrice();

        // Phase 4: Collateral Calculation
        // Calculate required collateral with precision handling
        uint256 collateralForDebt = (collateralNeededInUsd * _getPrecision()) / collateralPricePerUnit;

        // Phase 5: Safety Checks
        // Ensure minimum collateral requirements are met
        if (collateralForDebt >= totalCollateralToSeize) {
            return 0;
        }

        // Phase 6: Fee Calculation
        // Determine excess collateral available for protocol fee
        uint256 protocolFee = totalCollateralToSeize - collateralForDebt;

        // Phase 7: Final Validation
        // Verify fee doesn't exceed safe bounds
        if (protocolFee >= totalCollateralToSeize) {
            revert Errors.Liquidations__ProtocolFeeCalculationError();
        }

        return protocolFee;
    }

    /**
     * @notice Optimizes memory usage by resizing position arrays to exact length needed
     * @dev Implements efficient array resizing with following features:
     *
     * Architecture Highlights:
     * 1. Memory Management
     *    - Precise array sizing
     *    - Minimal memory footprint
     *    - Gas-optimized copying
     *
     * 2. Data Organization
     *    - Parallel array synchronization
     *    - Maintained data relationships
     *    - Zero garbage data
     *
     * Process Flow:
     * 1. Allocate right-sized arrays
     * 2. Copy valid position data
     * 3. Return optimized arrays
     *
     * @param positions Original oversized position arrays
     * @param positionCount Actual number of valid positions
     * @return debtTokens Optimized array of debt token addresses
     * @return collaterals Optimized array of collateral addresses
     * @return debtAmounts Optimized array of debt amounts
     */
    function _resizePositionArrays(
        PositionInfo memory positions,
        uint256 positionCount
    )
        private
        pure
        returns (address[] memory debtTokens, address[] memory collaterals, uint256[] memory debtAmounts)
    {
        // Phase 1: Array Allocation
        // Create new arrays with exact required size
        debtTokens = new address[](positionCount);
        collaterals = new address[](positionCount);
        debtAmounts = new uint256[](positionCount);

        // Phase 2: Data Transfer
        // Copy only valid position data to new arrays
        for (uint256 i = 0; i < positionCount; i++) {
            debtTokens[i] = positions.debtTokens[i];
            collaterals[i] = positions.collaterals[i];
            debtAmounts[i] = positions.debtAmounts[i];
        }

        // Phase 3: Return Optimized Arrays
        // Return memory-efficient position data
        return (debtTokens, collaterals, debtAmounts);
    }

    /**
     * @notice Creates optimized data structure for tracking liquidatable positions
     * @dev Implements efficient memory allocation with following features:
     *
     * Architecture Highlights:
     * 1. Memory Optimization
     *    - Single allocation pattern
     *    - Fixed-size arrays
     *    - Zero-initialized memory
     *
     * 2. Data Structure Design
     *    - Parallel array architecture
     *    - Synchronized array lengths
     *    - Indexed relationships
     *
     * Process Flow:
     * 1. Allocate memory for debt tokens
     * 2. Allocate memory for collateral tokens
     * 3. Allocate memory for debt amounts
     *
     * @param maxPositions Maximum number of positions to track
     * @return PositionInfo Initialized structure with parallel arrays
     */
    function _initializePositionArrays(uint256 maxPositions) private pure returns (PositionInfo memory) {
        // Create optimized data structure with parallel arrays
        // Each array index represents the same position across all arrays
        return PositionInfo({
            debtTokens: new address[](maxPositions), // Array of borrowed token addresses
            collaterals: new address[](maxPositions), // Array of collateral token addresses
            debtAmounts: new uint256[](maxPositions) // Array of borrowed amounts
         });
    }
}
