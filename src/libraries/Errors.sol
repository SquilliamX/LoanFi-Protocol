// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Errors {
    ///////////////////////////////
    //      Lending Errors      //
    ///////////////////////////////
    error Lending__NeedsMoreThanZero();
    error Lending__YouNeedMoreFunds();
    error Lending__TokenNotAllowed(address token);
    error Lending__TransferFailed();
    error Lending__NotEnoughAvailableTokens();

    ///////////////////////////////
    //     Borrowing Errors     //
    ///////////////////////////////
    error Borrowing__TransferFailed();
    error Borrowing__OverpaidDebt();
    error Borrowing__ZeroAddressNotAllowed();

    ///////////////////////////////
    //    CoreStorage Errors    //
    ///////////////////////////////
    error CoreStorage__TokenAddressesAndPriceFeedAddressesMustBeSameLength();

    ///////////////////////////////
    //   HealthFactor Errors    //
    ///////////////////////////////
    error HealthFactor__BreaksHealthFactor(uint256);
}
