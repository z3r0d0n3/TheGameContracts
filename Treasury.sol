// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Utils.sol";

contract Treasury is ReentrancyGuard {
    address owner;
    
    // using Counters for Counters.Counter;
    // Counters.Counter private _periodIds;

    Utils utils;
    ERC20 token;
    modifier restricted {
        require(utils.GameContracts(msg.sender) == true);
        _;
    }
    // modifier restricted {
    //     for (uint i = 0; i < utils.getGameContracts().length; i++) {
    //         if (msg.sender == utils.getGameContracts()[i]) {
    //             _;
    //             return;
    //         }
    //     }
    //     revert();
    // }

     constructor() {
        owner = msg.sender;
    }

    struct WeeklyStatistics {
        uint total;
        uint won;
        uint lost;
        uint draw;
        int profit;
        bool submitted;
        bool claimed;        
    }

    struct Participant {
        address player;
        uint wins;
        bool claimed;
    }

    mapping(address => WeeklyStatistics) public addressToStats;
    mapping(uint => uint) public reward;
    mapping(uint => mapping(uint => Participant)) public participants;
    mapping(uint => mapping(address => WeeklyStatistics)) public battleWeeks;

    function setContracts(address _utils, address _token) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
        token = ERC20(_token);
    }

    function updateRewards(uint _amount) external restricted {
        uint week = getCurrentWeek();
        uint currentWeekReward = _amount / 2;
        uint nextWeekReward = currentWeekReward / 2;
        uint futureWeekReward = _amount - currentWeekReward - nextWeekReward;

        if (block.timestamp < ((week + 1)*604800) - 86400) {        
            reward[week] += currentWeekReward;
            reward[week + 1] += nextWeekReward;
            reward[week + 2] += futureWeekReward;
        } else {
            reward[week + 1] += currentWeekReward;
            reward[week + 2] += nextWeekReward;
            reward[week + 3] += futureWeekReward;
        }
    }

    function getRewards(uint _week) public view returns(uint) {
        return reward[_week];
    }
    
    function updateWeeklyStats(address _player, uint _total, uint _won, uint _lost, uint _draw, int _profit) external restricted {
        uint week = getCurrentWeek();
        if (block.timestamp < ((week + 1)*604800) - 86400) {
            addressToStats[_player].total += _total;
            addressToStats[_player].won += _won;
            addressToStats[_player].lost += _lost;
            addressToStats[_player].draw += _draw;
            addressToStats[_player].profit += _profit;
        }
    }

    function submitScore() public {
        require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));
        uint week = getCurrentWeek();
        require(block.timestamp > (((week + 1)*604800) - 86400) && block.timestamp < ((week + 1)*604800)); //  - 43200
        require(battleWeeks[week][msg.sender].submitted == false && battleWeeks[week][msg.sender].claimed == false);
        battleWeeks[week][msg.sender].total = addressToStats[msg.sender].total;
        battleWeeks[week][msg.sender].won = addressToStats[msg.sender].won;
        battleWeeks[week][msg.sender].lost = addressToStats[msg.sender].lost;
        battleWeeks[week][msg.sender].draw = addressToStats[msg.sender].draw;
        battleWeeks[week][msg.sender].profit = addressToStats[msg.sender].profit;
        battleWeeks[week][msg.sender].submitted = true;
        // sort rewards table
        // check if > 0 element of rewards for this week 
        Participant[] memory test;
        Participant[] memory test2;
        if (battleWeeks[week][msg.sender].won > participants[week][0].wins) {
            delete participants[week][0];
            participants[week][0] = Participant(msg.sender, battleWeeks[week][msg.sender].won, false);
            for (uint i=0; i<100; i++) {
                test[i] = participants[week][i];
            }
            test2 = sortAsc(test);
            for (uint i=0; i<100; i++) {
                participants[week][i] = test2[i];
            }
        }
    }

    function sortAsc(Participant[] memory data) public pure returns (Participant[] memory) {
      quickSortAsc(data, int(0), int(data.length - 1));
      return data;
    }
    function quickSortAsc(Participant[] memory arr, int left, int right) private pure {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = arr[uint(left + (right - left) / 2)].wins;
        while (i <= j) {
            while (arr[uint(i)].wins < pivot) i++;
            while (pivot < arr[uint(j)].wins) j--;
            if (i <= j) {
                (arr[uint(i)].wins, arr[uint(j)].wins) = (arr[uint(j)].wins, arr[uint(i)].wins);
                i++; 
                j--;
            }
        }
        if (left < j)
            quickSortAsc(arr, left, j);
        if (i < right)
            quickSortAsc(arr, i, right);
            // return arr;
    }

    function claimReward(uint week, uint id) public nonReentrant {
        require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));
        require(block.timestamp > ((week + 1)*604800)); // - 43200
        require(battleWeeks[week][msg.sender].submitted == true && battleWeeks[week][msg.sender].claimed == false);
        require(msg.sender == participants[week][id].player && participants[week][id].claimed == false);
        addressToStats[msg.sender].total = 0;
        addressToStats[msg.sender].won = 0;
        addressToStats[msg.sender].lost = 0;
        addressToStats[msg.sender].draw = 0;
        addressToStats[msg.sender].profit = 0;
        battleWeeks[week][msg.sender].claimed == true;
        participants[week][id].claimed == true;
        uint playerReward = reward[week]*1e18*(id+1)/5050;
        token.transfer(msg.sender, playerReward);
    }

    function getCurrentWeek() public view returns (uint) {
        return block.timestamp / 604800; // 1 week in seconds        
    }

    function getPreviousWeek() public view returns (uint) {
        return block.timestamp / 604800 - 1; // 1 week in seconds        
    }

    function getCurrentDay() public view returns (uint) {
        return block.timestamp / 86400; // 1 day
    }

    function getParticipants(uint _week) public view returns (Participant[] memory) {
        // uint week = getCurrentWeek();
        Participant[] memory p = new Participant[](100);
        for (uint i = 0; i < 100; i++) {
            Participant storage currentItem = participants[_week][i];
            p[i] = currentItem;
        }
        return p;
    }

}