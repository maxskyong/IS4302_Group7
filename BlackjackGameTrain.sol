pragma solidity ^0.5.0;

import "./BlackjackToken.sol";
import "./BlackjackStrategy.sol";

contract BlackjackGameTrain {
    BlackjackStrategy public blackjackStrategy;
    BlackjackToken btContract;
    mapping(address => uint256) totalBets; 
    mapping(address => uint256) betAmounts;
    mapping(address => uint256) splitBetAmounts;
    mapping(address => bool) gameInProgress;
    mapping(address => bool) splitGameInProgress;
    mapping(address => bool) canSplit; // indicates if player can split their hand
    mapping(address => uint8[]) decksRanks; // 1 to 13 (Ace to King)
    mapping(address => uint8[]) playerHandsRanks; // 1 to 13 (Ace to King)
    mapping(address => uint8[]) playerSplitHands; // 1 to 13 (Ace to King)
    mapping(address => uint8[]) dealerHandsRanks; // 1 to 13 (Ace to King)
    mapping(address => bool) playerBlackjack; // indicates if player has a Blackjack at the start for extra payout
    mapping(address => bool) dealerBlackjack; // indicates if dealer has a Blackjack
    mapping(address => bool) playerStood; // indicates if player has called "Stand" on main hand
    mapping(address => bool) playerSplitStood; // indicates if player has called "Stand" on second hand if splitting
    // for training mode
    mapping(uint8 => string) public bustChances;
    mapping(uint => string) public actionToString;

    constructor(BlackjackToken btAddress, address _StrategyAddress) public {
        btContract = btAddress;
        // for training mode Initialize bust chances
        bustChances[4] = "0%";
        bustChances[5] = "0%";
        bustChances[6] = "0%";
        bustChances[7] = "0%";
        bustChances[8] = "0%";
        bustChances[9] = "0%";
        bustChances[10] = "0%";
        bustChances[11] = "0%";
        bustChances[12] = "31%";
        bustChances[13] = "39%";
        bustChances[14] = "56%";
        bustChances[15] = "58%";
        bustChances[16] = "62%";
        bustChances[17] = "69%";
        bustChances[18] = "77%";
        bustChances[19] = "89%";
        bustChances[20] = "92%";
        bustChances[21] = "100%";
        blackjackStrategy = BlackjackStrategy(_StrategyAddress);
        actionToString[uint(BlackjackStrategy.Action.Stand)] = "Stand";
        actionToString[uint(BlackjackStrategy.Action.Hit)] = "Hit";
        actionToString[uint(BlackjackStrategy.Action.Double)] = "Double";
    }

    event logEvent(string mess);
    event logInteger(uint256 num);
    event buyCredit(uint256 btAmt); //event of minting of BT to the msg.sender
    event returnCredits(uint256 btAmt); //event of taking BT and returning ETH to the msg.sender
    event winGame(address player);
    event loseGame(address player);
    event drawGame(address player);
    // for training mode
    event logbustChance(string bustChance);
    // Add a new event to log hand value and soft/hard status
    event logHandDetails(uint256 handValue, bool isSoft);
    // Log dealer's first card
    event DealerFirstCardObtained(uint8 dealerFirstCard);
    // Log the recommended action
    event RecommendedActionObtained(string action);

    /**
    * @dev Function to receive ETH from the msg.sender and give BlackjackToken in return
    * @param numTokens A uint256 representing the number of BlackjackTokens the msg.sender wants to buy
    */
    // Not yet air-tight, doesn't refund excess payment.
    function getBT(uint256 numTokens) public payable {
        uint256 conversionRate = btContract.getConversionRate();
        uint256 valueInWei = (numTokens * 1E18) / conversionRate;
        require(msg.value >= valueInWei, "Insufficient payment provided.");
        btContract.getCredit(msg.sender, valueInWei);
        emit buyCredit(numTokens);
    }


    /**
    * @dev Function to check the amount of BT the msg.sender has
    * @return A uint256 representing the amount of BT owned by the msg.sender
    */
    function checkBT() public view returns (uint256) {
        uint256 credit = btContract.checkCredit(msg.sender);
        return credit;
    }


    /**
    * @dev Function to cashout BT and get ETH back
    * @param numTokens A uint256 representing the amount of BT the msg.sender
    * wants to convert back to ETH
    */
    function cashoutBT(uint256 numTokens) public {
        uint256 btAmt = btContract.checkCredit(msg.sender);
        require(btAmt >= numTokens, "You do not have enough tokens.");
        
        uint256 conversionRate = btContract.getConversionRate();
        uint256 refundAmtInWei = (numTokens * 1E18) / conversionRate;
        btContract.transferCredit(address(this), numTokens);
        msg.sender.transfer(refundAmtInWei);
        emit returnCredits(numTokens);
    }


    /**
    * @dev Function to initialize a new deck of unshuffled cards
    * @param player An address belonging to the player
    */
    function initializeDeck(address player) internal {
        uint8[] memory deckRanks = new uint8[](52);
        for (uint8 i = 0; i < 4; i++) {
            for (uint8 j = 0; j < 13; j++) {
                uint8 index = i * 13 + j;
                deckRanks[index] = j + 1;
            }
        }
        decksRanks[player] = deckRanks;
    }


    /**
    * @dev Function to shuffle the deck of cards in a secure manner
    * @param player An address belonging to the player
    */
    function shuffleDeck(address player) internal {
        uint8[] memory deckRanks = decksRanks[player];
        uint256 cardsRemaining = deckRanks.length;
        
        require(cardsRemaining > 1, "Not enough cards remaining.");

        for (uint8 i = 0; i < cardsRemaining; i++) {
            uint8 randIndex = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i))) % cardsRemaining);
            uint8 firstCardRank = deckRanks[i];
            uint8 secondCardRank = deckRanks[randIndex];
            
            deckRanks[i] = secondCardRank;
            deckRanks[randIndex] = firstCardRank;
        }

        decksRanks[player] = deckRanks;
    }
    
    
    /**
    * @dev Function to deal a card from the deck to the player
    * @param player An address belonging to the player
    */
    function dealCardToPlayer(address player) internal {
        uint8[] memory deckRanks = decksRanks[player];
        uint256 cardsRemaining = deckRanks.length;

        require(cardsRemaining > 0, "No cards left to deal.");
        cardsRemaining--;

        uint8 cardRank = deckRanks[cardsRemaining];
        emit logInteger(cardRank);
        decksRanks[player].pop();
        playerHandsRanks[player].push(cardRank);
    }


    /**
    * @dev Function to deal a card from the deck to the player
    * @param player An address belonging to the player
    */
    function dealCardToPlayerSplit(address player) internal {
        uint8[] memory deckRanks = decksRanks[player];
        uint256 cardsRemaining = deckRanks.length;

        require(cardsRemaining > 0, "No cards left to deal.");
        cardsRemaining--;

        uint8 cardRank = deckRanks[cardsRemaining];
        emit logInteger(cardRank);
        decksRanks[player].pop();
        playerSplitHands[player].push(cardRank);
    }

    
    /**
    * @dev Function to deal a card from the deck to the dealer
    * @param player An address belonging to the player
    */
    function dealCardToDealer(address player) internal {
        uint8[] memory deckRanks = decksRanks[player];
        uint256 cardsRemaining = deckRanks.length;

        require(cardsRemaining > 0, "No cards left to deal.");
        cardsRemaining--;

        uint8 cardRank = deckRanks[cardsRemaining];
        emit logInteger(cardRank);
        decksRanks[player].pop();
        dealerHandsRanks[player].push(cardRank);
    }

    /**
    * @dev Function to check for the value of a hand
    * @param hand A uint8[] that stores the values of each card within a hand of cards
    * @return A tuple containing the value of the hand and a boolean indicating if the hand contains a soft ace
    */
    function getHandValue(uint8[] memory hand) internal pure returns (uint8, bool) {
        uint8 value = 0;
        uint8 numAces = 0;
        bool isSoft = false;

        for (uint8 i = 0; i < hand.length; i++) {
            uint8 rank = hand[i];
            if (rank >= 2 && rank <= 10) {
                value += rank;
            } else if (rank > 10) {
                value += 10; // Face cards (Jack, Queen, King)
            } else if (rank == 1) {
                value += 11; // Ace (initially, can later be reduced to 1 if needed)
                numAces++;
                isSoft = true; 
            }
        }

        // Adjust for aces if needed
        while (value > 21 && numAces > 0) {
            value -= 10;
            numAces--;
            // If numAces > 0, it means that at least one ace is still being counted as 11, making the hand "soft". 
            // Otherwise, if numAces is zero, all aces are being counted as 1, making the hand "hard".
            isSoft = (numAces > 0);
        }

        return (value, isSoft);
    }


    /**
    * @dev Function to check for Blackjack (an Ace and a 10-point card)
    * @param hand A uint8[] that stores the values of each card within a hand of cards
    * @return A boolean indicating whether a hand is a Blackjack (an Ace and a 10-point card)
    */
    function isBlackjack(uint8[] memory hand) internal pure returns (bool) {
        (uint8 value, ) = getHandValue(hand);  // Only capture the value, ignore isSoft
        return (hand.length == 2 && value == 21);
    }

    
    /**
    * @dev Function to check for bust (hand value over 21)
    * @param hand A uint8[] that stores the values of each card within a hand of cards
    * @return A boolean indicating whether a hand has busted (hand value over 21)
    */
    function isBust(uint8[] memory hand) internal pure returns (bool) {
        (uint8 value, ) = getHandValue(hand);  // Only capture the value, ignore isSoft
        return (value > 21);
    }


    // Function to get the recommended action
    function getStrategyAction(bool _isSoft, uint8 _playerValue, uint8 _dealerUpCard) public view returns (BlackjackStrategy.Action) {
        return blackjackStrategy.getRecommendedAction(_isSoft, _playerValue, _dealerUpCard);
    }

    /**
    * @dev Function to start a new training mode game of blackjack
    */
    function startNewTrainingGame() public {
        bool gameStarted = gameInProgress[msg.sender];
        require(!gameStarted, "A game is already in progress.");

        uint256 fixedBetAmount = 10;  // training mode - Fixed bet amount set to 10 tokens
        uint256 playerCredit = btContract.checkCredit(msg.sender);
        require(playerCredit >= fixedBetAmount, "Insufficient credits.");

        // Reset hands, bets, and set game state to true
        initializeDeck(msg.sender);
        shuffleDeck(msg.sender);
        betAmounts[msg.sender] = fixedBetAmount;  // training mode - Set the bet amount to the fixed value
        totalBets[msg.sender]  = fixedBetAmount;  // training mode - Set the bet amount to the fixed value
        gameInProgress[msg.sender] = true;
        
        dealCardToPlayer(msg.sender);
        dealCardToDealer(msg.sender);

        //training mode - get dealer first card
        uint8[] memory dealerFirstHand = dealerHandsRanks[msg.sender];
        (uint8 DFvalue, ) = getHandValue(dealerFirstHand);
        dealCardToPlayer(msg.sender);
        dealCardToDealer(msg.sender);
        
        uint8[] memory playerHand = playerHandsRanks[msg.sender];
        uint8[] memory dealerHand = dealerHandsRanks[msg.sender];
        (uint8 Pvalue, bool PisSoft) = getHandValue(playerHand);
        (uint8 Dvalue, bool DisSoft) = getHandValue(dealerHand);

        // Get the recommended action using the strategy contract with Dealer first card
        BlackjackStrategy.Action recommendedAction = getStrategyAction(PisSoft, Pvalue, DFvalue);

        // Convert the enum to its string representation
        string memory actionStr = actionToString[uint(recommendedAction)];

        emit logEvent("Player's Hand");
        emit logHandDetails(Pvalue, PisSoft);

        // for training mode - Recommended action based on player's 2 cards and dealer's first card
        emit DealerFirstCardObtained(DFvalue);
        emit RecommendedActionObtained(actionStr);
        // for training mode - Emit bust chance for the player's initial hand
        emit logEvent("bust Chance");
        emit logEvent(bustChances[Pvalue]);

        emit logEvent("Dealer's Hand");
        emit logHandDetails(Dvalue, DisSoft);

        // Check for blackjack condition at the start, 
        // only blackjacks obtained before splitting are paid extra
        if (isBlackjack(playerHand)) {
            emit logEvent("Blackjack!");
            if (!isBlackjack(dealerHand)) {
                emit logEvent("Dealer has no BJ :)");
                playerBlackjack[msg.sender] = true;
                endGame(msg.sender);
            } else {
                emit logEvent("Dealer also has BJ :(");
                dealerBlackjack[msg.sender] = true;
                endGame(msg.sender);
            }
        }

        if (playerHand[0] == playerHand[1]) {
            canSplit[msg.sender] = true;
        }
    }

    /**
    * @dev Function to split a player's hand into two separate hands. 
    * @notice Both of player's cards should be the same rank. 
    * Upon splitting into two separate hands, the dealer will deal one card each
    * to both hands to form two hands of two cards each, the player is now essentially
    * playing two games. Player must call a split before any other action (hit, double down etc.)
    */ 
    function split() public {
        address player = tx.origin;
        bool gameStarted = gameInProgress[player];
        require(gameStarted, "No game in progress.");

        bool playerCanSplit = canSplit[player];
        require(playerCanSplit, "Your hand cannot be split.");

        bool splitGameStarted = splitGameInProgress[player];
        require(!splitGameStarted, "You have already split your hand.");

        uint256 totalAmt = betAmounts[player] * 2;
        uint256 playerCredit = btContract.checkCredit(player);
        require(playerCredit >= totalAmt, "Insufficient credit to split hand.");
        
        // player places identical initial bet on the split hand, doubling total amount bet
        uint256 betAmt = betAmounts[player];
        splitBetAmounts[player] = betAmt;
        totalBets[player] += betAmt;

        uint8[] memory playerHand = playerHandsRanks[player];
        uint8 splitCard = playerHand[1];

        // split the player's initial hand into two hands, and then deal one card to each hand
        // so that the player is now playing two hands of two cards each        
        playerHandsRanks[player].pop();
        playerSplitHands[player].push(splitCard);
        dealCardToPlayer(player);
        dealCardToPlayerSplit(player);
        splitGameInProgress[player] = true;
    }


    /**
    * @dev Function to execute player's action "Hit" where the player wants to draw a card
    * @notice Function ensures that a player cannot split after making another move first 
    * (hit, double down etc.)
    */
    function playerHit() public {
        address player = tx.origin;
        bool gameStarted = gameInProgress[player];
        require(gameStarted, "No game in progress.");


        dealCardToPlayer(player);
        uint8[] memory playerHand = playerHandsRanks[player];
        (uint8 value,bool isSoft) = getHandValue(playerHand);
   
        canSplit[player] = false;

        if (isBust(playerHand)) {
            playerStand();
        } else {  // for training mode - Emit bust chance for the player's new hand
            emit logHandDetails(value, isSoft);
            emit logEvent("bust Chance");
            emit logEvent(bustChances[value]); 
        }      
    }


    /**
    * @dev Function to execute player's action "Stand" where the player wants to 
    * keep his current cards 
    * @notice Function ensures that a player cannot split after making another move first 
    * (hit, double down etc.)
    */ 
    function playerStand() public {
        address player = tx.origin;
        bool gameStarted = gameInProgress[player];
        require(gameStarted, "No game in progress.");

        playerStood[player] = true;
        canSplit[player] = false;

        // If the player did not split hand, then start dealer's turn to end the game
        bool hasSplitGame = splitGameInProgress[player];
        if (!hasSplitGame) {
            endGame(player);
        }
    }


    /**
    * @dev Function to execute player's action "Double Down" where the player wants to double his bet
    * after seeing his initial 2 cards. When a double down is called, the player must hit one more time
    * to obtain a total of 3 cards. If the player does not bust (hand value over 21), the
    * player must then stand without being able to draw any more cards.
    * @notice Function ensures that a player cannot split after making another move first 
    * (hit, double down etc.)
    */
    function playerDoubleDown() public {
        address player = tx.origin;
        bool gameStarted = gameInProgress[player];
        require(gameStarted, "No game in progress.");

        uint256 totalAmt = totalBets[player] + betAmounts[player];
        uint256 playerCredit = btContract.checkCredit(player);
        require(playerCredit >= totalAmt, "Insufficient credit to double down.");
        totalBets[player] = totalAmt;
        uint256 newBetAmt = betAmounts[player] * 2;
        betAmounts[player] = newBetAmt;
        
        dealCardToPlayer(player);
        canSplit[player] = false;
        playerStand();
    }


    /**
    * @dev Function to execute player's action "Hit" where the player wants to draw a card
    * for the second hand after splitting
    */
    function playerSplitHit() public {
        address player = tx.origin;
        bool gameStarted = gameInProgress[player];
        require(gameStarted, "No game in progress.");
        
        bool hasSplitGame = splitGameInProgress[player];
        require(hasSplitGame, "You have not split your hand.");

        bool finishedFirstHand = playerStood[player];
        require(finishedFirstHand, "You must finish playing your first hand.");

        dealCardToPlayerSplit(player);
        uint8[] memory playerSplitHand = playerSplitHands[player];

        if (isBust(playerSplitHand)) {
            playerSplitStand();
        }
    }


    /**
    * @dev Function to execute player's action "Stand" where the player wants to 
    * keep his current cards for the second hand after splitting
    */
    function playerSplitStand() public {
        address player = tx.origin;
        bool gameStarted = gameInProgress[player];
        require(gameStarted, "No game in progress.");

        bool hasSplitGame = splitGameInProgress[player];
        require(hasSplitGame, "You have not split your hand.");

        bool finishedFirstHand = playerStood[player];
        require(finishedFirstHand, "You must finish playing your first hand.");

        playerSplitStood[player] = true;
        bool firstHandFinished = playerStood[player];
        bool secondHandFinished = playerSplitStood[player];
        // fail-safe to ensure game ends only when they have called stand on both their hands when splitting
        if (firstHandFinished && secondHandFinished) {
            endGame(player);
        }
    }


    /**
    * @dev Function to execute player's action "Double Down" where the player wants to double their bet
    * after seeing their initial 2 cards for the second hand after splitting. 
    * When a double down is called, the player must hit one more time
    * to obtain a total of 3 cards. 
    * The player must then stand without being able to draw any more cards.
    */
    function playerSplitDoubleDown() public {
        address player = tx.origin;
        bool gameStarted = gameInProgress[player];
        require(gameStarted, "No game in progress.");

        bool hasSplitGame = splitGameInProgress[player];
        require(hasSplitGame, "You have not split your hand.");

        bool finishedFirstHand = playerStood[player];
        require(finishedFirstHand, "You must finish playing your first hand.");

        uint256 totalAmt = totalBets[player] + splitBetAmounts[player];
        uint256 playerCredit = btContract.checkCredit(player);
        require(playerCredit >= totalAmt, "Insufficient credit to double down.");
        
        totalBets[player] = totalAmt;
        uint256 newBetAmt = splitBetAmounts[player] * 2;
        splitBetAmounts[player] = newBetAmt;
        
        dealCardToPlayerSplit(player);
        playerSplitStand();   
    }

    /**
    * @dev Function to start dealer's turn and distribute winnings after ending the game
    * @param player An address belonging to the player
    */
    function endGame(address player) internal {

        require(gameInProgress[player], "No game in progress.");

        uint256 tokenValueInWei = (betAmounts[player] * 1E18) / btContract.getConversionRate();
        uint256 splitTokenValueInWei = (splitBetAmounts[player] * 1E18) / btContract.getConversionRate();

        bool isWin = false;
        bool isDraw = false;

        if (playerBlackjack[player]) {

            if (!dealerBlackjack[player]) {
                isWin = true;
                isDraw = false;
            } else {
                isWin = false;
                isDraw = true;
            }

            if (isWin) {
                // A blackjack hand pays 1.5 times bet amount
                btContract.getCredit(player, (tokenValueInWei * 3) / 2);
                emit winGame(player);
            } else if (isDraw) {
                emit drawGame(player);
            }
        } else {
            // Reveal Dealer's second card and check if player has won or loss
            // if Dealer already has 17 or higher

            (uint8 dealerValue,) = getHandValue(dealerHandsRanks[player]);
            (uint8 playerValue,) = getHandValue(playerHandsRanks[player]);

            if (isBust(playerHandsRanks[player])) {
                isWin = false;
                isDraw = false;
            } else if (dealerValue >= 17) {
                // To handle second possible blackjack case for the dealer 
                // where dealer's revealed card is a ten and face-down card is an ace.
                if (isBlackjack(dealerHandsRanks[player])) {
                    if (isBlackjack(playerHandsRanks[player])) {
                        isWin = false;
                        isDraw = true;
                    } else {
                        isWin = false;
                        isDraw = false;
                    }
                } else if (dealerValue > playerValue) {
                    isWin = false;
                    isDraw = false;
                } else if (playerValue > dealerValue) {
                    isWin = true;
                    isDraw = false;
                } else {
                    isWin = false;
                    isDraw = true;
                }
            } else {
                // Start Dealer's turn
                while (dealerValue < 17) {
                    dealCardToDealer(player);
                    //uint8[] memory newHand = dealerHandsRanks[player];
                    (dealerValue,) = getHandValue(dealerHandsRanks[player]);
                }

                // Determine the game outcome after Dealer draws cards until
                // hand value is a minimum of 17 points
                (uint8 finalDealerValue,) = getHandValue(dealerHandsRanks[player]);
                if (isBust(dealerHandsRanks[player]) || finalDealerValue < playerValue) {
                    isWin = true;
                    isDraw = false;
                } else if (finalDealerValue > playerValue) {
                    isWin = false;
                    isDraw = false;
                } else {
                    isWin = false;
                    isDraw = true;
                }
            }

            if (isWin) {
                btContract.getCredit(player, tokenValueInWei);
                emit winGame(player);
            } else if (isDraw) {
                emit drawGame(player);
            } else {
                btContract.transferCredit(address(this), betAmounts[player]);
                emit loseGame(player);
            }

            if (splitGameInProgress[player]) {

                (dealerValue,) = getHandValue(dealerHandsRanks[player]);
                (uint8 playerSplitValue,) = getHandValue(playerSplitHands[player]);

                bool splitWin = false;
                bool splitDraw = false;

                if (isBust(playerSplitHands[player])) {
                    splitWin = false;
                    splitDraw = false;
                } else if (dealerValue >= 17) {
                    // To handle second possible blackjack case for the dealer 
                    // where dealer's revealed card is a ten and face-down card is an ace.
                    if (isBlackjack(dealerHandsRanks[player])) {
                        if (isBlackjack(playerSplitHands[player])) {
                            splitWin = false;
                            splitDraw = true;
                        } else {
                            splitWin = false;
                            splitDraw = false;
                        }
                    } else if (dealerValue > playerSplitValue) {
                            splitWin = false;
                            splitDraw = false;
                    } else if (playerSplitValue > dealerValue) {
                            splitWin = true;
                            splitDraw = false;
                    } else {
                            splitWin = false;
                            splitDraw = true;
                    }
                } else {
                    // Start Dealer's turn
                    while (dealerValue < 17) {
                        dealCardToDealer(player);
                        uint8[] memory newHand = dealerHandsRanks[player];
                        (dealerValue,) = getHandValue(newHand);
                    }

                    // Determine the game outcome after Dealer draws cards until
                    // hand value is a minimum of 17 points
                    uint8[] memory finalDealerHand = dealerHandsRanks[player];
                    (uint8 finalDealerValue,) = getHandValue(finalDealerHand);
                    if (isBust(finalDealerHand) || finalDealerValue < playerSplitValue) {
                            splitWin = true;
                            splitDraw = false;
                    } else if (finalDealerValue > playerSplitValue) {
                            splitWin = false;
                            splitDraw = false;
                    } else {
                            splitWin = false;
                            splitDraw = true;
                    }
                }

                if (splitWin) {
                    btContract.getCredit(player, splitTokenValueInWei);
                    emit winGame(player);
                } else if (splitDraw) {
                    emit drawGame(player);
                } else {
                    btContract.transferCredit(address(this), splitBetAmounts[player]);
                    emit loseGame(player);
                }                
            }
        }

        // reset for next game
        totalBets[player] = 0;
        betAmounts[player] = 0;
        splitBetAmounts[player] = 0;

        decksRanks[player].length = 0;
        playerHandsRanks[player].length = 0;
        playerSplitHands[player].length = 0;
        dealerHandsRanks[player].length = 0;

        playerBlackjack[player] = false;
        dealerBlackjack[player] = false;

        gameInProgress[player] = false;
        splitGameInProgress[player] = false;
        canSplit[player] = false;

        playerStood[player] = false;
        playerSplitStood[player] = false;
    }
}
