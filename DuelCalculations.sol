// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./Duelist.sol";
import "./Weapon.sol";
import "./Randoms.sol";
import "./Utils.sol";

contract PvPGameplay {
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
    address owner;

    Duelist public duelist;
    DuelWeapon public duelWeapon;
    Randoms public random;
    Utils public utils;
    
    constructor () {
        owner = msg.sender;
    }

    
    function setContracts (address _utils, address _random, address _duelist, address _duelWeapon) public {
         require(msg.sender == owner);
         utils = Utils(_utils);
         random = Randoms(_random);
         duelist = Duelist(_duelist);
         duelWeapon = DuelWeapon(_duelWeapon);
    }

    function getCharData(uint charId) private view returns(Duelist.Character memory) {
        Duelist.Character memory attacker = duelist.getCharData(charId);
        return attacker;
    }

    function getWeaponData(uint wpnId) private view returns(DuelWeapon.Weapon memory) {
        DuelWeapon.Weapon memory attackerWeapon = duelWeapon.getWeaponData(wpnId);
        return attackerWeapon;
    }    


    function detectCollision(uint _attackerId, uint _deffenderId) private view returns(uint[3][16] memory, Duelist.Character[2] memory) {
        Duelist.Character memory attacker = getCharData(_attackerId);
        Duelist.Character memory deffender = getCharData(_deffenderId);
        uint[3][16] memory rounds;
        uint roundslen = 0;
        for (uint r = 0; r < 2; r++) {
            for (uint i = 0; i < attacker.ofensive_points.length; i++) {
                for (uint j = 0; j < deffender.defensive_points[i].length; j++) {
                    if (attacker.ofensive_points[i][j] == 1 && deffender.defensive_points[i][j] == 1) {
                        // collision attacker hits
                        if (j == 0 || j == 4) {
                            rounds[roundslen][0] = 100; //  hit rate percetange 
                            rounds[roundslen][1] = 0; // damage percentage increase
                            rounds[roundslen][2] = j; // hit zone
                        } else if (j == 1 || j == 3) {
                            rounds[roundslen][0] = 100; // hit rate percetange 
                            rounds[roundslen][1] = 25; // damage percentage
                            rounds[roundslen][2] = j; // hit zone
                        } else if (j == 2){
                            // _damage(_defenderCharId, 20);           //  (j == 2) headshot + 75 %
                            rounds[roundslen][0] = 100; // hit rate percetange 
                            rounds[roundslen][1] = 75; // damage percentage
                            rounds[roundslen][2] = j; // hit zone
                        }
                    } else if (attacker.ofensive_points[i][j] == 1 && deffender.defensive_points[i][j] == 0) {
                        // no collision attacker misses with some rate
                        rounds[roundslen][0] = 0; // hit rate percentage
                        rounds[roundslen][1] = 75; // damage percentage
                        rounds[roundslen][2] = j; // hit zone
                        if (j < 4) { 
                            if (deffender.defensive_points[i][j + 1] == 1) {
                                rounds[roundslen][0] = 5; // some attack hit rate increase
                            }
                        }
                        if (j > 0) {
                            if (deffender.defensive_points[i][j - 1] == 1) {
                                rounds[roundslen][0] = 5; // some attack hit rate increase
                            }  
                        }
                    }
                    if (deffender.ofensive_points[i][j] == 1 && attacker.defensive_points[i][j] == 1) {
                        // collision deffender hits
                        if (j == 0 || j == 4) {
                            rounds[roundslen+1][0] = 100; // hit rate percetange 
                            rounds[roundslen+1][1] = 0; // damage percentage
                            rounds[roundslen+1][2] = j;
                        } else if (j == 1 || j == 3) {
                            rounds[roundslen+1][0] = 100; // hit rate percetange 
                            rounds[roundslen+1][1] = 25; // damage percentage
                            rounds[roundslen+1][2] = j; // hit zone
                        } else if (j == 2){
                            rounds[roundslen+1][0] = 100; // hit rate percetange 
                            rounds[roundslen+1][1] = 75; // damage percentage
                            rounds[roundslen+1][2] = j;
                        }
                    } else if (deffender.ofensive_points[i][j] == 1 && attacker.defensive_points[i][j] == 0) {
                        // no collision, deffender misses with some rate
                        rounds[roundslen+1][0] = 0; //  hit rate percentage
                        rounds[roundslen+1][1] = 75; // damage percentage
                        rounds[roundslen+1][2] = j;
                        if (j < 4) { 
                            if (attacker.defensive_points[i][j + 1] == 1) {
                                rounds[roundslen+1][0] = 5;
                            }
                        }
                        if (j > 0) {
                            if (attacker.defensive_points[i][j - 1] == 1) {
                                rounds[roundslen+1][0] = 5;
                            }
                        }
                    }
                }
                roundslen = roundslen + 2;
            }
        }
        return (rounds, [attacker, deffender]);
    }
    // 0,0 strength;
    // 0,1 force;
    // 0,2 resistance;
    // 0,3 lifepoints;
    
    // 1,0 agility;
    // 1,1 dodge;
    // 1,2 reflex;
    // 1,3 tactics; // defensive
    
    // 2,0 dexterity;
    // 2,1 aim;
    // 2,2 shooting;
    // 2,3 strategy; // ofensive


    function processAimDodgeRounds(uint _attackerId, uint _attackerWpnId, uint _deffenderId, uint _deffenderWpnId) private view returns(uint[3][16] memory, Duelist.Character[2] memory, DuelWeapon.Weapon[2] memory) {
        (uint[3][16] memory rounds, Duelist.Character[2] memory chars) = detectCollision(_attackerId, _deffenderId);
        DuelWeapon.Weapon memory attackerWeapon = getWeaponData(_attackerWpnId);
        DuelWeapon.Weapon memory deffenderWeapon = getWeaponData(_deffenderWpnId);
        uint[4][3] memory attackerattributes = utils.sumAttributes(chars[0].attributes, attackerWeapon.perks);
        uint[4][3] memory deffenderattributes = utils.sumAttributes(chars[1].attributes, deffenderWeapon.perks);

        // get averange diff between aim of the attacker and dodge of the deffender, and viceversa
        uint[2] memory attacker_aim_rate;
        uint[2] memory deffender_aim_rate;
        (attacker_aim_rate[0], attacker_aim_rate[1]) = utils.averagePercentageDiff(int(attackerattributes[2][1]),int(deffenderattributes[1][1]));
        (deffender_aim_rate[0], deffender_aim_rate[1]) = utils.averagePercentageDiff(int(deffenderattributes[2][1]),int(attackerattributes[1][1]));
        
        // get aim  dodge  rate and process rounds with that info ...
        for (uint i = 0; i < rounds.length; i++) {
            if (i % 2 == 0) { 
                //attacker rounds
                rounds[i][0]  = rounds[i][0] + attacker_aim_rate[0]; // add bonus hit rate
                if (rounds[i][0] < attacker_aim_rate[1]) {
                    rounds[i][0] = 0;
                } else {
                    rounds[i][0] = rounds[i][0] - attacker_aim_rate[1];
                }
            } else { 
                // deffender rounds
                rounds[i][0]  = rounds[i][0] + deffender_aim_rate[0]; // add bonus hit rate
                if (rounds[i][0] < deffender_aim_rate[1]) {
                    rounds[i][0] = 0;
                } else {
                    rounds[i][0] = rounds[i][0] - deffender_aim_rate[1];
                }
            }
        }
        // get averange diff between strategy of the attacker and tactics of the deffender, and viceversa , sum to hit rate percentage
        uint[2] memory attacker_strategy_rate;
        uint[2] memory deffender_strategy_rate;
        (attacker_strategy_rate[0], attacker_strategy_rate[1]) = utils.difference(attackerattributes[2][3],deffenderattributes[1][3]);
        (deffender_strategy_rate[0], deffender_strategy_rate[1]) = utils.difference(deffenderattributes[2][3],attackerattributes[1][3]);
        for (uint i = 0; i < rounds.length; i++) {
            if (i % 2 == 0) { 
                //attacker rounds
                rounds[i][0]  = rounds[i][0] + (attacker_strategy_rate[0] / 2); // add bonus hit rate
                if (rounds[i][0] <= (attacker_strategy_rate[1] / 2)) {
                    rounds[i][0] = 0;
                } else {
                    rounds[i][0] = rounds[i][0] - (attacker_strategy_rate[1] / 2);
                }
            } else { 
                // deffender rounds
                rounds[i][0]  = rounds[i][0] + (deffender_strategy_rate[0] / 2); // add bonus hit rate
                if (rounds[i][0] < (deffender_strategy_rate[1] / 2)) {
                    rounds[i][0] = 0;
                } else {
                    rounds[i][0] = rounds[i][0] - (deffender_strategy_rate[1] / 2);
                }
            }
        }
        return (rounds, chars, [attackerWeapon, deffenderWeapon]);
    }
    
    function processDamageArmorRounds (uint _attackerId, uint _attackerWpnId, uint _deffenderId, uint _deffenderWpnId) private view returns (uint[3][16] memory, Duelist.Character[2] memory, DuelWeapon.Weapon[2] memory) {
        (uint[3][16] memory rounds, Duelist.Character[2] memory chars, DuelWeapon.Weapon[2] memory weapons) = processAimDodgeRounds(_attackerId, _attackerWpnId, _deffenderId, _deffenderWpnId);
        uint[4][3] memory attackerattributes = utils.sumAttributes(chars[0].attributes, weapons[0].perks);
        uint[4][3] memory deffenderattributes = utils.sumAttributes(chars[0].attributes, weapons[0].perks);
        uint[2] memory attacker_strategy_rate;
        uint[2] memory deffender_strategy_rate;
        (attacker_strategy_rate[0], attacker_strategy_rate[1]) = utils.difference(attackerattributes[2][3],deffenderattributes[1][3]);
        (deffender_strategy_rate[0], deffender_strategy_rate[1]) = utils.difference(deffenderattributes[2][3],attackerattributes[1][3]);
        for (uint i = 0; i < rounds.length; i++) {
            if (i % 2 == 0) {
                // attacker rounds
                if (weapons[0].wtype == 0) { // firearm
                    // attacker shooting [2][2]
                    // deffender reflex [1][2]
                    rounds[i][1] = (chars[0].attributes[2][2] + weapons[0].damage + (attacker_strategy_rate[0] / 2)) + utils.percentage((attackerattributes[2][2] + weapons[0].damage + (attacker_strategy_rate[0] / 2)), rounds[i][1]);
                    if (rounds[i][1] < chars[1].attributes[1][2]) {
                        rounds[i][1] = 1;
                    } else {
                        rounds[i][1] = rounds[i][1] - chars[1].attributes[1][2];
                    }
                    if (rounds[i][1] <= (attacker_strategy_rate[1] / 2)) {
                        rounds[i][1] = 1;
                    } else {
                        rounds[i][1] = rounds[i][1] - (attacker_strategy_rate[1] / 2);
                    }
                } else if (weapons[0].wtype == 1) {
                    // attacker force [0][1]
                    // deffender resistance [0][2]
                    rounds[i][1] = (chars[0].attributes[0][1] + weapons[0].damage + (attacker_strategy_rate[0] / 2)) + utils.percentage((attackerattributes[0][1] + weapons[0].damage + (attacker_strategy_rate[0] / 2)), rounds[i][1]);
                    if (rounds[i][1] < chars[1].attributes[0][2]) {
                        rounds[i][1] = 1;
                    } else {
                        rounds[i][1] = rounds[i][1] - chars[1].attributes[0][2];
                    }
                    if (rounds[i][1] <= (attacker_strategy_rate[1] / 2)) {
                        rounds[i][1] = 1;
                    } else {
                        rounds[i][1] = rounds[i][1] - (attacker_strategy_rate[1] / 2);
                    }
                }
            } else { // deffender rounds
                if (weapons[1].wtype == 0) {
                    // deffender shooting [2][2]
                    // attacker reflex [1][2]
                    rounds[i][1] = (chars[1].attributes[2][2] + weapons[1].damage) + utils.percentage((deffenderattributes[2][2] + weapons[1].damage + (deffender_strategy_rate[0] / 2)), rounds[i][1]);
                    if (rounds[i][1] < chars[0].attributes[1][2]) {
                        rounds[i][1] = 1;
                    } else {
                        rounds[i][1] = rounds[i][1] - chars[0].attributes[1][2];
                    }
                    if (rounds[i][1] < (deffender_strategy_rate[1] / 2)) {
                        rounds[i][1] = 1;
                    } else {
                        rounds[i][1] = rounds[i][1] - (deffender_strategy_rate[1] / 2);
                    }
                } else if (weapons[1].wtype == 1) {
                    // deffender force [0][1]
                    // attacker resistance [0][2]
                    rounds[i][1] = (chars[1].attributes[0][1] + weapons[1].damage) + utils.percentage((deffenderattributes[0][1] + weapons[1].damage + (deffender_strategy_rate[0] / 2)), rounds[i][1]);
                    if (rounds[i][1] < chars[0].attributes[0][2]) {
                        rounds[i][1] = 1;
                    } else {
                        rounds[i][1] = rounds[i][1] - chars[0].attributes[0][2];
                    }
                    if (rounds[i][1] < (deffender_strategy_rate[1] / 2)) {
                        rounds[i][1] = 1;
                    } else {
                        rounds[i][1] = rounds[i][1] - (deffender_strategy_rate[1] / 2);
                    }
                }
            }
        }
        return (rounds, chars, weapons);
    }
    
    function processHitsRounds (uint _attackerId, uint _attackerWpnId, uint _deffenderId, uint _deffenderWpnId) private view returns (uint[3][16] memory, Duelist.Character[2] memory, DuelWeapon.Weapon[2] memory) {
        (uint[3][16] memory rounds, Duelist.Character[2] memory chars, DuelWeapon.Weapon[2] memory weapons) = processDamageArmorRounds(_attackerId, _attackerWpnId, _deffenderId, _deffenderWpnId);
        // roll hit rates
        for (uint i = 0; i < rounds.length; i++) { 
            if (rounds[i][0] > 99) {
                rounds[i][0] = 1;
            } else {
                uint roll = random.freeRandom(100);
                if (roll <= rounds[i][0]) {
                    rounds[i][0] = 1;
                    rounds[i][1] = random.battleRandom(rounds[i][1] - (rounds[i][1] * (15*100) / 10000), rounds[i][1] + (rounds[i][1] * (15*100) / 10000), i);
                } else { 
                    rounds[i][0] = 0;
                    rounds[i][1] = 0;
                }
            }
        }
        return (rounds, chars, weapons);
    }
    
    
    function processHealthRounds (uint[2] memory _attackerIds, uint[2] memory _deffenderIds) private view returns (uint[3][16] memory, uint[6] memory) {
        (uint[3][16] memory rounds, Duelist.Character[2] memory chars, DuelWeapon.Weapon[2] memory weapons) = processHitsRounds(_attackerIds[0], _attackerIds[1], _deffenderIds[0], _deffenderIds[1]);
        uint[2] memory playersHp;
        playersHp[0] = duelist.getHealthPoints(_attackerIds[0]) + (weapons[0].perks[0][3] * 10); // attacker
        playersHp[1] = chars[1].maxHealth + (weapons[1].perks[0][3] * 10); // deffender
        uint[2] memory totalDamages;
        totalDamages[0] = 0; // attacker
        totalDamages[1] = 0; // deffender
        uint _winnerId;
        uint _knockout = 0;
        uint _draw = 0;
        uint _attackerHealthToDrain = 0;
        for (uint i = 0; i < rounds.length; i++) {  
            if (i % 2 == 0) {
                // attacker rounds
                if (rounds[i][0] == 1) {
                    totalDamages[0] = totalDamages[0] + rounds[i][1];
                    if (playersHp[1] < rounds[i][1]) {
                        // knockout deffender
                        _knockout = i;
                        _winnerId = _attackerIds[0];
                        break;
                    } else {
                        playersHp[1] = playersHp[1] - rounds[i][1];
                    }
                }
            } else {
                // deffender rounds
                if (rounds[i][0] == 1) {
                    totalDamages[1] = totalDamages[1] + rounds[i][1];
                    if (playersHp[0] < rounds[i][1]) {
                        // knockout attacker
                        _knockout = i;
                        _winnerId = _deffenderIds[0];
                        break;
                    } else {
                        playersHp[0] = playersHp[0] - rounds[i][1];
                        _attackerHealthToDrain = _attackerHealthToDrain + rounds[i][1];
                    }
                }
            }
        }
        if (_knockout == 0) {
            if (totalDamages[0] > totalDamages[1]) { // attacker wins
                _winnerId = _attackerIds[0];
            } else if (totalDamages[1] > totalDamages[0]) { // deffender wins
                _winnerId = _deffenderIds[0];
            } else {
                _draw = 1;
            }
        }
        if (_attackerHealthToDrain >= (weapons[0].perks[0][3] * 10)) { // TODO HP from oracle instead of 10
            _attackerHealthToDrain = _attackerHealthToDrain - (weapons[0].perks[0][3] * 10);
        }
        return (rounds, [chars[0].index, chars[1].index, _draw, _knockout, _winnerId, _attackerHealthToDrain]);
    }
    
    function processRounds (uint[2] memory _attackerIds, uint[2] memory _deffenderIds) external view restricted returns (uint[3][16] memory rounds, uint[6] memory data) {
        (rounds, data) = processHealthRounds(_attackerIds, _deffenderIds);
        return (rounds, data);
    }
 
}