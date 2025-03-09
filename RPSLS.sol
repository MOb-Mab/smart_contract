// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPSLS {
    CommitReveal public commitreveal = new CommitReveal();
    TimeUnit public timeUnit = new TimeUnit();

    uint public numPlayer = 0;
    uint public reward = 0;
    mapping(address => bytes32) public player_commit; 
    mapping(address => uint) public player_revealed;
    mapping(address => bool) public hasRevealed;
    address[] public players;
    uint public numInput = 0;
    
    
    uint public constant TIMEOUT_SECONDS = 300;
    
    mapping(address => bool) private allowedPlayersMap;
    
    constructor() {
        address[4] memory initialAllowedPlayers = [
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
            0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
            0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
            0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
        ];
        
        for (uint i = 0; i < initialAllowedPlayers.length; i++) {
            allowedPlayersMap[initialAllowedPlayers[i]] = true;
        }
    }

    function isAllowedPlayer(address player) private view returns (bool) {
        return allowedPlayersMap[player];
    }

    function addPlayer() public payable {
        require(numPlayer < 2, "Game is full");
        require(isAllowedPlayer(msg.sender), "You are not allowed to play");
        require(msg.value == 1 ether, "Entry fee is 1 ether");

        if (numPlayer == 0) {
            timeUnit.setStartTime();
        }

        players.push(msg.sender);
        reward += msg.value;
        numPlayer++;

        if (numPlayer == 2) {
            timeUnit.setStartTime(); 
        }
    }
    
    function commitChoice(bytes32 hashedData) public {
        require(numPlayer == 2, "Not enough players");
        require(player_commit[msg.sender] == bytes32(0), "Already committed");
        require(msg.sender == players[0] || msg.sender == players[1], "You are not in this round");
        
        player_commit[msg.sender] = hashedData;
        commitreveal.commit(hashedData);
        numInput++;
        
        if (numInput == 2) {
            timeUnit.setStartTime(); 
        }
    }

    function revealChoice(bytes32 rawData) public {
        require(numPlayer == 2, "Not enough players");
        require(player_commit[msg.sender] != bytes32(0), "You did not commit");
        
        commitreveal.reveal(rawData);
        
        uint8 choice = uint8(rawData[31]); 
        require(choice <= 4, "Invalid choice");
        
        player_revealed[msg.sender] = choice;
        hasRevealed[msg.sender] = true;
        
        if (hasRevealed[players[0]] && hasRevealed[players[1]]) {
            _checkWinnerAndPay();
            _resetGame();
        }
    }
    
    function refund() public {
        require(numPlayer == 1 && timeUnit.elapsedSeconds() > TIMEOUT_SECONDS, "Refund not available");
        
        payable(players[0]).transfer(reward);
        _resetGame();
    }

    function forceEndGame() public {
        require(numPlayer == 2, "Game not started");
        require(timeUnit.elapsedSeconds() > TIMEOUT_SECONDS, "Timeout not reached");

        if (player_commit[players[0]] == bytes32(0) || player_commit[players[1]] == bytes32(0)) {
            _refundBothplayer();
        } else if (!hasRevealed[players[0]] || !hasRevealed[players[1]]) {
            _refundBothplayer();
        } else {
            _checkWinnerAndPay();
        }
        _resetGame();
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_revealed[players[0]] - 1;
        uint p1Choice = player_revealed[players[1]] - 1;
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if (_isWinner(p0Choice, p1Choice)) {
            account0.transfer(reward);
        } else if (_isWinner(p1Choice, p0Choice)) {
            account1.transfer(reward);
        } else {
            _refundBothplayer();
        }
    }
     
    function _isWinner(uint choice1, uint choice2) private pure returns (bool) {
        return (
            (choice1 == 0 && (choice2 == 2 || choice2 == 3)) || 
            (choice1 == 1 && (choice2 == 0 || choice2 == 4)) || 
            (choice1 == 2 && (choice2 == 1 || choice2 == 3)) || 
            (choice1 == 3 && (choice2 == 1 || choice2 == 4)) || 
            (choice1 == 4 && (choice2 == 0 || choice2 == 2))    
        );
    }

    function _resetGame() private {
        numPlayer = 0;
        reward = 0;
        for (uint i = 0; i < players.length; i++) {
            address player = players[i];
            delete player_commit[player];
            delete player_revealed[player];
            delete hasRevealed[player];
        }
        delete players;
        numInput = 0;
    }

    function _refundBothplayer() private {
        payable(players[0]).transfer(reward / 2);
        payable(players[1]).transfer(reward / 2);
    }
}