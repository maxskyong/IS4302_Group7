Contract Deployment and Testing
Our smart contracts can be deployed in the following manner for testing.
1. Deploy BlackjackToken.sol first.
2. Use the address of the deployed BlackjackToken contract as an argument to deploy the BlackjackGame.sol.
3. For Practice Mode, deploy BlackjackStrategy.sol first. 
4. Use the addresses of the deployed BlackjackToken contract and the BlackjackStrategy contract to deploy BlackjackGameTrain.sol.

For the purpose of testing, we emit the rank of each card dealt to the player or dealer. This helps us keep track of hand values and ensure that game outcomes are being decided correctly. In the actual deployment of our dApp, we would not reveal the value of the dealer’s face-down card. Below is a standard test case for playing blackjack on our dApp (after deploying contracts) and does not exhaustively cover all the features within our dApp. For more detailed test cases, please refer to the accompanying video demonstration of our code.

1. Using the BlackjackGame contract, call the getBT function with a value of 1 Ether. Input a value of 1000 into the getBT function to top up 1000 BT.
2. Call the checkBT function, the account balance should now be 1000 BT.
3. Call the startNewGame function. Input a value of 100 into the startNewGame function to wager 100 BT for this game of blackjack.
4.If the player is dealt a blackjack (ace and a ten-point card), then the player automatically wins the game if the dealer does not also have a blackjack. Player would win 1.5 times their bet amount, so the player wins 150 BT. Check that account balance would now be 1150 BT. 
If the dealer also has a blackjack, then the game ends in a draw and bets are refunded. Check that account balance would now be 1000 BT.
5. If the player does not have a blackjack, the game proceeds to the player’s turn. 
6. Note down the rank and calculate the value of cards dealt to the player (you) and the dealer. To recall, the rank of a card ranges from 1 to 13 and corresponds to Ace, 2, 3, 4, 5, 6, 7, 8, 9, 10, Jack, Queen, King respectively. 
7. Call the stand function to keep current cards and proceed to the dealer’s turn.
8. The dealer will draw cards until its hand value is equal to 17 or higher.
9. Note the outcome of the game and check that account balance is updated properly.
a. If the dealer busts (hand values exceeds 21) or their hand value is smaller than the player’s, the player wins 100 BT (amount bet at Step 3).
b. If the dealer does not bust and their hand value is larger than the player’s, then the player loses 100 BT (amount bet at Step 3).
c. If the dealer and the player have the same hand value, then the game is a draw and the player’s bet is refunded.
