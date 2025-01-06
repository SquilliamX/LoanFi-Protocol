// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC20Burnable, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockFailedTransferFrom is ERC20Burnable, Ownable {
    error CoreStorage__AmountMustBeMoreThanZero();
    error CoreStorage__BurnAmountExceedsBalance();
    error CoreStorage__NotZeroAddress();

    /*
    In future versions of OpenZeppelin contracts package, Ownable must be declared with an address of the contract owner
    as a parameter.
    For example:
    constructor() ERC20("DogCoin", "Dog") Ownable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) {}
    Related code changes can be viewed in this commit:
    https://github.com/OpenZeppelin/openzeppelin-contracts/commit/13d5e0466a9855e9305119ed383e54fc913fdc60
    */

    /**
     * @notice Creates a new mock token that fails transferFrom operations
     * @dev Initializes with name "DogCoin" and symbol "Dog"
     */
    constructor() ERC20("DogCoin", "Dog") Ownable(msg.sender) { }

    /**
     * @notice Mock burn function
     * @param _amount The amount of tokens to burn
     * @dev Only the owner can burn tokens
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert CoreStorage__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert CoreStorage__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    /**
     * @notice Mock mint function that mints tokens
     * @param account The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    /**
     * @notice Mock transferFrom function that always fails
     * @return false Always returns false to simulate transferFrom failure
     */
    function transferFrom(
        address, /*sender*/
        address, /*recipient*/
        uint256 /*amount*/
    )
        public
        pure
        override
        returns (bool)
    {
        // Always return false to simulate transferFrom failure
        return false;
    }
}
