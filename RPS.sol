// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract RPSLS {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping(address => uint) public player_choice;
    mapping(address => bool) public player_not_played;
    address[] public players;

    uint public numInput = 0;
    address[4] private allowedPlayers = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    function isAllowedPlayer(address player) private view returns (bool) {
        for (uint i = 0; i < allowedPlayers.length; i++) {
            if (allowedPlayers[i] == player) {
                return true;
            }
        }
        return false;
    }

    function addPlayer() public payable {
        require(numPlayer < 2, "Game is full");
        require(isAllowedPlayer(msg.sender), "You are not allowed to play");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "Same player cannot join twice");
        }
        require(msg.value == 1 ether, "Entry fee is 1 ether");

        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    function input(uint choice) public {
        require(numPlayer == 2, "Not enough players");
        require(player_not_played[msg.sender], "You have already played");
        require(choice >= 0 && choice <= 4, "Invalid choice");

        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        numInput++;

        if (numInput == 2) {
            _checkWinnerAndPay();
            _resetGame();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if (_isWinner(p0Choice, p1Choice)) {
            account0.transfer(reward);
        } 
        else if (_isWinner(p1Choice, p0Choice)) {
            account1.transfer(reward);
        } 
        else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
    }

    function _isWinner(uint choice1, uint choice2) private pure returns (bool) {
        return (
            (choice1 == 0 && (choice2 == 2 || choice2 == 3)) || // Rock beats Scissors, Lizard
            (choice1 == 1 && (choice2 == 0 || choice2 == 4)) || // Paper beats Rock, Spock
            (choice1 == 2 && (choice2 == 1 || choice2 == 3)) || // Scissors beats Paper, Lizard
            (choice1 == 3 && (choice2 == 1 || choice2 == 4)) || // Lizard beats Paper, Spock
            (choice1 == 4 && (choice2 == 0 || choice2 == 2))    // Spock beats Rock, Scissors
        );
    }

    function _resetGame() private {
        numPlayer = 0;
        numInput = 0;
        reward = 0;
        delete players;
    }
}
