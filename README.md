# RockPaperScissors test project

For this test project, it is envisioned that the RockPaperScissors (RPS) game will be able to provide support for any types of ERC20 token by using the 'approve and transferFrom' approach:

- A user first approves the RPS contract for receiving the specific type of ERC20 token which then allows him/her to call transferFrom function of the ERC20 contract when creating an instance of `RockPaperScissors` through the `RockPaperScissorsFactory` smart contract. This allows the token balance of the specific `RockPaperScissors` smart contract to be updated and manage the wagers.

A test ERC20 token called ZeenusToken is used as an example here.

# Overall dApp flow

The owner of RockPaperScissors game will first deploy the `RockPaperScissorsFactory` smart contract.

The factory will be in charge of deploying new instances of `RockPaperScissors`, which is created by Player 1. It takes Player 1's total wager, choice and an option of having Player 2's address. The frontend will pass in an address of 0 if the Player 1 doesnot specify a specific Player 2 address. This utility allows any two players to play against each other.

To protect Player 1 against uncooprative players, Player 1 is allowed to withdraw their wagers after 10 minutes has passed instead of having a direct option to cancel a game instance. This also allows fair-ness of time for Player 2 if he was invited to play. Once Player 1 calls `withdrawWager()`, their original token balance is transfered to them and the smart contract self-destructs.

Essentially, the `RockPaperScissorsFactory` tracks the many instances of `RockPaperScissors` games and each `RockPaperScissors` contract is deployed by a Player 1. Player 2 will then be able place his wager and choice when participating in any of the `RockPaperScissors` instance. Once the `addPlayer2` function is called, `decideWinner` is also called last which runs the logic to determine the winner.

# Test's original instructions

Alice and Bob can play the classic game of rock, paper, scissors using ERC20 (of your choosing).

- To enroll, each player needs to deposit the right token amount, possibly zero.
- To play, each Bob and Alice need to submit their unique move.
- The contract decides and rewards the winner with all token wagered.

There are many ways to implement this, so we leave that up to you.

## Stretch Goals

Nice to have, but not necessary.

- Make it a utility whereby any 2 people can decide to play against each other.
- Reduce gas costs as much as possible.
- Let players bet their previous winnings.
- How can you entice players to play, knowing that they may have their funds stuck in the contract if they face an uncooperative player?
- Include any tests using Hardhat.
