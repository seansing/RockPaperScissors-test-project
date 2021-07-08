// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

/**
 * @title RockPaperScissors (RPS) and RockPaperScissorsFactory (RPSF)
 * @dev Rock paper scissors game that utilizes ZeenusToken ERC20 tokens to play.
 * Rather than creating a unique token for the game, the idea is to allow flexibility in supporting multiple ERC20 tokens.
 * To achieve this, the 'approve and transferFrom' approach is used. i.e.
 * Step 1 : On the front end, players sets their wager (number of ZeenusTokens) in an input and a button calls the 'approve' method on the ZeenusToken contract so that the RockPaperScissors contract is allowed to receive these tokens via transferFrom. msg.sender context is maintained as user's address.
 * Step 2 : Once the transaction succeeds, when a player makes their rock, paper or scissors choice, the 'transferFrom' function of ZeenusToken contract is called to increase the balance of ZeenusTokens for the RockPaperScissors contract by the wagered amount.
 * Note: at the moment, delegatecall will not work as it will reference the context's storage rather than the target ERC20 contract's storage
 * Player who wins gets the total wagered amount. If draw, both get their wagers back.
 */

//@dev Factory to deploy multiple RPS instances that allows an option to set Player 2's address so players can decide to play against each other.
//Player 1 will be the address that creates an instance of an RPS game. Player 2 will be an optional argument.
//If Player 1 does not specify a specifc Player 2 on the front-end's input, an address of 0 will be passed.
//This means that the game only has Player 1's registered and will use addPlayerWager to register Player 2.

contract RockPaperScissorsFactory {
    //store list of deployed RPS games
    address[] public deployedRPSAddress;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function createRPS(
        uint256 _wager,
        uint256 _choiceIndex,
        address _player2
    ) public {
        //Returns the address of the deployed contract
        address newRPSAddress = address(
            new RockPaperScissors(
                _wager,
                _choiceIndex,
                block.timestamp,
                msg.sender,
                _player2,
                owner
            )
        );
        deployedRPSAddress.push(newRPSAddress);
    }

    //function to retreive all RPS games created
    function getDeployedGames() public view returns (address[] memory) {
        return deployedRPSAddress;
    }
}

interface ERC20Interface {
    //use approve and transferFrom approach.
    //user will call the approve method on ZeenusToken's contract directly from the frontend as it maintains the msg.sender context
    //delegatecall will not work it will also reference the context's storage rather than the target ERC20 contract's storage
    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) external returns (bool success);
}

