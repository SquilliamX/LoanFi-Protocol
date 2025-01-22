// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Lending } from "src/Lending.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Errors } from "src/libraries/Errors.sol";
import { ERC20Burnable, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockWithdraw is ERC20Burnable, Ownable {
    /**
     * @notice Creates a new mock token that fails transferFrom operations
     * @dev Initializes with name "DogCoin" and symbol "Dog"
     */
    constructor() ERC20("DogCoin", "Dog") Ownable(msg.sender) { }

    function withdrawCollateral(address tokenCollateralAddress, uint256 amountCollateralToWithdraw) external view {
        _withdrawCollateral(tokenCollateralAddress, amountCollateralToWithdraw, msg.sender, msg.sender);
    }

    function _withdrawCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateralToWithdraw,
        address from,
        address to
    )
        internal
        pure
    {
        // zero address check
        // we removed the zero address check for the `to` parameter to save gas as there is no way a user can set/change the `to` address
        if (from == address(0)) {
            revert Errors.ZeroAddressNotAllowed();
        }

        // Transfer the collateral tokens from this contract back to the user
        // Using ERC20's transfer instead of transferFrom since the tokens are already in this contract
        bool success = transfer(to, amountCollateralToWithdraw, tokenCollateralAddress);

        // If the transfer fails, revert the transaction
        if (!success) {
            revert Errors.TransferFailed();
        }
    }

    function transfer(address, /* receiver */ uint256, /* amount */ address /* token*/ ) public pure returns (bool) {
        return false;
    }

    /**
     * @notice Mock transferFrom function that always fails
     * @return false Always returns false to simulate transferFrom failure
     */
    function transferFrom(
        address, /*sender*/
        address, /*recipient*/
        address, /* token */
        uint256 /*amount*/
    )
        public
        pure
        returns (bool)
    {
        // Always return false to simulate transferFrom failure
        return false;
    }

    /**
     * @notice Mock mint function that mints tokens
     * @param account The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
