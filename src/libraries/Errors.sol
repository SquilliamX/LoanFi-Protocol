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
    error Borrowing__ZeroAddressNotAllowed();
    error Borrowing__NotEnoughAvailableCollateral();

    ///////////////////////////////
    //    CoreStorage Errors    //
    ///////////////////////////////
    error CoreStorage__TokenAddressesAndPriceFeedAddressesMustBeSameLength();

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

    ///////////////////////////////
    //    Liquidation Errors    //
    //////////////////////////////
    error Liquidations__HealthFactorOk();
    error Liquidations__HealthFactorNotImproved();

    //////////////////////////////
    //     Withdraw Errors     //
    /////////////////////////////
    error Withdraw__UserHasCollateralDeposited();
    error Withdraw__UserDoesNotHaveThatManyTokens();
}
