// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Utils {
    address public owner;
    // address[] public GameContracts;

    mapping(address => bool) public GameContracts;

    constructor () {
        owner = msg.sender;
    }

    modifier restricted {
        require(GameContracts[msg.sender] == true);
        _;
    }
    // function f(address target, uint contractType) restrictTargetType(target, contractType) {
    //     ....
    // }

    // modifier restricted {
    //     for (uint i = 0; i < GameContracts.length; i++) {
    //         if (msg.sender == GameContracts[i]) {
    //             _;
    //             return;
    //         }
    //     }
    //     revert();
    // }
   
    // function getGameContractsLength() external view restricted returns (uint256) {
    //     return GameContracts.length;
    // }
    
    // function getGameContracts() external view restricted returns (address[] memory)  {
    //     return GameContracts;
    // }
    
    // function addContract (address _contract) public {
    //     require(msg.sender == owner);
    //     GameContracts.push(_contract);
    // }
    function addContract (address _contract) public {
        require(msg.sender == owner);
        GameContracts[_contract] = true;
    }
    
    function removeContract(address _contract) public {
        require(msg.sender == owner);
        GameContracts[_contract] = false;
    }
    
    // function removeContract (address _contract) public {
    //     require(msg.sender == owner);
    //     uint index;
    //     for (uint i = 0; i < GameContracts.length; i++) {
    //         if (GameContracts[i] == _contract) {
    //             index = i;
    //         }
    //     }

    //     for (uint i = index; i < GameContracts.length-1; i++){
    //         GameContracts[i] = GameContracts[i+1];
    //     }
    //     GameContracts.pop();
    // }
    
    function averagePercentageDiff(int a, int b) public pure returns (uint, uint) {
        int[2] memory attDeffBonus; // 0 attacker, 1 deffender
        if (a > b) {
            // attacker gets bonus
            attDeffBonus[0] = int((100 * (((a - b)*10**3) / (a + b))) / 10**3);
            attDeffBonus[1] = 0;
            return (uint(attDeffBonus[0]), uint(attDeffBonus[1]));
        } else if (a < b) {
            // deffender gets bonus
            attDeffBonus[0] = 0;
            attDeffBonus[1] = int((100 * (((b - a)*10**3) / (b + a))) / 10**3);
            return (uint(attDeffBonus[0]), uint(attDeffBonus[1]));
        } else {
            return (uint(attDeffBonus[0]), uint(attDeffBonus[1]));
        }
    }
    
    function difference(uint a, uint b) public pure returns (uint, uint) {
        if (a > b) {
            return (a-b, 0);
        } else if (a < b) {
            return (0, b-a);
        } else {
            return (0, 0);
        }
    }
    
    function sumAttributes(uint[4][3] memory _characterAttributes, uint[4][3] memory _weaponAttributes) public pure returns (uint[4][3] memory) {
        uint[4][3] memory totalCharacterAttr;
        for (uint i = 0; i < _characterAttributes.length; i++) {
            for (uint j = 0; j < _weaponAttributes[i].length; j++) {
                totalCharacterAttr[i][j] = _characterAttributes[i][j] + _weaponAttributes[i][j];
            }
        }
        return totalCharacterAttr;
    }
    
    function percentage (uint _amount, uint _percentage) external pure returns (uint) {
        _percentage = _percentage * 100;
        return _amount * _percentage / 10000;
    }

    
    function isContract(address addr) external view returns (bool) {
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
    
        bytes32 codehash;
        assembly {
            codehash := extcodehash(addr)
        }
        return (codehash != 0x0 && codehash != accountHash);
    }

    function parseRounds(uint[3][16] memory _rounds) external pure returns (uint[48] memory) {
        uint counter = 0;
        uint[48] memory parsedRounds;
        for(uint i = 0; i < _rounds.length; i++) {
            for(uint j = 0; j < _rounds[i].length; j++) {
                parsedRounds[counter] = _rounds[i][j];
                counter++;
            }
        }
        return parsedRounds;
    }

}