contract RockPaperScissors is ERC20Interface {
    //ZeenusToken's Rinkeby address
    //Can be substituted with other ERC20 token addresses
    address zeenusAddress = 0x1f9061B953bBa0E36BF50F21876132DcF276fC6e;

    //create instance of ZeenusToken contract
    ERC20Interface zeenus = ERC20Interface(zeenusAddress);

    //contract owner
    address public owner;
    address public factoryOwner;

    //registered players
    address public player1;
    address public player2;
    address public winner;

    //enrolement wager
    uint256 public minimum_wager;

    //time the game ends if second player is uncooprative
    uint256 public endTime;

    //To keep track of number of tokens deposited by user for withdrawal/burning.
    mapping(address => uint256) public wagerDeposited;

    enum Choice {
        ROCK,
        PAPER,
        SCISSORS
    }

    //players' choices
    Choice public player1_choice;
    Choice public player2_choice;

    bool public player1_chosen;
    bool public player2_chosen;

    //@dev modifier to check if msg.sender is a registered player
    modifier isPlayer() {
        require(
            msg.sender == player1 || msg.sender == player2,
            "Msg.sender is not a registered player"
        );
        _;
    }

    //@dev checks if block.timestamp is greater than endtime of the game
    modifier onlyIfEnded() {
        require(
            block.timestamp >= endTime,
            "Game is still active. Please wait for Player 2's input."
        );
        _;
    }

    //@dev Constructor sets owner of the contract, minimum fee to play the game, and sets player1 address to 0 to allow for player registration check in add_player function
    //@param _fee denotes the minimum fee to play the game
    constructor(
        uint256 _wager,
        uint256 _player1ChoiceIndex,
        uint256 _startTime,
        address _player1,
        address _player2,
        address _factoryOwner
    ) {
        owner = _player1;
        factoryOwner = _factoryOwner;
        minimum_wager = _wager;
        endTime = _startTime + 10 minutes;
        player1 = _player1;
        player2;

        if (_player1ChoiceIndex == 0) {
            player1_choice = Choice.ROCK;
        } else if (_player1ChoiceIndex == 1) {
            player1_choice = Choice.PAPER;
        } else if (_player1ChoiceIndex == 2) {
            player1_choice = Choice.SCISSORS;
        }

        //if Player 1 specified a Player 2, set player2's address
        if (_player2 != address(0)) {
            player2 = _player2;
        }

        //receive ERC20 tokens from Player 1 to the contract
        transferFrom(msg.sender, address(this), _wager);

        //store wager amount of Player 1
        wagerDeposited[msg.sender] += _wager;
    }

    // @dev implementation of interface function, player transfers Zeenus tokens to RockPaperScissors contract in order to play the game
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokens
    ) public override returns (bool success) {
        require(
            zeenus.transferFrom(_from, _to, _tokens),
            "Token transfer failed."
        );
        return true;
    }

    /**
     * @dev Transfers player's ERC20 token to the current contract as wager, then registers them
     * @param _wager denotes the player's paid fee
     */
    function addPlayer2(uint256 _wager, uint256 _player2ChoiceIndex) public {
        require(_wager >= minimum_wager, "Minimum wager not met");

        //receive ERC20 tokens from Player 2 to contract
        transferFrom(msg.sender, address(this), _wager);

        //store wager amount of Player 2
        wagerDeposited[msg.sender] += _wager;

        //Since player 1 created the game, set player 2 here;
        player2 = msg.sender;

        if (_player2ChoiceIndex == 0) {
            player2_choice = Choice.ROCK;
        } else if (_player2ChoiceIndex == 1) {
            player2_choice = Choice.PAPER;
        } else if (_player2ChoiceIndex == 2) {
            player2_choice = Choice.SCISSORS;
        }

        decideWinner(msg.sender, _player2ChoiceIndex);
    }

    /**
     * @dev Decide winner, either player 1 or player 2 can call to get the results once both players have keyed entered their choices.
     */
    function decideWinner(address _player2Address, uint256 _player2ChoiceIndex)
        public
    {
        uint256 total_wagered = wagerDeposited[player1] +
            wagerDeposited[player2];

        //empty out balance of wagers first to avoid reentrancy attack
        wagerDeposited[player1] = 0;
        wagerDeposited[player2] = 0;

        if (player1_choice == Choice.ROCK) {
            if (_player2ChoiceIndex == 0) {
                //draw, transfer original wagers back
                transferFrom(address(this), player1, wagerDeposited[player1]);
                transferFrom(address(this), player2, wagerDeposited[player2]);
            } else if (_player2ChoiceIndex == 1) {
                //player 2 wins, transfer all to player2
                transferFrom(address(this), player2, total_wagered);
                winner = _player2Address;
            } else {
                //player 1 wins, transfer all to player1
                transferFrom(address(this), player1, total_wagered);
                winner = player1;
            }
        } else if (player1_choice == Choice.PAPER) {
            if (_player2ChoiceIndex == 1) {
                //draw, transfer original wagers back
                transferFrom(address(this), player1, wagerDeposited[player1]);
                transferFrom(address(this), player2, wagerDeposited[player2]);
            } else if (_player2ChoiceIndex == 2) {
                //player 2 wins,transfer all to player2
                transferFrom(address(this), player2, total_wagered);
                winner = _player2Address;
            } else {
                //player 1 wins,transfer all to player1
                transferFrom(address(this), player1, total_wagered);
                winner = player1;
            }
        } else if (player1_choice == Choice.SCISSORS) {
            if (_player2ChoiceIndex == 2) {
                //draw, transfer original wagers back
                transferFrom(address(this), player1, wagerDeposited[player1]);
                transferFrom(address(this), player2, wagerDeposited[player2]);
            } else if (_player2ChoiceIndex == 0) {
                //player 2 wins, transfer all to player2
                transferFrom(address(this), player2, total_wagered);
                winner = _player2Address;
            } else {
                //player 1 wins, transfer all to player1
                transferFrom(address(this), player1, total_wagered);
                winner = player1;
            }
        }
    }

    /**
     * @dev Allow PLayer 1 to withdraw wager locked in the contract if 10 minutes has passed with no input from Player 2.
     * selfdesctruct is called to remove the game's contract from the chain.
     */

    function withdrawWager() public onlyIfEnded {
        require(msg.sender == player1);
        transferFrom(address(this), msg.sender, wagerDeposited[msg.sender]);
        selfdestruct(payable(address(msg.sender)));
    }
}
