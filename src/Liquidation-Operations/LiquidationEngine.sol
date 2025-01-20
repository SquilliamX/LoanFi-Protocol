// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILoanFi } from "../interfaces/ILoanFi.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAutomationRegistryInterface } from "src/interfaces/IAutomationRegistryInterface.sol";
import { SwapLiquidatedTokens } from "src/SwapLiquidatedTokens.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { LiquidationCore } from "./LiquidationCore.sol";
import { Errors } from "src/libraries/Errors.sol";

/**
 * @title Liquidations Contract
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
    using SafeERC20 for IERC20;

    SwapLiquidatedTokens private immutable i_swapRouter;
    IAutomationRegistryInterface private immutable i_automationRegistry;
    uint256 private immutable i_upkeepId;
    address private s_automationContract;

    // event for tracking protocol fees
    event ProtocolFeeCollected(address indexed collateralToken, uint256 feeAmount, uint256 bonusShortfall);

    struct PositionInfo {
        address[] debtTokens;
        address[] collaterals;
        uint256[] debtAmounts;
    }

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

    modifier onlyProtocolOwnerOrAutomation() {
        // Get LoanFi contract since it's our owner
        ILoanFi loanFi = ILoanFi(owner());

        // Revert unless caller is one of the authorized addresses
        if (msg.sender != owner() && msg.sender != loanFi.owner() && msg.sender != s_automationContract) {
            revert Errors.Liquidations__OnlyProtocolOwnerOrAutomation();
        }
        _;
    }

    function setAutomationContract(address automationContract) external onlyOwner {
        if (automationContract == address(0)) revert Errors.Liquidations__InvalidAutomationContract();
        s_automationContract = automationContract;
    }

    function getAutomationContract() external view returns (address) {
        return s_automationContract;
    }

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

    function protocolLiquidate(
        address user,
        address debtToken,
        uint256 debtAmountToPay
    )
        external
        onlyProtocolOwnerOrAutomation
        nonReentrant
    {
        // Get all user's collateral
        address[] memory allowedTokens = _getAllowedTokens();

        // 1. First withdraw ALL collateral from user
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            uint256 collateralBalance = _getCollateralBalanceOfUser(user, allowedTokens[i]);
            if (collateralBalance > 0) {
                // Take all collateral
                i_loanFi.liquidationWithdrawCollateral(allowedTokens[i], collateralBalance, user, address(this));

                if (debtAmountToPay > 0) {
                    TransferParams memory params = TransferParams({
                        liquidator: address(this),
                        user: user,
                        collateral: allowedTokens[i],
                        debtToken: debtToken,
                        debtAmountToPay: debtAmountToPay,
                        totalCollateralToSeize: collateralBalance,
                        recipient: address(this)
                    });

                    _onProtocolLiquidation(params); // This handles both debt repayment and automation funding
                    debtAmountToPay = 0;
                }
            }
        }
    }

    /**
     * @notice Finds ALL positions that need protocol liquidation due to insufficient bonus
     * @dev Returns arrays of matching debt tokens, collateral tokens, and amounts
     * @dev This function is critical for protocol safety during market stress events
     *
     * Key Features:
     * - Comprehensive position scanning
     * - Gas-optimized array handling
     * - Protection against flash crash scenarios
     * - Supports multi-collateral positions
     */
    function getInsufficientBonusPositions(address user)
        external
        view
        onlyProtocolOwnerOrAutomation
        returns (address[] memory debtTokens, address[] memory collaterals, uint256[] memory debtAmounts)
    {
        uint256 batchSize = 10; // Process in smaller chunks
        uint256 maxPositions = batchSize * batchSize;

        PositionInfo memory positions = _initializePositionArrays(maxPositions);
        uint256 positionCount = _findInsufficientBonusPositions(user, positions);

        return _resizePositionArrays(positions, positionCount);
    }

    function _findInsufficientBonusPositions(
        address user,
        PositionInfo memory positions
    )
        private
        view
        returns (uint256 positionCount)
    {
        address[] memory allowedTokens = _getAllowedTokens();

        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address potentialDebtToken = allowedTokens[i];
            uint256 userDebt = _getAmountOfTokenBorrowed(user, potentialDebtToken);

            if (userDebt == 0) continue;

            (bool hasPosition, address collateral, uint256 debtAmount) =
                _scanCollateralForInsufficientBonus(user, potentialDebtToken, userDebt);

            if (hasPosition) {
                positions.debtTokens[positionCount] = potentialDebtToken;
                positions.collaterals[positionCount] = collateral;
                positions.debtAmounts[positionCount] = debtAmount;
                positionCount++;
            }
        }

        return positionCount;
    }

    function _scanCollateralForInsufficientBonus(
        address user,
        address potentialDebtToken,
        uint256 userDebt
    )
        private
        view
        returns (bool hasPosition, address collateral, uint256 debtAmount)
    {
        uint256 debtInUsd = _getUsdValue(potentialDebtToken, userDebt);
        uint256 totalBonusNeededInUsd = getTenPercentBonus(debtInUsd);
        uint256 totalCollateralValueUsd;

        address[] memory allowedTokens = _getAllowedTokens();

        // Sum up ALL collateral value first
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address potentialCollateral = allowedTokens[i];
            uint256 collateralBalance = _getCollateralBalanceOfUser(user, potentialCollateral);
            if (collateralBalance > 0) {
                totalCollateralValueUsd += _getUsdValue(potentialCollateral, collateralBalance);
            }
        }

        // First check if total collateral is insufficient
        if (totalCollateralValueUsd < (debtInUsd + totalBonusNeededInUsd)) {
            return (true, allowedTokens[0], userDebt); // Position needs protocol liquidation
        }

        // If total collateral is sufficient, check each collateral for individual bonus insufficiency
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            address potentialCollateral = allowedTokens[i];
            uint256 collateralBalance = _getCollateralBalanceOfUser(user, potentialCollateral);

            if (collateralBalance > 0) {
                if (_hasInsufficientBonus(user, potentialCollateral, debtInUsd, totalBonusNeededInUsd)) {
                    return (true, potentialCollateral, userDebt);
                }
            }
        }

        return (false, address(0), 0);
    }

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
        // First check if position is liquidatable using health factor
        if (_healthFactor(user) < _getMinimumHealthFactor()) {
            uint256 collateralBalance = _getCollateralBalanceOfUser(user, collateral);
            uint256 collateralValueInUsd = _getUsdValue(collateral, collateralBalance);

            // Then check if bonus is insufficient
            uint256 bonusFromThisCollateral =
                _calculateBonusAmounts(totalBonusNeededInUsd, collateralValueInUsd, debtInUsd);
            return bonusFromThisCollateral < totalBonusNeededInUsd;
        }
        return false;
    }

    function _resizePositionArrays(
        PositionInfo memory positions,
        uint256 positionCount
    )
        private
        pure
        returns (address[] memory debtTokens, address[] memory collaterals, uint256[] memory debtAmounts)
    {
        debtTokens = new address[](positionCount);
        collaterals = new address[](positionCount);
        debtAmounts = new uint256[](positionCount);

        for (uint256 i = 0; i < positionCount; i++) {
            debtTokens[i] = positions.debtTokens[i];
            collaterals[i] = positions.collaterals[i];
            debtAmounts[i] = positions.debtAmounts[i];
        }

        return (debtTokens, collaterals, debtAmounts);
    }

    function _initializePositionArrays(uint256 maxPositions) private pure returns (PositionInfo memory) {
        return PositionInfo({
            debtTokens: new address[](maxPositions),
            collaterals: new address[](maxPositions),
            debtAmounts: new uint256[](maxPositions)
        });
    }

    function _onProtocolLiquidation(TransferParams memory params) internal override {
        // Calculate protocol fee first
        uint256 protocolFeeAmount = _calculateProtocolFee(
            params.collateral, params.totalCollateralToSeize, params.debtToken, params.debtAmountToPay
        );

        // Adjust collateral amount for debt repayment to account for protocol fee
        uint256 collateralForDebt = params.totalCollateralToSeize - protocolFeeAmount;

        // First swap enough collateral to cover debt
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

        // Then handle automation funding with remaining collateral
        if (protocolFeeAmount > 0) {
            _swapAndFundAutomation(params.collateral, protocolFeeAmount);
        }
    }

    function _swapCollateralForDebtToken(TransferParams memory params) private {
        // Approve router to spend collateral
        IERC20(params.collateral).approve(address(i_swapRouter), 0);
        IERC20(params.collateral).approve(address(i_swapRouter), params.totalCollateralToSeize);

        // Execute Swap
        i_swapRouter.swapExactInputSingle(
            params.collateral,
            params.debtToken,
            params.totalCollateralToSeize,
            params.debtAmountToPay // Ensure we get at least the debt amount
        );

        // Approve and repay debt
        IERC20(params.debtToken).approve(address(i_loanFi), params.debtAmountToPay);
        i_loanFi.liquidationPaybackBorrowedAmount(params.debtToken, params.debtAmountToPay, params.user, address(this));
    }

    function _swapAndFundAutomation(address collateral, uint256 protocolFeeAmount) private {
        address linkToken = i_automationRegistry.LINK();

        // Reset and set new approval for collateral
        IERC20(collateral).approve(address(i_swapRouter), 0);
        IERC20(collateral).approve(address(i_swapRouter), protocolFeeAmount);

        // Calculate minimum LINK output
        uint256 minAmountOutLink = _calculateMinAmountOut(collateral, linkToken, protocolFeeAmount);

        // Swap collateral for LINK
        uint256 linkReceived =
            i_swapRouter.swapExactInputSingle(collateral, linkToken, protocolFeeAmount, minAmountOutLink);

        // Fund Chainlink Automation
        _fundAutomation(linkToken, linkReceived);
    }

    function _fundAutomation(address linkToken, uint256 linkAmount) private {
        IERC20(linkToken).approve(address(i_automationRegistry), 0);
        IERC20(linkToken).approve(address(i_automationRegistry), linkAmount);
        i_automationRegistry.addFunds(i_upkeepId, uint96(linkAmount));
    }

    // For debt token calculations
    function _calculateMinAmountOutForDebt(uint256 debtAmount) private pure returns (uint256) {
        // Allow 2% slippage
        return (debtAmount * 98) / 100;
    }

    // For general token-to-token calculations
    function _calculateMinAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        private
        view
        returns (uint256)
    {
        // Get USD value of input amount
        uint256 valueInUsd = _getUsdValue(tokenIn, amountIn);

        // Allow 2% slippage
        uint256 minValueInUsd = (valueInUsd * 98) / 100;

        // Convert USD value back to token amount using output token's price
        return (minValueInUsd * _getPrecision()) / _getUsdValue(tokenOut, _getPrecision());
    }

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
        // Get USD values with proper scaling
        uint256 debtValueInUsd = _getUsdValue(debtToken, debtAmountToPay);

        // Add 2% slippage protection
        uint256 collateralNeededInUsd = (debtValueInUsd * 102) / 100;

        // Get collateral price per unit
        uint256 collateralPricePerUnit = _getUsdValue(collateral, _getPrecision());

        if (collateralPricePerUnit == 0) revert Errors.Liquidations__InvalidCollateralPrice();

        // Calculate required collateral with proper precision handling
        // First multiply by precision to maintain precision during division
        uint256 collateralForDebt = (collateralNeededInUsd * _getPrecision()) / collateralPricePerUnit;

        // Safety check for minimum collateral
        if (collateralForDebt >= totalCollateralToSeize) {
            return 0;
        }

        // Calculate remaining collateral for protocol fee
        uint256 protocolFee = totalCollateralToSeize - collateralForDebt;

        // Safety check - fee should not be larger than total collateral
        if (protocolFee >= totalCollateralToSeize) {
            revert Errors.Liquidations__ProtocolFeeCalculationError();
        }

        return protocolFee;
    }
}
