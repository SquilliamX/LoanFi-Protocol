# Notes 

## Glossary
```

Search for the Department Names with `ctrl + F`:

Getting Started Notes
    - Layout of Solidity Files/Contracts
    - When Beginning To Write A New Contract Help Notes 
    - CEI (Checks, Effects, Interactions) Notes
    - Modifier Notes
    - Visibility Modifier Notes 
    - Variable Notes
        - Constant Notes
        - Immutable Notes
        - Storage Variable Notes
        - Saving Gas with Storage Variable Notes
        - Custom Error Variable Notes
        - Reference Types Variable Notes
            - Array Notes
            - Struct Notes
            - Mapping Notes
    - Constructor Notes
    - Event Notes
    - Enum Notes
    - Call and staticcall differences Notes
    - Inheritance Notes
        - `Super` (Inheritance) keyword Notes
        - Inheriting Constructor Notes
    - Override Notes
    - Modulo Notes
    - Sending Money in Solidity Notes
    - Console.log Notes
    - Remappings in foundry.toml Notes
    - abi.encode Notes & abi.encodePacked Notes
    - How to use abi.encode and abi.decode Notes
    - Function Selector & Function Signature Notes
    - Delegatecall Notes
    - Merkle Tree & Merkle Proof Notes
        - What is a Merkle Tree?
        - Structure / How Merkle Tree Works
        - What is a Merkle Proof?
        - Benefits
    - Signatures Notes
        - EIP-191 Notes
        - EIP-712 Notes (Recommended)
        - OpenZeppelin Signature Notes
        - ECDSA Signatures
    

Package Installing Notes

Smart Contract Tests Notes
    - Local Chain Tests Don't Work on Forked Chain Tests?
    - Testing Events
    - Tests with Custom error notes
    - How to compare strings in Tests
    - Sending money in tests Notes
    - GAS INFO IN TESTS Notes
    - FUZZ TESTING NOTES
        - Handler Based Fuzz Testing (Advanced Fuzzing) Notes
        - Steps For Fuzzing Notes
        - `fail_on_revert` Notes
        - How to read fuzz test outputs
    - CHEATCODES FOR TESTS Notes
    - Foundry Assertion Functions Notes
    - Debugging Tests Notes

Chisel Notes

Deploying on Anvil Without A Script Notes

Script Notes
    - Getting Started with Scripts Notes
    - Script Cheatcodes 
    - HelperConfig Script Notes
    - Deploying A Script Notes
    - Deploying on Anvil Notes
    - Deploying to a Testnet
    - Interaction Script Notes

BroadCast Folder Notes

.env Notes

DEPLOYING PRODUCTION CONTRACT Notes
    - Verifying a Deploying Contract Notes
        - If a Deployed Contract does not Verify Correctly
        - ALL --VERIFY OPTIONS NOTES

How to interact with deployed contracts from the command line Notes
    - CAST SIG NOTES
    - cast --calldata-decode Notes
    - cast wallet sign Notes
    - How to be safe when interacting with contracts

TIPS AND TRICKS

ChainLink Notes
    - Chainlink Functions Notes
    - Aggregator PriceFeeds Notes
    - Chainlink VRF 2.5 Notes
    - Chainlink Automation (Custom Logic) Notes

OpenZeppelin Notes
    - OpenZeppelin ERC20 Notes
    - OpenZeppelin NFT Notes
    - OpenZeppelin Mocks Notes
    - OpenZeppelin Ownable Notes

Makefile Notes

Everything ZK-SYNC Notes
    - Zk-SYNC Foundry Notes
    - Deploying on ZK-SYNC Notes
        - Running a local zkSync test node using Docker, and deploying a smart contract to the test node.

ERC20 Notes

NFT Notes
    - What are NFTs?
    - Creating NFTs
    - Creating NFTs on IPFS
    - How Creating NFTs on-Chain Works
    - How to Create NFTs on-Chain

AirDrop Notes
    - What is an Airdrop?
    - Common Types of Airdrops
    - Why Do Projects Do Airdrops?
    - Common Requirements for Airdrops

EIP Notes
    - EIP status terms

DeFi Notes
    - StableCoin Notes
    - Why We Care About Stablecoins Notes
    - Different Categories/Properties of StableCoins

Account Abstraction Notes (EIP-4337)
    - How Account Abstraction Works
    - Account Abstraction in Ethereum Mainnet
    - Account Abstraction in Zk-Sync

Upgradeable Smart Contracts Notes
    - Not Really Upgrading / Parameterize Upgrade Method
    - Social Migration Method
    - Proxies Upgrade Method
    - Transparent Proxy Pattern
    - Universal Upgradeable Proxies (UUPS)
    - Diamond Pattern

DAO Notes
    - DAO Example: Compound Protocol
    - Discussion Forum in DAOs
    - Voting Mechanisms
        - Implementation of Voting
    - Tools
        - No Code Solutions to build DAOs
        - Dev Tools to build DAOs
    - Legality


Keyboard Shortcuts
```

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## Getting Started Notes

To start a new foundry project, run `forge init`.
  - Then add `.env` and `broadcast/` to your .gitignore

To compile a foundry project, run `forge build`
to run tests, run `forge test`
to install packages, run `forge install` with a `--no-commit` at the end

`forge` is used to compile and interact with our contracts
`cast` is used to interact with contracts that have already been deployed.
`anvil` is used to spin up a local blockchain in out terminal for testing. 

every smart contract should start with the following:

```javascript
// SPDX-License-Identifier: MIT // like always
pragma solidity 0.8.18; // like always

contract ThisIsAnExample {/* contract logic goes here */} 
```


### Layout of Solidity Files/Contracts:

Solidty files should be ordered correctly:
 1. solidity version
 2. imports
 3. errors
 4. interfaces
 5. libraries
 6. contracts
 7. Type declarations
 8. State variables
 9. Events
 10. Modifiers
 11. Functions

Layout of Functions:
 1. constructor
 2. receive function (if exists)
 3. fallback function (if exists)
 4. external
 5. public
 6. internal
 7. private
 8. internal & private view & pure functions
 9. external & public view & pure functions




### When Beginning To Write A New Contract Help Notes

When beginning to write a new contract, think about what you want the contract to do, break it down into function, and write the interface of these function out so it becomes easier to see.

example from foundry-defi-stablecoin-f23:
```js
contract DSCEngine {
    function depositCollateralAndMintDsc() external {}

    function depositCollateral() external {}

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
```


### CEI (Checks, Effects, Interactions) Notes
 When writing smart contacts, you always want to follow the CEI (Checks, Effects, Interactions) pattern in order to prevent reentrancy vulnerabilities and other vulnerabilities.
 This would look like

 ```js
function exampleCEI() public {
    // Checks
    // so this would be like require statements/conditionals

    // Effects
    // this would be updating all variables and emitting events

    // Interactions
    // This would be anything that interacts with users or the world. Examples include sending money to users, sending nfts, etc
}
 ```


### Modifier Notes

Sometimes you will type alot of the same code over and over. To keep things simple and non-redundant, you can use a modifier.

Modifiers are written with a `_;` before/after the code logic. The `_;` means to execute the code before or after the modifier code logic. The modifier will always execute first in the code function so `_;` represents whether to execute the function logic before or after the modifier.
examples:


```js
contract DSCEngine {
    /* Errors */
    error DSCEngine__NeedsMoreThanZero();

    /* Modifiers */
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    /*
    * @dev `@param` means the definitions of the parameters that the function takes.
    * @param tokenCollateralAddress: the address of the token that users are depositing as collateral
    * @param amountCollateral: the amount of tokens they are depositing
    */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external moreThanZero(amountCollateral) {}
}
```
As you can see from the example above, we created a modifier with a custom error. The modifier takes a parameter of a `uint256` named `amount`. When using this modifier, we pass the `uint256 amountCollateral` parameter used in the `function depositCollateral` as the parameter that the modifier uses. This needs to be done when your modifier has a parameter or you will get an error.



```js
 modifier raffleEntered() {
        vm.prank(PLAYER);
        // PLAYER pays the entrance fee and enters the raffle
        raffle.enterRaffle{value: entranceFee}();
        // vm.warp allows us to warp time ahead so that foundry knows time has passed.
        vm.warp(block.timestamp + interval + 1); // current timestamp + the interval of how long we can wait before starting another audit plus 1 second.
        // vm.roll rolls the blockchain forward to the block that you assign. So here we are only moving it up 1 block to make sure that enough time has passed to start the lottery winner picking in raffle.sol
        vm.roll(block.number + 1);
        // completes the rest of the function that this modifier is applied to
        _;
    }
```
In this example the `_;` is after the modifier code logic to say that the modifier should be executed first, then the function it is applied to's logic should be execute afterwards. If the `_;` was before the modifier code logic, then it whould mean to execute the function it is applied to's logic before the modifier and then do the modifier logic afterwards 


Modifiers go after the visibility modifiers in the function declaration. 
example:
```js
 function testPerformUpkeepUpdatesRafflesStateAndEmitsRequestId() public raffleEntered {
        // Act
        // record all logs(including event data) from the next call
        vm.recordLogs();
        // call performUpkeep
        raffle.performUpkeep("");
        // take the recordedLogs from `performUpkeep` and stick them into the entries array
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // entry 0  is for the VRF coordinator
        // entry 1 is for our event data
        // topic 0 is always resevered for
        // topic 1 is for our indexed parameter
        bytes32 requestId = entries[1].topics[1];

        // Assert
        // gets the raffleState and saves it in a variable named raffleState
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // assert that the requestId was indeed sent, if it was zero then no request Id was sent.
        assert(uint256(requestId) > 0);
        // this is asserting that the raffle state is `calculating` instead of `OPEN`
        assert(uint256(raffleState) == 1);
        // this is the same as saying what is below:
        // assert(raffleState == Raffle.RaffleState.CALCULATING);
        //         enum RaffleState {
        //     OPEN,      // index 0
        //     CALCULATING // index 1
        // }
    }
```
In this example, the modifier is `raffleEntered`. 

### Visibility Modifier Notes: 

There are 4 types of visibility modifiers in solidity. Public, Private, External, Internal.

1. Public:
Accessible from anywhere (inside contract, other contracts, and externally)
Automatically creates a getter function for state variables
Most permissive modifier
Example:
```javascript
contract Example {
    uint public myNumber; // Creates automatic getter
    
    function publicFunction() public {
        // Can be called from anywhere
    }
}
```

2. Private: 
Only accessible within the contract where it's defined
Cannot be accessed from derived contracts or externally
Most restrictive modifier
Private variables are still visible on the blockchain
Needs a Getter Function to be used/called outside the contract where it's defined.
Example:
```javascript
contract Example {
    uint private secretNumber; // Only this contract can access

    // internal & private functions start with a `_` to let us developers know that they are internal functions
    function _privateFunction() private {
        // Only callable from within this contract
    }
}
```

3. Internal:
Accessible within the current contract and contracts that inherit from it
Cannot be accessed externally
Default visibility for state variables
Example:
```javascript
contract Base {
    uint internal sharedNumber; // Accessible by inheriting contracts
    
    // internal & private functions start with a `_` to let us developers know that they are internal functions
    function _internalFunction() internal {
        // Callable from this contract and inherited contracts
    }
}

contract Example is Base {
    function useInternal() public {
        _internalFunction(); // Can access internal members
        sharedNumber = 5;   // Can access internal variables
    }
}
```

4. External
Only accessible from outside the contract
Cannot be called internally (except using this.function())
More gas efficient for large data parameters
Only available for functions (not state variables)
Example:
```javascript
contract Example {
    function externalFunction() external {
        // Only callable from outside
    }
    
    function someFunction() public {
        // this.externalFunction(); // Need 'this' to call external function
    }
}
```

*** Key points to remember: ***
1. State Variable Default Visibility:
- If you don't specify visibility, state variables are internal by default

2. Function Default Visibility:
- Functions without specified visibility are public by default
- However, it's considered best practice to always explicitly declare visibility

3. Visibility Access Levels (from most to least restrictive):
    private - internal - external/public

4. Gas Considerations:
- external functions can be more gas-efficient when dealing with large arrays in memory
- public functions create an additional JUMP in the bytecode which costs more gas

