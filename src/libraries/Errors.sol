// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Errors {
    ///////////////////////////////
    //      Lending Errors      //
    ///////////////////////////////
    error Lending__YouNeedMoreFunds();

    ///////////////////////////////
    //     Borrowing Errors     //
    ///////////////////////////////
    error Borrowing__OverpaidDebt();
    error Borrowing__NotEnoughAvailableCollateral();
    error Borrowing__NotEnoughTokensToPayDebt();

    ///////////////////////////////
    //    CoreStorage Errors    //
    ///////////////////////////////
    error CoreStorage__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error CoreStorage__BatchSizeTooLarge();

    ///////////////////////////////
    //   HealthFactor Errors    //
    ///////////////////////////////
    error HealthFactor__BreaksHealthFactor(uint256);

    ///////////////////////////////
    //      Shared Errors       //
    ///////////////////////////////
    error AmountNeedsMoreThanZero();
    error TokenNotAllowed(address token);
    error TransferFailed();
    error ZeroAddressNotAllowed();

    ///////////////////////////////
    //    Liquidation Errors    //
    //////////////////////////////
    error Liquidations__HealthFactorIsHealthy();
    error Liquidations__HealthFactorNotImproved();
    error Liquidations__InsufficientBalanceToLiquidate();
    error Liquidations__CantLiquidateSelf();
    error Liquidations__DebtAmountPaidExceedsBorrowedAmount();
    error Liquidation__UserHasNotBorrowedToken();
    error Liquidations__OnlyProtocolCanLiquidateInsufficientBonus();
    error Liquidations__ProtocolLiquidationFailed();
    error Liquidations__OnlyProtocolOwnerOrAutomation();
    error Liquidations__InvalidAutomationContract();
    error Liquidations__ProtocolFeeCalculationError();
    error Liquidations__InvalidCollateralPrice();
    error Liquidations__NoPositionsToLiquidate();

    //////////////////////////////
    //     Withdraw Errors     //
    /////////////////////////////
    error Withdraw__UserDoesNotHaveThatManyTokens();
    error Withdraw__UserHasNoCollateralDeposited();

    //////////////////////////////
    //      LoanFi Errors      //
    /////////////////////////////
    error LoanFi__OnlyLiquidationEngine();
}
