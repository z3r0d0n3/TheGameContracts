// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Utils.sol";

contract Leaderboard {
    Utils utils;
    address owner;
    modifier restricted(address requester) {
        require(utils.GameContracts(requester) == true);
        _;
    }
    // modifier restricted {
    //     address[] memory gameContracts = utils.getGameContracts();
    //     for (uint i = 0; i < gameContracts.length; i++) {
    //         if (msg.sender == gameContracts[i]) {
    //             _;
    //             return;
    //         }
    //     }
    //     revert();
    // }

//    struct Statistics {
//        uint total;
//        uint won;
//        uint lost;
//        uint draw;
//        int profit;
//    }
//    mapping(address => Statistics) public addressToStats;
//
    constructor() {
        owner = msg.sender;
    }
//
    function setGameContracts(address _utils) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
    }
//
//    function updateStats(address _playerAddress, uint _total, uint _won, uint _lost, uint _draw, int _profit) external restricted {
//        Statistics storage playerStats = addressToStats[_playerAddress];
//        playerStats.total += _total;
//        playerStats.won += _won;
//        playerStats.lost += _lost;
//        playerStats.draw += _draw;
//        playerStats.profit += _profit;
//    }
}