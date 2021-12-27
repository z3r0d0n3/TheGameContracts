// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Utils.sol";
import "./Oracle.sol";

contract Randoms {
    address owner;
    
    Utils utils;
    Oracle oracle;

    uint nonce;

    modifier restricted {
        address[] memory gameContracts = utils.getGameContracts();
        for (uint i = 0; i < gameContracts.length; i++) {
            if (msg.sender == gameContracts[i]) {
                _;
                return;
            }
        }
        revert();
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function setUtilsOracleContract (address _utils, address _oracle) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
        oracle = Oracle(_oracle);
    }
    
    function _randModulus(uint _mod) private returns(uint) {
        uint rand = uint(keccak256(abi.encodePacked(
            nonce,
            oracle.rand(),
            oracle.rrand(),
            block.timestamp,
            block.difficulty,
            msg.sender)
        )) % _mod;
        
        if (nonce == 115792089237316195423570985008687907853269984665640564039457584007913129639935) {
            nonce = 0;
            oracle.incrementRand();
        } else {
            nonce++;
        }
        return rand;
    }
    
    function random(uint _mod) private restricted returns(uint) {
        return _randModulus(_mod);
    }
    
    function randomRange(uint _start, uint _mod) public restricted returns(uint) {
        _mod = _mod - _start;
        uint rand = _randModulus(_mod);
        rand += _start;
        return rand;
    }
    
   
    function freeRandom(uint _mod) public view returns(uint) {
        uint rand = uint(keccak256(abi.encodePacked(
            nonce,
            oracle.rand(),
            oracle.rrand(),
            block.timestamp,
            block.difficulty,
            msg.sender)
        )) % _mod;
        return rand;
    }
    
    function battleRandom(uint _start, uint _end, uint _iter) public view returns(uint) {
        _end = _end - _start;
        uint rand = uint(keccak256(abi.encodePacked(
            nonce,
            _iter,
            oracle.rand(),
            oracle.rrand(),
            block.timestamp,
            block.difficulty,
            msg.sender)
        )) % _end;
        rand += _start;
        return rand;
    }
    
    
    function rollWeaponData() external restricted returns (uint, uint, uint, uint, uint, uint[4][3] memory) {
        // roll weapon type
        uint wtier = 0;
        uint wtype;
        uint wquality;
        uint wdamage;
        uint wlevel;
        uint[4][3] memory wstats;
        
        wtype = random(1000);
        if (wtype < 500) {
            wtype = 0;
        } else {
            wtype = 1;
        }
        
        // roll quality, roll damage, roll stats (attributes/skills)
        wquality = random(1000);
        
        if (wquality < 10) {        // 1 % artifact
            wquality = 6; 
            wdamage = randomRange(55, 85);
            wlevel = 30;
            // attributes 4x
            for (uint i = 0; i < 4; i++) {
                uint attribute = random(3);
                for (uint x = 0; x < 4; x++) {
                    wstats[attribute][x] ++;
                }
            }
            
            // skills 5x 9-14
            for (uint j = 0; j < 5; j++) {
                uint skill = randomRange(1, 10);
                
                if (skill > 6) {
                    wstats[2][skill-6] += randomRange(9, 14);
                } else if (skill > 3) {
                    wstats[1][skill-3] += randomRange(9, 14);
                } else {
                    wstats[0][skill] += randomRange(9, 14);
                }
            }
            
            
        } else if (wquality < 50) { // 4 % legendary
            wquality = 5;
            wdamage = randomRange(45, 65);
            wlevel = 25;
            // attributes 3x
            for (uint i = 0; i < 3; i++) {
                uint attribute = random(3);
                for (uint x = 0; x < 4; x++) {
                    wstats[attribute][x] ++;
                }
            }
            
            // skills 4x 12-20
            for (uint j = 0; j < 4; j++) {
                uint skill = randomRange(1, 10);
                
                if (skill > 6) {
                    wstats[2][skill-6] += randomRange(9, 14);
                } else if (skill > 3) {
                    wstats[1][skill-3] += randomRange(9, 14);
                } else {
                    wstats[0][skill] += randomRange(9, 14);
                }
            }
            
        } else if (wquality < 140) { // 9 % epic
            wquality = 4; 
            wdamage = randomRange(35, 50);
            wlevel = 20;
            // attributes 2x
            for (uint i = 0; i < 2; i++) {
                uint attribute = random(3);
                for (uint x = 0; x < 4; x++) {
                    wstats[attribute][x] ++;
                }
            }
            
            // skills 3x 11-18
            for (uint j = 0; j < 3; j++) {
                uint skill = randomRange(1, 10);
                
                if (skill > 6) {
                    wstats[2][skill-6] += randomRange(9, 14);
                } else if (skill > 3) {
                    wstats[1][skill-3] += randomRange(9, 14);
                } else {
                    wstats[0][skill] += randomRange(9, 14);
                }
            }
        } else if (wquality < 280) { // 14 % rare
            wquality = 3; 
            wdamage = randomRange(25, 40);
            wlevel = 15;
            // attribute
            uint attribute = random(3);
            for (uint x = 0; x < 4; x++) {
                wstats[attribute][x] ++;
            }

            // skills 3x 9-15
            for (uint j = 0; j < 3; j++) {
                uint skill = randomRange(1, 10);
                
                if (skill > 6) {
                    wstats[2][skill-6] += randomRange(7, 10);
                } else if (skill > 3) {
                    wstats[1][skill-3] += randomRange(7, 10);
                } else {
                    wstats[0][skill] += randomRange(7, 10);
                }
            }
            
        } else if (wquality < 470) { // 19 % uncommon
            wquality = 2; 
            wdamage = randomRange(20, 30);
            wlevel = 10;
            // skills 2x 6-14
            for (uint j = 0; j < 2; j++) {
                uint skill = randomRange(1, 10);
                
                if (skill > 6) {
                    wstats[2][skill-6] += randomRange(7, 10);
                } else if (skill > 3) {
                    wstats[1][skill-3] += randomRange(7, 10);
                } else {
                    wstats[0][skill] += randomRange(7, 10);
                }
            }
            
        } else if (wquality < 720) { // 25 % common
            wquality = 1; 
            wdamage = randomRange(15, 25);
            wlevel = 5;
            // skills 2x 3-9
            for (uint j = 0; j < 2; j++) {
                uint skill = randomRange(1, 10);
                
                if (skill > 6) {
                    wstats[2][skill-6] += randomRange(5, 8);
                } else if (skill > 3) {
                    wstats[1][skill-3] += randomRange(5, 8);
                } else {
                    wstats[0][skill] += randomRange(5, 8);
                }
            }
        } else {                    // 28 % poor
            wquality = 0; 
            wdamage = randomRange(10, 20);
            wlevel = 0;
            // skills 1x 2-6
            uint skill = randomRange(1, 10);
                
            if (skill > 6) {
                wstats[2][skill-6] += randomRange(4, 10);
            } else if (skill > 3) {
                wstats[1][skill-3] += randomRange(4, 10);
            } else {
                wstats[0][skill] += randomRange(4, 10);
            }
        }
        return (wtier, wtype, wquality, wdamage, wlevel, wstats);
    }
    
    
}