5. Security Best Practices:
- Always use the most restrictive visibility possible
- Be explicit about visibility (don't rely on defaults)
- Remember that private doesn't mean secret - data is still visible on the blockchain

### Variable Notes
All of the value types variables are: `boolean`, `unit`(only positive), `int`(postive or negative), `string`, `bytes`, `address`

The reference types of variables are: `arrays`, `structs`, `mappings`. 


The Followings variable must be declared at the contract level (not in any functions):

#### Constant Notes
Variables that will never be updated or changed can be listed as constant. 
For example:
`uint8 public constant DECIMALS = 8; ` - constant veriable should be CAPITALIZED as seen in this example.
Constant variables are directly embedded in the bytecode. This saves gas.
`constant` is a state mutability modifier.

#### Immutable Notes
Variables that are declared at the contract level but initialized in the constructor can be listed as Immutable. This saves gas.
For Example:
```javascript
address public immutable i_owner; // As you can see immutable variables should be named with an `i_` infront of the name

 constructor() {
        i_owner = msg.sender; // As you can see immutable variables should be named with an `i_` infront of the name
    }
``` 
Immutable variables are directly embedded in the bytecode when the contract is deployed and can only be set once during contract construction.
`immutable` is a state mutability modifier.

#### Storage Variable Notes
Variables that are not constant or immutable but are declared at the contract level at saved in storage. So these variables should be named with `s_`.
For Example:
```javascript
    address[] public s_funders;
    mapping(address funder => uint256 amountFunded) public s_addressToAmountFunded;
    AggregatorV3Interface private s_priceFeed;
```
State Variables declared at contract level by default ARE stored in storage.
Storage variables are mutable by default (can be changes at anytime), so there isn't a specific state mutability modifier.


#### Saving Gas with Storage Variable Notes

If you have a storage variable or immutable variables (not constant variables), then you can save gas and make the contract more reeadable by making the storage/immutable variables `private` and making a getter function that grabs the storage variable.
Example:
```javascript  

    // an array of addresses called funders.
    address[] private s_funders;

    // a mapping, mapping the addresses and their amount funded.
    // the names "funder" and "amountFunded" is "syntaxic sugar", just makes it easier to read
    mapping(address funder => uint256 amountFunded) private s_addressToAmountFunded;

    // to be used in constructor
    address private immutable i_owner; // variables defined in the constructor, can be marked as immutable if they will not change. This will save gas
    // immutable varibles should use "i_" in their name

  /**
     * View / Pure Functions (These are going to be our Getters)
     * Below are our Getter functions. by making storage variables private, they save more gas. Then by making view/pure functions to get the data within the private storage functions, it also makes the code much more readable.
     * These are called getter functions because all they do is read and return private data from the contracts storage without modifying the contract state.
     */

    // This function allows anyone to check how much eth a specific address has funded to the contract.
    function getAddressToAmountFunded(address fundingAddress) external view returns (uint256) {
        // takes the fundingAddress parameter that users input and reads and returns the amount that that address has funded. It is accessing the mapping of s_addressToAmountFunded which stores the funding history.
        return s_addressToAmountFunded[fundingAddress];
    }

    //this function allows anyone to input a number(index) and they will see whos address is at that index(number).
    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
```

#### Custom Error Variable Notes

Reverting with strings is not good because it costs too much gas. Instead, save the error as a custome error and revert with the custom error.
Example:
```javascript
contract Raffle {
    error Raffle__SendMoreToEnterRaffle(); // custom errors saves gas

    function enterRaffle() public payable {
        // users must send more than or equal to the entranceFee or the function will revert
        // require(msg.value >= i_entranceFee, "Not enough ETH sent!"); // this is no good because string revert messages cost TOO MUCH GAS!

        // if a user sends less than the entranceFee, it will revert with the custom error
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        } // this is the best way to write conditionals because they are so gas efficent.
    }
}
```
Another Example:
```js
contract Lending {

    error LendingEngine__YouNeedMoreFunds();

    mapping(address user => uint256 amountUserHas) private s_balances;

 function depositCollateral(address tokenCollateralAddress, uint256 amountCollateralSent)
        public
        moreThanZero(amountCollateralSent)
    {
        // require(s_balances[msg.sender] >= amountCollateralSent, "Not Enough"); // this is no good because string revert messages cost TOO MUCH GAS!
        if (s_balances[msg.sender] < amountCollateralSent) {
            revert LendingEngine__YouNeedMoreFunds();
        }
    }
}
```

To make custome errors even easier for users or devs to read when they get this error, we can let them know why they go this error:
Example
```js
contract Raffle {
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playerslength, uint256 raffleState);


    function performUpkeep(bytes calldata /* performData */ ) external {
        //
        (bool upkeepNeeded,) = checkUpkeep("");
        //
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(
                    s_raffleState /*This could be a Rafflestate raffleState as well. Since enums map to their indexed position it can also be uint256(s_raffleState) since we have this defined as well */
                )
            );
        }
}
```

#### Reference Types Variable Notes

The reference types of variables are: `arrays`, `structs`, `mappings`. 

##### Array Notes

There are two types of Arrays, static and dynamic.
Dynamic array: the size of the array can grow and shrink
Static array: the size is fixed: example: Person[3]


Setting up an array variable:
Examples:
```js
// an array of addresses called funders.
    address[] private s_funders;

// address array(list) of players who enter the raffle
address payable[] private s_players; // this array is NOT constant because this array will be updated everytime a new person enters the raffle.
// ^ this is payable because someone in this raffle will win the money and they will need to be able to receive the payout
```

Pushing items into an array example:
```js
 // You can create your own types by using the "struct" keyword
    struct Person {
        // for every person, they are going to have a favorite number and a name:
        uint256 favoriteNumber; // slot 0
        string name; // slot 1
    }

    //dynamic array of type struct person
    Person[] public listOfPeople; // Gets defaulted to a empty array

     // arrays come built in with the push function that allows us to add elements to an array
    function addPerson(string memory _name, uint256 _favoriteNumber) public {
        // pushes(adds) a user defined person into the Person array
        listOfPeople.push(Person(_favoriteNumber, _name));

        // adds the created mapping to this function, so that when you look up a name, you get their favorite number back
        nameToFavoriteNumber[_name] = _favoriteNumber;
    }
```

To reset an array:
Example:
```js
 function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length; 
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;

        // s_players gets updated to a new address array of size 0 to start(since it removed all items in the array, it starts a 0) that is also payable
        s_players = new address payable[](0); // resets the array

        // updates the current timestamp into the most recent timestamp so we know when this raffle started
        s_lastTimeStamp = block.timestamp;

        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(s_recentWinner);
    }
```

##### Struct Notes
Structs are custom data types that let you create your own complex data structure by grouping together different variables. They're like creating a template for a custom object.

Example:
```js
 // You can create your own types by using the "struct" keyword
    struct Person {
        // for every person, they are going to have a favorite number and a name:
        uint256 favoriteNumber; // slot 0
        string name; // slot 1
    }

//dynamic array of type struct `person`
Person[] public listOfPeople; // Gets defaulted to a empty array

 // arrays come built in with the push function that allows us to add elements to an array
function addPerson(string memory _name, uint256 _favoriteNumber) public {
// pushes(adds) a user defined person into the Person array
listOfPeople.push(Person(_favoriteNumber, _name));
// adds the created mapping to this function, so that when you look up a name, you get their favorite number back
nameToFavoriteNumber[_name] = _favoriteNumber;
    }
```

##### Mapping Notes
Mappings are key-value pair data structures, similar to hash tables or dictionaries in other languages. They're unique in Solidity because all possible keys exist by default and map to a value of 0/false/empty depending on the value type.

examples:
```js
// mapping types are like a search functionality or dictionary
    mapping(string => uint256) public nameToFavoriteNumber;

    function addPerson(string memory _name, uint256 _favoriteNumber) public {
        // pushes(adds) a user defined person into the Person array
        listOfPeople.push(Person(_favoriteNumber, _name));

        // adds the created MAPPING to this function, so that when you look up a name, you get their favorite number back
        nameToFavoriteNumber[_name] = _favoriteNumber;
    }
```
```js
    // a mapping, mapping the addresses and their amount funded.
    // the names "funder" and "amountFunded" is "syntaxic sugar", just makes it easier to read
    mapping(address funder => uint256 amountFunded) private s_addressToAmountFunded;

    function fund() public payable {
     
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "didn't send enough ETH");

        // this line keeps track of how much each sender has sent
        // you read it like: mapping(check the mapping) address => amount sent of the sender. So how much the sender sent = how much the sender has sent plus how much he is currently sending.
        // addressToAmountFunded[msg.sender] = addressToAmountFunded[msg.sender] + msg.value;
        //above is the old way. below is the shortcut with += . This += means we are adding the new value to the existing value that already exists.
        s_addressToAmountFunded[msg.sender] += msg.value;

        // the users whom successfully call this function will be added to the array.
        s_funders.push(msg.sender);
    }

     function cheaperWithdraw() public onlyOwner {
        uint256 funderLength = s_funders.length;
        for (uint256 funderIndex = 0; funderIndex < funderLength; funderIndex++) {
            address funder = s_funders[funderIndex];
            
            // then we reset this funders amount(this is tracked by the mapping of "addressToAmountFunded") to 0 when he withdraws
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, ) =
            payable(msg.sender).call{value: address(this).balance}(""); 
        require(callSuccess, "Call Failed");
    }

    /* Getter Function since the mapping is private to save gas */

     // This function allows anyone to check how much eth a specific address has funded to the contract.
    function getAddressToAmountFunded(address fundingAddress) external view returns (uint256) {
        // takes the fundingAddress parameter that users input and reads and returns the amount that that address has funded. It is accessing the mapping of s_addressToAmountFunded which stores the funding history.
        return s_addressToAmountFunded[fundingAddress];
    }
```


### Constructor Notes
Constructors are special functions that are executed only once when a contract is deployed.

Constructor Facts:
- Called once during contract creation
- Used to initialize state variables
- Cannot be called after contract deployment
- Only one constructor per contract

Example:
```js
contract Raffle {

    uint256 private immutable i_entranceFee; 
    uint256 private immutable i_interval;

    uint256 private s_lastTimeStamp;

    // this constructor takes a entranceFee and interval, so when the owner deploys this contract, he will input what these variables are equal to.
    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        // at contract deployment, the s_lastTimeStamp will record the timestamp of the block in which the contract is deployed. This value will be used as the initial timestamp for the raffle contract.
        s_lastTimeStamp = block.timestamp;
    }
}
```

### Event Notes
When a storage variable is updated, we should always emit an event. This makes migration/version-updates of contracts much easier and events make front-end "indexing" much easier. It allows for the smart contract, front-end, and blockchain to easily know when something has been updated. You can only have 3 indexed events per event and can have non indexed data. Indexed data is basically filtered data that is easy to read from the blockchain and non-indexed data will be abi-encoded on the blockchain and much much harder to read.

The indexed parameter in events are called "Topics".

Example:
```javascript

contract Raffle() {
    error Raffle__SendMoreToEnterRaffle(); 
    uint256 private immutable i_entranceFee; 
    address payable[] private s_players; 


/* Events */
    // events are a way to allow the smart contract to listen for updates.
    event RaffleEntered(address indexed player); // the player is indexed because this means 
    // ^ the player is indexed because events are logged to the EVM. Indexed data in events are essentially the important information that can be easily queried on the blockchain. Non-Indexed data are abi-encoded and difficult to decode.

    function enterRaffle() public payable {   
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        } 

        // when someone enters the raffle, `push` them into the array
        s_players.push(payable(msg.sender)); // we need the payable keyword to allow the address to receive eth when they will the payout

        // an event is emitted the msg.sender is added the the array/ when a user successfully calls enterRaffle()
        emit RaffleEntered(msg.sender); // everytime we update storage, we always want to emit an event
    }
}
```

### Enum Notes

An Enum (enumeration) is a type declaration. An enum is a way to create a user-defined type with a fixed set of constant values or states. It's useful for representing a fixed number of options or states in a more readable way.

Examples:
```js                                   
contract Raffle {

      /* Type Declarations */
        enum RaffleState {
        OPEN, // index 0
        CALCULATING // index 1
    }

    // The state of the raffle of type RaffleState(enum)
    RaffleState private s_raffleState;

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;

        // when the contract is deployed it will be open
        s_raffleState = RaffleState.OPEN; // this would be the same as s_raffleState = RaffleState.(0) since open in the enum is in index 0
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        // if the raffle is not open then any transactions to enterRaffle will revert
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender)); 
        emit RaffleEntered(msg.sender); 
    }

    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        // when someone calls the pickWinner, users will no longer be able to join the raffle since the state of the raffle has changed to calculating and is no longer open.
        s_raffleState = RaffleState.CALCULATING;

       ...
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length; 
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        // the state of the raffle changes to open so players can join again.
        s_raffleState = RaffleState.OPEN;

        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }
}


```

In enums:

- You can only be in ONE state at a time
- Each option has a number behind the scenes (starting at index 0)
- You can't make up new options that aren't in the list of the Enum you created.




### Call and staticcall differences Notes

In a function call, what is the difference between 'call' and 'staticcall'?

'call' allows the function to modify the contract's state while 'staticcall' only reads data without changing the contract's state.




### Inheritance Notes

To inherit from another contract, import the contract and inherit it with `is` keyword.
Example:
```js
// importing the Chainlink VRF
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

// inheriting the Chainlink VRF
contract Raffle is VRFConsumerBaseV2Plus {}
```
After inheriting contracts, you can use variables from the parent contract in the child contract.


#### `Super` (Inheritance) keyword Notes

The keyword super should be used when we override a function from a parent contract, want to add logic, but still also call the regular function with all its logic from the parent contract.
example from foundry-defi-stablecoin-f23:
```js

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    // ... skipped code

  function burn(uint256 _amount) public override onlyOwner {
        // balance variable is the msg.sender's current balance
        uint256 balance = balanceOf(msg.sender);
        // if the amount they input is less than or equal to 0 revert.
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        // if the msg.sender's balance is less than the amount they try to burn, revert.
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        // calls the burn function from the parent class
        // `super` means to call the parent contract(ERC20Burnable) and call the function `burn` from the parent contract
        // super is used because we overrided the contract, and we also want to complete the if statements above and do the regular burn function in the parent contract
        super.burn(_amount);
    }

    // ... skipped code
}
```



#### Inheriting Constructor Notes

If the contract you are inheriting from has a constructor, then the child contract(contract that is inheriting from the parent) needs to add that constructor.
Example:

Before Inheritance:
```js
contract Raffle {

    uint256 private immutable i_entranceFee; 
    uint256 private immutable i_interval;

    uint256 private s_lastTimeStamp;

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }
}

```


Parent Contract we are inheriting from's constructor:
```js
abstract contract VRFConsumerBaseV2Plus is IVRFMigratableConsumerV2Plus, ConfirmedOwner {
  error OnlyCoordinatorCanFulfill(address have, address want);
  error OnlyOwnerOrCoordinator(address have, address owner, address coordinator);
  error ZeroAddress();

  // s_vrfCoordinator should be used by consumers to make requests to vrfCoordinator
  // so that coordinator reference is updated after migration
  IVRFCoordinatorV2Plus public s_vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) ConfirmedOwner(msg.sender) {
    if (_vrfCoordinator == address(0)) {
      revert ZeroAddress();
    }
    s_vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
  }
```

After Child Contract Inherits:
```js
contract Raffle is VRFConsumerBaseV2Plus {
     uint256 private immutable i_entranceFee; 
    uint256 private immutable i_interval;

    uint256 private s_lastTimeStamp;

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator)
    // `VRFConsumerBaseV2Plus` is the name of the contract we are inheriting from
    VRFConsumerBaseV2Plus(vrfCoordinator) // here we are going to define the vrfCoordinator address during this contracts deployment, and this will pass the address to the VRFConsumerBaseV2Plus constructor.
    
    {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }
}

```

### Override Notes

Functions tagged with `virtual` are overrided by functions with the same name but with the `override` keyword.

### Modulo Notes

The ` % ` is called the modulo operation. It's kinda like divison, but it represents the remainder. 
For example: 

`10` / `2` = `5`                                           Key: ` / ` = divison  
but 10 % 2 = 0 as there is no remainder                         ` % ` = modulo

10 % 3 = 1 (because 10 divided by 3 leaves a remainder of 1)

20 % 7 = 6 (because the remainder is 6)
(^ this is read `20 mod 7 equals 6`)
 


### Sending Money in Solidity Notes

There are three ways to transfer the funds: transfer, send, and call

Transfer (NOT RECOMMENDED):
```js
    // transfers balance from this contract's balance to the msg.sender
    payable(msg.sender).transfer(address(this).balance); //  this is how you use transfer
    // ^there is an issue with using transfer, as if it uses more than 2,300 gas it will throw and error and revert. (sending tokens from one wallet to another is already 2,100 gas)
```

Send (NOT RECOMMENDED) :
```js
    // we need to use "bool" when using `send` because if the call fails, it will not revert the transaction and the user would not get their money. ("send" also fails at 2,300 gas)
    bool sendSuccess = payable(msg.sender).send(address(this).balance);
    // require sendSuccess to be true or it reverts with "Send Failed"
    require(sendSuccess, "Send failed");
```

Call (RECOMMENDED) :
    Using `call` is lower level solidity and is very powerful, is the best one to use most of the time.

    `call` can be used to call almost every function in all of ethereum without having an ABI!

     Using `call` returns a boolean and bytes data. The bytes aren't important in the example below, so we commented it out and left the comma. (but really we would delete it if this was a production contract and we would leave the comma. however if we were calling a function we would keep the bytes data) (bytes objects are arrays which is why we use the memory keyword).
    
```js
        (bool callSuccess, /* bytes memory dataReturned */ ) = payable(msg.sender).call{value: address(this).balance}(
            "" /*<- this is where we would put info of another function if we were calling another function(but we arent here so we leave it blank) */
        );
        //        calls the value to send to the payable(msg.sender)^

        // require callSuccess to be true or it reverts with "Call Failed"
        require(callSuccess, "Call Failed");
```

Here is another example for the recommended `Call` to transfer funds:
```js
contract Raffle {
    address payable private s_recentWinner;

    ...

     function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // randomWords is 0 because we are only calling for 1 Random number from chainlink VRF and the index starts at 0, so this represets the 1 number we called for.
        uint256 indexOfWinner = randomWords[0] % s_players.length; // this says the number that is randomly generated modulo the amount of players in the raffle
        //  ^ modulo means the remainder of the division. So if 52(random Number) % 20(amount of people in the raffle), this will equal 12 because 12 is the remainder! So whoever is in the 12th spot will win the raffle. And this is saved into the variable indexOfWinner ^

        // the remainder of the modulo equation will be identified within the s_players array and saved as the recentWinner
        address payable recentWinner = s_players[indexOfWinner];

        // update the storage variable with the recent winner
        s_recentWinner = recentWinner;

        // pay the recent winner with the whole amount of the contract. 
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        // if not success then revert
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }
}
```

### Console.log Notes

To use console.log, import the following into your contract:

```js
import {console} from "forge-std/console.log";
```

Then to use console.log, follow the format below:

```js
function exampleLog() external {
    console.log("Hello!");

    uint256 dog = 3;
    // this will say "Dog is equal to 3"
    console.log("Dog is equal to: ", dog); 
}
```




### Remappings in foundry.toml Notes
Remappings tell foundry to replace the mapping for imports. 
for example:
```javascript
 remappings = ["@chainlink/contracts/=lib/chainlink-brownie-contracts/contracts/"]  // in this example, we are telling foundry that everytime it sees @chainlink/contracts/ , it should point to lib/chainlink-brownie-contracts/ as this is where our packages that we just installed stays
 ```

when using cyfrin foundry devops, make sure to Update your `foundry.toml` to have read permissions on the broadcast folder (copy and paste the following into your `foundry.toml`):
```js
fs_permissions = [
    { access = "read", path = "./broadcast" },
    { access = "read", path = "./reports" },
]
```

when deploying or interacting with contracts, if you get an error of `-ffi` then you must input `ffi = true` in your `foundry.toml`. However, make sure to turn this off when you are done as this command is dangerous and allows the host of the library to execute commands on your machine.




### abi.encode Notes & abi.encodePacked Notes
(If you need help, the following video will explain it: `https://updraft.cyfrin.io/courses/advanced-foundry/how-to-create-an-NFT-collection/evm-opcodes-advanced`)

From a high level, `abi.encodePacked` can combine strings or nummbers or pretty much anything together.

How does it do this? `abi.encode` can take any value or string and encode it into the evm's opcodes. By doing this, the evm can translate it from english string/numbers to an encoded opcode value.

`abi.encode`: Will transform any value into the evm's bytecode/opcode value, but it will have many 0000s.

`abi.encodePacked`: Will transform any value into the evm's bytecode/opcode value without the many 000s.

`abi.decode`: Will take the bytecode/opcode that is encoded and transfrom it back into its original value.


#### How to use abi.encode and abi.decode Notes

`abi.encode` examples:
```js
 // In this function, we encode the number one to what it'll look like in binary
    // Or put another way, we ABI encode it.
    function encodeNumber() public pure returns (bytes memory) {
        bytes memory number = abi.encode(1);
        return number;
    }

    // You'd use this to make calls to contracts
    function encodeString() public pure returns (bytes memory) {
        bytes memory someString = abi.encode("some string");
        return someString;
    }

    // encodes the two strings together as one opcode
     function multiEncode() public pure returns (bytes memory) {
        bytes memory someString = abi.encode("some string", "it's bigger!");
        return someString;
    }

```

`abi.encodePacked` examples:
```js
 // https://forum.openzeppelin.com/t/difference-between-abi-encodepacked-string-and-bytes-string/11837
    // encodePacked
    // This is great if you want to save space, not good for calling functions.
    // You can sort of think of it as a compressor for the massive bytes object above.
    function encodeStringPacked() public pure returns (bytes memory) {
        bytes memory someString = abi.encodePacked("some string");
        return someString;
    }

    // encodes the two strings together as one opcode
     function multiEncodePacked() public pure returns (bytes memory) {
        bytes memory someString = abi.encodePacked("some string", "it's bigger!");
        return someString;
    }
```

`abi.decode` examples:
```js
 function decodeString() public pure returns (string memory) {
        string memory someString = abi.decode(encodeString(), (string));
        return someString;
    }

    // Gas: 24612
    // decode the two strings and keeps them as two different strings
    function multiDecode() public pure returns (string memory, string memory) {
        (string memory someString, string memory someOtherString) = abi.decode(multiEncode(), (string, string));
        return (someString, someOtherString);
    }
```


Examples of what does not work vs what does:
```js
  // This doesn't work!
    function multiDecodePacked() public pure returns (string memory) {
        string memory someString = abi.decode(multiEncodePacked(), (string));
        return someString;
    }

    // This does!
    // Gas: 22313
    function multiStringCastPacked() public pure returns (string memory) {
        string memory someString = string(multiEncodePacked());
        return someString;
    }
```

How to use `abi.encodePacked` in tests:

example from foundry-nft-f23:
```js
contract BasicNftTest is Test {

    string public constant PUG =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

    // ... skipped code

    // Test to verify the NFT contract was deployed with the correct name
    function testNameIsCorrect() public view {
        // Define the expected name that we set in the constructor
        string memory expectedName = "Dogie";
        // Get the actual name from the deployed contract
        string memory actualName = basicNft.name();
        // We can't directly compare strings in Solidity, so we:
        // 1. Convert both strings to bytes using abi.encodePacked
        // 2. Hash both byte arrays using keccak256
        // 3. Compare the resulting hashes
        assert(keccak256(abi.encodePacked(expectedName)) == keccak256(abi.encodePacked(actualName)));
    }

    // Test to verify NFT minting works and updates balances correctly
    function testCanMintAndHaveABalance() public {
        // Use Forge's prank function to make subsequent calls appear as if they're from USER
        vm.prank(USER);
        // Mint a new NFT with our test URI (PUG)
        basicNft.mintNft(PUG);

        // Verify the USER now owns exactly 1 NFT
        assert(basicNft.balanceOf(USER) == 1);
        // Verify the token URI was stored correctly for token ID 0
        // Using the same string comparison technique as above since we can't directly compare strings
        assert(keccak256(abi.encodePacked(PUG)) == keccak256(abi.encodePacked(basicNft.tokenURI(0))));
    }
}
```

example from foundry-nft-f23:
```js
 function testFlipTokenToSad() public {
        // Start a series of transactions from USER address
        vm.startPrank(USER);

        // Mint a new NFT
        moodNft.mintNft();

        // Flip the mood of token 0 from happy to sad
        moodNft.flipMood(0);

        // Log the token URI for verification
        console.log(moodNft.tokenURI(0));

        // Verify the token URI matches the expected SAD SVG URI
        assertEq(keccak256(abi.encodePacked(moodNft.tokenURI(0))), keccak256(abi.encodePacked(SAD_SVG_URI)));
    }
```

example from foundry-nft-f23:
```js
    // Test function to verify SVG to URI conversion
    function testConvertSvgToUri() public view {
        // Expected URI after base64 encoding the SVG
        string memory expectedUri =
            "data:image/svg+xml;base64,PHN2ZyB2aWV3Qm94PSIwIDAgMjAwIDIwMCIgd2lkdGg9IjQwMCIgaGVpZ2h0PSI0MDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+IDxjaXJjbGUgY3g9IjEwMCIgY3k9IjEwMCIgZmlsbD0ieWVsbG93IiByPSI3OCIgc3Ryb2tlPSJibGFjayIgc3Ryb2tlLXdpZHRoPSIzIiAvPiA8ZyBjbGFzcz0iZXllcyI+IDxjaXJjbGUgY3g9IjQ1IiBjeT0iMTAwIiByPSIxMiIgLz4gPGNpcmNsZSBjeD0iMTU0IiBjeT0iMTAwIiByPSIxMiIgLz4gPC9nPiA8cGF0aCBkPSJtMTM2LjgxIDExNi41M2MuNjkgMjYuMTctNjQuMTEgNDItODEuNTItLjczIiBzdHlsZT0iZmlsbDpub25lOyBzdHJva2U6IGJsYWNrOyBzdHJva2Utd2lkdGg6IDM7IiAvPiA8L3N2Zz4=";

        // Raw SVG data to be converted
        string memory svg =
            '<svg viewBox="0 0 200 200" width="400" height="400" xmlns="http://www.w3.org/2000/svg"> <circle cx="100" cy="100" fill="yellow" r="78" stroke="black" stroke-width="3" /> <g class="eyes"> <circle cx="45" cy="100" r="12" /> <circle cx="154" cy="100" r="12" /> </g> <path d="m136.81 116.53c.69 26.17-64.11 42-81.52-.73" style="fill:none; stroke: black; stroke-width: 3;" /> </svg>';

        // Convert the SVG to URI using our contract's function
        string memory actualUri = deployer.svgToImageURI(svg);

        // Verify the conversion matches our expected result
        // Using keccak256 hash comparison for string equality
        assert(keccak256(abi.encodePacked(expectedUri)) == keccak256(abi.encodePacked(actualUri)));

        // Log both URIs for manual verification
        console.log("expectedUri:", expectedUri);
        console.log("actualUri:", actualUri);
    }
```





### Function Selector & Function Signature Notes

The function Signature is the function name and its parameters:
example:

if the function is:
```js
function transferFrom(address src, address dst, uint256 wad) {
    // ... code skipped
}
```
Then the function signature would be:
```js
// the function name and its parameters
transferFrom(address,address,uint256)
```


The Function Selector is the first four bytes of the function signature:
example:
```js
// this would be the function selector of the function signature above (of function transferFrom above)
// if we encode the transferFrom function selector (found above) we would get this function selector:
0x23b872dd
```
These are the first four bytes because opcodes in the evm are defined in two digits/units. so the first four bytes are: `23` `b8` `72` `dd` to make the function selector of `0x23b872dd`


if you want to interact with an outside contract from within a contract, its best to use an interface instead of a lowlevel call for security reasons


If you want more information, you can find it at ` https://updraft.cyfrin.io/courses/advanced-foundry/how-to-create-an-NFT-collection/evm-signatures-selectors ` - This video also goes over how to call any contracts/function even without having an interface







------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


### Delegatecall Notes

https://solidity-by-example.org/delegatecall/

`delegatecall` is a low level function similar to `call`.

When contract A executes `delegatecall` to contract B, B's code is executed with contract A's storage, `msg.sender` and `msg.value`.
example:
```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// NOTE: Deploy this contract first
contract B {
    // NOTE: storage layout must be the same as contract A
    uint256 public num;
    address public sender;
    uint256 public value;

    function setVars(uint256 _num) public payable {
        num = _num;
        sender = msg.sender;
        value = msg.value;
    }
}

contract A {
    uint256 public num;
    address public sender;
    uint256 public value;

    event DelegateResponse(bool success, bytes data);

    function setVars(address _contract, uint256 _num) public payable {
        // A's storage is set, B is not modified.
        (bool success, bytes memory data) = _contract.delegatecall(
            abi.encodeWithSignature("setVars(uint256)", _num)
        );

        emit DelegateResponse(success, data);
    }
}

```

Note: in the example above, contract A has the same variable names are contract B, but this is not needed. Contract A could have it's variables named:  
```js
    uint256 public food;
    address public drinks;
    uint256 public dessert;
```
and the delegate call function would still work. `delegatecall` allows us to borrow functions and transposes the function logic to the storage location equivalence. `delegatecall` does not copy the storage values, `delegatecall` only copies the function logic, and whatever values are updated in the `delegatecall` function will be saved in the storage location equivalence. So in the example above, if `setVars` is called in contract A, it calls `delegatecall`, takes a contract address and a number paramter, this uint256 will be saved in the variable `food` since that is the storage location equivalence. The contract address is needed in the `delegatecall` so it knows which contract to point to, to copy its function logic in the function signature of "setVars(uint256)" within the contract that is passed.

Also, in the example above, even if we did not have any variables in contract A, storage slot 00 and storage slot 01 would still get updated (the first two storage slots, it starts counting at 00).

Also, in the example above, in contract A, if we change the variables to:
```js
    bool public food; // changed this to a bool
    address public drinks;
    uint256 public dessert;
```
the delegatecall function will still work, it's just setting the storage slot of the boolean to a number and when solidity reads it, it goes "well the storage location equivalence here is storage slot 00 and this storage slot is a boolean" And if this storage slot gets updated to anyting other than zero, it will be `true`; and if its a 0, it will return `false`.




------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




### Merkle Tree & Merkle Proof Notes
If we had a dynamic array that can grow indefintely, looping through every item in the array would be incredibly gas expensive and can cause a DOS. To fix this, we can use a `Merkle Proof`. 

Essentially, merkle proofs allow us to prove that some piece of data is in fact in a group of data. 
Example:
    If we have a group of data, like a group of addresses with an allowed amount, is my address in that group of addresses? Merkle Proofs enable us to do this, and Merkel Proofs come from Merkel Trees, and Merkel tress are the data strcuture that is used here

You can learn more about Merkle Trees at `https://updraft.cyfrin.io/courses/advanced-foundry/merkle-airdrop/merkle-proofs `. This section of the cyfrin course goes over Merkle Trees & proofs, signatures and ECDSA(v, r, s).
    
#### What is a Merkle Tree?
Merkle trees are a data structure in computer science. Merkle trees are used to encrypt blockchain data more securely and efficiently. It was invented by Ralph Merkle in 1979. Ralph Merkle also happens to be one of the inventors of public key cryptography!

Example:
How is a Merkle tree used to verify eligibility for an airdrop?:

    Answer: A smart contract can store only the Merkle root on-chain, saving more gas than storing every address on an airdrop. The Merkle tree generates a Merkle proof, which can be verified to prove eligibility. This proof authenticates a specific wallet address included in the list of eligible wallets by comparing it to the Merkle root.


##### Structure / How Merkle Tree Works
```js
                                            [H(H1-4 + H5-8)]                        <------ Root Hash
                                                    |
                         +--------------------------+-------------------------+
                         |                                                    |
                        H1-4                                                H5-8
                 [H(H1-2 + H3-4)]                                     [H(H5-6 + H7-8)]           <----Branches(proofs)
                         |                                                    |
            +------------+------------+                          +------------+------------+
            |                         |                          |                         |
            H1-2                    H3-4                        H5-6                      H7-8
        [H(Block1+2)]           [H(Block3+4)]               [H(Block5+6)]            [H(Block7+8)]     <-----Branches(proofs)     
            |                         |                           |                         |
    +-------+-------+         +-------+-------+           +-------+-------+         +-------+-------+
    |               |         |               |           |               |         |               |
Block 1         Block 2    Block 3         Block 4     Block 5         Block 6     Block 7        Block 8     <----Leaves
"data1"         "data2"    "data3"         "data4"     "data5"         "data6"     "data7"        "data8"
```
Note: `H` stands for Hash.

- As you can see from the diagram above, a merkle tree is a binary hash tree where each leaf node contains the hash of a data block.
- Each non-leaf node contains the hash of its two child nodes
- The root node (Merkle root) represents a single hash that verifies all data in the tree
- Typically uses cryptographic hash functions like Keccak256

How it works
    - Data is divided into blocks/chunks
    - Each block is hashed to create leaf nodes
    - Pairs of hashes are combined and hashed again to form parent nodes
    - Process continues until reaching a single root hash
    - Creates a hierarchical structure of hashes
Use cases
    - Bitcoin and other cryptocurrencies for transaction verification
    - Git for version control and file integrity
    - Distributed file systems like IPFS
    - Peer-to-peer networks for data verification
    - Certificate transparency logs

#### What is a Merkle Proof?
A merkle Proof is a way for someone to prove that some data is on one of the Merkle tree's leaves to someone who only knows the root hash.

    How proofs work
        - Also called "Merkle paths" or "proof of inclusion"
        - Proves a specific data block is part of the Merkle tree
        - Only requires providing the sibling hashes along the path to the root
        - Verifier can reconstruct path to root using these hashes
        - If reconstructed root matches known root, proof is valid

    Example:
    What is a Merkle proof used for?
        To verify the presence of a specific piece of data within a Merkle tree.


    Given a Merkle proof, how can the validity of a leaf node be verified?:
        
        Answer: By iterating through the proof array hashing each element with the previous computed hash, then compare the final output to the expected root hash.

        
    Common applications
        Bitcoin, blockchain, L2 rollups, airdrops and more

#### Benefits
    - Efficiency
        - O(log n) proof size and verification time
        - Only need to store/transmit small proofs instead of entire dataset
        - Efficient updates - only affected path needs rehashing
        - Perfect for large datasets and distributed systems

    - Privacy
        - Reveals minimal information about other data blocks
        - Can prove inclusion without exposing entire dataset
        - Supports selective disclosure of data
        - Useful for zero-knowledge proofs
    - Security
        - Tamper-evident structure
        - Changes in any data block affect the root hash
        - Computationally infeasible to forge proofs
        - Based on cryptographic hash functions
        - Widely tested and proven in production systems


#### Using a Merkle Tree & Proofs Example

The following example is from `merkle-airdrop`. https://github.com/SquilliamX/christmas-merkle-airdrop

GenerateInput.s.sol:
This script generates the input JSON file for the Merkle tree.
    - Creates a list of addresses and amounts
    - Writes them to input.json
```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

// Merkle tree input file generator script
contract GenerateInput is Script {
    uint256 private constant AMOUNT = 25 * 1e18;
    string[] types = new string[](2);
    uint256 count;
    string[] whitelist = new string[](4);
    string private constant INPUT_PATH = "/script/target/input.json";

    function run() public {
        types[0] = "address";
        types[1] = "uint";
        whitelist[0] = "0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D";
        whitelist[1] = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
        whitelist[2] = "0x2ea3970Ed82D5b30be821FAAD4a731D35964F7dd";
        whitelist[3] = "0xf6dBa02C01AF48Cf926579F77C9f874Ca640D91D";
        count = whitelist.length;
        string memory input = _createJSON();
        // write to the output file the stringified output json tree dumpus
        vm.writeFile(string.concat(vm.projectRoot(), INPUT_PATH), input);

        console.log("DONE: The output is found at %s", INPUT_PATH);
    }

    function _createJSON() internal view returns (string memory) {
        string memory countString = vm.toString(count); // convert count to string
        string memory amountString = vm.toString(AMOUNT); // convert amount to string
        string memory json = string.concat('{ "types": ["address", "uint"], "count":', countString, ',"values": {');
        for (uint256 i = 0; i < whitelist.length; i++) {
            if (i == whitelist.length - 1) {
                json = string.concat(
                    json,
                    '"',
                    vm.toString(i),
                    '"',
                    ': { "0":',
                    '"',
                    whitelist[i],
                    '"',
                    ', "1":',
                    '"',
                    amountString,
                    '"',
                    " }"
                );
            } else {
                json = string.concat(
                    json,
                    '"',
                    vm.toString(i),
                    '"',
                    ': { "0":',
                    '"',
                    whitelist[i],
                    '"',
                    ', "1":',
                    '"',
                    amountString,
                    '"',
                    " },"
                );
            }
        }
        json = string.concat(json, "} }");

        return json;
    }
}

```


MakeMerkle.s.sol:
This script takes the input JSON and generates the Merkle proofs:
    - Reads input.json
    - Creates leaf nodes by hashing address+amount pairs
    - Generates Merkle proofs for each leaf
    - Writes proofs to output.json
```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { Merkle } from "murky/src/Merkle.sol";
import { ScriptHelper } from "murky/script/common/ScriptHelper.sol";

// Merkle proof generator script
// To use:
// 1. Run `forge script script/GenerateInput.s.sol` to generate the input file
// 2. Run `forge script script/Merkle.s.sol`
// 3. The output file will be generated in /script/target/output.json

/**
 * @title MakeMerkle
 * @author Squilliam
 *
 * Original Work by:
 * @author kootsZhin
 * @notice https://github.com/dmfxyz/murky
 */
contract MakeMerkle is Script, ScriptHelper {
    using stdJson for string; // enables us to use the json cheatcodes for strings

    Merkle private m = new Merkle(); // instance of the merkle contract from Murky to do shit

    string private inputPath = "/script/target/input.json";
    string private outputPath = "/script/target/output.json";

    string private elements = vm.readFile(string.concat(vm.projectRoot(), inputPath)); // get the absolute path
    string[] private types = elements.readStringArray(".types"); // gets the merkle tree leaf types from json using
        // forge standard lib cheatcode
    uint256 private count = elements.readUint(".count"); // get the number of leaf nodes

    // make three arrays the same size as the number of leaf nodes
    bytes32[] private leafs = new bytes32[](count);

    string[] private inputs = new string[](count);
    string[] private outputs = new string[](count);

    string private output;

    /// @dev Returns the JSON path of the input file
    // output file output ".values.some-address.some-amount"
    function getValuesByIndex(uint256 i, uint256 j) internal pure returns (string memory) {
        return string.concat(".values.", vm.toString(i), ".", vm.toString(j));
    }

    /// @dev Generate the JSON entries for the output file
    function generateJsonEntries(
        string memory _inputs,
        string memory _proof,
        string memory _root,
        string memory _leaf
    )
        internal
        pure
        returns (string memory)
    {
        string memory result = string.concat(
            "{",
            "\"inputs\":",
            _inputs,
            ",",
            "\"proof\":",
            _proof,
            ",",
            "\"root\":\"",
            _root,
            "\",",
            "\"leaf\":\"",
            _leaf,
            "\"",
            "}"
        );

        return result;
    }

    /// @dev Read the input file and generate the Merkle proof, then write the output file
    function run() public {
        console.log("Generating Merkle Proof for %s", inputPath);

        for (uint256 i = 0; i < count; ++i) {
            string[] memory input = new string[](types.length); // stringified data (address and string both as strings)
            bytes32[] memory data = new bytes32[](types.length); // actual data as a bytes32

            for (uint256 j = 0; j < types.length; ++j) {
                if (compareStrings(types[j], "address")) {
                    address value = elements.readAddress(getValuesByIndex(i, j));
                    // you can't immediately cast straight to 32 bytes as an address is 20 bytes so first cast to
                    // uint160 (20 bytes) cast up to uint256 which is 32 bytes and finally to bytes32
                    data[j] = bytes32(uint256(uint160(value)));
                    input[j] = vm.toString(value);
                } else if (compareStrings(types[j], "uint")) {
                    uint256 value = vm.parseUint(elements.readString(getValuesByIndex(i, j)));
                    data[j] = bytes32(value);
                    input[j] = vm.toString(value);
                }
            }
            // Create the hash for the merkle tree leaf node
            // abi encode the data array (each element is a bytes32 representation for the address and the amount)
            // Helper from Murky (ltrim64) Returns the bytes with the first 64 bytes removed
            // ltrim64 removes the offset and length from the encoded bytes. There is an offset because the array
            // is declared in memory
            // hash the encoded address and amount
            // bytes.concat turns from bytes32 to bytes
            // hash again because preimage attack
            leafs[i] = keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))));
            // Converts a string array into a JSON array string.
            // store the corresponding values/inputs for each leaf node
            inputs[i] = stringArrayToString(input);
        }

        for (uint256 i = 0; i < count; ++i) {
            // get proof gets the nodes needed for the proof & strigify (from helper lib)
            string memory proof = bytes32ArrayToString(m.getProof(leafs, i));
            // get the root hash and stringify
            string memory root = vm.toString(m.getRoot(leafs));
            // get the specific leaf working on
            string memory leaf = vm.toString(leafs[i]);
            // get the singified input (address, amount)
            string memory input = inputs[i];

            // generate the Json output file (tree dump)
            outputs[i] = generateJsonEntries(input, proof, root, leaf);
        }

        // stringify the array of strings to a single string
        output = stringArrayToArrayString(outputs);
        // write to the output file the stringified output json tree dumpus
        vm.writeFile(string.concat(vm.projectRoot(), outputPath), output);

        console.log("DONE: The output is found at %s", outputPath);
    }
}

```




MerkleAirdrop.sol
```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";
import { Merkle } from "murky/src/Merkle.sol";
import { ScriptHelper } from "murky/script/common/ScriptHelper.sol";

// Merkle proof generator script
// To use:
// 1. Run `forge script script/GenerateInput.s.sol` to generate the input file
// 2. Run `forge script script/Merkle.s.sol`
// 3. The output file will be generated in /script/target/output.json

/**
 * @title MakeMerkle
 * @author Squilliam
 *
 * Original Work by:
 * @author kootsZhin
 * @notice https://github.com/dmfxyz/murky
 */
contract MakeMerkle is Script, ScriptHelper {
    using stdJson for string; // enables us to use the json cheatcodes for strings

    Merkle private m = new Merkle(); // instance of the merkle contract from Murky to do shit

    string private inputPath = "/script/target/input.json";
    string private outputPath = "/script/target/output.json";

    string private elements = vm.readFile(string.concat(vm.projectRoot(), inputPath)); // get the absolute path
    string[] private types = elements.readStringArray(".types"); // gets the merkle tree leaf types from json using
        // forge standard lib cheatcode
    uint256 private count = elements.readUint(".count"); // get the number of leaf nodes

    // make three arrays the same size as the number of leaf nodes
    bytes32[] private leafs = new bytes32[](count);

    string[] private inputs = new string[](count);
    string[] private outputs = new string[](count);

    string private output;

    /// @dev Returns the JSON path of the input file
    // output file output ".values.some-address.some-amount"
    function getValuesByIndex(uint256 i, uint256 j) internal pure returns (string memory) {
        return string.concat(".values.", vm.toString(i), ".", vm.toString(j));
    }

    /// @dev Generate the JSON entries for the output file
    function generateJsonEntries(
        string memory _inputs,
        string memory _proof,
        string memory _root,
        string memory _leaf
    )
        internal
        pure
        returns (string memory)
    {
        string memory result = string.concat(
            "{",
            "\"inputs\":",
            _inputs,
            ",",
            "\"proof\":",
            _proof,
            ",",
            "\"root\":\"",
            _root,
            "\",",
            "\"leaf\":\"",
            _leaf,
            "\"",
            "}"
        );

        return result;
    }

    /// @dev Read the input file and generate the Merkle proof, then write the output file
    function run() public {
        console.log("Generating Merkle Proof for %s", inputPath);

        for (uint256 i = 0; i < count; ++i) {
            string[] memory input = new string[](types.length); // stringified data (address and string both as strings)
            bytes32[] memory data = new bytes32[](types.length); // actual data as a bytes32

            for (uint256 j = 0; j < types.length; ++j) {
                if (compareStrings(types[j], "address")) {
                    address value = elements.readAddress(getValuesByIndex(i, j));
                    // you can't immediately cast straight to 32 bytes as an address is 20 bytes so first cast to
                    // uint160 (20 bytes) cast up to uint256 which is 32 bytes and finally to bytes32
                    data[j] = bytes32(uint256(uint160(value)));
                    input[j] = vm.toString(value);
                } else if (compareStrings(types[j], "uint")) {
                    uint256 value = vm.parseUint(elements.readString(getValuesByIndex(i, j)));
                    data[j] = bytes32(value);
                    input[j] = vm.toString(value);
                }
            }
            // Create the hash for the merkle tree leaf node
            // abi encode the data array (each element is a bytes32 representation for the address and the amount)
            // Helper from Murky (ltrim64) Returns the bytes with the first 64 bytes removed
            // ltrim64 removes the offset and length from the encoded bytes. There is an offset because the array
            // is declared in memory
            // hash the encoded address and amount
            // bytes.concat turns from bytes32 to bytes
            // hash again because preimage attack
            leafs[i] = keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))));
            // Converts a string array into a JSON array string.
            // store the corresponding values/inputs for each leaf node
            inputs[i] = stringArrayToString(input);
        }

        for (uint256 i = 0; i < count; ++i) {
            // get proof gets the nodes needed for the proof & strigify (from helper lib)
            string memory proof = bytes32ArrayToString(m.getProof(leafs, i));
            // get the root hash and stringify
            string memory root = vm.toString(m.getRoot(leafs));
            // get the specific leaf working on
            string memory leaf = vm.toString(leafs[i]);
            // get the singified input (address, amount)
            string memory input = inputs[i];

            // generate the Json output file (tree dump)
            outputs[i] = generateJsonEntries(input, proof, root, leaf);
        }

        // stringify the array of strings to a single string
        output = stringArrayToArrayString(outputs);
        // write to the output file the stringified output json tree dumpus
        vm.writeFile(string.concat(vm.projectRoot(), outputPath), output);

        console.log("DONE: The output is found at %s", outputPath);
    }
}

```


To summarize:
1. GenerateInput.s.sol creates the initial data.
2. MakeMerkle.s.sol processes this data.
3. MerkleAirdrop.sol uses this data.

The flow works like this:
1. GenerateInput.s.sol creates list of who gets what
2. MakeMerkle.s.sol:
    - Creates a Merkle tree from this list
    - Generates one root hash
    - Generates unique proofs for each address
3. MerkleAirdrop.sol:
    - Stores only the root hash on-chain
    - When someone claims:
        - They provide their proof (from output.json)
        - Contract verifies their proof matches the root
        - If valid, they get their tokens

This is efficient because:
    - Only one hash (the root) needs to be stored on-chain
    - Each user can prove they're on the list without the contract needing to store the full list
    - The proofs can be distributed off-chain (via output.json)
    - The Merkle tree structure makes it cryptographically impossible to:
    - Claim if you're not on the list
    - Claim more than your allocated amount
    - Claim on behalf of someone else (due to signatures)



Note: What is the significance of hashing a leaf node twice before verification?

    Answer: Hashing twice helps mitigate second preimage attacks, which could allow someone to create a different input that generates the same hash, potentially leading to unauthorized token claims.

### Signatures Notes

Note: You can learn more about Signatures at `https://updraft.cyfrin.io/courses/advanced-foundry/merkle-airdrop/signature-standards `. This section of the cyfrin course goes over Merkle Trees & proofs, signatures and ECDSA(v, r, s).

In order to understand signature creation, signature verification and preventing replay attacks, EIP-191 and EIP-712 must be understood first:

#### EIP-191 Notes
EIP-191 standardizes what the sign data should look like.

EIP-191 is the signed data standard and it proposed the following format for signed data: 
`0x19<1 byte version><version specific data><data to sign>`.
Lets break this down:

`0x19`: is the prefix, and this just signifies that the data is a signature.

`<1 byte version>`: this is the version that the signed data is using. this allows different versions to have different signed data structures. 
    Allowed values of <1 byte version>:
        - `0x00`: Data with intended validator. The person or smart contract who is going to validate the signature is provided here.
        - `0x01`: Structured Data: Most commonly used in production apps and is associated with EIP-712.
        - `0.45`: personal_sign messages.

`<version specific data>`: data associated with that verison and it will be specified. For example, for `0x01`, you have to provide the validator address.

`<data to sign`: this is purely the message we intend to sign, such as a string.

EIP-191 Example:
```js
function getSigner191(uint256 message, uint8 _v, bytes32 _r, bytes32 _s) public view returns (address) {
    // Arguments when calculating hash to validate
    // 1: byte(0x19) - the initial 0x19 byte
    // 2: byte(0) - the version byte
    // 3: version specific data, for version 0, it's the intended validator address
    // 4-6 : Application specific data

    bytes1 prefix = bytes1(0x19);
    bytes1 eip191Version = bytes1(0);
    address indendedValidatorAddress = address(this);
    bytes32 applicationSpecificData = bytes32(message);

    // 0x19 <1 byte version> <version specific data> <data to sign>
    bytes32 hashedMessage = 
        keccak256(abi.encodePacked(prefix, eip191Version, indendedValidatorAddress, applicationSpecificData));

    address signer = ecrecover(hashedMessage, _v, _r, _s);
    return signer;
}
```
However what if this data to sign, the message, is alot more complicated? A way to format this data that could be more easily understood is the EIP-721 standard:

#### EIP-712 Notes (Recommended)
EIP-712 standardizes the format of the version of specific data and the data to sign.

EIP-712 structured this data to sign, and also the version-specific data. This made signatures more easy to read and made it so that we could display them inside wallets. Also, it prevents replay attacks!

Note: EIP-712 is key to prevent replay attacks. Replay attacks are where the same transaction can be sent more than once or the same signature used more than once. The extra data in the structure of EIP-712 prevents these replay attacks!

EIP-712(version 0x01) signature structure:
`0x19 0x01 <domainSeparator> <hashStruct(message)>`
Let's break this down:

`0x19`: is the prefix, and this just signifies that the data is a signature.

`0x01`: this is the version that the signed data is using.

`<domainSeparator>`: this is the version-specific data. Notes: this example is 0x01 and this is the version that's associated with EIP-712.
    <domainSeparator> = <hashStruct(eip712Domain)>
        The domain separator is the hash of the struct, defining the domain of the message being signed, and the EIP712 domain looks like this:
        ```js
        struct eip712Domain = {
            string name,
            string version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt
        }
        ```
        This means that smart contracts can know whether the signature was created specifically for that smart contract, because the smart contract itself will be the verifying contract and it will be encoded in the data.
    
    This means we can rewrite the data as `0x19 0x01 <hashStruct(eip712Domain)> <hashStruct(message)>`

    `<hashStruct(structData)>` = `keccak256(typeHash || hash(structData))`
        The hash struct is the hash of type hash plus the hash of the struct itself, so the data.
        ```js
        // Here is the hash of our EIP721 domain struct
        bytes32 constant EIP712DOMAIN_TYPEHASH = 
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        ```
        ^ The type hash is a hash of what the actual struct looks like, so what are the types involved here? What is the name of the struct and what are all the types insdie that struct? And then we hash this data together to create the type hash.

        We then create a domain separator struct by providing all of the data necessary, and then we hash together the type hash with all those individual pieces of data by first ABI encoding them together to create some bytes and then hashing that data:
        ```js
        // Here, we define what our "domain" struct looks like.
        eip_712_domain_separator_struct = EIP712Domain({
        name: "SignatureVerifier",
        version: "1",
        chainId: 1,
        verifyingContract: address(this)
        });
        ```

        ```js
        i_domain_separator = keccak256(
        abi.encode(
        EIP712DOMAIN_TYPEHASH,
        keccak256(bytes(eip_712_domain_separator_struct.name)),
        keccak256(bytes(eip_712_domain_separator_struct.version)),
        eip_712_domain_separator_struct.chainId,
        eip_712_domain_separator_struct.verifyingContract
        )
        );
        ```

        But the hash struct is basically, what does the data look like and what actually is the data, hashed together 

`hashStruct(message)`: what is the type of the message and then what is the message itself?
    Example:
    ```js
    struct Message {
        uint256 number; // member
    }
    ```
    So Then the message type hash will then just be the hash of the type message:
    ```js
    bytes32 public constant MESSAGE_TYPEHASH = keccak256("Message(uint256 number)");
    ```

    The has struct of the message then becomes the ABI encoded type hash alongside the actual message struct data encoded together and then hashed:
    ```js
    // now, we can hash our message struct
    bytes32 hashedMessage = keccak256(abi.encode(MESSAGE_TYPEHASH, Message({ number: message })));
    ```

    and this is the hash struct of the message!

So we can thin of this EIP-712 data as just `0x19 0x01 <hash of who verifies this signature, and what the verifier looks like> <hash of signed structured message, and what the signature looks like>`

Full example of EIP-712:
```js
contract SignatureVerifier {
    // ..skipped code

    // Here is the hash of our EIP712 domain struct
bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    // ..skipped code

    function getSignerEIP712(uint256 message, uint8 _v, bytes32 _r, bytes32 _s) public view returns (address) {
        // Arguments when calculating hash to validate
        // 1: bytes(0x19) - the initial 0x19 byte
        // 2: byte(1) - the version byte
        // 3: domainSeparator (includes the typehash of the domain struct)
        // 4: hashstruct of message (includes the typehash of the message struct)

        // bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        // bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, nonces[msg.sender], _hashedMessage));
        // address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        // require(msg.sender == signer);
        // return signer;

        bytes1 prefix = bytes1(0x19);
        bytes1 eip712Version = bytes1(0x01); // EIP-712 is version 1 of EIP-191
        bytes32 hashStructOfDomainSeparator = _domain_separator;

        // now, we can hash our message struct
        bytes32 hashedMessage = keccak256(abi.encode(MESSAGE_TYPEHASH, Message({ number: message })));

        // And finally, combine them all (when combined together is known as the `digest`)(the definition of a digest is any data resulting after a hash.)
        bytes32 digest = keccak256(abi.encodePacked(prefix, eip712Version, hashStructOfDomainSeparator, hashedMessage));
        // call the ECRecover with this digest and the signature to retrieve the actual signer.
        return ecrecover(digest, _v, _r, _s);
    }

    // Function to verify if a signature is valid for a given message and signer using EIP-712
function verifySignerEIP712(
    // The message that was signed
    uint256 message,
    // components of the signature
    uint8 _v,
    bytes32 _r,
    bytes32 _s,
    // The address of the expected signer
    address signer
)
    public
    view
    returns (bool)
{
    // Recover the address of the actual signer using EIP-712 signature recovery
    address actualSigner = getSignerEIP712(message, _v, _r, _s);
    
    // Verify that the recovered signer matches the expected signer
    // Will revert if they don't match
    require(signer == actualSigner);
    
    // Return true if verification passed
    // (function will revert before reaching here if verification fails)
    return true;
}

    // ..skipped code
}
```

Note:
Digest: is any data resulting after a hash and you often see it referred to when talking about signatures after you have hashed the message and combined it with all of the other data assocaited with EIP-712. So don't be confused if you see `digest` in another context.


#### OpenZeppelin Signature Notes
Using Openzeppelin, alot of the proccess of signatures can be done for us. All we need to do is create the message typehash and hash it together with the message data to create the hash struct of the message. We can then pass this as an argument to the function `_hashTypedDataV4` and this will add the EIP712 domain and the domain type hash and hash it all together to create the `digest`. This will be done in `getMessageHash` to get the message-hash/fully-encoded-EIP-712-message, and then we pass this through to `getSignerOZ` and this will call `ECDSA.tryRecover` from openZeppellin. TryRecover checks the s value of the signature to check the signature maleability and then uses the ECRecover precomplile to retrieve the signer (tryRecover also checks if the signer returned is the zero address to make sure its a valid address) which we can then compare to the actual signer that we had to verify the signature
```js
contract SignatureVerifier {
    // Define the type hash for the Message struct using keccak256
    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        "Message(uint256 message)"
    );

    // Returns the hash of the fully encoded EIP712 message for this domain i.e. the keccak256 digest of an EIP-712
    function getMessageHash(
        string _message,
    ) public view returns (bytes32) {
        return
        // adds to EIP712 domain and the domain type hash and hash it all together to create the digest
            _hashTypedDataV4(
                // hash the message typehash with the message data to create the hash struct of the message
                keccak256(
                    abi.encode(
                        MESSAGE_TYPEHASH,
                        Message({message: _message})
                    )
                )
            );
    }


    function getSignerOZ(uint256 digest, uint8 _v, bytes32 _r, bytes32 _s) public pure returns (address) {
    // Convert the message digest to bytes32
    bytes32 hashedMessage = bytes32(message);
    
    // Recover the signer's address using ECDSA.tryRecover
    (address signer, /*ECDSA.RecoverError recoverError*/, /*bytes32 signatureLengthV*/) = 
        ECDSA.tryRecover(hashedMessage, _v, _r, _s);
    
    // The above is equivalent to each of the following:
    // address signer = ECDSA.recover(hashedMessage, _v, _r, _s);
    // address signer = ECDSA.recover(hashedMessage, _r, _s, _v);
    
    // bytes memory packedSignature = abi.encodePacked(_r, _s, _v); // <-- Yes, the order here is different!
    // address signer = ECDSA.recover(hashedMessage, packedSignature);
    
    return signer;
    }

    function verifySignerOZ(
    uint256 message,
    uint8 _v,
    bytes32 _r,
    bytes32 _s,
    address signer
    )
    public
    pure
    returns (bool)
    {
    // You can also use isValidSignatureNow
    // pass the fully-encoded-EIP-712-message
    address actualSigner = getSignerOZ(getMessageHash(message), _v, _r, _s);
    require(actualSigner == signer);
    return true;
    }
}
```

#### ECDSA Signatures

Note: You can learn more about Signatures at ` https://updraft.cyfrin.io/courses/advanced-foundry/merkle-airdrop/ecdsa-signatures `. This section of the cyfrin course goes over Merkle Trees & proofs, signatures and ECDSA(v, r, s).

ECDSA = Elliptic Curve Digital Signature Algorithm

ECDSA is based on Elliptic Curve Cryptography.

ECDSA is used to:
    - Generate key pairs
    - Create Signatures
    - Verify Signatures

The specific curve used in ECDSA in ethereum is the Secp256k1 curve, and it was chosen for its interoperability with bitcoin, its effciency and its security

##### What are signatures? 

Blockchain signatures:
    - Provide authentication in blockchain technology
    - Verify that the message/transaction originates from the intended sender

Proof of ownership in Ethereum is achieved using public and private key pairs and they are used to create digitial signatures.

    Signatures are analogous(similar/comparable/parallel) to having to provide ID to withdraw from the bank. They are kind of like a digital finger print, adn they are unique to you, the user.

    This public private key pair is used to verify that the sender is the owner of the account, this is known as public key cryptography and involves asymmetric encryption.






------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Package Installing Notes:

to install packages, run `forge install` with a `--no-commit` at the end.
for example:
`forge install https://github.com/smartcontractkit/chainlink-brownie-contracts --no-commit` 
(you can also do it without the github link: 
`forge install smartcontractkit/chainlink-brownie-contracts --no-commit` as it does the same thing)

if you want to install a certain version, then install the version number at the end of the link:
exmaple:
`forge install https://github.com/smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit`
(you can also do it without the github link: 
`forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit` as it does the same thing)



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Smart Contract Tests Notes

All Smart Contracts must have tests. You need tests before going for a smart contract audit or you will be turned away. 


You can see the test coverage by running:
 `forge coverage`: shows you how many lines of code have been tested.
 `forge coverage --report debug`: outputs a coverage report and tells you which lines have not been tested.
 `forge coverage --report debug > coverage.txt`: creates a coverage report/file named `coverage.txt` and it will have all the output of the terminal command `forge coverage --report debug`.


When writing tests, following this order:
1. Write deploy scripts to use in our tests so we can test the exact same way we are going to deploy these smart contracts
    - Note these deployment scripts will not work on zkSync. zkSync needs scripts written in Bash (for now)
2. Then Write tests in this order:
    3. Local Chain (Foundry's Anvil)
    4. Forked testnet
    5. Forked mainnet
  

THe convention for test files is that all test files should end in `.t.sol`.

Example of a test file:
```javascript
// SPDX-License-Identifier: MIT // like always
pragma solidity 0.8.18; // like always

import {Test, console} from "forge-std/Test.sol"; // import the test and console package from foundry. the test package is for testing. the console package is for console.logging. To see the logs, run `-vv` after forge test
import {FundMe} from "../src/FundMe.sol"; // import the contract we are testing


// the test contract should always inherit from the Test package we import
contract FundMeTest is Test {

    // to test functions in the FundMe contract, we need to declare the fundMe variable of type FundMe contract at the contract level and initialize it in the setup function. (This makes the variable a storage or state variable )
    FundMe fundMe;
    // ^ we declare this at the contract level so it can be in scope to all functions in this contract ^


     // every test contract needs to have a setup function. in this setup function, we deploy the contract that we are testing.
    // when we run `forge test`, the setup function always get called before any test function
    function setUp() external {
        // the fundMe variable of type FundMe contract is gonna be a new FundMe contract. The constructor takes no input parameters so we don't pass any parameters.
        fundMe = new FundMe();
        // ^ we deploy a new contract in a testing environment to test the contract ^
    }

 // testing to make sure that the minimum deposit is indeed $5
    function testMinimumDollarisFive() public {
        // assertEq is from the test foundry package
        // this line says that we are assert that the minimum USD variable in the fundMe contract is equal to 5e18.
        assertEq(fundMe.MINIMUM_USD(), 5e18); // the test passes. if you change it to 6e18 then the test fails.
    }

    function testOwnerIsMsgSender() public {
        // console.log(fundMe.i_owner());
        // console.log(msg.sender);
        // this line fails. we can console.log above it to find out why.
        // assertEq(fundMe.i_owner(), msg.sender);
        // ^this line fails because in the setup function, this contract of `FundMeTest` is the one that deployed the FundMe Contract and so the FundMeTest is the owner.

        // so the correct line is:
        assertEq(fundMe.i_owner(), address(this));
        // this line passes because it is asserting that the owner of the FundMe contract is indeed the owner of the deployed contract as the constructor is FundMe says it should be.
    }
    
} 

```

you don't need to declare or deploy the libraries in your test setup. This is because:
1. Libraries are different from contracts - they are not deployed independently in the same way contracts are.
2. The PriceConverter library is already imported and linked to your FundMe contract
3. Library functions can be called directly using the library name.

In the above example we declared the fundMe variable and deployed a new contract of the fundMe contract in the setup function but this is not needed when testing libraries as libraries are of different type. Just import the library into the test file. Library functions marked as internal become part of the calling contract's code. You can call static library functions directly using the library name


To run Tests: `forge test`
To run tests with a detailed output: `forge test -vvvv`
to run a singular test: `forge test --mt <test-function-name> -vvvv`

you can use `-vv`, `-vvv`, `-vvvv`, `-vvvvv` after at the end of your `forge test` command.

`-vv` = console.logs
`-vvv` = stack traces and console.logs
`-vvvv` = more detailed stack trace, console.logs and bytes.

There are 4 different test types:
1. Unit: Testing a specific part of our code: Example: Writing a test for our contract that does not get deployment from a deployment script
2. Integration: Testing how our code works with other parts of our code: Example: Testing our main contract that is combined with a deployment script
3. Forked: Testing our code on a simulated real environment
4. Staging: Testing our code in a real environment that is not production (testnet or sometimes mainnet for testing)

If we need to test a part of our code that is outside of our system(example: pricefeed from chainlink) then we can write a test to test it, then we can fork a testnet or mainnet to check if it really works. You can do this by running:
 `forge test --mt <test-function-name> -vvv --fork-url $ENV_RPC_URL` - you can learn more about this and keeping it modular by looking at [the  section 7 Foundry FundMe course](https://updraft.cyfrin.io/courses/foundry/foundry-fund-me/refactoring-helper) and your codebase of foundry-fund-me-f23.

 for example: `forge test --mt testPriceFeedVersionIsAccurate -vvv --fork-url $SEPOLIA_RPC_URL`. Of course to use this you would have the RPC URL(that you can get from a node provider such as Alchemy) in your .env file. After adding a .env making sure to run `source .env` to add the environment variables. Also make sure you fork the correct chain where the logic is.

 run `forge coverage` to see how many lines of code have been tested.

 you only want to deploy mocks when you are working on a local chain like anvil.

### Local Chain Tests Don't Work on Forked Chain Tests?

If you have a test that passes on the local chain, but fails on a forked chain, this could be happening for several reasons.
First off, you want to make sure that you are deploying the tests from some sort of burner metamask wallet when deploying on a forked chain. When you write a test on a local chain, it just spins us a fake and local chain and account to run the the tests on. To make sure you are correctly deploying from a burner metamask on a local chain, review the `vm.startBroadcast` section in the `Getting Started With Scripts` section of this notes file.

Second off, some tests may fail on a forked chain instead of a local chain if the test is using mocks. So when running tests on a forked chain, we must skip over these tests that are meant for a local chain(tests with mocks). We can do this by creating a modifier that skips over the tests with this modifier.
example:
```js
   modifier skipFork() {
    // if the blockchain that we are deploying these tests on is not the local anvil chain, then return. When a function hits `return` it will not continue the rest of the logic 
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

     function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        // Arrange / Act / Assert
        // we expect the following call to revert with the error of `VRFCoordinatorV2_5Mock`;
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }
```
As you can see this test has the `skipFork` modifier that we made.





### Testing Events

To test an event, you need to copy and paste the events from the codebase to the test file in order to test them.

Once you have the events in your test file, the logic for testing them is `vm.expectEmit(true/false, true/false, true/false, true/false, contractEmittingEvent)`

These 3 first true/false statements will only be true when there is an indexed parameter, and the 4th one is for any data that is not indexed within the event. For example:
```js
contract RaffleTest is Test {
    ...
    // we copy and paste the event from the smart contract into our test
    // as you can see there is only one indexed event and no other data.
    event RaffleEntered(address indexed player, /* No Data */, /* No Data */, /* No Data */); // events can have up to 3 indexed parameters and other data that is not indexed.
    ...
    function setUp() external {
        ...
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

  function testEnteringRaffleEmitsEvent() public {
        // Arrange
        // next transaction will come from the PLAYER address that we made
        vm.prank(PLAYER);
        // Act 
        // because we have an indexed parameter in slot 1 of the event, it is true. However we have no data in slot 2, 3, and 4  so they are false. `address(raffle) is the contract emitting the event`
        // we expect the next event to have these parameters.
        vm.expectEmit(true, false, false, false, address(raffle));
        // the event that should be expected to be emitted from the next transaction
        emit RaffleEntered(PLAYER);
        // Assert
        // PLAYER makes this transaction of entering the raffle and this should emit the event we are testing for.
        raffle.enterRaffle{value: entranceFee}();
    }


}
```


### Tests with Custom error notes

When writing a test with a custom error, you need to expect the revert with `vm.expectRevert()` and you need to end it with `.selector` after the custom error. 

Example:
```js
 function testRaffleEvertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER); // the next transaction will be the PLAYER address that we made
        // Act / Assert
        // expect the next transaction to revert with the custom error Raffle__SendMoreToEnterRaffle.
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        // call the Enter Raffle with 0 value (the PLAYER is calling this and we expect it to evert since we are sending 0 value)
        raffle.enterRaffle();
    }
```

If the customr error has parameters, then the custom error needs to be abi.encoded and the parameters need to be apart of the error.
Example:

`Raffle.sol`:
```js
contract Raffle is VRFConsumerBaseV2Plus {
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playerslength, uint256 raffleState);
}
```
`test/Raffle.t.sol`:
```js
   function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        // start the current balance of the raffle contract at 0 
        uint256 currentBalance = 0;
        // the raffle has 0 players
        uint256 numPlayers = 0;
        // we get the raffle state, which should be open since no one is in the raffle yet
        Raffle.RaffleState rState = raffle.getRaffleState();

        // the next transaction will be by PLAYER
        vm.prank(PLAYER);
        // the player enters the raffle and pays the entrance fee
        raffle.enterRaffle{value: entranceFee}();
        // the balance is now updated with the new entrance fee
        currentBalance = currentBalance + entranceFee;
        // PLAYER is the one person in the raffle
        numPlayers = 1;

        // Act / Assert
        // we expect the next call to fail with the custom error of Raffle__UpkeepNotNeeded
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }
```

Also, if you have a specific instance of the contract, you need not to use it for the error type and instead use the contract type/definition.
```js
contract DSCEngineTest is Test {
    // even though we deploy a new instance of the DSCEngine, we cannot use this instance when calling the custom error type.
    DSCEngine dsce;
    function setUp() public {
        // initialize the variables in setup function
        deployer = new DeployDSC();
        // get the values returns from the deployment script's `run` function and save the values to our variables dsc and dsce
        (dsc, dsce, config) = deployer.run();
}

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock fakeTokenToTestWith = new ERC20Mock("fakeTokenToTestWith", "FTTTW", USER, AMOUNT_COLLATERAL);

        vm.startPrank(USER);
        // this works because we call the DSCEngine directly when calling the custom error type.
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        // for pretty much everything else we call on the DSCEngine contract, we call it through the new instance of the contract `dsce`
        dsce.depositCollateral(address(fakeTokenToTestWith), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
}
```


### How to compare strings in Tests

To compare strings in foundry, we must abi.encode them. The following is an example from foundry-nft-f23:
```js


// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MoodNft} from "src/MoodNFT.sol";


contract MoodNftIntegrationTest is Test {
string public constant SAD_SVG_URI =
        "data:application/json;base64,eyJuYW1lIj";

    // ... (skipped code)

 function testFlipTokenToSad() public {
        // Start a series of transactions from USER address
        vm.startPrank(USER);

        // Mint a new NFT
        moodNft.mintNft();

        // Flip the mood of token 0 from happy to sad
        moodNft.flipMood(0);

        // Log the token URI for verification
        console.log(moodNft.tokenURI(0));

        // Verify the token URI matches the expected SAD SVG URI
        assertEq(keccak256(abi.encodePacked(moodNft.tokenURI(0))), keccak256(abi.encodePacked(SAD_SVG_URI)));
    }
}
```





### Sending money in tests Notes

 When writing a test in solidity and you want to pass money to the test, you write it like this:
 ```javascript
  function testFundUpdatesFundedDataStructure() public {
        fundMe.fund{value: 10e18}();
    }
 ```
 because the fund function that we are calling does not take any parameter, it should be written like `fundMe.fund{value: 10e18}();` and not like ``fundMe.fund({value: 10e18});``. This is because the fund function does not take any parameters but is payable. So {value: 10e18} is the value being passed while () is the parameters being passed. IF the fund function was written like `function fund(uint256 value) public payable {}` then the test line of `fundMe.fund({value: 10e18}); ` would indeed work.





 ### GAS INFO IN TESTS Notes

 When working on tests in anvil, the gas price defaults to 0. So for us to simulate transactions in test with actual gas prices, we need to tell our tests to actually use real gas prices. This is where `vm.txGasPrice` comes in. (See `vm.txGasPrice` below in cheatcodes for tests)




 ### FUZZ TESTING NOTES

 For most of your testing, ideally you do most of your tests as fuzz tests. You should always try to default all of your tests to some type of fuzz testing. There are two types of fuzz tests, stateless fuzz testing, and stateful fuzz testing.

 `Fuzz Testing`: is when you supply random data to your system in an attempt to break it.

`Invariants`: property of our system that should always hold.
For example, if we said our ballon is indestructable, or unbreakable, or unpoppable, the inavariant would be: the ballon cannot be broken/popped.

Code example:
if our contract is:
```js
contract MyContract {
    uint256 public shouldAlwaysBeZero = 0;
    uint256 private hiddenValue = 0;
    
    function doStuff(uint256 data) public {
        if (data == 2) {
            shouldAlwaysBeZero = 1;
        }
        if (hiddenValue == 7) {
            shouldAlwaysBeZero = 1;
        }
        hiddenValue = data; 
    }
}
```

Then tests would be:
```js
contract MyContractTest is Test {
    My contract exampleContract;

    function setUp() public {
        exampleContract = new MyContract();
    }

    // this unit wouldn't be an effective test because we can only test one number at a time in unit tests. 
    function testIAlwaysGetZero() public {
        uint256 data = 0;
        exampleContract.doStuff(data);
        assert(exampleContract.shouldAlwaysBeZero() == 0);
    }


    // This stateless fuzz test is much more effective because foundry will automatically randomize data and run through our code with a ton of different examples, like 1 or 2, or 34242, or 972482, or 7, or 297492649274.
     function testIAlwaysGetZeroFuzz(uint256 data) public {

        // instead of manually selecting/defining our data, we add the variable in the functions test parameter^.
        // uint256 data = 0;
        exampleContract.doStuff(data);
        assert(exampleContract.shouldAlwaysBeZero() == 0);
    }

    // if you run `forge test --mt testIAlwaysGetZeroFuzz` it will return an `Assertion Failed` log with an `args=[2]` because it will find out that 2 breaks our invariant!

}
```


 `Stateless` fuzz testing: Where the state of the previous run is discarded for every new run. link ` https://book.getfoundry.sh/forge/fuzz-testing `

 `Stateful` fuzz testing: Fuzzing where the final state of your previous run is the starting state of your next run. To write a stateful fuzz test in foundry, you need the `invariant_` keyword. link: ` book.getfoundry.sh/forge/invariant-testing `

Note:
    In Foundry:
        `Fuzz Tests` = Random Data to one function (Stateless fuzzing).
        `Invariant Tests` = Random Data & Random Function Calls to many functions(Stateful Fuzzing).

        Foundry Fuzzing = Stateless Fuzzing
        Foundry Invariant = Stateful Fuzzing
            (Even though they are both technically fuzzing lol)


Stateful Fuzz Example (Open Fuzz Testing):
```js
// Stateful Fuzzing example

// First import the StdInvariant and Test from foundry.
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

// Inherit from StdInvariant and Test
contract MyContractTest is StdInvariant, Test {
    My contract exampleContract;

    function setUp() public {
        exampleContract = new MyContract();

        // we need to tell foundry which contract to call random functions on. Since we only have one contract with one function, we are going to tell foundry that `myContract` should be called and its allowed to call any of the functions in `myContract`. Foundry is smart enough to know to grab any and all functions from `myContract` and call them in random orders, with random data. To do this we call `targetContract` from the parent contract `StdInvariant`.
        targetContract(address(example));
    }

    // This is an example of open fuzz testing. Open fuzz testing means that it calls all the functions in our contract to try to break the invariant. This is good for an initial run of the code, but a better fuzz testing approach is Handler Based Fuzz Testing(see section `Handler Based Fuzz Testing (Advanced Fuzzing) Notes` (its the next section))

    // To write a stateful fuzz test in foundry, you need the `invariant_` and keyword. 
    function invariant_testAlwaysIsZero() public {
        assert(exampleContract.shouldAlwaysBeZero == 0);
    }

    // if we run this test, the stateful fuzz test returns `FAIL. Reason: Assertion Violated` does indeed find a sequence where our invariant/assertion/property is broken.

    // The sequence will logs will list every call it made and with what arguments to show us why it failed. In this case, when it ran `7`, then ran again with the final state of the previous run(7), it failed when it called the function `doStuff` again.
}
```


 Note: Fuzzers are actually doing semi-random data instead of purely random data. And the way fuzzers pick the random data matters. Fuzzers won't be able to go through every single uint256, so understanding how your fuzzer picks the random data is important.


When you run a fuzz test, you will see a log that says `(runs:256)` on the same line as your pass log. Fuzz testing gets defaulted to 256 runs, which means the fuzz test get defaulted to 256 different random inputs to make our test run.
To change the amount of tests foundry does in a fuzz test, in your `foundry.toml` change the runs number:

for stateless fuzzing/fuzz tests:
```js
[fuzz]
runs = 256 // change this number, the number of runs is important because more runs means more random inputs, more use cases, more chance you'll actually catch the issue.
```

for stateful fuzzing/Invariant Tests:
```js
[invariant]
runs = 256 // how many fuzzing runs
depth = 128 // number of calls in a single run
fail_on_revert = true /* or */ false // (see below)
```
#### `fail_on_revert` Notes

`fail_on_revert = false` has some pros and cons.
Pros: Can very quickly write open testing functions and minimal handler functions that are not perfect.
Cons: Hard to make sure that all the calls we're making actually make sense. For example, it could be calling a depositCollateral function but it uses random collateral addresses that do not make sense.

`fail_on_revert = false` can be good and can be good for a sanity check and perhaps it catches something. Is good for quick tests and can be good during competetive audits. Would be much better with mini or indepth handlers. Is great for very small contracts but the more complex the contracts are, the less sense it makes to use this, probably wont catch anything, and will probably keep breaking.

Example: 
```js
[PASS] invariant_protocolMustHaveMoreValueThanTotalSupply() (runs: 128, calls: 16384, reverts: 16384) // an example of using `fail_on_revert = false` on a complex contract, it makes 16384 calls and every single one reverts.
```


`fail_on_revert = true`: can give us peace of mind knowing that if the test passes, then that means all of the transactions/calls that went through, actually went through.worked and it didn't make a bunch of really dumb calls.
Pro: Is much more precise and better at finding bugs in bigger code bases only when it has a handler.
Cons: More time spent writing a handler to guide the fuzz.

You should always aim for `fail_on_revert = true`. However, if you make your handler too specific, you can narrow it down too much and remove edge cases that would break the system that are valid. So its kinda of a balancing game you have to play with fuzzing tests and wether or not to put `fail_on_revert` on `true` or `false`. There is an art to this. When fuzzing testing, switch between both for maximum value. Create two folders in your fuzz folder of `continueOnRevert` and `failOnRevert`, this way you can switch between both. Start with `continueOnRevert` since this will have `fail_on_revert = false` and will be faster to write tests and handlers for. 


`fail_on_revert = true`: this will revert everytime a call in the stateful fuzz test reverts, which without a handler will probably be often. For example, it can call a withdraw function first without depositing anything, which does not make sense. Which is why it needs a handler to guide the fuzz.
Example:
##### How to read fuzz test outputs

```js
Failing tests:
Encountered 1 failing test in test/fuzz/OpenInvariantsTest.t.sol:OpenInvariantsTest
[FAIL: DSCEngine__NeedsMoreThanZero()]
        [Sequence]
                sender=0x00000000000000000000000000000000000007Ee addr=[src/DSCEngine.sol:DSCEngine]0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 calldata=redeemCollateralForDsc(address,uint256,uint256) args=[0xD6EaB94B9eCD92B953bA29Ef5621429201577852, 96071856155 [9.607e10], 0]
 invariant_protocolMustHaveMoreValueThanTotalSupply() (runs: 1, calls: 1, reverts: 1)

Encountered a total of 1 failing tests, 0 tests succeeded
```
In this example the fuzz test failed because it called the redeemCollateralForDsc function first, which does not make sense as it does not have any deposited amount.

Each time it says `sender`, it is a new run/transaction being sent by the fuzzer. In this example we only have 1.

It says `calldata=redeemCollateralForDsc(address,uint256,uint256)` which is the function called and the parameters the function takes. 

Then it also shows us the random values it inserted for the parameters the function needs in the same order that the function takes them: 
```js
args=[/* random address: */ 0xD6EaB94B9eCD92B953bA29Ef5621429201577852, /* random uint256: */96071856155 [9.607e10], /* random uint256: */ 0]
 invariant_protocolMustHaveMoreValueThanTotalSupply()
```

Then it also tells us how many runs it did, how many calls it did, and how many reverted:
```js
(runs: 1, calls: 1, reverts: 1)
```

If you get an output with 0 reverts, and the test passes, this means the invariant you are asserting is holding true and is not breaking.
Example:
```js
Ran 1 test for test/fuzz/Invariants.t.sol:Invariants
[PASS] invariant_protocolMustHaveMoreValueThanTotalSupply() (runs: 128, calls: 16384, reverts: 0)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 3.63s (3.63s CPU time)
```

You can learn more about fuzzing (and foundry.toml commands in general) at` https://github.com/foundry-rs/foundry/tree/master/config ` and scroll down to the fuzz section.





#### Handler Based Fuzz Testing (Advanced Fuzzing) Notes
link: ` book.getfoundry.sh/forge/invariant-testing `

Note: Sometimes when fuzz testing, the system will continue to show the results of old tests. Run `forge clean` from time to time when fuzz testing. There will be warnings that show up as well.

Protocols will have so many many different random intricacies that we want to narrow down the random call so that we have a higher likelihood of getting and catching errors/exploits/vulnerabilities/bugs.

In Open Based testing, it calls any functions in the contract in any order. 

In Handler based testing, we create a contract called `handler` where we call functions in specific ways. For example, when depositing tokens, we need to make sure an approve happens beforehand, if you just call deposit without approving that token, thats a kind of a wasted fuzz run. And if we onlyy have 200 fuzz runs and we're wasting them on failed fuzz runs, the chance of us actually finding a bug becomes much smaller.

The `Handler` contract that we make is going to call functions in specific ways to the functions so that we have a higher likelihood of calling functions in orders that we want (higher likehood of catching bugs).

Our Handler should also simulate interacting with other contracts. For example, if our contract interacts with pricefeeds, tokens(like weth, wbtc or any other token), and pretty much any contract that we interact with. So our Handler should show people doing random things with the other contracts as well because people are going to do random weird things with our contracts and in combination with other contracts.

Example from `foundry-defi-stablecoin-f23`:
```js
contract StopOnRevertHandler is Test {
// ..skipped code

MockV3Aggregator public ethUsdPriceFeed;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
  // initialize the ethUsdPriceFeed variable as a Mock of a pricefeed of weth
        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
    }

// fuzzing a mock of our pricefeeds.
 function updateCOllateralPrice(uint96 newPrice) public {
        // save the random price inputted by the fuzzer as an int256. PriceFeeds take int256 and we chose a uint96 so that the number wouldn't be so big. We chose uint instead of int as the fuzz test parameter so the AI can be as random as possible.
        int256 newPriceInt = int256(uint256(newPrice));
        // call the mock pricefeed's `updateAnswer` function to update the current price to the random `newPriceInt` inputted by the fuzzer.
        ethUsdPriceFeed.updateAnswer(newPriceInt);
    }
}

// Note: This breaks our invariant test suite as if the price of the collateral plummets in a crash, our entire system would break. This is why we are using weth and wbtc as collateral and not memecoins. This is a known issue.
```



`bound`: The bound function is a Foundry utility (from forge-std) that constrains a fuzzed value to be within a specific range. It's particularly useful in fuzz testing to keep randomly generated values within reasonable and valid bounds. In the example below, you can see we ran `amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);`, here we passes it the parameter that we want to bound, the minimum amount and the max amount the parameter can be, and then we saved it as the parameter `amountCollateral` itself.

Example from foundry-defi-stablecoin-f23/test/fuzz/Handler.t.sol:
```js

     // why don't we do max uint256? because if we deposit the max uint256, then the next stateful fuzz test run is +1 or more, it will revert.
    uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max; // the max uint96 value

    // to fix random collateral address, we are going to tell foundry to only deposit either weth or wbtc.
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        // Gets either WETH or WBTC token based on whether collateralSeed is even or odd and saves it as a variable named collateral
        // This ensures we only test with valid collateral tokens that our system accepts
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        // Bound the amountCollateral to be between:
        // - Minimum: 1 (since we can't deposit 0)
        // - Maximum: MAX_DEPOSIT_SIZE (type(uint96).max)
        // This prevents:
        // 1. Zero deposits which would revert
        // 2. Deposits so large they could overflow in subsequent tests
        // 3. Ensures amounts are realistic and within system limits
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE); // The bound function is a Foundry utility (from forge-std) that constrains a fuzzed value to be within a specific range.

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);

        // Call the DSCEngine's depositCollateral function with:
        // 1. The selected collateral token's address
        // 2. The randomly generated amount of collateral to deposit
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }
```



#### Steps For Fuzzing Notes

`Stateless Fuzzing`:
To stateless fuzz a function, you can pass the data you want to fuzz test into the parameter of the test.

```js
contract MyContractTest is Test {
    My contract exampleContract;

    function setUp() public {
        exampleContract = new MyContract();
    }

    // this unit wouldn't be an effective test because we can only test one number at a time in unit tests. 
    function testIAlwaysGetZero() public {
        uint256 data = 0;
        exampleContract.doStuff(data);
        assert(exampleContract.shouldAlwaysBeZero() == 0);
    }


    // This stateless fuzz test is much more effective because foundry will automatically randomize data and run through our code with a ton of different examples, like 1 or 2, or 34242, or 972482, or 7, or 297492649274.
     function testIAlwaysGetZeroFuzz(uint256 data) public {

        // instead of manually selecting/defining our data, we add the variable in the functions test parameter^.
        // uint256 data = 0;
        exampleContract.doStuff(data);
        assert(exampleContract.shouldAlwaysBeZero() == 0);
    }

    // if you run `forge test --mt testIAlwaysGetZeroFuzz` it will return an `Assertion Failed` log with an `args=[2]` because it will find out that 2 breaks our invariant!

}
```

`Stateful Fuzzing`:
1. Understand/Identify the Invariants (there is most likely many more than 1). What are our invariants?
    Invariant examples:
        - New tokens minted < inflation rate
        - only possible to have 1 winner in a lottery
        - users cannot withdraw more than they deposited
        - total supply of collateral should be more than the total value of borrowed tokens
        - Getter view functions should never revert

2. Write a fuzz test that inputs that random data to try to break the invariants.
    1. To do this, create a `fuzzing` folder inside of the test folder.
    2. Create a `continueOnRevert` folder and a `failOnRevert` folder.
        1. Work on `continueOnRevert` folder first as this will run with `fail_on_Revert = false`. Create mini `Handler.t.sol`. Can find bugs if you narrow down the mini `Handler.t.sol` enough.
            1. Create a `ContinueOnRevertHandler.t.sol` file in `continueOnRevert` to write the handler in.
            2. Create a `ContinueOnRevertInvariants.t.sol` file in `continueOnRevert` to write fuzz tests in.
        2. Then work on `failOnRevert` afterwards as this will take more time and will use `fail_on_Revert = true`. Create `Handler.t.sol` to guide the fuzzing
            1. Create a `StopOnRevertHandler.t.sol` file in `FailOnRevert` to write the handler in.
            2. Create a `StopOnRevertInvariants.t.sol` file in `FailOnRevert` to write fuzz tests in.
        


Example Invariant Test & Handler:

Handler (from foundry-defi-stablecoin-f23):
```js
// SPDX-License-Identifier: MIT

// Handler is going to narrow down the way we call functions.

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    // declare new variables at the contract level so variables are in scope for all functions
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    // why don't we do max uint256? because if we deposit the max uint256, then the next stateful fuzz test run is +1 or more, it will revert.
    uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max; // the max uint96 value

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        // define variables declared at contract level at set them when this contract is first deployed
        dsce = _dscEngine;
        dsc = _dsc;

        // Get the list of allowed collateral tokens from DSCEngine and save it in a new array named collateralTokens
        address[] memory collateralTokens = dsce.getCollateralTokens();

        // Cast the tokens to ERC20Mock type for testing. This ensures our fuzzing tests are always aligned with the actual system configuration, making the tests more reliable and maintainable while also being able to mint tokens for the pranked user
        // Cast the first collateral token address (index 0) to an ERC20Mock type and assign it to weth
        // This assumes the first token in the collateralTokens array is WETH
        weth = ERC20Mock(collateralTokens[0]);
        // Cast the second collateral token address (index 1) to an ERC20Mock type and assign it to wbtc
        // This assumes the second token in the collateralTokens array is WBTC
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    // in the handlers functions, what ever parameters you have are going to be randomized
    // function depositCollateral(address collateral, uint256 amountCollateral) public {
    // this does not work because it chooses a random collateral address and tries to deposit it, when our DSCEngine only takes weth and btc. Also it could try to deposit 0 amount, which will fail because our DSCEngine reverts on 0 transfers.
    // dsce.depositCollateral(collateral, amountCollateral);
    // }

    // to fix random collateral address, we are going to tell foundry to only deposit either weth or wbtc.
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        // Gets either WETH or WBTC token based on whether collateralSeed is even or odd and saves it as a variable named collateral
        // This ensures we only test with valid collateral tokens that our system accepts
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        // Bound the amountCollateral to be between:
        // - Minimum: 1 (since we can't deposit 0)
        // - Maximum: MAX_DEPOSIT_SIZE (type(uint96).max)
        // This prevents:
        // 1. Zero deposits which would revert
        // 2. Deposits so large they could overflow in subsequent tests
        // 3. Ensures amounts are realistic and within system limits
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE); // The bound function is a Foundry utility (from forge-std) that constrains a fuzzed value to be within a specific range.

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);

        // Call the DSCEngine's depositCollateral function with:
        // 1. The selected collateral token's address
        // 2. The randomly generated amount of collateral to deposit
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    //////////////////////////
    //   Helper Functions   //
    /////////////////////////

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        // if the collateralSeed(number) inputted divided by 2 has a remainder of 0, then return the weth address.
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        // if the collateralSeed(number) inputted divided by 2 has a remainder of anything else(1), then return the wbtc address.
        return wbtc;
    }
}
```

Invariant Stateful Fuzz Test (from foundry-defi-stablecoin-f23):
```js
// SPDX-License-Identifier: MIT

// What are our Invariants?
//  - total supply of collateral should be more than the total value of borrowed tokens
//  - Getter view functions should never revert

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DeployDSC} from "script/DeployDSCEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    // declare new variables at the contract level so variables are in scope for all functions
    DeployDSC deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        // define variables declared at contract level through our deployment script variable
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();

        (,, weth, wbtc,) = config.activeNetworkConfig();

        // deploys a new handler contract and saves it as a variable named handler.
        // Handler contract has a constructor that takes the `DSCEngine _dscEngine, DecentralizedStableCoin _dsc` so we pass them here
        handler = new Handler(dsce, dsc);
        // calls `targetContract` from parent contract `StdInvariant` to tell foundry that it has access to all functions in our handler contract and to call them in a random order with random data.
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to all the debt

        // gets the total supply of dsc in the entire world. We know that the only way to mint DSC is through the DSCEngine. DSC is the debt users mint.
        uint256 totalSupply = dsc.totalSupply();

        // gets the balance of all the weth tokens in the DSCEngine contract and saves it as a variable named totalWethDeposited.
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));

        // gets the balance of all the wbtc tokens in the DSCEngine contract and saves it as a variable named totalBtcDeposited.
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        // calls the getUsdValue function from our DSCEngine and passes it the weth token and the total amount deposited. This will get the value of all the weth in our DSCEngine contract in terms of USD
        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);

        // calls the getUsdValue function from our DSCEngine and passes it the wbtc token and the total amount deposited. This will get the value of all the wbtc in our DSCEngine contract in terms of USD
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalBtcDeposited);

        console.log("weth value: ", wethValue);
        console.log("wbtc value: ", wbtcValue);
        console.log("total supply: ", totalSupply);

        // asserting that the value of all the collateral in the protocol is greater than all the debt.
        assert(wethValue + wbtcValue >= totalSupply);
    }
}

```





 ### CHEATCODES FOR TESTS Notes
 `makeAddr()` : This cheatcode creates a fake address for a fake person for testing Purposes.
 For example:
 ```javascript
// creating a user so that he can send the transactions in our tests. "MakeAddr" is a cheatcode from foundry that allows use to make a fake address for someone for testing purposes (we named the address being made "user" and the person is called USER).
    address USER = makeAddr("user");
 ```

`vm.deal()` : After we make a new fake person (see `makeAddr` above) the fake persons address/wallet needs funds in it in order for them to make transactions in our tests. So we `deal` them some fake money.
For Example:
```javascript
// this is the amount that we are going to pass to the "USER" saved as a variable to avoid magic numbers.
uint256 constant STARTING_BALANCE = 10 ether;

function setup() public {
 // we need to give the fake person "USER" some money so he has money in his wallet to make transactions with. This needs to go in the setup function because the setup function is always called before the tests when we run `forge test`
        vm.deal(USER, STARTING_BALANCE);}
```

 `vm.prank()` : This cheatcode allows for the next call to be made by the user passed into it.
 For example:
 ```javascript
 function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // the next transaction will be sent by "USER".
        fundMe.fund{value: SEND_VALUE}(); // so this value is sent by the "USER"
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }
 ```
 
   `vm.expectRevert()` : This cheatcode tells foundry that the next line in the test function is expected to revert. If the test/transaction reverts, then the test passes since we expect it to revert.
 For Example:
 ```javascript
    // this test is making sure that if a user sends less than the minimum amount, the contract will revert and not allow it.
    function testFundFailsWithoutEnoughEth() public {
        // this is a cheat code in foundry. it is telling foundry that the next line should revert.
        vm.expectRevert();

        fundMe.fund(); // send zero value. this fails because there is a minimum that needs to be sent.
            // so because we used expectRevert, this test passes.
    }
 ```

 `hoax` : This is vm.prank and vm.deal combined. (This is not a cheatcode but instead is apart of the Forge Standard library(slightly different from the cheatcodes)).
 For Example:
 ```javascript
 function testWithdrawFromMultipleSenders() public funded {
        // Arrange
        uint160 numberofFunders = 10; // This is a uint160 because we use `hoax` here. and if you use `hoax` then to use number to generate address you must use uint160s. this is because uint160s have the same amount of bytes as addresses.
        uint160 startingFundingIndex = 1;

        for (uint160 i = startingFundingIndex; i <= numberofFunders; i++) {
            hoax(address(i), SEND_VALUE); // hoax is vm.deal and vm.prank combined.
            fundMe.fund{value: SEND_VALUE}();
        }
 }
 ```
As you can see from the example, `hoax` dealt money to the accounts in the loop and made it so that the next transactions would be from the accounts in the loop.


`vm.startPrank` - `vm.stopPrank` : These cheat codes are like `vm.prank` except instead of just doing 1 transaction, all transactions between `vm.startPrank` and `vm.stopPrank` are simulated from an account.
For example:
```javascript
vm.startprank(fundMe.getOwner()); // next transaction is from the owner
fundMe.withdraw(); // owner withdraws
vm.stopPrank;
```

`vm.txGasPrice` : Sets the gas factor since when working on anvil the gas factor is always 0. meaning that transactions will always cost not gas unless you tell anvil to use a gas factor.
```javascript
    // This is the gas price that we tell anvil to use with the cheat code `vm.txGasPrice`. We can set this number to anything.
    uint256 constant GAS_PRICE = 1;
    // ^ tells solidity to use gas of a factor by 1 because on anvil it is always set to 0 ^
function ...
   //In order to see how much gas a function is going to spend, we need to calculate the gas spend before and after.
        // here we are checking how much gas is left before we call the withdraw function(which is the main thing we are testing).
        uint256 gasStart = gasleft(); // gasleft() is a built in function in solidity.

        vm.txGasPrice(GAS_PRICE); // tells solidity to use gas of a factor by 1 because on anvil it is always set to 0.
        vm.prank(fundMe.getOwner()); // next transaction is from the owner
        fundMe.withdraw(); // owner withdraws

        // getting the balance of the gas after we finish calling the withdraw function.
        uint256 gasEnd = gasleft();
        // here we do the math to figure out how much gas we used taking the gasStart and subtracting it from the gasEnd and multiplying that number against the current gas price.
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; //tx.gasprice is built into solidity that tells you the current gas price
        // now when we run this test it will tell us how much gas was used.
...
```

`vm.warp` & `vm.roll`:
`vm.warp`: allows us to warp time ahead so that foundry knows time has passed.
`vm.roll`: rolls the blockchain forward to the block that you assign.
These don't have do be used together, but they should be used together to avoid issues and be technically correct.
Example:
```js
 function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        // next transaction will come from the PLAYER address that we made
        vm.prank(PLAYER);
        // PLAYER pays the entrance fee and enters the raffle
        raffle.enterRaffle{value: entranceFee}();
        // vm.warp allows us to warp time ahead so that foundry knows time has passed.
        vm.warp(block.timestamp + interval + 1); // current timestamp + the interval of how long we can wait before starting another audit plus 1 second.
        // vm.roll rolls the blockchain forward to the block that you assign. So here we are only moving it up 1 block to make sure that enough time has passed to start the lottery winner picking in raffle.sol
        vm.roll(block.number + 1);
        // now we can call performUpkeep and this will change the state of the raffle contract from open to calculating, which should mean no one else can join.
        raffle.performUpkeep("");

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }
```





### Foundry Assertion Functions Notes


At the end of a test written in foundry, we need to assert the values that we are testing. An assert is a statement that verifies if a condition is true. If the condition is false, the assert will fail and provide an error message. It's a way to validate that your code is working as expected.

Some Assertion Functions are:

```js
// Compare equality
assertEq(x, y);          // x == y
assertEq(x, y, "message"); // x == y with custom error message
```

AssertEq is my favorite because it is the most used and it will log both the values when you run the test

```js
assert(x == y) // x == y
```
Assert is like AssertEq but it will not log the values, you must console.log them

```js
// Compare inequality
assertNotEq(x, y);       // x != y
```

```js
// Boolean assertions
assertTrue(x);           // x is true
assertFalse(x);          // x is false
```

```js
// Compare approximate equality (for floating point)
assertApproxEqAbs(x, y, delta);  // |x - y| <= delta
assertApproxEqRel(x, y, percentage); // |x - y| <= |x| * percentage
```

```js
// Compare greater/less than
assertGt(x, y);          // x > y
assertLt(x, y);          // x < y
assertGe(x, y);          // x >= y
assertLe(x, y);          // x <= y
```

Examples:

assertEq (from foundry-defi-stablecoin-f23):
```js
 function testGetUsdPriceValue() public {
        // 15 eth tokens(each eth token has 18 decimals)
        uint256 ethAmount = 15e18;
        // our helperconfig puts the eth price on anvil at 2,000/eth
        // 15e18 * 2000eth = 30,000e18
        uint256 expectedUsd = 30000e18;
        // calls getUsdValue, but getUsdValue needs two paramters, the token and the amount
        // so we pass the weth token we defined earlier from our helperconfig and we define the ethAmount earlier in this function
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        // Assert the the expectedUsd and the actualUsd are the same
        assertEq(expectedUsd, actualUsd);
    }
```



### Debugging Tests Notes

You will come across many errors when testing. To debug them you have a few different choices:

1. You can `console.log` values in the test to try and debug. Remember to run `-vv`/`-vvv`/`-vvvv` to see the logs

2. You can run `-vv`/`-vvv`/`-vvvv` at the end of your `forge test --mt <functionName> -vvvv` to see the detailed output of the test output.


3. You can run `--debug` to enter into a low level debugger in your terminal.
    Example:
    `forge test --debug <functionName> -vvv`, then press q to quit.

    This is a low-level debugger and will have all the opCodes.

    If you press `shift` + `g` this will bring you to the end where it actually reverted. It will show you in blue the line of the test that revert/has an issue.

    At the bottom it shows you what keys to press and their functions.

    If you start pressing `k`, it will walk us back through the codebase and eventually we will land on a line of code, this will be the line that is causing issues.






 ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ## Chisel Notes

 To run chisel, run `chisel` in your terminal.
 you can run `!help` in chisel to see everything you can do in the chisel terminal.

 Chisel allows us to write solidity in our terminal and execute it line by line so we can quickly see if something works.

For example, if we wrote (in chisel):
`uint256 dog =1` (press ENTER)
then we typed `dog` (PRESS ENTER)
it would return: 
```javascript
Type: uint256
├ Hex: 0x1
├ Hex (full word): 0x1
└ Decimal: 1
```
Another Example following the previous:
```javascript
➜ uint256 dogAndThree = dog + 3;
➜ dogAndThree
Type: uint256
├ Hex: 0x4
├ Hex (full word): 0x4
└ Decimal: 4
➜ 
```

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Deploying on Anvil Without A Script Notes

You always want to deploy contracts through deployment scripts (SEE SCRIPT NOTES).

*** NEVER USE A .ENV FOR PRODUCTION BUILDS, ONLY USE A .ENV FOR TESTING ***

to deploy a Singular Contract while testing on anvil or a testnet:

to deploy a smart contract to a chain, use the following command of:

`forge create <filename> --rpc-url http://<endpoint-url> --account <account-Name> --sender <account-public-address> --broadcast `.

you can get the endpoint url(PRC_URL)  from alchemy. when getting the url from alchemy, copy the https endpoint. then set up your .env like `.env`


example:
`forge create SimpleStorage --rpc-url http://127.0.0.1:8545 --account testing --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast`.

in the example above, we are deploying to anvil's blockchain with a fake private key from anvil. if you want to run anvil, just run the command "anvil" in your terminal.

*** HOWEVER WHEN DEPLOYING TO A REAL BLOCKCHAIN, YOU NEVER WANT TO HAVE YOUR PRIVATE KEY IN PLAIN TEXT ***

*** ALWAYS USE A FAKE PRIVATE KEY FROM ANVIL OR A BURNER ACCOUNT FOR TESTING ***

*** NEVER USE A .ENV FOR PRODUCTION BUILDS, ONLY USE A .ENV FOR TESTING ***

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Script Notes

### Getting Started with Scripts Notes

When writing Scripts, you must import the `script` directory from `foundry`. and if you are using `console.log`, then you must import `console.log` as well.
For Example:
```javascript
import {Script, console} from "forge-std/Script.sol";
contract DeployFundMe is Script {} // Also the deployment script MUST inherit the Script Directory.
```

All Script functions must have a `run()` function. 
For example:
```javascript
// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// we must import Script.sol to tell foundry that this is a script.
import {Script} from "forge-std/Script.sol"; // we need to import the script package from foundry when working on scripts in foundry/solidity.
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// this script will deploy our smart contracts. we should always deploy smart contracts this way.
// Script contracts always need to inherit from scripts
contract DeployFundMe is Script {
    // all deployments scripts need to have this "run" function because this will be the main function called when deploying the contract.
    function run() external returns (FundMe) {
        // this says that when we start this `run` function, it will create a new helperconfig of type HelperConfig contract.
        HelperConfig helperConfig = new HelperConfig();
        // because we send this before `vm.startBroadcast`, it is executing this code in a simulated environment. So it is grabbing the chainId that we are deploying to right before we deploy the contracts

        // we get the activeNetwork's pricefeed address and save it as a variable called "ethUsdPriceFeed"
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();
        // `activeNetworkConfig` is a variable of type struct, so if we had more variables in the struct, depending on what we would want we should save it as (address ethUsdPriceFeed, address exampleAddress, , ,)

        // "vm.startBroadcast" is a cheatcode from foundry. it tells foundry "everything after this line should be sent to the rpc"
        vm.startBroadcast();
        // this line says variable name "fundMe" of type contract FundMe is equal to a new FundMe contract that is now being created and the broadcast line deploys it.
        // FundMe fundMe = new FundMe(); // this line throws a warning since we do not use the variable fundMe
        // new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306); // this also creates a new FundMe contract

        // we use this because now it will be more modular. All we do is now change this address and it will update our entire codebase.
        FundMe fundMe = new FundMe(ethUsdPriceFeed); // this address gets inputted into the FundMe constructor.
        vm.stopBroadcast();
        return fundMe; // because this returns the deployed fundMe contract, we can make changes and it will always return the change we made. making the testing easier and more modular.
    }
}
```

another example: DeployRaffle.s.sol from foundry-smart-contract-lottery
```js
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    function run() public {}

    function deployContracts() public returns (Raffle, HelperConfig) {
        // deploy a new helpconfig contract that grabs the chainid and networkConfigs
        HelperConfig helperConfig = new HelperConfig();
        // grab the network configs of the chain we are deploying to and save them as `config`.
        // its also the same as doing ` HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid);`
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // everything between startBroadcast and stopBroadcast is broadcasted to a real chain
        vm.startBroadcast();
        // create a new raffle contract with the parameters that are in the Raffle's constructor. This HAVE to be in the same order as the constructor!
        Raffle raffle = new Raffle(
            // we do `config.` before each one because our helperConfig contract grabs the correct config dependent on the chain we are deploying to
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callBackGasLimit
        );
        vm.stopBroadcast();
        // returns the new raffle and helperconfig that we just defined and deployed so that these new values can be used when this function `deployContracts` is called
        return (raffle, helperConfig);
    }
}

```



#### Script Cheatcodes 

`vm.startBroadcast` & `vm.stopBroadcast`: All logic inbetween these two cheatcodes will be broadcasted/executed directly onto the blockchain. Broadcast is just a tool that allows msg.sender to become the owner of the contract. So you would be the owner, not the deployment script. And when using deployment scripts that use `broadcast` in tests, the test contract would become the msg.sender. 
example: (from `foundry-smart-contract-lottery/script/DeployRaffle.s.sol`)
```js
contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        // deploy a new helpconfig contract that grabs the chainid and networkConfigs
        HelperConfig helperConfig = new HelperConfig();
        // grab the network configs of the chain we are deploying to and save them as `config`.
        // its also the same as doing ` HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid);`
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // if the subscription id does not exist, create one
        if (config.subscriptionId == 0) {
            // deploys a new CreateSubscription contract from Interactions.s.sol and save it as a variable named createSubscription
            CreateSubscription createSubscription = new CreateSubscription();
            // calls the createSubscription contract's createSubscription function and passes the vrfCoordinator from the networkConfigs dependent on the chain we are on. This will create a subscription for our vrfCoordinator. Then we save the return values of the subscriptionId and vrfCoordinator and vrfCoordinator as the subscriptionId and values in our networkConfig.
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator);

            // creates and deploys a new FundSubscription contract from the Interactions.s.sol file.
            FundSubscription fundSubscription = new FundSubscription();
            // calls the `fundSubscription` function from the FundSubscription contract we just created and pass the parameters that it takes.
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link);
        }

        // everything between startBroadcast and stopBroadcast is broadcasted to a real chain
        vm.startBroadcast();
        // create a new raffle contract with the parameters that are in the Raffle's constructor. This HAVE to be in the same order as the constructor!
        Raffle raffle = new Raffle(
            // we do `config.` before each one because our helperConfig contract grabs the correct config dependent on the chain we are deploying to
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callBackGasLimit
        );
        vm.stopBroadcast();

        // creates and deploys a new AddConsumer contract from the Interactions.s.sol file.
        AddConsumer addConsumer = new AddConsumer();
        // calls the `addConsumer` function from the `AddConsumer` contract we just created/deplyed and pass the parameters that it takes.
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId);

        // returns the new raffle and helperconfig that we just defined and deployed so that these new values can be used when this function `deployContracts` is called
        return (raffle, helperConfig);
    }
}
```

However, the `vm.startBroadcast` can also be passed in the account that will be sending these transactions
example: from `foundry-smart-contract-lottery-f23`
```js
    // these are the items that the constructor in DeployRaffle.s.sol takes
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callBackGasLimit;
        uint256 subscriptionId;
        address link;
        address account;
    }

    ...

     // everything between startBroadcast and stopBroadcast is broadcasted to a real chain and the account from the helperConfig is the one making the transactions
        vm.startBroadcast(config.account);
        // create a new raffle contract with the parameters that are in the Raffle's constructor. This HAVE to be in the same order as the constructor!
        Raffle raffle = new Raffle(
            // we do `config.` before each one because our helperConfig contract grabs the correct config dependent on the chain we are deploying to
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callBackGasLimit
        );
        vm.stopBroadcast();
```

`vm.readFile`: reads from the file you point to

example from `NFTs-2024/script
/DeployMoodNft.s.sol`:
```js
// Deployment contract that inherits from Forge's Script contract
contract DeployMoodNft is Script {
    // Main deployment function that returns the deployed MoodNft instance
    function run() external returns (MoodNft) {
        // Read SVG files from the local filesystem using Forge's vm.readFile
        string memory sadSvg = vm.readFile("./img/sad.svg");
        string memory happySvg = vm.readFile("./img/happy.svg");

        // Start recording transactions for deployment
        vm.startBroadcast();
        // Deploy new MoodNft contract with converted SVG URIs
        // svgToImageURI converts raw SVG to base64 encoded data URI
        MoodNft moodNft = new MoodNft(svgToImageURI(sadSvg), svgToImageURI(happySvg));
        // Stop recording transactions
        vm.stopBroadcast();
        // Return the deployed contract instance
        return moodNft;
    }
```
Note: in order to use `vm.readFile` cheatcode, you need to activate fs_permissions in your `foundry.toml`:
```js
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
// the fs_permissions should be above the remappings:
fs_permissions = [{ access = "read", path = "./img/" /* img should be replaced with the folder that you want to readFiles from. In this example i want to use readFile on my `img` folder */ }]
remappings = ['@openzeppelin/contracts=lib/openzeppelin-contracts/contracts']
```




`vm.writeFile`: writes code into the file you point to
example from `merkle-airdrop/script/GenerateInput.s.sol`
```js
// Merkle tree input file generator script
contract GenerateInput is Script {
    uint256 private constant AMOUNT = 25 * 1e18;
    string[] types = new string[](2);
    uint256 count;
    string[] whitelist = new string[](4);
    string private constant  INPUT_PATH = "/script/target/input.json";
    
    function run() public {
        types[0] = "address";
        types[1] = "uint";
        whitelist[0] = "0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D";
        whitelist[1] = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
        whitelist[2] = "0x2ea3970Ed82D5b30be821FAAD4a731D35964F7dd";
        whitelist[3] = "0xf6dBa02C01AF48Cf926579F77C9f874Ca640D91D";
        count = whitelist.length;
        string memory input = _createJSON();
        // write to the output file the stringified output json tree dumpus 
        vm.writeFile(string.concat(vm.projectRoot(), INPUT_PATH), input);

        console.log("DONE: The output is found at %s", INPUT_PATH);
    }

    function _createJSON() internal view returns (string memory) {
        string memory countString = vm.toString(count); // convert count to string
        string memory amountString = vm.toString(AMOUNT); // convert amount to string
        string memory json = string.concat('{ "types": ["address", "uint"], "count":', countString, ',"values": {');
        for (uint256 i = 0; i < whitelist.length; i++) {
            if (i == whitelist.length - 1) {
                json = string.concat(json, '"', vm.toString(i), '"', ': { "0":', '"',whitelist[i],'"',', "1":', '"',amountString,'"', ' }');
            } else {
            json = string.concat(json, '"', vm.toString(i), '"', ': { "0":', '"',whitelist[i],'"',', "1":', '"',amountString,'"', ' },');
            }
        }
        json = string.concat(json, '} }');
        
        return json;
    }
}
```
Note: in order to use `vm.writeFile` cheatcode, you need to activate fs_permissions in your `foundry.toml`:
```js
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
// the fs_permissions should be above the remappings:
fs_permissions = [{ access = "read-write", path = "./" /* this says it can read from our root directory, if you want to make it more narrow, you can change the path to the file/folder you want to write into*/}]

remappings = ['@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/', 'forge-std=lib/forge-std/src/']
```


### HelperConfig Script Notes

We live in a multi-chain world, there are many different chains and often we will want to deploy the same protocol to different chains. To do this smoothly, we can create a `HelperConfig.s.sol` file that can see what chain we are on, and grab the correct network configurations for our deployment script when we are deploying.

For example: HelperConfig.s.sol from foundry-smart-contract-lottery-f23
```js
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    /* VRF Mock Values */
    // values that are from chainlinks mock constructor
    uint96 public MOCK_BASE_FEE = 0.25 ether; // when we work with chainlink VRF we need to pay a certain amount of link token. The base fee is the flat value we are always going to pay
    uint96 public MOCK_GAS_PRICE_LINK = 1e19; // when the vrf responds, it needs gas, so this is the cost of the gas that we spend to cover for it. This calculation is how much link per eth are we going to use?
    int256 public MOCK_WEI_PER_UNIT_LINK = 4_16; // link to eth price in wei
    // ^ these are just fake values for anvil ^

    // chainId for Sepolia
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    // chainId for anvil
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainID();

    // these are the items that the constructor in DeployRaffle.s.sol takes
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callBackGasLimit;
        uint256 subscriptionId;
    }

    // creating a variable named localNetworkConfig of type struct NetworkConfig
    NetworkConfig public localNetworkConfig;

    // mapping a chainId to the struct NetworkConfig so that each chainId has its own set of NetworkConfig variables.
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        // mapping the chainId 11155111 to the values in getSepoliaEthConfig
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        // if the if the vrf.coordinator address does exist on the chain we are on,
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            // then return the all the values in the NetworkConfig struct
            return networkConfigs[chainId];
            // if we are on the local chain, return the getOrCreateAnvilEthConfig() function
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
            // otherwise revert with an error
        } else {
            revert HelperConfig__InvalidChainID();
        }
    }

    // calls getConfigByChainId to grab the chainId of the chain we are deployed on and do the logic in getConfigByChainId
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    // these are the items that are relevant for our raffle constructor if we are on the Sepolia Chain when we deploy.
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.1 ether, // 1e16 // 16 zeros
            interval: 30, // 30 seconds
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // got this from the chainlink docs here: https://docs.chain.link/vrf/v2-5/supported-networks
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // // got this keyhash from the chainlink docs here: https://docs.chain.link/vrf/v2-5/supported-networks
            callBackGasLimit: 500000, // 500,000 gas
            subscriptionId: 0
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // if the if the vrf.coordinator address does exist on the anvil chain that we are on,
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            // then return the all the values in the NetworkConfig struct that is has since it already exists
            return localNetworkConfig;
        }

        // if the if the vrf.coordinator address does NOT exist on the anvil chain that we are on, then deploy a mock vrf.coordinator
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        vm.stopBroadcast();

        // these are the items that are relevant for our raffle constructor if we are on the Anvil Chain when we deploy.
        localNetworkConfig = NetworkConfig({
            entranceFee: 0.1 ether, // 1e16 // 16 zeros
            interval: 30, // 30 seconds
            vrfCoordinator: address(vrfCoordinatorMock), // the address of the vrfCoordinatorMock
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // does not matter since this is on anvil
            callBackGasLimit: 500000, // 500,000 gas, but it does not matter since this is on anvil
            subscriptionId: 0
        });
        // then return the all the values in the NetworkConfig struct when this function is called
        return localNetworkConfig;
    }
}
```


### Interaction Script Notes
(its most likely easier to just use Cast Send to interact with deployed contracts.)

You can write a script to interact with your deployed contract. This way, if you want to repeatedly call a function or interact with your contract for any reason, a script is a great way to do so as it makes these interactions reproducible. These interaction scripts should be saved in the script/Interactions folder!

A great package to use is `Cyfrin Foundry DevOps` as it grabs your latest version of a deployed contract to interact with. Install it with `forge install Cyfrin/foundry-devops --no-commit`. (this Cyfrin Foundry Devops tool can be found here: `https://github.com/Cyfrin/foundry-devops`)

when using cyfrin foundry devops, make sure to Update your `foundry.toml` to have read permissions on the broadcast folder (copy and paste the following into your `foundry.toml`):
```js
fs_permissions = [
    { access = "read", path = "./broadcast" },
    { access = "read", path = "./reports" },
]
```

This package has a function that allows you to grab your lastest version of a deployed contract.
For Example:
```javascript
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


// this is going to be our script for funding the fundMe contract
contract FundFundMe is Script {
    // amount we are funding with
    uint256 constant SEND_VALUE = 0.01 ether;

    function fundFundMe(address mostRecentlyDeplyed) public {
        // `startBroadcast` sends all transactions between startBroadcast and stopBroadcast
        vm.startBroadcast();

        // takes an input parameter of an address, which is going to be the mostRecentlyDeplyed address of our contract and funds it with the amount we want.
        FundMe(payable(mostRecentlyDeplyed)).fund{value: SEND_VALUE}();

        vm.stopBroadcast();

        console.log("Funded FundMe with %s", SEND_VALUE); // import the console.log from the script directory
            // this console.log also lets us know when the transaction goes through because it pops up when the transaction goes through.
    }

    function run() external {
        // grabs the most recent deployment from the broadcast folder. takes the name of the contract and the blockchain so it knows what to do
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("FundMe", block.chainid);
        // calls the fundFundMe function to deploy funds to the most recently deployed contract
        fundFundMe(mostRecentlyDeployed);
    }
}
```
Always write tests for scripts as getting them wrong and deploying them is a waste of money. Save the money and write the tests! But its most likely easier to just use Cast Send to interact with deployed contracts.

Below is another example of running Interaction Scripts:

First we ran the following command to deploy our NFT.
```bash
forge script script/DeployBasicNft.s.sol:DeployBasicNft --rpc-url http://127.0.0.1:8545 --account testing --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast 
```

Then we ran the following command to mint the first NFT in our contract through an Interactions.s.sol script:
```bash
 forge script script/Interactions.s.sol:MintBasicNft --rpc-url http://127.0.0.1:8545 --account testing --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast
```

Below is the example Interactions.s.sol script we executed (from foundry-nft-f23):
```js
// Specifies the license for this contract
// SPDX-License-Identifier: MIT

// Declares the Solidity version to be used
pragma solidity 0.8.19;

// Import necessary contracts and libraries
import {Script} from "forge-std/Script.sol";
import {BasicNft} from "../src/BasicNFT.sol";
// DevOpsTools helps us interact with already deployed contracts
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

// Contract for minting NFTs on an already deployed BasicNft contract
contract MintBasicNft is Script {
    // Define a constant IPFS URI for the PUG NFT metadata
    // This URI points to a JSON file containing the NFT's metadata (image, attributes, etc.)
    string public constant PUG =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

    // Main function that will be called to mint an NFT
    function run() external {
        // Get the address of the most recently deployed BasicNft contract on the current chain
        // This allows us to interact with the contract without hardcoding addresses
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("BasicNft", block.chainid);
        // Call the function to mint an NFT on this contract
        mintNftOnContract(mostRecentlyDeployed);
    }

    // Function that handles the actual minting process
    function mintNftOnContract(address contractAddress) public {
        // Start recording transactions for broadcasting to the network
        vm.startBroadcast();
        // Cast the address to our BasicNft contract type and call the mint function
        // This creates a new NFT with the PUG metadata
        BasicNft(contractAddress).mintNft(PUG);
        // Stop recording transactions
        vm.stopBroadcast();
    }
}

```



### Deploying A Script Notes
If you have a script, you can run a simulation of deploying to a blockchain with the command in your terminal of `forge script script/<file-name> --rpc-url http://<endpoint-url>` 

example:
```bash
forge script script/DeploySimpleStorage.s.sol --rpc-url http://127.0.0.1:8545 # this will spin up a temporary anvil blockchain with a fake account for simulation purposes 
```

this will create a broadcast folder, and all deployments will be in your deployment folder in case you want to view any information about your deployment.

to deploy to a testnet or anvil run the command of `forge script script/<file-name> --rpc-url http://<endpoint-url> --account <account-Name> --sender <account-public-address> --broadcast `   

example: 
` forge script script/DeploySimpleStorage.s.sol --rpc-url $RPC_URL --broadcast --account <account-Name> --sender <account-public-address> --broadcast `

if you have multiple contracts in a file and only want to send one, you can send the one by running `forge script script/Interactions.s.sol:FundFundMe --rpc-url http://<endpoint-URL> --account <account-Name> --sender <account-public-address> --broadcast`

example: 
` forge script script/DeployBasicNft.s.sol:DeployBasicNft --rpc-url http://127.0.0.1:8545 --account testing --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast `

when deploying or interacting with contracts, if you get an error of `-ffi` then you must input `ffi = true` in your `foundry.toml`. However, make sure to turn this off when you are done as this command is dangerous and allows the host of the library to execute commands on your machine.

*** HOWEVER WHEN DEPLOYING TO A REAL BLOCKCHAIN, YOU NEVER WANT TO HAVE YOUR PRIVATE KEY IN PLAIN TEXT ***

*** ALWAYS USE A FAKE PRIVATE KEY FROM ANVIL OR A BURNER ACCOUNT FOR TESTING ***

*** NEVER USE A .ENV FOR PRODUCTION BUILDS, ONLY USE A .ENV FOR TESTING ***




### Deploying on Anvil Notes (Local Foundry Blockchain)
You always want to deploy a contract through a deployment script. 

Steps:

1. run `anvil`
2. create a new terminal.
3. cd into the correct folder in the new terminal.

run the following format to deploy the deployment script:
```bash
forge script script/Interactions.s.sol:FundFundMe --rpc-url http://<endpoint-URL> --account <account-Name> --sender <account-public-address> --broadcast
```

example:
```bash
forge script script/DeployBasicNft.s.sol:DeployBasicNft --rpc-url http://127.0.0.1:8545 --account testing --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast
```


when deploying or interacting with contracts, if you get an error of `-ffi` then you must input `ffi = true` in your `foundry.toml`. However, make sure to turn this off when you are done as this command is dangerous and allows the host of the library to execute commands on your machine.


### Deploying to a Testnet Notes

You always want to deploy a contract through a deployment script. 
Deployment script example:
```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Import the Forge scripting utilities and our NFT contract
import {Script} from "forge-std/Script.sol";
import {BasicNft} from "../src/BasicNFT.sol";

// Contract for deploying our BasicNft, inheriting from Forge's Script contract
contract DeployBasicNft is Script {
    // Main function that will be called to deploy the contract
    // When deployed to a real network, msg.sender will be the wallet address that runs this script
    // In tests, msg.sender is a test address provided by Forge's testing environment
    // This difference occurs because:
    // 1. Real deployments: vm.startBroadcast() uses the private key from your wallet or environment
    // 2. Tests: Forge's VM creates a test address and uses that as msg.sender
    function run() external returns (BasicNft) {
        // Start recording transactions for broadcasting to the network
        vm.startBroadcast();
        // Create a new instance of our BasicNft contract
        // This will initialize it with "Dogie" name and "Dog" symbols
        BasicNft basicNft = new BasicNft();
        // Stop recording transactions
        vm.stopBroadcast();
        // Return the deployed contract instance
        return basicNft;
    }
}
```

Then you will need to update your `.env` with your RPC_URL for the tesnet you want to deploy to. You can get this RPC_URL from alchemy. The link you are looking for on Alchemy will be the https link on the testnet of the chain you want to deploy on.
example `.env`:
```js
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/abc123
```
Then run `source .env` to add the environment varibles you just defined in `.env` to your project

Then run the following command format to deploy your deployment script to the testnet:
```bash
forge script script/<file-Name>:<contract-Name> --rpc-url $RPC_URL_LINK --account <account-Name> --sender <account-public-address> --broadcast
```
example:
```bash
forge script script/DeployBasicNft.s.sol:DeployBasicNft --rpc-url $SEPOLIA_RPC_URL --account SepoliaBurner --sender 0xBe3dDdB70EA16cBfd0cE0A4028902678EECDBe6D --broadcast
```
And to verify the contract when deploying, run `--verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv`. Make sure to have the `$ETHERSCAN_API_KEY` in your `.env` file.
```bash
forge script script/DeployBasicNft.s.sol:DeployBasicNft --rpc-url $SEPOLIA_RPC_URL --account SepoliaBurner --sender 0xBe3dDdB70EA16cBfd0cE0A4028902678EECDBe6D --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
```

when deploying or interacting with contracts, if you get an error of `-ffi` then you must input `ffi = true` in your `foundry.toml`. However, make sure to turn this off when you are done as this command is dangerous and allows the host of the library to execute commands on your machine.


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## BroadCast Folder Notes

the `dry-run` folder is where the transactions with no blockchain specified go.

`run-latest.json` is the latest transaction sent. the transaction data will look like: 

```javascript
  "transactions": [
    {
        
      "hash": "0x8677435aa38539f85122ff0f9f6a30f0bb1587d6f08837b13b0dea2a8b8d217d", // the serial number of the transaction is called the hash
      "transactionType": "CREATE", // we are creating/deploying the contract onto the blockchain
      "contractName": "SimpleStorage", // name of contract 
      "contractAddress": "0x5fbdb2315678afecb367f032d93f642f64180aa3", // address the contract is deployed on
      "function": null,
      "arguments": null,
      "transaction": { // this transaction section is what is actually being sent on chain.
        "from": "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", // the address i sent this transaction from
        "gas": "0x71556", // we can decode this by running the command `cast --to-base 0x71556 dec`. "dec" stands for decimal. it represents the type of format we want to decode the data to.
        "value": "0x0", // you can add value when deploying a contract by making the constructor payable in the contract being deployed and adding `SimpleStorage simpleStorage = new SimpleStorage{value: 1 ether}();` in the deploy script. 
        "input": "0x608060405234801561001057600080fd5b5061057f8061...", // this is the contract deployment code and the contract being deployed code. This holds all the opcodes/EVM bytecode
        "nonce": "0x0", // In Solidity and Ethereum, a nonce is a number that keeps track of the number of transactions sent from an address. This increments everytime we send a transaction.
        "chainId": "0x7a69"
      },
      "additionalContracts": [],
      "isFixedGasLimit": false
    }
  ],
```
  When you send a transaction, you are signing it and sending it.

  cast is a very helpful tool. run `cast --help` to see all the helpful things it can do. 

  Watch the video about this @ https://updraft.cyfrin.io/courses/foundry/foundry-simple-storage/what-is-a-transaction . if that does not work, then it is the foundry fundamentals course, section 1, lesson 18: "What is a transaction"

Nonce Main purpose:


Prevent transaction replay attacks (same transaction being executed multiple times)
Ensure transactions are processed in the correct order
Track the number of transactions sent by an account

If you ever forget the contract address of a contract you just deployed, you can find it heree in the `broadcast` folder
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## .env Notes


*** NEVER USE A .ENV FOR PRODUCTION BUILDS, ONLY USE A .ENV FOR TESTING ***

when using a .env, after adding the variables into the .env, run `source .env` in your terminal to added the environment variables.

then run `echo $<variable>` to check it it was added properly. example: `echo $RPC_URL`. 

this way, when testing, instead of typing our rpc-url and private key into the terminal each time, we can instead run ` forge script script/<file-Name> --rpc-url $RPC_URL --account <account-Name> --sender <account-public-address> --broadcast` .

example: `forge script script/DeployBasicNft.s.sol:DeployBasicNft --rpc-url http://127.0.0.1:8545 --account testing --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast`

You never want to have your private key in plain text. Please do not use 

*** NEVER USE A .ENV FOR PRODUCTION BUILDS, ONLY USE A .ENV FOR TESTING ***



example:
` forge script script/DeploySimpleStorage.s.sol --rpc-url $RPC_URL --broadcast --account <account-Name> --sender <account-public-address>  ` 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## DEPLOYING PRODUCTION CONTRACT Notes


*** DEPLOYING PRODUCTION CONTRACTS ***
 to deploy production contracts, you must encrypt your private key. this will result in you also creating a password for your private key, so don't lose it. to encrypt a private key run the following commands in your terminal, NOT in VS-Code or Cursor:
 
 ```javascript
`cast wallet import <your-account-name> --interactive` // pass an account name to name this wallet and do not forget the account name!
Enter private key: // it will prompt you to enter your private key to encrypt it
Enter password: // it will prompt you to enter a password. Don't forget the password!
`your-account-name` keystore was saved successfully. Address: address-corresponding-to-private-key
 ```

 Then deploy with:
`forge script <script> --rpc-url <rpc_url> --account <account_name> --sender <address> --broadcast`

After you deploy with this command, it will prompt you for your password. Do not lose your account name, public address, password, and obviously, do not lose your private key!. 

you can of course add a RPC_URL to your .env and run `forge script <script> --rpc-url $RPC_URL --account <account_name> --sender <address> --broadcast` as well. NEVER PUT YOUR PRIVATE KEY IN YOUR .env !!

example: `forge script script/DeployBasicNft.s.sol:DeployBasicNft --rpc-url http://127.0.0.1:8545 --account testing --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast`

you can run `cast wallet list` and it will show you all a list of the names you choose for the wallets you have encrpted.

after encrypting your private key clear your terminal's history with `history -c`

After deploying a contract copy the hash and input it into its blockchain's etherscan, then click on the "to" as this will be the contract. (The hash created is the hash of the transaction and the "to" is the contract itself.)

### Verifying a Deploying Contract Notes

Manually (Not Recommended):
1. When on the contract on etherscan, click the "Verify and Publish" button in the "Contract" tab of the contract on etherscan. This will take you to a different page on etherscan.
2. Select the correct options that define what you just deployed. (it will ask for info such as: address, Compiler type and version, and License type.)
3. Then copy the code of the contract and paste it in the "Enter Solidity Contract Code below" section and define the contrustor args if you have them(if you dont then leave it blank).
4. Select "yes" for the "Optimization" button.
5. If done correctly, you will now be able to see your contracts that have been deployed in the contracts "read" tab.

Programatically (Recommended):
To programtically verify a contract, you must do it while deploying. When deploying, the command must end with `--verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv`. Make sure to have the `$ETHERSCAN_API_KEY` in your .env file!

Example:
`forge script script/DeployFundMe.s.sol:DeployFundMe --rpc-url $SEPOLIA_RPC_URL --account <accountName> --sender <address> --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv`

#### If a Deployed Contract does not Verify Correctly


If a deployed contract does not verify correctly during deployment, we can then do the following to verify a contract:

1. Run `forge verify-contract <contract-address> <contract> --etherscan-api-key $ETHERSCAN_API_KEY --rpc-url $SEPOLIA_RPC_URL --show-standard-json-input > json.json`

Arguments:
  <ADDRESS>
          The address of the contract to verify

  [CONTRACT]
          The contract identifier in the form `<path>:<contractname>`

example: `forge verify-contract 0x123456789 src/Raffle.sol:Raffle --etherscan-api-key $ETHERSCAN_API_KEY --rpc-url $SEPOLIA_RPC_URL --show-standard-json-input > json.json` 

Make sure you have a ETHERSCAN_API_KEY and SEPOLIA_RPC_URL in your .env file.

This command will create a new json.json in your root directory.

2. Go to the file and press `ctrl` + `shift` + `p` and search for and select `format`. This json.json file is what is known as the standard json and is what verifiers will use to actually verify a contract.

3. Go back to etherscan, in your contract tab where your contract should be verified. Click `Verify and publish`. This will take you to a page to select/fill details about your contract, such as the address of the contract, the compiler type and version and Open Source License Type (probably MIT). For the Compiler type, choose `Solidity (Standard-Json-Input)` and the compiler version you are using in your contract(s). 

4. Click COntinue and on the next page it will ask you to select the `Standard-Json-Input` file to upload, here is where you will upload the json.json file we just made earlier. 

5. Click `I'm not a robot` and verify and publish!



#### ALL --VERIFY OPTIONS NOTES

To see all the options of verifying a contract with forge, run `forge verify-contract --help`


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## How to interact with deployed contracts from the command line Notes

After you deploy a contract, you can interact with it:

if you type `cast --help` you will see a bunch of commands. One of the commands we are going to work with is going to be `send`. To see the arguments that `send` takes, run `cast send --help`; the arguments are:
`TO`: The destination of the transaction. If not provided, you must use cast send --create.
`SIG`: The signature of the function to call.
`ARGS`: The arguments of the function to call.

For example, if we want to call our store function in SimpleStorage.sol, we would run the following:
`cast send 0x5fbdb2315678afecb367f032d93f642f64180aa3 "store(uint256)" 123 --rpc-url $RPC_URL --account <accountName>`.

Explantion:
`cast send`: command to interact with the contract / write to the contracts functions
`0x5fbdb2315678afecb367f032d93f642f64180aa3`: address of the contract. if you forget what the address is, it can be found in the broadcast folder (check notes above).
` "store(uint256)" `: we want to interact with the store function, and it takes a uint256 as its parameter.
`123`: the values(arguments) that we want to pass.

Another example: `cast send 0x6c4791c3a9E9Bc5449045872Bd1b602d6385E3E1 "solveChallenge(string,string)" "chocolate" "Squilliam" --rpc-url $SEPOLIA_RPC_URL --account SepoliaBurner` - As you can see, here we put the name of the parameters as well as its type, this is how you would do it. as you can see we are passing the arugments of "chocolate" and "Squilliam". 

Running this command will return a bunch of data, to read the data, run `cast call --help`. This will show you the arguments that `call` takes. The arguments are `TO`, `SIG`, and `ARGS` again! The difference is, `call` is calling a transaction to read data, whereas `send` is sending a transaction to modify the blockchain!

To use `call` run: `cast call <contract address> <function name> <input parameters>`

example:
`cast call 0x5fbdb2315678afecb367f032d93f642f64180aa3 "retrieve()" ` (the retrieve function has no input parameters so we leave it blank.)

this command will return hex data, and needs to be decoded. so to decode it, run `cast --to-base <hex-data> dec`

example: the hex data returned is: `0x000000000000000000000000000000000000000000000000000000000000007b` so the command is `cast --to-base 0x000000000000000000000000000000000000000000000000000000000000007b dec` ("dec" stands for decimal. it represents the type of format we want to decode the data to.)

This returns the data that we submitted of `123`. (NOTE: This returns the data we submitted because it is the only data submitted and the contract function "retrieve" is written to return the most recent number.)

Another Example of 
`Cast call`: `cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "balanceOf(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 ` - calls the balanceOf function on an ERC20 contract to see how many tokens of that ERC20 an address has. This returns hex data of `0x0000000000000000000000000000000000000000000000015af1d78b58c40000`, and to decode we can run either `cast --to-base 0x0000000000000000000000000000000000000000000000015af1d78b58c40000 dec` or `cast --to-dec 0x0000000000000000000000000000000000000000000000015af1d78b58c40000`

`cast --to-dec`:
    - Converts hexadecimal (base 16) to decimal (base 10)
    - Commonly used for converting blockchain data to readable numbers
    Example:
```js
cast --to-dec 0x0000000000000000000000000000000000000000000000015af1d78b58c40000
25000000000000000000
```

`cast --to-base <hex-data> dec`:
Converts from one base to another
    - The "dec" parameter specifies conversion to decimal (base 10)
    - More flexible than --to-dec as it can convert between different bases
    Example:
```js
    # Convert hex to decimal (same as --to-dec)
$ cast --to-base 0xff dec
255

# Can also convert to other bases like binary (2) or octal (8)
$ cast --to-base 0xff bin  # to binary
11111111
```

### CAST SIG NOTES

When interacting with a contract on the internet from metamask, metamask will prompt you with a confirm transaction. In this confirm window on metamask, it will tell you what function you are calling at the top of the window and there will be a `HEX DATA: 4 BYTES` section at the bottom of the window that has the function selector hex data of the function you are calling.

In your terminal, if you run `cast sig "<function-Name>()" ` and it will return the hex data so we can make sure it is the same hex data as the function we are calling in our transaction to make sure it is calling the correct function and we are not getting scammed.
Example:
```js
/* (Command): */ cast sig "createSubscription()"
/* (Terminal returns): */ 0xa21a23e4
```

Sometimes you will not know what the function's hex is. But there are function signature databases that we can use (like `openChain.xyz` and we go to signature database). If you paste in the function selector/ hex data and press search, it has a database of different hashes/hex data and the name of the function associated with it. So this way we can see what hex data is associated with what functions. These databases only work if someone actually updates them. Foundry has a way to automatically update these databases (Check foundry docs).



### cast --calldata-decode Notes

When doing a transaction on a websites frontend, metamask pops up with three tabs, "DETAILS", "DATA", and "HEX". if you click on the hex and scroll down, you will see the hex data. This encoded hex-data is information from the transaction, and to see exactly what this transaction is doing, we can use `cast --calldata-decode` to decode this bytecode.

You would use this in the following format:
Run `cast --calldata-decode <"function signature"> <encoded hex-data-from-metamask>`

example:
`cast --calldata-decode "transferFrom(address,address,uint256)" 0x12345678909876543211234567890987654321`

This will return what values are being passed in this transaction for the parameters.


### cast wallet sign Notes

`cast wallet sign` is a Foundry command that creates digital signatures. Here's a general explanation:
Think of cast wallet sign like a digital version of signing a physical document:
`cast wallet sign <message> --private-key <your-private-key>` for anvil
`cast wallet sign <message> --account <account-Name> --sender <account-public-address> ` for testnet/mainnet

What it does:
1. Takes a message (usually a hash) that you want to sign
2. Uses your private key (like your unique signing ability)
3. Produces a cryptographic signature that:
    - Proves YOU signed this specific message
    - Can be verified by anyone, but only created by you
    - Cannot be forged without your private key
    - Cannot be reused for other messages

Common flags:
`--no-hash` : Sign the exact message bytes (without hashing first).
example: `cast wallet sign --no-hash <message> --account <account-Name> --sender <account-public-address>`

Real-world analogy:
    - Message = The document you're signing
    - Private key = Your ability to sign
    - Signature = Your actual signature
    - Anyone can verify your signature (public), but only you can create it (private)

This is commonly used in blockchain for:
    - Proving ownership of an address
    - Authorizing transactions
    - Signing messages off-chain
    - Creating meta-transactions
The signature can later be verified on-chain using functions like `ECDSA.recover()` to prove that the owner of a specific address authorized something.




### How to be safe when interacting with contracts

1. Check the address (read the function) - can be read on etherscan
2. Check the function selector - check section `Function Selector & Function Signature Notes` & `cast sig notes`
3. Decode the calldata (check the paramters) - check section `cast --calldata-decode Notes` 

It is important to check the contracts, functions, and parameters being sent when interacting with external contract with frontend wallets or backend to make sure we are being safe and not being scammed in any way. This is especially important when working with real money and large amounts of money 




------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## TIPS AND TRICKS

run `forge inspect <contract-Name> methods` to see all the function names and its corresponding function selector. Example: `forge inspect DSCEngine methods` 

run `forge fmt` to auto format your code. If you run `forge fmt` and it is not formatting the way you want, then go to you solidity extension (should be Nomic Foundation's Solidity), click settings, extension settings, and toggle the solidity formatter setting between prettier & forge to set the one you like more. Then when you save your code or run `forge fmt` it should format correctly.

run `forge coverage` to see how many lines of code have been tested.

run `forge snapshot --mt <test-function-name>` to create a `.gas-snapshot` file to tell us exactly how much gas a test function uses. you could also run `forge snapshot` and it will create a `.gas-snapshot` file to tell us exactly how much gas each function in the contracts cost.

run `forge inspect <Contract-Name> storagelayout` and it will tell you the exact layout of storage that your contract has.

run `cast storage <contract-address> <index-of-storage>` and it will tell you exactly what is in that storage slot. For example: `cast storage 0x12345..88 2`. (mapping and arrays take up a storage slot but they are blank because they are dynamic and can change lengths). if you dont add an index number than it will tell you the whole storage layout of the contract from etherscan (make sure you are connected to etherscan if you want this!).


Reading and writing from storage is 33x more expensive than reading and writing from memory. Try to keep reading and writing to memory at a minimum by reading and writing to memory instead.
For example:
```javascript
  function cheaperWithdraw() public onlyOwner {
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) { // this is repeatedly reading from storage and will cost a ton, Especially as the array gets longer.
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, ) =
            payable(msg.sender).call{value: address(this).balance}(""); 
        require(callSuccess, "Call Failed");
    }
```

```javascript
  function cheaperWithdraw() public onlyOwner {
        uint256 funderLength = s_funders.length; // this way we are only reading from the storage array `funders` one time and saving it as a memory variable
        for (uint256 funderIndex = 0; funderIndex < funderLength; funderIndex++) { // then here we loop through the memory instead of the storage
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, ) =
            payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call Failed");
    }
```

If you want to quickly compile or console.log a contract to see if something works, you can run `forge script script/<file-Name>`.
exmaple (from foundry-nft-f23):
```js
contract DeployMoodNft is Script {
    function run() external returns (MoodNft) {
        string memory sadSvg = vm.readFile("./img/sad.svg");
        string memory happySvg = vm.readFile("./img/happy.svg");
        console.log(sadSvg);
    }
```
In this example i wanted to make sure vm.readFile was working correctly so i just compiled the contract onto anvil with `forge script script/<file-Name>` (since this will just spin up a fake anvil blockchain).


How to make all the text be on one line? 
Open the command pallete with `ctrl + shift + p ` and search for `join lines`. If word wrap is still on then search for `view toggle word wrap` or `toggle word wrap`




------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## ChainLink Notes

### Chainlink Functions Notes
Chainlink functions allow you to make any API call in a decentralized context through decentralized nodes. Chainlink functions will be the future of DeFi and smart contracts. If you want to make something novel and something that has never been done before, you should check out chainlink functions. You can learn more about chainlink functions at `docs.chain.link/chainlink-functions`.

### Aggregator PriceFeeds Notes
Smart Contracts by themselves cannot access data outside of their own contracts. They cannot tell what the price of tokens are, what day it is, or who the president is. This is where chainlink datafeeds come in. Chainlink datafeeds take in data from many decentralized sources and their decentralized chainlink nodes decide what data is true based off their many decentralized sources. This is what is known as an oracle. You can learn more about chainlink datafeeds in the chaink docs at `docs.chain.link` or at `https://updraft.cyfrin.io/courses/solidity/fund-me/real-world-price-data`.

Pricefeeds are a type of datafeed from chainlink. You can see examples at data.chain.link. To use pricefeeds, you will need the address of the pricefeed and the interface of the AggregatorV3Interface.

To get the address of the PriceFeed, go to `https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1`, click on the chain you are looking to get data from, then scroll down to the contract pair that you want to get the price of and copy that address.

To use the interface of the AggregatorV3Interface, run `forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit` in your terminal. Then in your `foundry.toml` create/add a remapping of ` remappings = ["@chainlink/contracts/=lib/chainlink-brownie-contracts/contracts/"] `

If you need the interface of the AggregatorV3Interface from github for any reason, you can go to `https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol` - (this link may change, if so, the AggregatorV3Interface will still be in the smartcontractkit/chainlink github, but under a different file. If you cannot find it, then you can find the correct link in `https://github.com/Cyfrin/foundry-full-course-cu?tab=readme-ov-file#solidity-101-section-1-simple-storage` in Solidity 101 Section 3: Remix Fund Me, under `Interfaces`. The link should say something like `For reference - ChainLink Interface's Repo` and the link will be here.)

To find out how many decimals a token pricefeed has, you can go to the pricefeed addresses of the chainlink docs and click `show more details` and it will have a tab named `Dec`, which stands for decimals.


Once you import the AggregatorV3Interface, you can pass the pricefeed address into the AggregatorV3Interface and it will return any data that you want from the AggregatorV3Interface interface. 

AggregatorV3Interface at the time of this writing:
```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

```

So for example, if you want to get the version of the pricefeed, you would call the function within the AggregatorV3Interface in one of your own functions in your contract. Example:
```js
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract FundMe {
// to attach the Price Converter functions to all uint256s:
    using PriceConverter for uint256;

// this variable is of type AggregatorV3Interface, and is used in the constructor. So that when deployed, the contract will read what chain we are on and use the correct pricefeed.
    AggregatorV3Interface private s_priceFeed;

     // the constructor is a function that gets immediately called when the contract is deployed.
    // the priceFeed parameter means that it takes a pricefeed address, and this will depend on the chain we are deploying to. This way the codebase is much more modular.
    constructor(address priceFeed) {
        // this pricefeed address is set in the deployment script input!
        // makes the deployer of this contract the "owner" of this contract.
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

  function getVersion() public view returns (uint256) {
        // this works because the address defined is correlated the functions "AggregatorV3Interface" and "version". We also imported the "AggregatorV3Interface" from chainlink.
        // return AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306).version();
        // ^ we refactored this code because it was hardcoded to sepolia, to make it more modular, we change it to (below): ^
        return s_priceFeed.version();
        // ^this is more modular because now it will get the address of the pricefeed dependant on the chain we deployed to. ^
    }
}
```

If for any reason you get stuck, watch the video Cyfrin Updraft, Course: Foundry Fundamentals, Section 2: Foundry Fund Me.


example (The following 4 snippets are from foundry-fund-me-f23):
create a library that uses the AggregatorV3Interface from chainlink: 
```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    // libraries cannot have any state variables. State Variables are variables declared on the contract level.
    //  this function will get the price of the naive blockchain token(in this case its eth) in terms of USD
    function getPrice(AggregatorV3Interface dataFeed) internal view returns (uint256) {
        // to reach out to this contract, we need the Address and the ABI
        // address: 0x694AA1769357215DE4FAC081bf1f309aDC325306 ✅ (This is the address of the ETH/USD datafeed from chainlink)
        // ABI: Chainlink's AggregatorV3Interface ✅(the interface acts like an ABI). when we combine a contracr address with the interface, we can easily call the functions in that contract
        // the formating of this code comes from the docs of chainlink which can be found at https://docs.chain.link/data-feeds/using-data-feeds
        // the formating of this code comes from the docs of chainlink which can be found at https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol
        (, int256 answer,,,) = dataFeed.latestRoundData();
        // ^ because we dont need the other items, we can just remove them and keep the commas.
        // this will return the price of ETH in terms of USD
        // so if the value is $3k, it will show as 300000000000 (8decimals).
        return uint256(answer * 1e10);
        // ^ we multiply this by 1e10 to get 18 decimals instead of 8!
        // ^^ we typecast this with uint256 because the answer returned is in int and we need it in uint. This is because int can be negative and this can lead to bugs. Uint can never be negative. Also, we typecasted because our msg.value is type uint and answer is type int, so we need to convert it.
        // to typecast means we did that uint256() around the answer * 1e10 to convert it to a different type.
    }

    // this function will convert the msg.value price(in the fund function) of eth into USD
    function getConversionRate(uint256 ethAmount, AggregatorV3Interface dataFeed) internal view returns (uint256) {
        uint256 ethPrice = getPrice(dataFeed);
        // we divide this by 1e18 because both eth price and ethAmount have 18 zeros, so the outcome would be 36 zeros if we dont divide.
        // you always want to multiply before you divide.
        // the user inputs in ethAmount
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;
        return ethAmountInUsd;
    }
}

```

Use the library in the main contract to get price of assets:
```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


error FundMe__NotOwner(); // custom errors save a ton of gas

contract FundMe {
    // to attach the Price Converter functions to all uint256s:
    using PriceConverter for uint256;

    // uint256 public minimumUsd = 5 * (10 ** 18); // you can do this
    uint256 public constant MINIMUM_USD = 5e18; // this is the same as above. 

    // an array of addresses called funders.
    address[] private s_funders;

    // a mapping, mapping the addresses and their amount funded.
    // the names "funder" and "amountFunded" is "syntaxic sugar", just makes it easier to read
    mapping(address funder => uint256 amountFunded) private s_addressToAmountFunded;

    // to be used in constructor
    address private immutable i_owner; // variables declared in the contract level but defined in the constructor, can be marked as immutable if they will not change. This will save gas
    // immutable varibles should use "i_" in their name

    // this variable is of type AggregatorV3Interface, and is used in the constructor. So that when deployed, the contract will read what chain we are on and use the correct pricefeed.
    AggregatorV3Interface private s_priceFeed;

    // the constructor is a function that gets immediately called when the contract is deployed.
    // the priceFeed parameter means that it takes a pricefeed address, and this will depend on the chain we are deploying to. This way the codebase is much more modular.
    constructor(address priceFeed) {
        // this pricefeed address is set in the deployment script input!
        // makes the deployer of this contract the "owner" of this contract.
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    // the "payable" keyword is allows functions to be sent $ from users
    function fund() public payable {
        // Allow users to send $
        // Have a minimum $ sent
        // 1e18 is equal to 1 ETH(which is also 1,000,000,000,000,000,000 wei(18-zeros)(which is also 1 * 10 ** 18(in solidity,  ** means exponent)))
        // require means if <first section> is false, then revert with the message of <second section>
        // because we are using the PriceConverter for all uint256, all uint256s now have access to getConversionRate. This way, when we write "msg.value.getConversionRate", the first value will be the first parameter, which is msg.value. So msg.value is ethAmount in the getConversionRate function. If we had a second parameter in the getConversaionRate, the second paramter would be whatever input would be passed into msg.value.getConversionRate() (in this case there is no second value).
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "didn't send enough ETH"); // "didn't send enough ETH" is the revert message if it reverts if the user does not send more than 1 eth.
        // msg.value is always in terms of ETH/wei
        // if the require statement fails, then all actions or code that have been executed in that function will revert as well.
        // if you send a failed transaction, you will still spend all as up to that failed transaction, if any remaining gas will be returned to the user.

        // this line keeps track of how much each sender has sent
        // you read it like: mapping(check the mapping) address => amount sent of the sender. So how much the sender sent = how much the sender has sent plus how much he is currently sending.
        // addressToAmountFunded[msg.sender] = addressToAmountFunded[msg.sender] + msg.value;
        //above is the old way. below is the shortcut with += . This += means we are adding the new value to the existing value that already exists.
        s_addressToAmountFunded[msg.sender] += msg.value;

        // the users whom successfully call this function will be added to the array.
        s_funders.push(msg.sender);
    }

    // we are making a cheaper Withdraw function because function `withdraw` is very expensive. When you read and write to storage it is very expensive. Whereas if you read and write to memory it is much much cheaper. Check evm.codes(website) to see how much each opcode cost in gas.
    function cheaperWithdraw() public onlyOwner {
        uint256 funderLength = s_funders.length; // this way we are only reading from the storage array `funders` one time and saving it as a memory variable
        for (uint256 funderIndex = 0; funderIndex < funderLength; funderIndex++) {
            // then here we loop through the memory instead of the storage
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, /* bytes memory dataReturned */ ) =
            payable(msg.sender).call{value: address(this).balance}(""); /*<- this is where we would put info of another function if we were calling another function(but we arent here so we leave it blank) */
        require(callSuccess, "Call Failed");
    }

    function withdraw() public onlyOwner {
        // for loop explanation:
        // [1, 2, 3, 4] elements   <-- below
        //  0, 1, 2, 3  indexes    <- so we would loop through the indexes to get all the elements out of this array

        // in a for loop, you first give it the starting index, then the ending index, and then the step amount
        // for example, if you want to go start at the 0th index, end at the 10th index, and increase by 1 every time, then it would be for (uint256 i = 0; i <= 10; i++)
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; /* length of the funders array */ funderIndex++) {
            /*++ means to add 1 after everytime we go through the following code in the brackets: */
            // we get the index position of the funders array, name this element funder
            address funder = s_funders[funderIndex];
            // then we reset this funders amount(this is tracked by the mapping of "addressToAmountFunded") to 0 when he withdraws
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);

        // there are three ways to transfer the funds: transfer, send, and call

        // msg.sender is of type address
        // payable(msg.sender) is of type payable address

        // transfers balance from this contract's balance to the msg.sender
        // payable(msg.sender).transfer(address(this).balance); //  this is how you use transfer
        // ^there is an issue with using transfer, as if it uses more than 2,300 gas it will throw and error and revert. (sending tokens from one wallet to another is already 2,100 gas)

        // we need to use "bool" here because when using "send", if the call fails, it will not revert the transaction and the user would not get their money. ("send" also fails at 2,300 gas)
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require sendSuccess to be true or it reverts with "Send Failed"
        // require(sendSuccess, "Send failed");

        // using "call" is lower level solidity and is very powerful, is the best one to use most of the time.
        // "call" can be used to call almost every function in all of ethereum without having an ABI!
        // using "call" returns a boolean and bytes data. The bytes arent important here so we commented it out and left the comma. (but really we would delete it if this was a production contract and we would leave the comma. however if we were calling a function we would keep the bytes data) (bytes objects are arrays which is why we use the memory keyword).
        (bool callSuccess, /* bytes memory dataReturned */ ) = payable(msg.sender).call{value: address(this).balance}(
            "" /*<- this is where we would put info of another function if we were calling another function(but we arent here so we leave it blank) */
        );
        //        calls the value to send to the payable(msg.sender)^

        // require callSuccess to be true or it reverts with "Call Failed"
        require(callSuccess, "Call Failed");
    }

    function getVersion() public view returns (uint256) {
        // this works because the address defined is correlated the functions "AggregatorV3Interface" and "version". We also imported the "AggregatorV3Interface" from chainlink.
        // return AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306).version();
        // ^ we refactored this code because it was hardcoded to sepolia, to make it more modular, we change it to (below): ^
        return s_priceFeed.version();
        // ^this is more modular because now it will get the address of the pricefeed dependant on the chain we deployed to. ^
    }

    function getDecimals() public view returns (uint8) {
        return AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306).decimals();
    }

    modifier onlyOwner() {
        // requires the owner to be the only person allowed to call this withdraw function or reverts with "Must be Owner!"
        // require(msg.sender == i_owner, "Must be Owner!");

        // changed to use custom errors to save a ton of gas since. This saves alot of gas since we do not need to store and emit the revert Strings if the require statement fails.
        // this says that if the sender of the message is not the owner, then revert with custom error NotOwner.
        if (msg.sender != i_owner) {
            revert FundMe__NotOwner();
        }

        // always needs to be in the modifier because modifiers are executed first in functions, then this underscore shows that after the modifier code is executed, to then go on and execute the code in the fucntion with the modifier.
        _;
        // if we had the underscore above the logic in this modifier, this means that we would execute the logic in the function with this modifier first and then execute the modifier's logic. So the order of the underscore matters!!!
    }

    // receive function is called when a transaction is sent to a contract that has no data. it can have not not have funds, but if it has no data, it will be received by the receive function. (the contract needs to have a receive function)
    receive() external payable {
        fund();
    }

    // fallback function is called when a transaction is sent to a contract with data, for example like if a user calls a function that does not exist, then it will be handled by the fallback function. (the contract needs to have a fallback function). the fallback function can also be used if the receive function is not defined.
    fallback() external payable {
        fund();
    }

    // Note: view functions use gas when called by a contract but not when called by a person.

    // if something is "unchecked", then that means when a value hits its max + 1, it will reset to 0.
    // after 0.8.0 of solidity, if a number reaches its max, the number will then fail instead of reseting. instead of overflowing or underflowing, it just fails.

    /**
     * View / Pure Functions (These are going to be our Getters)
     * Below are our Getter functions. by making storage variables private, they save more gas. Then by making view/pure functions to get the data within the private storage functions, it also makes the code much more readable.
     * These are called getter functions because all they do is read and return private data from the contracts storage without modifying the contract state.
     */

    // This function allows anyone to check how much eth a specific address has funded to the contract.
    function getAddressToAmountFunded(address fundingAddress) external view returns (uint256) {
        // takes the fundingAddress parameter that users input and reads and returns the amount that that address has funded. It is accessing the mapping of s_addressToAmountFunded which stores the funding history.
        return s_addressToAmountFunded[fundingAddress];
    }

    //this function allows anyone to input a number(index) and they will see whos address is at that index(number).
    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}

```

Have an `HelperConfig.s.sol` file that grabs the correct address of the pricefeed dependent on the chain we are deploying to:
```js
// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/* this contract will do the following:
1. Deploy mocks when we are on a local Anvil Chain
2. Keep track of contract addresses across different chains
*/

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    // If we are on a local anvil, we deploy mocks.
    // Otherwise, grab the existing address from the live network.

    // we are declaring a variable named activeNetworkConfig of type struct NetworkConfig to use
    NetworkConfig public activeNetworkConfig;

    // to reduce magic numbers we defined these. these are the decimal count and start price of ETH/USD in the mockV3Aggregator.
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;

    // the items inside the FundMe.sol constructor
    struct NetworkConfig {
        address priceFeed; // ETH/USD pricefeed address
    }

    constructor() {
        // every blockchain has a chainId. The `block.chainid` is a key word from solidity.
        // this is saying "if we the chain we are on has a chainId of 11155111, then use `getSepoliaEthConfig()` (this getSepoliaEthConfig function returns the pricefeed address to use)"
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            // this is saying "if we the chain we are on has a chainId of 1, then use `getMainnetEthConfig()` (this getMainnetEthConfig function returns the pricefeed address to use)"
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            // if the chain is not 11155111, then use `getAnvilEthConfig()` (the getAnvilEthConfig function uses a mock to simulate the pricefeed since its a fake temporary empty blockchain and does not have chainlink pricefeeds)
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        // we want to get the price feed address.
        // but what if we want more than just one variable? We create a struct (so we made struct NetworkConfig)!

        // this grabs the pricefeed address that we hardcoded and saves it to a variable named sepoliaConfig
        NetworkConfig memory sepoliaConfig = NetworkConfig({priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306});
        // returns the variable sepoliaConfig when this function is called.
        return sepoliaConfig; //  This returns the pricefeed address saved in the variable gets passed to the deployment script to let it know what the address it to pull data from the address.
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        // we want to get the price feed address.
        // but what if we want more than just one variable? We create a struct (so we made struct NetworkConfig)!

        // this grabs the pricefeed address that we hardcoded and saves it to a variable named sepoliaConfig
        NetworkConfig memory ethConfig = NetworkConfig({priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419});
        // returns the variable sepoliaConfig when this function is called.
        return ethConfig; //  This returns the pricefeed address saved in the variable gets passed to the deployment script to let it know what the address it to pull data from the address.
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // we want to get the price feed address, but this is anvils local blockchain, that does not have pricefeeds.
        // so we need to deploy mocks onto the local blockchain(anvil) to simulate pricefeeds.

        // 1. Deploy Mocks
        // 2. Return the Mock addresses

        // this if statement is saying that if we already have deployed a mockV3Aggregator, to use that one instead of deploying a new one everytime.
        // if it is not address 0 then this means we already deployed it and it has an address, otherwise it would be 0 if it didnt exist.
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        } // we do not need an "else" clause here because once a return statement in a function is executed, the function immediately exits and no further code in that function will run.

        // everything inbetween the startBroadcast is being broadcasted to the blockchain. So here we are deploying the mock to anvil.
        vm.startBroadcast();
        // this says to deploy a new MockV3Aggregator and save it in a variable of MockV3Aggregator named mockPriceFeed.
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        // ^ we passed `8` and `2000e8` as parameters because the MockV3Aggregator's constructor asks for decimals and inital price. So here we are saying that the pair price feed that we are mocking(eth/usd) has 8 decimals and the starting price is 2000 with 8 decimals(2000e8). ^
        vm.stopBroadcast();

        // grabs the address of the mock pricefeed (within the struct we declared) and saves it as variable of type struct NetworkConfig named anvilConfig
        NetworkConfig memory anvilConfig = NetworkConfig({priceFeed: address(mockPriceFeed)});
        // returns this variable anvilConfig when this function is called. This returns the pricefeed address saved in the variable gets passed to the deployment script to let it know what the address it to pull data from the address.
        return anvilConfig;
    }
}

```

Have a deployment script that sets the correct pricefeed address dependent on the chain we are on(works with HelperConfig.s.sol):
```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

// we must import Script.sol to tell foundry that this is a script.
import {Script} from "forge-std/Script.sol"; // we need to import the script package from foundry when working on scripts in foundry/solidity.
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// this script will deploy our smart contracts. we should always deploy smart contracts this way.
// Script contracts always need to inherit from scripts
contract DeployFundMe is Script {
    // all deployments scripts need to have this "run" function because this will be the main function called when deploying the contract.
    function run() external returns (FundMe) {
        // this says that when we start this `run` function, it will create a new helperconfig of type HelperConfig contract.
        HelperConfig helperConfig = new HelperConfig();
        // because we send this before `vm.startBroadcast`, it is executing this code in a simulated environment. So it is grabbing the chainId that we are deploying to right before we deploy the contracts

        // we get the activeNetwork's pricefeed address and save it as a variable called "ethUsdPriceFeed"
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();
        // `activeNetworkConfig` is a variable of type struct, so if we had more variables in the struct, depending on what we would want we should save it as (address ethUsdPriceFeed, address exampleAddress, , ,)

        // "vm.startBroadcast" is a cheatcode from foundry. it tells foundry "everything after this line should be sent to the rpc"
        vm.startBroadcast();
        // this line says variable name "fundMe" of type contract FundMe is equal to a new FundMe contract that is now being created and the broadcast line deploys it.
        // FundMe fundMe = new FundMe(); // this line throws a warning since we do not use the variable fundMe
        // new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306); // this also creates a new FundMe contract

        // we use this because now it will be more modular. All we do is now change this address and it will update our entire codebase.
        FundMe fundMe = new FundMe(ethUsdPriceFeed); // this address gets inputted into the FundMe constructor.
        vm.stopBroadcast();
        return fundMe; // because this returns the deployed fundMe contract, we can make changes and it will always return the change we made. making the testing easier and more modular.
    }
}

```

Note: As advanced as Chainlink oracles are, Chainlink is a system just like any other system. Sometimes systems can go down. So we need to add checks to make sure everything is working properly.

What we want to do is to make sure that the prices from Chainlink's datafeeds are not stale. If you go to chainlinks pricefeed address page and select `show more details`, it will reveal a tab named `Heartbeat` ( https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1 ). This `Heartbeat` tab shows how often in seconds a the price should be updated. 

So we want to write checks in our system to make sure that the price is indeed updating every x amount of seconds as chainlink says, and if it is not, we should pause the functionality of our contracts.

To do this, we can create a library to check the Chainlink Oracle for stale data:
(this library would go in src/libraries/OracleLib.sol)
```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/* 
 * @title OracleLib
 * @author Squilliam
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, the function will revert and render the DSCEngine unusable - this is by design
 * We want the DSCEngine to freeze if prices becomes stale.
 * 
 * So if the Chainlink network explodes and you have a lot of money locked in the protocol... a pause will begin in order to protect users funds
 */
library OracleLib {
    // Custom error for when price data is considered stale
    error OracleLib__StalePrice();

    // `hours` is a solidity keyword, means 3 * 60 * 60 = 10800 seconds
    uint256 private constant TIMEOUT = 3 hours;

    /**
     * @notice Checks if the latest price data from Chainlink is fresh (not stale)
     * @param priceFeed The Chainlink price feed to check
     * @return A tuple containing the round data from Chainlink:
     *         - roundId: The round ID of the price data
     *         - answer: The price value
     *         - startedAt: Timestamp when the round started
     *         - updatedAt: Timestamp when the round was last updated
     *         - answeredInRound: The round ID in which the answer was computed
     */
    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (
            // returns the same return value of the latest round data function in an aggregator v3
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        // Get the latest round data from the Chainlink price feed
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        // Calculate how many seconds have passed since the last update
        uint256 secondsSince = block.timestamp - updatedAt;

        // If more time has passed than our TIMEOUT, consider the price stale and revert
        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }

        // If price is fresh, return all the round data
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
```

Then in our main contracts, we use this OracleLib library as a type:
```js
contract DSCEngine is ReentrancyGuard {
    // ..skipped code
    using OracleLib for AggregatorV3Interface;
    // ..skipped code
}
```



### Chainlink VRF 2.5 Notes
Help: https://updraft.cyfrin.io/courses/foundry/smart-contract-lottery/implementing-chainlink-vrf

The Chainlink VRF(Verifiable Random Function) is a way to generate a random number. Currently, chainlink has 2 ways of using this VRF, the `V2 Subscription Method` and `V2 Direct Funding Method`. The better option to use is `V2 Subscription Method` because it is much more scable. 
`V2 Subscription Method`: Fund the subscription and apply that to as many raffles/contracts/items as we want.
`V2 Direct Funding Method`: Everytime we deploy a new raffle/contract/item we would have to refund it. 

This section will be covering the ``V2 Subscription Method`` as it is better.

Getting a Random Number through Chainlink VRF is a 2-step process.
1. Request RNG (Random Number Generator) - We call the request in a transaction that we send
2. Get RNG (Random Number Generated) - Then the chainlink node is going to give us the random number in a transaction that it sends. It sends it in the callback function(a function that chainlink VRF calls back to.) 

Steps:
1. In the link `https://docs.chain.link/vrf/v2-5/getting-started` you will find a `Open in Remix Button`, click that to see the full code.
2. In `function rollDice` we can see the function calling Chainlink VRF for the RNG.
```javascript
  function rollDice(
        address roller
    ) public onlyOwner returns (uint256 requestId) {
        require(s_results[roller] == 0, "Already rolled");
        // Will revert if subscription is not set and funded.
        // this is the section we want, copy from here ->
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        ); // <- this is the section we want, copy to here

        s_rollers[requestId] = roller;
        s_results[roller] = ROLL_IN_PROGRESS;
        emit DiceRolled(requestId, roller);
    }
```
3. Copy and Paste this section(step 2) that we want into your code where you want to get a random number. Also copy the beginning of `function fulfillRandomWords`.
```js
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {}
```

4. This code will not work at first.  we need to import the chainlink contracts. Run `forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit`.
5. In the Remix Example, copy and paste the `VRFConsumerBaseV2Plus` import.
```javascript
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol"; // remove the version number from the import. Originally it has a @1.1.1 but thats only for remix
```
6. In the `foundry.toml` of your project, put an remapping in of:
```js
remappings = ['@chainlink/contracts/=lib/chainlink-brownie-contracts/contracts']
```
7. Make sure your contract inherits from the import:
```js
contract Raffle is VRFConsumerBaseV2Plus {}
```
8. Update your constructor to inherit from Chainlink's VRF constructor.
Example:

Before Inheritance:
```js
contract Raffle {

    uint256 private immutable i_entranceFee; 
    uint256 private immutable i_interval;

    uint256 private s_lastTimeStamp;

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }
}

```


Chainlink VRF V2.5's constructor:
```js
abstract contract VRFConsumerBaseV2Plus is IVRFMigratableConsumerV2Plus, ConfirmedOwner {
  error OnlyCoordinatorCanFulfill(address have, address want);
  error OnlyOwnerOrCoordinator(address have, address owner, address coordinator);
  error ZeroAddress();

  // s_vrfCoordinator should be used by consumers to make requests to vrfCoordinator
  // so that coordinator reference is updated after migration
  IVRFCoordinatorV2Plus public s_vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) ConfirmedOwner(msg.sender) {
    if (_vrfCoordinator == address(0)) {
      revert ZeroAddress();
    }
    s_vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
  }
```

After Child Contract Inherits:
```js
contract Raffle is VRFConsumerBaseV2Plus {
     uint256 private immutable i_entranceFee; 
    uint256 private immutable i_interval;

    uint256 private s_lastTimeStamp;

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator) 
    // `VRFConsumerBaseV2Plus` is the name of the contract we are inheriting from
    VRFConsumerBaseV2Plus(vrfCoordinator) // here we are going to define the vrfCoordinator address during this contracts deployment, and this will pass the address to the VRFConsumerBaseV2Plus constructor.
    
    {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }
}

```

9. Import `VRFV2PlusClient` into your file as this is a file that the VRF needs. (import but do NOT inherit)
```js
import {VRFV2PlusClient} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
```

10. After doing everything above. we need to fill out the data in the pasted section that we copied from chainlink in step 2/3. You can read the comments here or read from the Chainlink docs to find out what the variables in example function `pickWinner` do. (https://docs.chain.link/vrf/v2-5/getting-started)
```js
contract Raffle is VRFConsumerBaseV2Plus {

// this is a uint16 because it will be a very small number and will never change.
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // // how many blocks the VRF should wait before sending us the random number

    uint32 private constant NUM_WORDS = 1; // the number of random numbers that we want

    // this is being declared to identify its type of uint256. this will be how much it costs to enter the raffle. it is being initialized in the constructor and will be set when the contract is deployed through the deployment script.
    uint256 private immutable i_entranceFee; // we made this private to save gas. because it is private we need a getter function for it

    // this variable is declared to set the interval of how long each raffle will be. it is being initialized in the constructor and will be set when the contract is deployed through the deployment script.
    // @dev the duration of the lottery in seconds.
    uint256 private immutable i_interval;
    // the amount of gas we are willing to send for the chainlink VRF
    bytes32 private immutable i_keyHash;
    // kinda linke the serial number for the request to Chainlink VRF
    uint256 private immutable i_subscriptionId;
    // Max amount of gas you are willing to spend when the VRF sends the RNG back to you
    uint32 private immutable i_callbackGasLimit;

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        // entranceFee gets set in the deployment script(when the contract is being deployed).
        i_entranceFee = entranceFee;
        // interval gets set in the deployment script(when the contract is being deployed).
        i_interval = interval;
        // sets the s_lastTimeStamp variable to the current block.timestamp when deployed.
        s_lastTimeStamp = block.timestamp;
        // keyHash to chainlink means the amount of max gas we are willing to pay. So we named it gasLane because we like gasLane as the name more
        i_keyHash = gasLane;
        // sets i_subscriptionId equal to the one set at deployment
        i_subscriptionId = subscriptionId;

        // Max amount of gas you are willing to spend when the VRF sends the RNG back to you
        i_callbackGasLimit = callbackGasLimit;
    }

    function pickWinner() external {
        // this checks to see if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        // calling to Chainlink VRF to get a randomNumber
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash, // how much gas you are willing to pay
                subId: i_subscriptionId, // kinda of like a serial number for the request
                requestConfirmations: REQUEST_CONFIRMATIONS, // how many blocks the VRF should wait before sending us the random number
                callbackGasLimit: i_callbackGasLimit, // Max amount of gas you are willing to spend when the VRF sends the RNG back to you
                numWords: NUM_WORDS, // the number of random numbers that we want
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {}
}
```

11. After you have done all the steps above, you need to get a subscription ID. This way only you will have access to your subscription ID and no one else can use it.

To do this you need to Create the Subscription, Fund the subscription, then add a consumer.

Creating the Subscription:
example (from: `foundry-smart-contract-lottery-f23/Interactions.s.sol`):
```js 
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

// to use chainLink VRF, we need to create a subscription so that we are the only ones that can call our vrf.
// this is how you do it programically.

// we made this interactions file because it makes our codebase more modular and if we want to create more subscriptions in the future, we can do it right from the command line

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        // deploys a new helperConfig contract so we can interact with it
        HelperConfig helperConfig = new HelperConfig();
        // calls `getConfig` function from HelperConfig contract, this returns the networkConfigs struct, by but doing `getConfig().vrfCoordinator` it only grabs the vrfCoordinator from the struct. Then we save it as a variable named vrfCoordinator in this contract
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        // runs the createSubscription with the `vrfCoordinator` that we just saved as the parameter address and saves the return values of subId.
        (uint256 subId,) = createSubscription(vrfCoordinator);

        return (subId, vrfCoordinator);
    }

    // created another function so that it can be even more modular
    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        console.log("Creating Subscription on chain Id:", block.chainid);
        // everything between startBroadcast and stopBroadcast will be broadcasted to the blockchain.
        vm.startBroadcast();
        // VRFCoordinatorV2_5Mock inherits from SubscriptionAPI.sol where the createSubscription lives
        // calls the VRFCoordinatorV2_5Mock contract with the vrfCoordinator as the input parameter and calls the createSubscription function within the VRFCoordinatorV2_5Mock contract.
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscription Id in your HelperConfig.s.sol");

        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}
```

Funding the Subscription:
example (from `foundry-smart-contract-lottery-f23/Interactions.s.sol`):
```js
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";


contract FundSubscription is Script, CodeConstants {
    // this says ether, but it really is (chain)LINK, since there are 18 decimals in the (CHAIN)LINK token as well
    uint256 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        // deploys a new helperConfig contract so we can interact with it
        HelperConfig helperConfig = new HelperConfig();
        // calls `getConfig` function from HelperConfig contract, this returns the networkConfigs struct, by but doing `getConfig().vrfCoordinator` it only grabs the vrfCoordinator from the struct. Then we save it as a variable named vrfCoordinator in this contract
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        // in our DeployRaffle, we are updating the subscriptionId with the new subscription id we are generating. Here, we call the subscriptionId that we are updating the network configs with(in the deployment script).
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        // calls the getConfig function from helperConfig and gets the link address and saves it as a variable named linkToken
        address linkToken = helperConfig.getConfig().link;
        // runs `fundSubscription` function (below) and inputs the following parameters (we just defined these variables in this function)
        fundSubscription(vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On Chain: ", block.chainid);

        // if we are on Anvil (local fake blockchain) then deploy a mock and pass it our vrfCoordinator address
        if (block.chainid == LOCAL_CHAIN_ID) {
            // everything between startBroadcast and stopBroadcast will be broadcasted to the blockchain.
            vm.startBroadcast();
            // call the fundSubscription function with the subscriptionId and the value amount. This
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            // everything between startBroadcast and stopBroadcast will be broadcasted to the blockchain.
            vm.startBroadcast();
            // otherwise, if we are on a real blockchain call `transferAndCall` function from the link token contract and pass the vrfCoordinator address, the value amount we are funding it with and encode our subscriptionID so no one else sees it.
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}
```

Adding Consumer:
First install foundry devops with `forge install Cyfrin/foundry-devops --no-commit` (or whatever the installtion says in https://github.com/Cyfrin/foundry-devops ).

Then we need to update the `foundry.toml` file to have read permissions on the broadcast folder.
example (from `foundry-smart-contract-lottery-f23/foundry.toml`):
```js
contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        // deploys a new helperConfig contract so we can interact with it
        HelperConfig helperConfig = new HelperConfig();
        // calls for the `subscriptionId` from the networkConfigs struct that getConfig returns from the HelperConfig contract
        uint256 subId = helperConfig.getConfig().subscriptionId;
        // calls for the `vrfCoordinator` from the networkConfigs struct that getConfig returns from the HelperConfig contract
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        // calls `addConsumer` and passes the mostRecentlyDeployed, vrfCoordinator, subId as parameters. we just identified `vrfCoordinator` and `subId`. `mostRecentlyDeployed` get passed in when the run function is called.
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("To vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        // everything between startBroadcast and stopBroadcast will be broadcasted to the blockchain.
        vm.startBroadcast();
        // calls `addConsumer` from the `VRFCoordinatorV2_5Mock` and it takes the parameters of the subId and consumer (so we pass the subId and contractToAddToVrf.)
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        // calls the `get_most_recent_deployment` function from the DevOpsTools library in order to get the most recently deployed version of our Raffle smart contract.
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        // calls the `addConsumerUsingConfig` and passed the most recently deployed raffle contract as its parameter.
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
```

12. Then we need to add the CreateSubscription, FundSubscription and AddConsumer contracts and functions to our deploy script.
example (from DeployRaffle.s.sol):
```js
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        // deploy a new helpconfig contract that grabs the chainid and networkConfigs
        HelperConfig helperConfig = new HelperConfig();
        // grab the network configs of the chain we are deploying to and save them as `config`.
        // its also the same as doing ` HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid);`
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // if the subscription id does not exist, create one
        if (config.subscriptionId == 0) {
            // deploys a new CreateSubscription contract from Interactions.s.sol and save it as a variable named createSubscription
            CreateSubscription createSubscription = new CreateSubscription();
            // calls the createSubscription contract's createSubscription function and passes the vrfCoordinator from the networkConfigs dependent on the chain we are on. This will create a subscription for our vrfCoordinator. Then we save the return values of the subscriptionId and vrfCoordinator and vrfCoordinator as the subscriptionId and values in our networkConfig.
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator);

            // creates and deploys a new FundSubscription contract from the Interactions.s.sol file.
            FundSubscription fundSubscription = new FundSubscription();
            // calls the `fundSubscription` function from the FundSubscription contract we just created and pass the parameters that it takes.
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link);
        }

        // everything between startBroadcast and stopBroadcast is broadcasted to a real chain
        vm.startBroadcast();
        // create a new raffle contract with the parameters that are in the Raffle's constructor. This HAVE to be in the same order as the constructor!
        Raffle raffle = new Raffle(
            // we do `config.` before each one because our helperConfig contract grabs the correct config dependent on the chain we are deploying to
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callBackGasLimit
        );
        vm.stopBroadcast();

        // creates and deploys a new AddConsumer contract from the Interactions.s.sol file.
        AddConsumer addConsumer = new AddConsumer();
        // calls the `addConsumer` function from the `AddConsumer` contract we just created/deplyed and pass the parameters that it takes.
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId);

        // returns the new raffle and helperconfig that we just defined and deployed so that these new values can be used when this function `deployContracts` is called
        return (raffle, helperConfig);
    }
}

```

13. Finally, after we deploy the contract onto a testnet or mainnet, we need to register the new Upkeep with chainlink. To do this, go to vrf.chain.link and connect your wallet that deployed the contract. You should see that you have a new consumer added. Then switch from VRF, to automation and register a new Upkeep.

### Chainlink Automation (Custom Logic) Notes 

Chainlink Automation (formerly called Keeper Network) is a decentralized service that enables the automatic execution of smart contracts and other blockchain tasks when specific conditions are met. Think of it as a highly reliable, blockchain-native scheduling system. It can call any functions for you whenever you want.

help: `https://updraft.cyfrin.io/courses/foundry/smart-contract-lottery/chainlink-automation` & `https://updraft.cyfrin.io/courses/foundry/smart-contract-lottery/implementing-automation-2`

Steps:
1. In `https://docs.chain.link/chainlink-automation/guides/compatible-contracts` click on the "Open in Remix" button. Here you will see the the AutomationCounter example, as you can see, you need a checkUpkeep function and a performUpkeep function.

2. You will need to create a `checkUpkeep` and `performUpkeep` function. 
The `checkUpkeep` function will be called indefinitely by the chain link nodes until the Boolean in the return function of the `checkUpkeep` function returns true. Once it returns true it will trigger `performUpkeep`. The `checkUpkeep` function is the function that has all the requirements that are needed to be true in order to perform the automated task and the automated task that you want is in and performed in `performUpkeep`
Example:
```js
 /**
     * @dev this is the function that the chainlink nodes will call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time inteval has passes between raffle runs
     * 2. the lottery is open.
     * 3. The contract has ETH(has players)
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     */
    // checkData being commented out means that it is not being used anywhere in the function but it can be used if we want.
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (
            // variables defined in return function are already initialized. bool upkeepNeeded starts as false until updated otherwise.
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        // this checks to see if enough time has passed
        bool timHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        // the state of the raffle changes to open so players can join again.
        bool isOpen = s_raffleState == RaffleState.OPEN;
        // checks that this raffle contract has some money in it
        bool hasBalance = address(this).balance > 0;
        // checks there is at least 1 player
        bool hasPlayers = s_players.length > 0;
        // if all the above booleans are true, then upkeepNeeded will be set to true as well.
        upkeepNeeded = timHasPassed && isOpen && hasBalance && hasPlayers;
        // when this contract is called it will return whether or not upkeepNeeded is true or not. it will also return the performData but we are not using performData in this function so it is an empty string.
        return (upkeepNeeded, "");
    } // - chainlink nodes will call this function non-stop, and when it returns true, it will call performUpkeep.

    function performUpkeep(bytes calldata /* performData */ ) external {
        //
        (bool upkeepNeeded,) = checkUpkeep("");
        //
        if (!upkeepNeeded) {
            revert();
        }
    
        s_raffleState = RaffleState.CALCULATING;

        // the following is for calling to Chainlink VRF to get a randomNumber and has nothing to do with chainlink automation, this is just the automated task that is being performed in this example.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash, // how much gas you are willing to pay
                subId: i_subscriptionId, // kinda of like a serial number for the request
                requestConfirmations: REQUEST_CONFIRMATIONS, // how many blocks the VRF should wait before sending us the random number
                callbackGasLimit: i_callbackGasLimit, // Max amount of gas you are willing to spend when the VRF sends the RNG back to you
                numWords: NUM_WORDS, // the number of random numbers that we want
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }
```

In this example, `checkUpkeep` checking to see if all the conditionals return true then if all the conditionals return true then the return boolean in the `checkUpkeep` function declaration returns true as well. Then once the `checkUpkeep` function returns that ` bool upkeepNeeded` is true, It will perform perform upkeep. The `performUpkeep` function makes sure that the `checkUpkeep` is true, then it calls for a random number to be generated from Chainlink VRF. (The Chainlink VRF to get a randomNumber task and has nothing to do with chainlink automation, this task is just the automated task that is being performed in this example. )


3. Finally, after we deploy the contract onto a testnet or mainnet, we need to register the new Upkeep with chainlink. To do this, go to automation.chain.link and register a new Upkeep. Connect your wallet that deployed the contract, and register the new upkeep. Click "Custom Logic" since that is what we are most likely using, then click next and it will prompt you for your contracts address. Input the contract address of the contract that was just deployed tat uses the Chainlink Automation. Then click next and enter the Upkeep details, such as the contract name and starting balance (it will ask for optional items, but you do not need to fill these out.). Then just click `Register Upkeep` and confirm the transaction in your metamask.

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


## OpenZeppelin Notes

OpenZeppelin has many contracts, parent contracts, mocks and more that can help us in development. 

To use OpenZeppelin, install their package with `forge install OpenZeppelin/openzeppelin-contracts --no-commit`. 

then create a remapping in your `foundry.toml` of `remappings = ['@openzeppelin=lib/openzeppelin-contracts']` .




### OpenZeppelin ERC20 Notes

OpenZeppelin has ERC contracts that are ready to deploy and have been audited. You can find more about these in their docs. `https://docs.openzeppelin.com/contracts/5.x/tokens`.

OpenZeppelin also has a `wizard` that allows you to build a pre-selection of different tokens depending on what you want them to do: `https://docs.openzeppelin.com/contracts/5.x/wizard`


To use OpenZeppelin Contracts in your codebase do the following:
 1. run `forge install OpenZeppelin/openzeppelin-contracts --no-commit`. 
 
 2. then create remapping in your `foundry.toml` of `remappings = ['@openzeppelin=lib/openzeppelin-contracts']` .

 3. Then import the ERC you want to use and inherit the imported file.

 4. Implement the constructor used in the inherited file.

 example from foundry-erc20-f23:
 ```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OurToken is ERC20 {
    // since the ERC20 contract we inherited from has a constructor, we must implement the constructor.
    constructor(uint256 initalSupply) ERC20("OurToken", "OT") {
        // mint the msg.sender of this contract the entire initial Supply
        _mint(msg.sender, initalSupply);
    }
}
```


### OpenZeppelin NFT Notes

To learn more about NFT building and how to work with OpenZeppelin's NFT contracts, view the ` Creating NFTs ` section.

### OpenZeppelin Mocks Notes

OpenZeppelin has many mocks that can help developers with testing.

Some examples are:
    - ERC20 Mock
    - ERC1271 Wallet Mock
    - ERC2771 Context Mock
    - ERC3156 Flash Borrower Mock
    - ERC4626 Mock

and many more.

An example of using a mock is below:
```js

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "test/Mocks/MockV3Aggregator.sol";
// import the ERC20 Mock from openzeppelin
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public constant INITIAL_BALANCE = 1000e8;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        // create new ERC20Mock with the constructor params that it takes. So here we are mocking the WETH token
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, INITIAL_BALANCE);


        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        // create new ERC20Mock with the constructor params that it takes. So here we are mocking the WBTC token
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, INITIAL_BALANCE);
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}

```


### OpenZeppelin Ownable Notes

The Ownable contract by OpenZeppelin is a fundamental access control mechanism that provides a way to restrict certain functions to only be callable by an "owner" address. Here's a breakdown:



Core Functionality
1. Ownership Model:
```js
address private _owner;
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```
- Maintains a single owner address
- Emits an event whenever ownership changes

2. Constructor:
```js
constructor() {
    _transferOwnership(_msgSender());
}
```
- Sets the deployer (msg.sender) as the initial owner of the contract

3. Key Modifier:
```js
modifier onlyOwner() {
    _checkOwner();
    _;
}
```
- Used to restrict function access to only the owner
- Can be added to any function that should be owner-only


Main Functions

1. Owner Management:
```js
function owner() public view virtual returns (address)
function _checkOwner() internal view virtual
```
- owner(): Returns current owner's address
- _checkOwner(): Internal validation that caller is owner

2. Ownership Transfer:
```js
function transferOwnership(address newOwner) public virtual onlyOwner
function _transferOwnership(address newOwner) internal virtual
```
- Allows owner to transfer ownership to new address
- Includes safety check against zero address

3. Ownership Renouncement:
```js
function renounceOwnership() public virtual onlyOwner
```
- Allows owner to permanently give up ownership
- Sets owner to address(0)
- Makes owner-only functions permanently inaccessible

Common Use Cases:
Restricting administrative functions
Managing upgradeable contracts
Controlling privileged operations
Setting protocol parameters
Emergency functions (like pause/unpause)
To use Ownable in your contract, you would inherit from it like:
```js
contract MyContract is Ownable {
    function privilegedFunction() public onlyOwner {
        // Only the owner can call this
    }
}
```


Below is an example of transfering ownership of a contract(DecentralizedStableCoin.sol) to my DSCEngine.sol contract so that only the DSCEngine is the only contract that can use the mint and burn functions in my DecentralizedStableCoin.sol. Example is from foundry-defi-stablecoin-f23

We transfer the ownership in my Deployment script where i deploy both the DSCEngine.sol and the DecentralizedStableCoin.sol
```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        HelperConfig config = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        // Transferring ownership of the DSC contract to the DSCEngine contract
        // Making the DSCEngine the only contract that can mint and burn DSC tokens (because these functions are marked with onlyOwner modifier)

        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();
        return (dsc, engine);
    }
}

```

This is important because:
- It ensures that only the DSCEngine can mint/burn DSC tokens
- Users can't directly mint or burn tokens by interacting with the DSC contract
- All minting/burning must go through the DSCEngine's logic, which enforces:
- Proper collateralization ratios
- Health factor checks
- Other safety mechanisms

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


## Makefile Notes

A makefile is a way to create your own shortcuts. terminal commands in solidity can be very long, so you can essentially route your own shortcuts for terminal commands. Also, the `Makefile` needs to be `Makefile` and not `MakeFile` (the `f` needs to be lowercase) or `make` commands will not work.

If you want to include the `.env` variables, then at the top of the MakeFile, write `--include .env`. Environment Variables must be have a $ in front of it and be wrapped in parenthesis(). Example: ` $(SEPOLIA_RPC_URL) `

The way to create a short cut in a Makefile is to write the shortcut on the left, and the command that is being rerouted goes on the right in the following format:
`build:; forge build`. OR the shortcut goes on the left, and the command being rerouted goes below and indented with TAB in the format of:

```MakeFile
-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# to run, an example would be ` make deploy ARGS="--network sepolia" `
deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

# to run, an example would be ` make createSubscription ARGS="--network sepolia" `
createSubscription:
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

# to run, an example would be ` make addConsumer ARGS="--network sepolia" `
addConsumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)

# to run, an example would be ` make fundSubscription ARGS="--network sepolia" `
fundSubscription:
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)



```

Then to run a Makefile command, run `make <shortcut-name>`. Example: `make build` !!!
For example:
(the .PHONY is to tell the MakeFile that the commands are not folders)


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## Everything ZK-SYNC Notes

Zk-sync is a rollup L2.


### Zk-SYNC Foundry Notes
When deploying to ZK-sync, you want to use the zk-sync version of foundry. Learn more at https://github.com/matter-labs/foundry-zksync. learn more @ https://updraft.cyfrin.io/courses/foundry/foundry-simple-storage/foundry-zksync. this is course "Foundry Fundamentals" section 1, video #27 - #32

0. run `forge --version`
1. clone the repo in the parent directory. so the parent directory for this file(soundry-simple-storage-F23) would be foundry-23. once in the parent directory, clone the repo with `git clone git@github.com:matter-labs/foundry-zksync.git` or whatever the clone is at the time you are reading this.
2. this will create a new zksync folder that we can cd into. so cd into it. (this would be in the parent directory you just cloned the repo into).
3. then once inside the new directory, run `./install-foundry-zksync` (you have to be on linux or wsl or ubuntu).
4. now go back to the directory you want to deploy to zksync and run `forge --version`, you will see it is now slightly different.
5. in the directory you want to deploy to zksync run `foundryup-zksync`. this will install the latest version of foundry zksync.

Now you are all done! If you run `forge build --help` you will see there is now zksync flags.

 *** If you want to switch back to vanilla/base foundry, run `foundryup` ***
and if you want to switch back to zksync foundry, just run `foundryup-zksync` as you already have the pre-requisites.

when we run `forge build` in vanilla foundry, we get an `out` folder that has all the compilation details. when we run `forge build --zksync` in zksync foundry, we get a `zkout` folder with all the compilation details for zksync.

### Deploying on ZK-SYNC Notes

#### Running a local zkSync test node using Docker, and deploying a smart contract to the test node.
to learn more, learn more @ https://github.com/Cyfrin/foundry-simple-storage-cu and at the bottom it has a "zk-Sync" intructions

run `foundryup-zksync`
install docker.
to deploy to zksync, use `forge create`.

There are more steps for a local zkSync test node. To find out more watch course "Foundry Fundamentals" section 1, video #29 and #30. 

Will update this later!


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


## ERC20 Notes

ERC = Ethereum Request of Comments

ERC-20s are the industry standard of Tokens. ERC-20s represent tokens, but they are also smart contracts.

In order to create an ERC-20, it needs to have all the functions that the ERC20 token standard has. You can read more about this @https://eips.ethereum.org/EIPS/eip-20

OpenZeppelin has ERC contracts that are ready to deploy and have been audited. You can find more about these in their docs. `https://docs.openzeppelin.com/contracts/5.x/tokens`.

OpenZeppelin also has a `wizard` that allows you to build a pre-selection of different tokens depending on what you want them to do: `https://docs.openzeppelin.com/contracts/5.x/wizard`


To use OpenZeppelin Contracts in your codebase do the following:
 1. run `forge install OpenZeppelin/openzeppelin-contracts --no-commit`. 
 
 2. then create remapping in your `foundry.toml` of `remappings = ['@openzeppelin=lib/openzeppelin-contracts']` .

 3. Then import the ERC you want to use and inherit the imported file.

 4. Implement the constructor used in the inherited file.

 example from foundry-erc20-f23:
 ```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OurToken is ERC20 {
    // since the ERC20 contract we inherited from has a constructor, we must implement the constructor.
    constructor(uint256 initalSupply) ERC20("OurToken", "OT") {
        // mint the msg.sender of this contract the entire initial Supply
        _mint(msg.sender, initalSupply);
    }
}

 ```

 ERC20s have many different functions. Two functions in ERC20s are the `transferFrom` and `transfer` functions.

 The `transferFrom` function will allow another user or contract to transfer tokens from an address(if the address approves them to do so), to another address, with an amount to spend.

 The `approve` function will make the msg.sender the _from address and it will approve parameters of an `_address` and an `_amount`
example:
```js
  function testAllowancesWorks() public {
        uint256 initialAllowance = 1000;

        // Bob approves Alice to spend tokens on his behalf
        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        uint256 transferAmount = 500;

        // alice transfers bobs tokens from bobs account, to alice, of an amount of 500.
        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);
    }
```

If the TransferFrom function is used in a contract, then this means that the sequence must be:
1. User approves DSCEngine to spend their tokens
2. User calls depositCollateral
3. DSCEngine uses transferFrom to move the tokens

This must be how the test is written because this is how the function transferFrom works.
Example from foundry-defi-stablecoin-f23:
src/DSCEngine.sol:
```js

    /*
    * @notice follows CEI
    * @dev `@param` means the definitions of the parameters that the function takes.
    * @param tokenCollateralAddress: the address of the token that users are depositing as collateral
    * @param amountCollateral: the amount of tokens they are depositing
    */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // we update state here, so when we update state, we must emit an event.
        // updates the user's balance in our tracking/mapping system by adding their new deposit amount to their existing balance for the specific collateral token they deposited
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;

        // emit the event of the state update
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        // Attempt to transfer tokens from the user to this contract
        // 1. IERC20(tokenCollateralAddress): Cast the token address to tell Solidity it's an ERC20 token
        // 2. transferFrom parameters:
        //    - msg.sender: the user who is depositing collateral
        //    - address(this): this DSCEngine contract receiving the collateral
        //    - amountCollateral: how many tokens to transfer
        // 3. This transferFrom function that we are calling returns a bool: true if transfer succeeded, false if it failed, so we capture the result
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        // This transferFrom will fail if there's no prior approval. The sequence must be:
        // 1. User approves DSCEngine to spend their tokens
        // User calls depositCollateral
        // DSCEngine uses transferFrom to move the tokens

        // if it is not successful, then revert.
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }
```

Then the test from `transferFrom` is:
test/integration/DSCEngineTest.t.sol:
```js
function testRevertsIfCollateralIs0() public {
        // Start acting as the USER
        vm.startPrank(USER);

        // USER approves DSCEngine (dsce) to spend 0 WETH tokens
        ERC20Mock(weth).approve(address(dsce), 0);

        // Expect the next call to revert with this specific error
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);

        // Try to deposit 0 collateral
        dsce.depositCollateral(weth, 0);

        // Stop acting as the USER
        vm.stopPrank();
    }
```
If we tried to skip the approval step, the transferFrom would fail because the DSCEngine contract would have no permission to move the user's tokens.

`transferFrom` is when you transfer from another person. (So this would be good in a deposit function as we are transfering tokens from a user into this contract. The other suer has to give us approval)





The `transfer` function will make the `msg.sender`(the caller of the transfer function) to be the `_from` address, and the only parameters it will take are a `_to` address and an `_amount`:
example:
```js
    // msg.sender is the from address.
    ourToken.transfer(alice, transferAmount);

```
`transfer` is when you transfer from yourself(so this would be good in withdraw functions for example, as we would be sending from this contract to another user).


Note: All functions in a public or external functions in a contract are callable. ERC20s have many functions we can call, for example, a famous one is `balanceOf`. We can run the following command in our terminal to get the balance of an address: `cast call <contract address> "balanceOf(address)" <address-of-user_or_contract>`.
Example:
`cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "balanceOf(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 ` - calls the balanceOf function on an ERC20 contract to see how many tokens of that ERC20 an address has. This returns hex data of `0x0000000000000000000000000000000000000000000000015af1d78b58c40000`, and to decode we can run either `cast --to-base 0x0000000000000000000000000000000000000000000000015af1d78b58c40000 dec` or `cast --to-dec 0x0000000000000000000000000000000000000000000000015af1d78b58c40000`


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## NFT Notes (ERC-721 Notes)

### What are NFTs?

Most NFTs are ERC-721s. ERC-721 is a token-Standard that was created on the ethereum platform.

Nft stands for Non-Fungible Token and is a token standard similar to the ERC-20. 

NFTs are essentially a type of class where every object within the class is apart of the same class/category, but each object within the class is different/worth a different amount from eachother.

An NFT (Non-Fungible Token) is a unique digital certificate, registered on a blockchain, that is used to record ownership of a digital asset. The term "non-fungible" means that each token is unique and cannot be replaced with something else of equal value – unlike cryptocurrencies such as Bitcoin, which are "fungible" because any Bitcoin can be exchanged for another Bitcoin.
Here are the key aspects of NFTs:

1. Digital Assets: NFTs can represent ownership of digital items like:

- Digital artwork
- Music
- Videos
- Virtual real estate
- Gaming items
- Collectibles
- And More!


2. Blockchain Technology: NFTs typically exist on blockchain platforms (most commonly Ethereum), which maintain a secure and decentralized record of transactions.

3. Uniqueness: Each NFT has unique identifying code and metadata that distinguish it from other NFTs, making it impossible to be exactly replicated.

4. Ownership: When you buy an NFT, you get a digital certificate of ownership, though this doesn't necessarily mean you own the copyright or intellectual property rights.

5. Value: The value of NFTs can vary greatly based on factors like rarity, artistic value, and market demand. Some NFTs have sold for millions of dollars, while others may have little to no value.

You can learn more about NFTs and their contracts @ `https://eips.ethereum.org/EIPS/eip-721`

### Creating NFTs

When creating the NFT, you must store the image somewhere on the internet and have your contract point to it. There are different places to store the image, and the most popular ways are IPFS, https://IPFS, and directly on chain. Let's take a look at the pros and cons of each one of these:

`IPFS` (Interplanetary File System): IPFS is a series of nodes that can store data. You can upload your image here, however someone would need to pin it constantly and not have their laptop/node turned off in order to keep the image visible. If you choose to use this, then you can use services like `Pinata.cloud` that will pin your images for you, this way you know at least one other person in pinning your images on IPFS. Rating: Medium Recommended. (Note: There are other options than IPFS, like Arweave and FileCoin (website file.storage will help you deploy to fileCoin and other places ))

`Https://IPFS`: This is the centralized browser/website version of IPFS, if this website goes down, so does the image of your NFT. Rating: NOT RECCOMENDED!

`On-Chain`: You can store your image directly on chain as an SVG and this way the only way the image can go down is if the whole blockchain goes down (which is almost impossible)! Great! However images are much more expensive to store on the blockchain than any other data. Rating: BEST (if affordable)

Note: 
TokenURI is the metadata of the NFT

ImageURI is the link of the image, and is inside of the metadata in the TokenURI.

#### Creating NFTs on IPFS

Note: Steps will be numbered and info will be sprinkled in between steps for your convenience.

To create NFTs, create a contract that inherits from OpenZeppelin's NFT contracts.

1. Run `forge install OpenZeppelin/openzeppelin-contracts --no-commit` in your terminal.

2. Then create a remappings in your `foundry.toml`:
` remappings = ['@openzeppelin/contracts=lib/openzeppelin-contracts/contracts'] `

3. Then import the NFT contracts into your contract and inherit from them, and setup your constructor as the OpenZeppelin contract has a constructor:
example (from foundry-nft-f23):
```js
// SPDX-License_Identifier: MIT

pragma solidity 0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNft is ERC721 {
    constructor() ERC721("Dogie", "Dog") {}
}

```


In the example above, when we launch our Nft contracts, it will actually be the entire collection of "Dogie" NFTs. And each "Dogie" in this collection will get its own `_tokenId`

Each Nfts are a combination of the contracts address(collection) and the token Id.

One of the most important functions in the ERC-721 token standard is the `function tokenURI(uint256 _tokenId)`. 

`TokenURI` = Token Uniform Resource Indicator 

`URL`(like browsers) = Uniform Resource Locator

A `URL` provides a location of the resource. Whereas a `URI` identifies the resource by name at the specified location or `URL`. A `URI` is slightly different from a `URL`, but you can think of it as an endpoint/API call that returns the metadata of the NFT

example ERC721 Metadata JSON Schema that will be returned by the URI:
```JSON
{
    "title": "Asset Metadata",
    "type": "object",
    "properties": {
        "name": {
            "type": "string",
            "description": "Identifies the asset to which this NFT represents"
        },
        "description": {
            "type": "string",
            "description": "Describes the asset to which this NFT represents"
        },
        "image": {
            "type": "string",
            "description": "A URI pointing to a resource with mime type image/* representing the asset to which this NFT represents. Consider making any images at a width between 320 and 1080 pixels and aspect ratio between 1.91:1 and 4:5 inclusive."
        }
    }
}
```

Each token within an NFT collection should have their own URI that points to what that NFT should look like.

4. The OpenZeppelin ERC721 contract has a `function tokenURI` that can be overridden. So we are going to override it.
example:
```js
    function tokenURI(uint256 tokenId) public view override returns (string memory) {}
```
5. Then we are going to create a new folder named `img`, and move the image of the NFT that we want into this folder.

6. Upload your Image to IPFS and get the hash and use this hash as the image URI for your nft.
example:
```js
function tokenURI(uint256 token) public view override returns (string memory) {
    return "ipfs://<hash-Goes-Here>"
}
```


#### How Creating NFTs on-Chain Works

To create NFTs on chain, we must first turn the image into an SVG. To turn the image into an SVG, we can use AI.

Once we have the SVG, we need to get the URL so our browsers can read it. We can do this by:

The following is how it works. However we do not want to use `base64` manually. We want to use it programmatically. Read the following instructions to Create NFTs on chain.
1. Have our SVG in our NFT root directory in a folder named `img`. 
2. cd into the `img` folder.
3. run `base64` (not all computers have this, so you can run `base64 --help` to check if you do)
4. run `base64 -i <img-file-name>`. This will base64 encode the entire SVG.
example: 
command: `base64 -i <example.svg>`
Output: 
PHN2ZyB2aWV3Qm94PSIwIDAgMjAwIDIwMCIgd2lkdGg9IjQwMCIgaGVpZ2h0PSI0MDAiIHhtbG5z
PSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPGNpcmNsZSBjeD0iMTAwIiBjeT0iMTAw
IiBmaWxsPSJ5ZWxsb3ciIHI9Ijc4IiBzdHJva2U9ImJsYWNrIiBzdHJva2Utd2lkdGg9IjMiIC8+
CiAgPGcgY2xhc3M9ImV5ZXMiPgogICAgPGNpcmNsZSBjeD0iNDUiIGN5PSIxMDAiIHI9IjEyIiAv
PgogICAgPGNpcmNsZSBjeD0iMTU0IiBjeT0iMTAwIiByPSIxMiIgLz4KICA8L2c+CiAgPHBhdGgg
ZD0ibTEzNi44MSAxMTYuNTNjLjY5IDI2LjE3LTY0LjExIDQyLTgxLjUyLS43MyIgc3R5bGU9ImZp
bGw6bm9uZTsgc3Ryb2tlOiBibGFjazsgc3Ryb2tlLXdpZHRoOiAzOyIgLz4KPC9zdmc+

5. Copy and paste the output of the base64 encoding into a README.md file to edit it
6. Right before the encoded output, we add a beginning piece to tell our browser that this is an SVG. Add ` data:image/svg+xml;base64, ` before the encoded output.

data:image/svg+xml;base64,PHN2ZyB2aWV3Qm94PSIwIDAgMjAwIDIwMCIgd2lkdGg9IjQwMCIgaGVpZ2h0PSI0MDAiIHhtbG5z
PSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPGNpcmNsZSBjeD0iMTAwIiBjeT0iMTAw
IiBmaWxsPSJ5ZWxsb3ciIHI9Ijc4IiBzdHJva2U9ImJsYWNrIiBzdHJva2Utd2lkdGg9IjMiIC8+
CiAgPGcgY2xhc3M9ImV5ZXMiPgogICAgPGNpcmNsZSBjeD0iNDUiIGN5PSIxMDAiIHI9IjEyIiAv
PgogICAgPGNpcmNsZSBjeD0iMTU0IiBjeT0iMTAwIiByPSIxMiIgLz4KICA8L2c+CiAgPHBhdGgg
ZD0ibTEzNi44MSAxMTYuNTNjLjY5IDI2LjE3LTY0LjExIDQyLTgxLjUyLS43MyIgc3R5bGU9ImZp
bGw6bm9uZTsgc3Ryb2tlOiBibGFjazsgc3Ryb2tlLXdpZHRoOiAzOyIgLz4KPC9zdmc+

7. If you copy this whole code and input it into an browser, the browser will show the SVG.
8. Now we can take this SVG and put it on-chain! 



#### How to Create NFTs on-Chain

To do so, we need to input the Image URI (which is the svg we just made) into the encoding of the token URI (NFT metadata). We can do so by doing to following:
example (from Foundry-nft-f23):
```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Imports the ERC721 contract from OpenZeppelin library for NFT functionality
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// We need ERC721 as the base contract for NFT functionality
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
// Base64 is needed to encode our NFT metadata on-chain

// Creates a new contract called MoodNft that inherits from ERC721
contract MoodNft is ERC721 {
    error MoodNft__CantFlipMoodIfNotOwner();

    // we declare this variable but do not initialize it because its value is going to keep changing
    // Counter to keep track of the number of NFTs minted
    // Private variable with storage prefix (s_) for better gas optimization
    uint256 private s_tokenCounter;

    // Stores the SVG data for the sad mood NFT
    // Private variable with storage prefix (s_)
    string private s_sadSvgImageUri;

    // Stores the SVG data for the happy mood NFT
    // Private variable with storage prefix (s_)
    string private s_happySvgImageUri;

    enum Mood {
        HAPPY,
        SAD
    }

    // Map token IDs to their current mood
    // This allows each NFT to have its own mood state
    mapping(uint256 => Mood) private s_tokenIdToMood;

    // when this contract is deployed, it will take the URI of the two NFTs
    // Constructor function that initializes the contract
    // Takes two parameters: SVG data for sad and happy moods
    // Calls the parent ERC721 constructor with name "Mood NFT" and symbol "MN"
    constructor(string memory sadSvg, string memory happySvg) ERC721("Mood NFT", "MN") {
        // Start counter at 0 for first token ID
        s_tokenCounter = 0;
        // Store SVGs that are passed in deployment in contract storage for permanent access
        s_sadSvgImageUri = sadSvg;
        s_happySvgImageUri = happySvg;
    }

    // ...(skipped code)


    // Override base URI to return base64 data URI prefix (parent contract: OpenZeppelin's ERC721)
    // This is needed for on-chain SVG storage
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    // Generate and return the token URI containing metadata and SVG
    // This function must be public and override the parent contract (OpenZeppelin's ERC721)
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // Select appropriate SVG based on token's current mood
        string memory imageURI;
        if (s_tokenIdToMood[tokenId] == Mood.HAPPY) {
            imageURI = s_happySvgImageUri;
        } else {
            imageURI = s_sadSvgImageUri;
        }

        // Construct and encode the complete metadata JSON
        // We use abi.encodePacked for efficient string concatenation
        // returning/typecasting the following encoded data as a string so it can be on chain as a string  
        return string(
            // encoding the following data so it can go on chain
            abi.encodePacked(
                // returning `data:application/json;base64,` infront of the following encoded data so our browser can decode it
                _baseURI(),
                // base64 encoding the following bytes
                Base64.encode(
                    // typecasting the following encoded data into bytes
                    bytes(
                        // encoding the metadata with the Name of the NFT, description, attributes, and ImageURI inside of it.
                        abi.encodePacked(
                            '{"name": "',
                            name(), // Get name from ERC721 parameter that we passed
                            '", "description": "An NFT that reflects the owners mood.", "attributes": [{"trait_type": "moodiness", "value": 100}], "image": "',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }
}
```
In this example, we import the Open Zeppelin contract and the base64 contract. The openZeppelin contract is for the ERC721 contract inheritance, and the base64 contract is to encode the metadata so it can be on chain!

In this example, inside of the tokenURI function, there are many comments explaining what it does. this token URI is the metadata of the NFTs and it is encoded properly reside on-chain.

However, we do not want to have to get the base64 encoding of the ImageUrl manually everytime, we want to get it programatically.

To do this we must create a script that reads from our SVG images file, encodes the SVGs, and adds the baseURL to the encoded text.
example (from foundry-nft-f23):
```js
// SPDX-License-Identifier: MIT

// Declares the Solidity version to be used
pragma solidity 0.8.19;

// Import the Forge scripting utilities and our NFT contract
import {Script, console} from "forge-std/Script.sol";
import {MoodNft} from "../src/MoodNFT.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployMoodNft is Script {
    function run() external returns (MoodNft) {
        string memory sadSvg = vm.readFile("./img/sad.svg");
        string memory happySvg = vm.readFile("./img/happy.svg");

        vm.startBroadcast();
        MoodNft moodNft = new MoodNft(svgToImageURI(sadSvg), svgToImageURI(happySvg));
        vm.stopBroadcast();
    }

    function svgToImageURI(string memory svg) public pure returns (string memory) {
        string memory baseUrl = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        return string(abi.encodePacked(baseUrl, svgBase64Encoded));
    }
}

```

In this example, we are using the cheatcode `vm.readFile` that foundry has to read from our images folder. To use this cheatcode, we must update our foundry.toml with:
```js
fs_permissions = [{ access = "read", path = "./img/" /* img should be replaced with the folder that you want to readFiles from. In this example i want to use readFile on my `img` folder */ }]
```

Then in this example, after we read/save the SVG files, we write the function `svgToImageURI` that adds the baseURL (so our browser can decode the base64 encoded text) to the encoded text after it encodes it. then it passes these BaseURL+encoded-strings to the constructor of the main NFT contract. 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


## Airdrop Notes

### What is an Airdrop?
An airdrop is a marketing strategy where cryptocurrency projects or companies distribute free tokens or NFTs to specific wallet-addresses/people. Think of it like a digital giveaway or promotional campaign.

### Common Types of Airdrops
Airdrops can be any type of token, including but not limited to: ERC20s, ERC115, ERC721s(NFTs) and more!

    1. Standard Airdrop
        Free tokens sent to existing wallet addresses
        Usually requires basic tasks like following social media accounts

    2. Holder Airdrop
        Tokens given to people who already hold certain cryptocurrencies
            Example: holders of ETH receiving new tokens from Ethereum-based projects

    3. Governance Airdrop
        Tokens given to early users of a protocol
    Provides voting rights in the project's governance
        Example: Uniswap's UNI token airdrop to early users

### Why Do Projects Do Airdrops?
    - Create awareness for their project
    - Reward early adopters and community members
    - Distribute tokens widely for decentralization
    - Generate buzz and marketing momentum
    - Helps to "bootstrap" the project
    - and more!
    
### Common Requirements for Airdrops
Normally there is some type of eligibility criteria in order to be able to receive an airdrop, examples include:

    - Holding minimum amounts of certain cryptocurrencies
    - Completing social media tasks (following, sharing, etc.)
    - Being an early user of the platform
    - Participating in testnet activities
    - Using their services
    - Developing on their protocol on github
    - Be apart of their community









------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## EIP Notes 

EIP = Ethereum Improvement Proposal

EIPs are a way for the community to suggest improvements to industry standards.



### EIP status terms
1. Idea - An idea that is pre-draft. This is not tracked within the EIP Repository.

2. Draft - The first formally tracked stage of an EIP in development. An EIP is merged by an EIP Editor into the EIP repository when properly formatted.

3. Review - An EIP Author marks an EIP as ready for and requesting Peer Review.

4. Last Call - This is the final review window for an EIP before moving to FINAL. An EIP editor will assign Last Call status and set a review end date (`last-call-deadline`), typically 14 days later. If this period results in necessary normative changes it will revert the EIP to Review.

5. Final - This EIP represents the final standard. A Final EIP exists in a state of finality and should only be updated to correct errata and add non-normative clarifications.

6. Stagnant - Any EIP in Draft or Review if inactive for a period of 6 months or greater is moved to Stagnant. An EIP may be resurrected from this state by Authors or EIP Editors through moving it back to Draft.

7. Withdrawn - The EIP Author(s) have withdrawn the proposed EIP. This state has finality and can no longer be resurrected using this EIP number. If the idea is pursued at later date it is considered a new proposal.

8. Living - A special status for EIPs that are designed to be continually updated and not reach a state of finality. This includes most notably EIP-1.


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## DeFi Notes

### StableCoin Notes

A stablecoin is a non-volatile crypto asset. 

A stablecoin is a crypto asset whose buying power fluctuates very little relative to the rest of the market/stablecoins stay relatively stable. A stablecoin is a crypto asset whose buying power stays relatively the same.

#### Why We Care About Stablecoins Notes

In every type of society, we need some type of low volatility/stable currency to fulfull the 3 functions of money:
1. `Storage of Value`: a way to keep the value/wealth we've generated. Putting dollars in your bank account, or buying stocks/cryptos are a good example of storing your value. Apples would make for a poor storage of value since they would rot over time and lose their value.

2. `Unit of Account`: is a way to measure of valuable something is. When you go shopping, you see prices being listed in terms of dollars. This is an exmaple of the dollar being used as an unit of account. Pricing something in bitcoin would be a poor unit of account since the prices would change all the time.

3. `Medium of Exchange`: is an agreed upon method to transact with eachother. Buying groceries with dollars is a good example of using dollars as a medium of exchange. Buying groceries with car tires would make for a poor medium of exchange, since car tires are hard to transact with.

In order for our everyday lives to be efficient, we need our money to do these three things (above).

In a decentralized world, we need a decentralized money. Assets like Ethereum work great as a storage of value and medium of exchange, but fall behind a little bit due to their unit of account bue to their buying power volatility. (Perhaps in the future ethereum will become stable and we won't even need stablecoins lol).

#### Different Categories/Properties of StableCoins


1. `Relative Stability` - `Pegged/Anchored` or `Floating`
    - When we talk about stability, something is stable only to something else.
    - The most popular type of Stablecoins are pegged/anchored stablecoins. These are stablecoins that are pegged or anchored to another asset like the US dollar.
        - Thether, DAI, and USDC are all examples of US dollar pegged StableCoins. These coins follow the natative of 1 coin = 1 dollar. It's stable because they track the price of another asset that we think is stable. Most of these stablecoins have sometype of mechanism to make these stablecoins almost interchangeable with their pegged asset.
            - For example, USDC says that for every USDC token printed/minted there is a dollar or a bunch of assets that equal a dollar in a bank account somewhere. The way this works is that at any time you should be able to swap your USDC for the dollar.
            - DAI uses a permissionless over-collateralization to maintain its peg.
    - A stablecoin does not have to be pegged to another asset, it can be "floating". To be considered a stablecoin, its' buying power needs to stay relatively the same over time. So a floating stablecoin is "floating" because its buying power stays the same and it is not tied down to any other asset.
        - With this mechanism, you could hypothetically have a stablecoin that is even more stable than a pegged/anchored stablecoin.
            - For example, the US dollar experiences inflation every year, whereas a floating stablecoin could experience no inflation, ever.


2. `Stability Method` - `Governed` or `Algorithmic`
    - Stability Method is the way that keeps the coin stable. If it is a pegged stablecoin, what is the pegging mechanism? If it is a floating stablecoin, what is the floating mechanism? Typically, the mechanism revolves around minting or buring the stablecoin in very specific ways, and typically refers to who or what is doing the minting and burning. These are on a spectrum of Governed to Algorithmic.
        - In a governed stablecoin, there is a governed body or a centralized body that is minting or burning the stablecoin. A maximally governed and least algorithmic stablecoin, there is a single person/entity/organization/government/DAO minting or burning new stablecoins.
            - These Governed coins are typically considered centralized, since there is a singular body that is controlling the minting and burning. You could make them a little more decentralized by introducing a DAO
            - USDC, Thether, and TUSD are examples of governed stablecoins.
        
        - Algorithmic Stablecoins whose stablity is by a permissionless algorithim with no human intervention. An Algorithmic Stablecoin is just when a set of autonomous code or algorthim dictates the minting and burning. There are 0 humans involved.
            - A coin like DAI is much more algorthmic than governed because it uses a permission algorthim to mint and burn tokens.
            - Examples of Algorthimic stablecoins are DAI, Frax, Rai and the disaster UST.

        - A token can have alorithimic and governed properties. There is a spectrum of Most governed to most algorithmic.
            - DAI does have a autonomous set of code that dictates the minting and burning of tokens, but it does also have a DAO where they can vote on and different things like different interest rates, what can be collateral types, and more.
                - Technically, DAI is a hybrid system because it has a governance mechanism and some algorithimic mechanisms.
            - USDC would fall purely in the governed category because it is controlled by a centralized body.
            UST and LUNA would fall almost purely in algorithimic.

   

3. `Collateral Type` - `Endogenous` or `Exogenous`

    Collateral here means the assets backing our stable coins and giving it value.
        - For example, USDC has the dollar as its collateral and its the dollar that gives the USDC token its value. You can hypothetically swap 1 usdc for 1 dollar
        - Dai is collateralized by many assets. For example, you can deposit eth and get minted DAI in return.


    `Exogenous` collateral is collateral that originates from outside the protocol.

    `Endogenous` collateral originates from inside the protocol.

    One of the easier ways to define what type of collateral a token is using is to ask this question:
        If the stablecoin fails, does the underlying collateral also fail?
            - If yes, then its endogenous.
            - If no, then its Exogenous.


        Let's test this:
        If USDC fails, does the underlying collateral(US dollar) fail? 
            - No! The US dollar would not fail if USDC fails. Therefore, USDC is exogenous.

        If DAI fails, does the underlying collateral(eth & other cryptos) fail?
            - No! The other cryptos would not fail if DAI fails. Therefore, DAI is exogenous.

        If UST fails, does the underlying collateral(LUNA) fail?
            - Yes! LUNA would fail! Therefore, UST is/was endogenous.

    Other questions to ask to define what type of collateral a token is using are to ask these questions:
        - Was the collateral created with the sole purpose of being collateral?
            - If yes, then its endogenous.
            - If no, then its exogenous.
        and/or
        - Does the protocol own the issuance of the underlying collateral?
            - If yes, then its endogenous.
            - If no, then its Exogenous.


    Endogenous Collateral stablecoins are typically backed by nothing since they own their own underlying collateral. This is why UST/LUNA failed. 





 Here is an example of a chart comparing collateral type vs stability mechanism.
 Governed vs Algorithmic on the y axis, and Exogenous(anchored) vs Endogenous(reflexive) on the x axis: 
     ![alt text](image.png)
     This image can be found at ` https://github.com/SquilliamX/Foundry-Defi-Stablecoin-f23/raw/main/image.png `

     Most Fiat collateralized stablecoin almost all fall into the governed/dumb section (lol) since they are dealing with fiat currency and you need a centralized entity to onboard that fiat to the blockchain.


You can learn more at ` https://updraft.cyfrin.io/courses/advanced-foundry/develop-defi-protocol/defi-stablecoins `

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


## Account Abstraction Notes (EIP-4337)

https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction/introduction

Some people feel overwhelmed when getting into crypto, due to its private key rules, wallet mechanisms, gas costs, etc. The wallet use experience for getting into crypto isn't great.

Account abstraction can be boiled down to one single thing: In a traditional transaction, you need to use your private key to sign the data to send a transaction; with account abstraction, you can sign the data with anything. Imagine being able to sign a transaction with your google account, or github account, or X account, or maybe you want to only be able to sign transactions during the day, or maybe 3 of your friends need to sign off first before you can make a transaction, or  you want a spending limit.

So normally, with a private key(wallet) you can make transactions, but with account abstraction, whatever you want can be a wallet! And with this customization, this means that we can have other people pay for our transactions(gas costs) if we want to!

Even parents can give their kids their first wallet, and code in some parental controls where the kids can create all the transactions and the parents approve them.

Account Abstraction allows us to define anything can validate a transaction, not just a private key. All we have to do is code a smart contract that says "Here is what can sign my transactions". You can code literally any rules that you want into your account.


### How Account Abstraction Works

Here are two places where account abstraction exist, Ethereum, and zkSync, (but really most evm-compataible chain supports this, but not really L2s, which is why we use zkSync):


#### Account Abstraction in Ethereum Mainnet
https://eips.ethereum.org/EIPS/eip-4337

As of March 1st, 2023, Ethereum Mainnet launched the first official Account Abstraction smart contract called the `entryPoint.sol`, and you have to interact with this smart contract in order to do account abstraction.

In a traditional Ethereum transaction, you sign data with your wallet and spend gas, then send this transaction on-chain and the ethereum nodes will add this transaction to a block in the blockchain.

To use account abstraction in ethereum, you must:
    
    1. Deploy a smart contract that defines "what" can sign transactions.
        (Whereas previously only private keys could sign transactions).
        For example, you could code that 3 friends have to sign the transaction with their private keys, or you could use something like a google session key to be the one to sign transactions. If you can code it, you can build it. So this new smart contract will be your new smart contract wallet.

    2. To send a transaction, you send a "UserOperation" to an Alt-Mempool.
        - "UserOperations" have additional transaction information
        - Alt-Mempools are not the blockchain, Alt-Mempools are off-chain. Alt-Mempools are groups of nodes that are facilatating these "User Operations". Alt-Mempools are going to validate your user-operation, and they are going to pay gas to send your sign transaction on-chain. So it's the Alt-Mempool nodes that send transactions and doing the traditional ethereum transaction. Alt-Mempools nodes will send your smart contract to `EntryPoint.sol`. It's the EntryPoint.sol smart contract that handles every single account abstraction userOperations sent. All these Alt-Mempool nodes call the EntryPoint.sol's `handleOps` function, where they pass all the data associated with a user operation, which includes pointing to your smart contract that you deployed!

        To summarize: You deploy your "UserOperations" smart contract to Alt-Mempool Nodes, Alt-Mempool nodes, validate your transaction, and they route your transaction on-chain to EntryPoint.sol where it points to your smart contract, which is where everything will be directed from. So whenever you interact the blockchain, your smart contract account that you deployed will be the msg.sender/"from" account. And it will go through all the logic in your smart contract, so if you make it so that you use google to sign keys, if googe does not sign your key, the whole transaction reverts.


Signature Aggregator: Optional add-on to account abstraction where EntryPoint.sol will let you define a group of signatures that need to be aggregated. For example, this is where you can have your friends be on your multi-sig.


PayMaster: This is where you setup your codebase to have somebody else pay for the transactions. You need to have a paymaster, because if you do not, the alt-mempool nodes will pay for your gas in transactions but they will only pay for the transaction if one of the account on chain is going to pay for it. So if you do not have a paymaster setup, it will pull funds out of your account.

First run `forge install eth-infinitism/account-abstraction --no-commit`


#### Account Abstraction in Zk-Sync
Other chains like ZkSync have account abstraction natively baked in.

You still have to deploy a smart contract that has all your rules codified, but the main difference is that the alt-mempool nodes are also the ZK-Sync nodes. So we get to skip the step of having to send our transactions to the alt-mempool because the Zk-Sync nodes also work as alt-mempool nodes.

Zk-Sync can do this because they have "DefaultAccount.sol" is which default accounts for every single account. Every single metamask account, every single account in ZK-Sync is technically a smart contract account that has very specific functions and behaviors that can be validated. So anytime you interact with any address, it will always assume it's a smart contract because that's just how Zk-Sync works!


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



## Upgradeable Smart Contracts Notes

Once Contracts are deployed onto the blockchain they are immutable and this is one of the major benefit of Smart Contracts. However this can be an issue if for example we want to upgrade our smart contracts or fix a bug in our smart contracts. This section will go into the different philosophies & patterns to upgrade smart contracts, each pattern as different advantages and disadvantages.

Note: Majority of people in web3 view upgrading smart contracts as a terrible thing as it ruins the decentralization of the protocol.

### Not Really Upgrading / Parameterize Upgrade Method

This is the simplest way to think about upgrading your smart contracts. And it really isn't upgrading our smart contracts because we can't really change the logic of the smart contract when doing this method. Whatever logic is written, stays.

    - Can't add new storage/state variables
    - Can't add new logic

An example of this method is:
```js
uint256 public reward;

function setReward(uint256 _reward) public onlyOwner{
    reward = _reward;
}
```
This `setReward` function means we just have a bunch of setter functions and we can update certain parameters. For example, the Owner of this example contract could change the percentage of the rate of the reward at any time, or perhaps has a setter function that changes the variable every year/over time. It's just a setter function that changes some variable.


Advantages: 
    - Simple

Disadvantages: 
    - Not Flexible
    - If you want to add logic to the smart contract, you cannot. Cannot Update Logic/code

Note: Who has access to these setter functions? If it is one person, it is a CENTRALIZED smart contract. Of course you can add a DAO contract to be the admin contract of your protocol and that would be a decentralized way of doing this.


### Social Migration Method

If we want to upgrade a smart contract while also keeping decentralization, we can use the Social Migration Method. This is when you deploy a new contract that is not connected to your old smart contract in any way and by social convention, you tell everyone(all users) that this new contract that you have deployed is the most updated version and to begin using this new version instead of the old version.

For example, AAVE uses this method. AAVE has AAVE-V1 and AAVE-V2 and users can use whichever one they want. 

When doing this type of upgrade, we have to move the state of the first contract over to the second one. For example, if you are an ERC token moving to a new version of your token, you do need to have a way to take all those mappings from the first contract and move it to the second one. Obviously, there are ways to do this since everything is on-chain, but if you have a million transfer calls, you have to write a script that updates everyones balance and figures out what everyones balance is just to migrate to the new version of the contract. There is a ton of social convention work here to do. TrailOfBits has a fantastic blog on upgrading from a V1 to a V2(or other versions) with this yeet methodology and they give alot of steps for moving your storage and state variables over to the new contract: ` https://blog.trailofbits.com/2018/10/29/how-contract-migration-works/ `

Advantages: 
    - The most decentalized way to upgrade / Truest to blockchain value
    - Easiest to Audit

Disadvantages:
    - Lot of work to convince users to move
    - Different contract addresses.
        For example, if you are an ERC20 token, you have to convince all the exchanges to list your new contracts address as the actual address.


### Proxies Upgrade Method


Proxies are the truest programatic form of upgrades since a user can keep interacting with the protocols through these proxies and not even notice that anything changes or even got updated. This is also the upgrade method where the most bugs happen.

Proxies use alot of low level functionality, and the main one being `delegatecall` functionality. (see the delegateCall Notes sections)

`Delegatecall`: is a low level function where the code in the target contract is executed in the context of the calling contract and `msg.sender` and `msg.value` do not change their values. This means if i delegatecall a function in contract 'B' from contract 'A', I will do contracts B's logic in contract A. So if contract B has a function that says:
```js
contract B {
    uint256 public value;

    function setValue(uint256 _value){
        value = _value;
    }
}
``` 
Then the value variable will be set in contract a:
```js
Contract A {
    // value is set in contract A
    function doDelegateCall(){
        callContractB(setValue());
    }
}
```
This is the powerhouse and this combined with the fallback function allows us to delegate all calls through a proxy contract address to some other contract. This means that I can have one proxy contract that will have the same address forever and I can just point and route people to the correct implementation contract that has the logic. Whenever I want to upgrade, I just deploy a new implementation contract and point my proxy to that new implementation. Now whenever a user calls a function on the proxy contract, I'm going to deletgate call it to the new contract. I can just call an admin only function on my proxy contract and I make all contract calls go to the new contract.


Proxy Terminology:
1. The Implementation Contract:
    - Which has all our code of our protocol. When we upgrade, we launch a brand new implementation contract.

2. The Proxy Contract:
    - Which points to which implementation is the "correct" one, and routes everyone's function calls to that contract.

3. The User:
    - The user makes contract and function calls to the proxy

4. The Admin:
    - This is the user (or group of users/voters) who upgrade to new implemenatation contracts
    - Admin is the one who decides when to upgrade and which contract to point to.


All storage variables should be stored in the Proxy contract and not the implemantation contract. This way when I upgrade to a new logic contract, all of my data will stay on the proxy contract. So whenever I want to update my logic, just point to a new implementation contract. If i want to add a new storage variable or a new type of storage, I just add it my logic/implementation contract and the proxy contract will pick it up.


Most likely bugs:
    1. Storage Clashes
    2. Function Selector Clashes

Storage Clashes:
When we use `delegateCall`, we do the logic of contract B inside of contract A. So if contract B says we need to set value to 2, it sets the value to 2 in contract A. But this actually sets the value of whatever is in the same storage location on Contract A as contract B.
For example:
```js
contract B {
    uint256 public differentValue;
    uint256 public value;

    function setDValue(uint256 _differentValue){
        differentValue = _differentValue;
    }
}
```
Then in contract A, `value` is OVERWITTEN since we are setting the first storage spot on contract A to the new value:
```js
Contract A {
    // value is set & OVERWRITTEN in contract A
    function doDelegateCall(){
        callContractB(setValue());
    }
}
```

This is crucial to know because this means we can only append new storage variables and new implementation contracts and we can't reorder or change old ones. This is called Storage Clashing.


Function Selector Clashes:
When we tell our proxies to delegate call to one of these implementations, it uses a function selector to find a function (Function Selector: A 4 bytes hash of a function name and function signature that define a function). It is possible that a function in the implementation contract has the same function selector as an admin function in the proxy contract, which may cause you to accidentally a whole bunch of weird stuff. For example:
```js
contract Foo {
    function collate_propagate_storage(bytes16) external {}
    function burn(uint256) external {}
}
```
In the sample code above, even though these functions are totally different, they actually have the same function selector. So we can run into an issue where some harmless function like `getPrice()` has the same function selector as `upgradeProxy()` or `destoryProxy()` or something like that


Advantages:
    - Easy for users

Disadvantages:
    - most prone to bugs
    - Centralized unless ran by a real DAO


All the proxies mentioned below have some type of Ethereum improvemtn proposal (EIP) and most of them are in the draft phase

Note: Upgradeable contracts do not use constructors in the implementation. This is because if the implementation has logic that sets variables, the proxy will not set those variables as the constructor for the implementation only sets those variables in the implementation.
    To get around this, we need to deploy the implementation function, then we need to call a "intializer" function. This is basically our constructor, except it will be called in the proxy.


#### Transparent Proxy Pattern

In this pattern, admins are only allowed to call admin functions and admins can't functions in the implementation contract.

Admin functions are functions that govern the upgrades.

Users can only call functions in the implementation contract and not any admin contracts/functions. 

This way, you can't ever accidentally have one of the two swapping and having a function selector clash and running into a big issue where you call a function you shouldn't have.

Summary: 
If you're an admin you call admin functions. Admin Functions are functions that govern the upgrades. Admin functions are located in the proxy contract. If admins want to use the protocol as a user, admins need to participate from a separate wallet address as a user.

If you're a user, you're calling implementation functions.


#### Universal Upgradeable Proxies (UUPS)

This version of upgradeable contracts puts all logic of upgrading(AdminOnly Upgrade functions) in the implementation contracts instead of the proxy. This way the solidity compiler will throw an error and say "we have two functions here that have the same function selector".

This is also advantageous because we have one less read that we have to do, saving gas. We no longer have to check in the proxy contract if someone is an admin or not, saving gas. And the proxy is also a little bit smaller because of this, saving gas.

The issue is that if you deploy an implementation contract without any upgradeable functionality, you're stuck and its back to the social migration method for you.

In UUPS proxies, the upgrade is handles by the implementation and can eventually be removed!
 
To use a UUPS, you can use openzeppelin's package:
```js
forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
```

and import and inherit the UUPS, and write a `_authorizeUpgrade` override function:
Example from `foundry-upgrades-f23/src/BoxV1.sol`:
```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BoxV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 internal number;

    /// @custom:oz-upgrades-unsafe-allow constructor // this comment turns off the warning/error of using a constructor
    /// in the proxy.
    constructor() {
        _disableInitializers(); // constructors are not used in upgradeable contracts. this is best practice to prevent initializers from happening in the constructor
    }

    // intialize function is essentially a constuctor for proxies
    // initializer modifier makes it so that this initialize function can only be called once
    function initialize() public initializer {
        // upgradeable intializer functions should start with double underscores `__`
        __Ownable_init(); // sets owner to: owner = msg.sender
        __UUPSUpgradeable_init(); // best practice to have to show this is a UUPS upgradeable contract
    }

    // example
    function getNumber() external view returns (uint256) {
        return number;
    }

    // example
    function version() external pure returns (uint256) {
        return 1;
    }

    // we need to override this function a use it
    function _authorizeUpgrade(address newImplementation) internal override { }
}

```

at the bottom of the `UUPSUpgradeable` file, there is a `uint256[50] private __gap;` that saves storage spaces for your contract, and you can change this `[50]` number to any number you want, and it is for adding new variables in the future, so that you can dont break your proxy when doing upgrades. This is so that in the future if you need to add storage slots, you don't collide with the existing storage reserves/slots.

Note: If you see an error of `Linearization of inheritance graph impossible`, this means that we are trying to inherit contracts in the wrong order. So change the order of the inheritances.

Below is an example of a implementation contract(BoxV2) that we are upgrading to:
Example from `foundry-upgrades-f23/src/BoxV2.sol`:
```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// second version of the implementation contract after the upgrade, this is the contract we are upgrading to
contract BoxV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // example
    uint256 internal number;

    /// @custom:oz-upgrades-unsafe-allow constructor // this comment turns off the warning/error of using a constructor in the implementation.
    constructor() {
        _disableInitializers(); // constructors are not used in upgradeable contracts. this is best practice to prevent initializers from happening in the constructor
    }

    // intialize function is essentially a constuctor for proxies/implementations/upgrades
    // initializer modifier makes it so that this initialize function can only be called once
    function initialize() public initializer {
        // upgradeable intializer functions should start with double underscores `__`
        __Ownable_init(); // sets owner to: owner = msg.sender
        __UUPSUpgradeable_init(); // best practice to have to show this is a UUPS upgradeable contract
    }

    function setNumber(uint256 _number) external {
        number = _number;
    }

    function getNumber() external view returns (uint256) {
        return number;
    }

    function version() external pure returns (uint256) {
        return 2;
    }

    // we need to override this function a use it
    function _authorizeUpgrade(address newImplementation) internal override { }
}

```

below is a deployment script example of deploying our implementation before the upgrade:
Example from `foundry-upgrades-f23/script/DeployBox.s.sol`:
```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Import required contracts
import { Script } from "forge-std/Script.sol";
import { BoxV1 } from "src/BoxV1.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployBox is Script {
    // Main entry point for the deployment script
    function run() external returns (address) {
        // Call the deployment function and return the proxy address
        address proxy = deployBox();
        return proxy;
    }

    function deployBox() public returns (address) {
        vm.startBroadcast();
        // Step 1: Deploy the implementation contract (BoxV1)
        // This contains the actual logic but should never be used directly
        BoxV1 box = new BoxV1();

        // Step 2: Deploy the ERC1967Proxy contract
        // - First parameter (address(Box)): Points to the implementation contract
        // - Second parameter (""): Empty bytes for initialization data
        //   Note: We could pass initialize() function call here, but in this case we'll call it separately
        ERC1967Proxy proxy = new ERC1967Proxy(address(box), "");
        // The ERC1967Proxy is the actual proxy contract that users will interact with, and it delegates calls to your implementation contracts (BoxV1 first, and later can be upgraded to Boxv2).

        vm.stopBroadcast();

        // Return the address of the proxy contract
        // This is the address users will interact with
        return address(proxy);
    }
}

```

below is a upgrade script example of upgrade our implementation to boxV2:
Example from `foundry-upgrades-f23/script/UpgradeBox.s.sol`:
```js
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Import required contracts and tools
import { Script } from "forge-std/Script.sol";
import { BoxV1 } from "src/BoxV1.sol"; // Original implementation
import { BoxV2 } from "src/BoxV2.sol"; // New implementation to upgrade to
import { DevOpsTools } from "foundry-devops/src/DevOpsTools.sol"; // Helper for finding deployed contracts

contract UpgradeBox is Script {
    function run() external returns (address) {
        // Get the address of the most recently deployed proxy contract
        // DevOpsTools searches broadcast logs to find the ERC1967Proxy deployment
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);

        vm.startBroadcast();
        // Deploy the new implementation contract (BoxV2)
        BoxV2 newBox = new BoxV2();
        vm.stopBroadcast();

        // Upgrade the proxy to point to the new implementation
        // This keeps the same proxy address but changes the logic contract
        address proxy = upgradeBox(mostRecentlyDeployed, address(newBox));
        return proxy;
    }

    function upgradeBox(address proxyAddress, address newBox) public returns (address) {
        vm.startBroadcast();
        // Cast the proxy to BoxV1 to access the upgrade function
        // We use BoxV1 type because it has the UUPS upgrade interface we need
        BoxV1 proxy = BoxV1(proxyAddress);

        // Call upgradeTo() which is inherited from UUPSUpgradeable
        // This changes the implementation address in the proxy's storage
        proxy.upgradeTo(address(newBox)); // proxy contract now points to this new address
        vm.stopBroadcast();

        // Return the proxy address (which hasn't changed)
        return address(proxy);
    }
}
```

Below is a test contract, testing the implementation contract, the deployments, and upgrades:
Example from `foundry-upgrades-f23/test/DeployAndUpgradeTest.t.sol`:
```js
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { DeployBox } from "../script/DeployBox.s.sol";
import { UpgradeBox } from "../script/UpgradeBox.s.sol";
import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BoxV1 } from "../src/BoxV1.sol";
import { BoxV2 } from "../src/BoxV2.sol";

contract DeployAndUpgradeTest is Test {
    DeployBox public deployer;
    UpgradeBox public upgrader;
    address public OWNER = makeAddr("owner");

    address public proxy;

    function setUp() public {
        deployer = new DeployBox();
        upgrader = new UpgradeBox();
        proxy = deployer.run(); // right now, points to boxV1
    }

    function testProxyStartsAsBoxV1() public {
        vm.expectRevert();
        BoxV2(proxy).setNumber(7);
    }

    function testUpgrades() public {
        BoxV2 box2 = new BoxV2();

        upgrader.upgradeBox(proxy, address(box2));

        uint256 expectedValue = 2;
        assertEq(expectedValue, BoxV2(proxy).version());

        BoxV2(proxy).setNumber(7);
        assertEq(7, BoxV2(proxy).getNumber());
    }
}

```



#### Diamond Pattern

- Allows for multiple implementation contracts

If you're contract is so big and it doesn't fit into the one contract maximum size, you can just have multiple contracts through this multi-implementation method.

It also alows you to make more granular upgrades, like you don't have to always deploy and upgrade your entire smart contract, you can just upgrade little pieces of it if you've chunked them out.


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## DAO Notes

https://updraft.cyfrin.io/courses/advanced-foundry/daos/introduction-to-dao

Decentralized Autonomous Organizations (DAOs): any group that is governed by a transparent set of rules found on a blockchain or smart contract

Users are given voting power into what the DAO should do next and the rules of the voting is immutable, transparaent and decentralized.

This solves an age old problem of trust, centrality and transparency in giving the power to the users of the protocol/application instead of everything happening behind closed doors. And this voting piece is a cornerstone of how these operate, this "decentralized governance".

Technically, in a way, a DAO can be summarized by "Company/Organization operated exclusively through code".


### DAO Example: Compound Protocol

Compound is a borrowing and lending application/protocol that allows users to borrow and lend their assets. Everything is built in smart contracts.

In compound, we can go to the governance tab, and click on any proposal and actually see everything about the proposal; who voted for, who voted against, and the proposal history. Somebody has to create the proposal in a proposed transaction, and we can actually see the proposed transaction in the proposal history; if we click on the proposal creation, we can actually see the exact parameters they used to make this proposal, just click "decode the input data" in etherscan. The way they are typically divided is they have list of addresses and a list of functions to call on those addresses, and the parameters to pass those addresses.

So for example: A proposal can say "I would like to call `supportMarket(address)` on address <this-address>, and set reserve factor on <this-other-address>, <here> are the parameters & values we are going to pass" (parameters are encoded in bytes). Then also, there should be a description string of what this proposal is actually doing and why we are actually doing this.

The reason we have to do this proposal governance process is that the contracts have access controls where the owner of the contracts is the one to call the two functions and the owner is the governance DAO.

Once a proposal has been created, after a short delay, it becomes active, and this is when people can start voting on them. The delay between a proposal and an active vote can be changed or modified depending on your DAO. Then people have a set amount of time to vote on the proposal. If the proposal passes, it reaches succeeded status.

If we go to the governance contract of the DAO, scroll down and click on "contract" and then "write as proxy", we can actually see the exact functions that people call to vote:
    castVote:

    castVoteBySignature:

    castVoteWithReason:

If we go to the compound app, click on vote, this is a user interface we can actually vote through to make it easier for non-tech-savvy users, so users can vote directly on the app.

After a proposal passes, it goes into "queued" status, and there is a minimum delay between a proposal passing and a proposal being executed. Somebody has to call the "queued" function and it can only be called if the vote passes. The "queued" function/status says "the proposal has passed, it is now queued, and will be executed soon".

Then after the proposal is queued after a certain amount of time, people can call the "executed" function to execute the passed proposal.

This is a full example of the life cycle of a proposal going through this process.

If a proposal vote fails, it stops right after it fails the vote.


### Discussion Forum in DAOs

Usually, just starting a proposal is not enough to garner votes for it. DAOs usually want a forum or sometype of discussion place to talk about these proposal and why you like them or don't like them. Oftentimes, a discourse is one of the main places that people are going to argue for why something is good or bad, so people can vote on the changes.

`Snapshot.org` is a good tool DAOs use to figure out if the DAO community even wants something before it goes to vote. You can join snapshot group, and with the DAO tokens actually vote on things without them being executed just to get the sentiment. Some DAOs use this or even build their DAO in a way that helps the DAO with the voting process


### Voting Mechanisms

Voting in decentralized governance is critical to DAOs because sometimes they need to update and change to keep with the times.

Not all protocols need to have a DAO, but those that do need a DAO need a way for the particapants to engage. DAO Users need to know how to particapte and engage in the DAO to help make decisions. - This is a tricky problem to solve:

    Methods: 

        Use an ERC20/NFT as voting power: 
            In compound, users use the  Comp token to vote for different proposals. This runs the risk of being less fair, because when you tokenize the voting power, you're essentially auctioning off the voting power to the richest person/people; whoever has the most money gets to pick the changes. So if its only the rich people that get to vote, then its highly likely that all the changes in the protocol are going to benefit the rich - which is not an improvement over our current web2 world.

            If a user buys a bunch of votes, make bad/malicious decisions, and then sells all his votes, the user as an individual does not get punished, he just punishes the group as a whole. 

        Skin in the Game:
            Whenever a user makes a decision, the vote is recorded. And if the decision leads to a bad outcome, you get punished for making evil or bad decisions for your DAO/protocol. This stops malicious evil users as they are held accountable for their decisions.

            The hardest part about this is how a community decides what is a bad outcome and how do we punish malicious users?

        Proof of Personhood or Participation:
            Image that all users of the compound protocol were given a single vote simply because they used the protocol. Even if they had a thousand wallets, one human being = 1 vote. This would be a fair implementation where votes couldn't actually just be bought. 
            
            The issue is "Sybil resistance", how can we be sure that it's one vote equal one participant and not one participant pretending to be thousands of different people so they get more votes? This method has not been solved yet. This most likely will be solved soon with some type of chainlink integration because proof of personhood is basically just off-chain data that can be delievered on-chain, and that's exactly where chainlink shines.

        And more! Can you think of more Voting methods?!

#### Implementation of Voting

On-chain Voting:
    Example: Compound Finance
    On-Chain smart contracts, voters call some type of vote functions with their wallet, send the transaction, and done! 

    The problem with this is that if gas is expensive. If you have 10,000 people, and it is $100 per vote, you are costing your community $1,000,000 everytime you want to change anything, This is not sustainable.

    Pro: the architecture is easy and everything is transparent and everything is on-chain

    Con: Very expensive for users/voters.

    Could `Governer C` be the a fix or the beginning of the fix? Governer C uses random samping to do some quadratic voting to help reduce costs while increasing civil resistance.

Off-Chain Voting:
    You can vote off-chain and still have it be 100% decentralized. You can sign a transaction and sign a vote without actually sending to a blockchain, thereforespending NO gas. Users can send the signed transaction to a decentralized database like IPFS, count all the votes in IPFS, and when the time comes, deliver the result of that data through something like an Oracle, like chainlink, to the blockchain, all in a single transaction!

    Then if you wanted, you can replay all these side transactions in a single transaction to save gas. This can reduce the voting costs by up to 99%. Right now, this is an implementation, and one of the most popular ways to do this is through `SnapShot.org`.

    This off-chain voting mechanism sames a ton of gas to the community and can be a more efficient way to store these transactions anyways, however it needs to be implemented very carefully. If you run youre entire DAO through a centralized oracle, you are introducing a centralized intermediary and ruining the decentralization aspect of your application, so do not use a centralized oracle.


### Tools

#### No Code Solutions to build DAOs

- DAO stack

- aragon: 
    (https://updraft.cyfrin.io/courses/advanced-foundry/daos/introduction-to-aragon-dao?lesson_format=video)
    
- Colony

- DAO House

are all alternatives that can actually help you with the dev side of running a DAO and building a DAO.

However, if you want more granular control and you do not want to have to pay any of the fees associated with these protocols, you might want to do it from scratch:

#### Dev Tools to build DAOs

- `snapshot.org` is one of the most popular tools out there for both getting the sentiment of the DAO and actually performing that execution. Users can vote through this protocol with their actual tokens, the transactions get stored in IPFS, but none of it actually gets executed unless the DAO chooses to. This is a great way to get a feel of what your DAO wants to do, and you can send transactions and execute votes as well.

- zodiac: Suite of DAO-based tools for you to implement into your DAOs as well.

- Tally: another UI that allows people to see, vote, and interact with smart contracts through user interface.

- Gnosis Safe: Multi-sig wallet, kind of a centrality component, but is on this list because most DAOs in the beginning are probably going to start with some type of centrality. It is must easier to be fast when you don't have thousands of people to wait for a vote. And in the beginning, any protocol is going to be centralized to some degree anyways. Using a multi-sig where voting happens through only a few key members can be "good" in the beginning for your DAO to build faster and often emergencies as well.

Keep in mind that when adding any of these above, you are adding a level of of centrality.

- Openzeppelin contracts: These are the contracts that we're going to be basing our DAO code along on.

### Legality

The future of DAOs is interesting for all these reasons we just above, but especially on a legal front. 

Does it make sense for a DAO to live by the same regulation as another company?

How would you even force a DAO to do something? You'd have to force all users to vote a certain way if the government tells you something... it's not clear on the future of DAOs in the regulation aspect.

it's hard to tell who is even accountable for DAOs.

In the United States, you can actually form a DAO and have it legally recognized in the state of Wyoming.








------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




## Keyboard Shortcuts

`ctrl` + `a` = select everything

`ctrl` + `b` = open left side bar

`ctrl` + `c` = copy

`ctrl` + `k`(in terminal) = clears terminal (VSCode)

`ctrl` + `l` = open AI chat 

`ctrl` + `n` = new tab

`ctrl` + `p` = command pallet

`ctrl` + `s` = save file

`ctrl` + `v` = paste

`ctrl` + `w` = closes currently active/focused tab

`ctrl` + `y` = redo

`ctrl` + `z` = undo

`ctrl` + `/` = commenting out a line

`ctrl` + ` = toggle terminal

`ctrl` + `shift` + `t` = reopen the last closed tab

`ctrl` + `shift` + `v` = paste without formating

`ctrl` + <arrowKey> = move cursor to next word

`ctrl` + `shift` + (←/→)<arrowKey> = select word by word

`ctrl` + `shift` + (↑/↓)<arrowKey> = select line by line

`alt` + (←/→)(<arrowKey>) = return to previous line in code

`alt` + (↑/↓)<arrowKey> = move lines of code up or down

`ctrl` + `alt` + (↑/↓)<arrowKey> = new cursor to edit many code lines simultaneously

`crtl` + `alt` + (←/→)(<arrowKey>) = splitScreen view of code files

`shift` + `alt` + (↑/↓)(<arrowKey>) = duplicate current line  

`shift` + `alt` + (←/→)(<arrowKey>) = expanding or shrinking your text selection blocks

`ctrl` + `shift` + `alt` + (←/→)(<arrowKey>) = selecting letter by letter

`ctrl` + `shift` + `alt` + (↑/↓)(<arrowKey>) = new cursor to edit many code lines simultaneously

`fn` + (←/→)(<arrowKey>) = beginning or end of text

`ctrl` + `fn` + (←/→)(<arrowKey>) = beginning or end of page/file

`ctrl` + `fn` + (↑/↓)(<arrowKey>) = switch through open tabs

`fn` + `alt` + (↑/↓)(<arrowKey>) = scroll up or down

`shift` + `fn` + (↑/↓)(<arrowKey>) = selects 1 page of items above or below

`shift` + `fn` + (←/→)(<arrowKey>) = select everything on current line from cursor position.

`ctrl` + `shift` + `fn` + (↑/↓)(<arrowKey>) = moves tab location

`ctrl` + `shift` + `fn` + (←/→)(<arrowKey>) = selects all text to beginning or end from your cursor position.

`ctrl` + `shift` + `alt` + `fn` + (↑/↓)(<arrowKey>) = new cursors created up to 1 page above or below
