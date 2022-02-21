// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Utils.sol";
import "./Duelist.sol";
import "./Weapon.sol";
import "./DuelCalculations.sol";
import "./Oracle.sol";
import "./Treasury.sol";

contract Saloon {
    event NewLobby(uint id, address _owner, uint playerCharId, uint playerLvl ,uint playerWeaponId, uint autoDisableLoses, bool isActive, uint losesCounter);        
    event UpdateLobby(uint id, address _owner, bool isActive); // , uint losesCountert
    event BattleE(address playerAddress, bool attacking, uint playerCharId, uint currentWeek, uint winnerCharId, uint[48] parsedRounds, uint now, uint knockout, uint draw);

    modifier restricted(address requester) {
        require(utils.GameContracts(requester) == true);
        _;
    }

    uint _duelLobbyIds = 1;
    address owner;
    address treasure_addr;

    Utils utils;
    Duelist duelist;
    DuelWeapon weapon;
    PvPGameplay pvpCalculations;
    Oracle oracle;
    Treasury treasury;
    ERC20 token;

    constructor () {
        owner = msg.sender;
    }

    struct DuelLobby {
        uint index;
        address playerOwner;
        uint playerCharId;
        uint playerLvl;
        uint playerWeaponId;
        uint autoDisableLoses;
        uint createdAt;
        bool isActive;
        uint losesCounter;
    }
    mapping(uint => DuelLobby) public duelsLobby;

    struct Battle {
        uint timestamp;
        bool attacking;  // true player is attacker, false player is deffender
        uint playerCharId;
        uint playerWeaponId;
        uint opponentCharId;
        uint opponentWeaponId;
        uint draw; 
        uint knockout;
        uint winnerCharId;
        uint[3][16] roundsData;
    }
    mapping(uint => mapping(address => Battle[])) public addressToBattles;

    struct Statistics {
        uint total;
        uint won;
        uint lost;
        uint draw;
        int profit;
    }
    mapping(address => Statistics) public addressToStats;

    function setContracts(address _utils, address _oracle, address _pvpCalculations, address _duelist, address _weapon, address _treasury, address _token) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
        oracle = Oracle(_oracle);
        pvpCalculations = PvPGameplay(_pvpCalculations);
        duelist = Duelist(_duelist);
        weapon = DuelWeapon(_weapon);
        treasury = Treasury(_treasury);
        treasure_addr = _treasury;
        token = ERC20(_token);
    }

    function createDuelLobby (uint _playerCharId, uint _playerWeaponId, uint _autoDisableLoses, uint _supplyTokens) public {
        require(msg.sender == duelist.ownerOf(_playerCharId) && msg.sender == weapon.ownerOf(_playerWeaponId));
        Duelist.Character memory player = duelist.getCharData(_playerCharId);
        require(player.pvp == false && player.duelTimestamp < block.timestamp);
        DuelWeapon.Weapon memory playerWeapon = weapon.getWeaponData(_playerWeaponId);
        require(playerWeapon.pvp == false && token.balanceOf(msg.sender) >= _supplyTokens * 18e1); // TODO 
        require(player.mintCoins + player.coins + _supplyTokens >= oracle.battleReward());
        uint coins = player.coins;
        if (_supplyTokens > 0) {
            token.transferFrom(msg.sender, address(this), _supplyTokens*1e18);
            coins = player.coins + _supplyTokens;
        }

        duelsLobby[_duelLobbyIds] = DuelLobby(_duelLobbyIds, msg.sender, player.index, player.level, playerWeapon.index, _autoDisableLoses, block.timestamp, true, 0);
        duelist.setPvPData(_playerCharId, player.mintCoins, coins, true, player.withdrawTimestamp, player.duelTimestamp);
        weapon.setPvPData(_playerWeaponId, true);
        _duelLobbyIds += 1;
        emit NewLobby(_duelLobbyIds - 1,
                        msg.sender,
                        player.index,
                        player.level, 
                        playerWeapon.index, 
                        _autoDisableLoses,
                        true,
                        0);
    }
    
    function disableDuelLobby (uint _duelIndex) public {
        DuelLobby storage d = duelsLobby[_duelIndex];
        require(d.playerOwner == msg.sender && d.isActive == true);
        d.isActive = false;
        Duelist.Character memory c = duelist.getCharData(d.playerCharId);
        duelist.setPvPData(d.playerCharId, c.mintCoins, c.coins, false, c.withdrawTimestamp, c.duelTimestamp);
        weapon.setPvPData(d.playerWeaponId, false);
        emit UpdateLobby(_duelIndex,
                        msg.sender,
                        false);
    }

    function updateStats(address _playerAddress, uint _total, uint _won, uint _lost, uint _draw, int _profit) private {
        Statistics storage playerStats = addressToStats[_playerAddress];
        playerStats.total += _total;
        playerStats.won += _won;
        playerStats.lost += _lost;
        playerStats.draw += _draw;
        playerStats.profit += _profit;
    }

    function attack(uint _playerLobbyId, uint _opponentLobbyId) public {
        require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));
        DuelLobby storage player_dl = duelsLobby[_playerLobbyId];
        DuelLobby storage opponent_dl = duelsLobby[_opponentLobbyId];
        address opponent_dl_playerOwner = opponent_dl.playerOwner;
        require(player_dl.playerOwner == msg.sender && msg.sender != opponent_dl_playerOwner);
        require(opponent_dl.isActive == true && player_dl.isActive == true);
        require(player_dl.playerLvl - 1 <= opponent_dl.playerLvl && player_dl.playerLvl + 1 >= opponent_dl.playerLvl);
        uint battleReward = oracle.battleReward();
        uint currentWeek = treasury.getCurrentWeek();
        uint[2] memory _attackerIds = [player_dl.playerCharId, player_dl.playerWeaponId];
        uint[2] memory _deffenderIds = [opponent_dl.playerCharId, opponent_dl.playerWeaponId];
        Duelist.Character memory attacker = duelist.getCharData(_attackerIds[0]);
        require(attacker.duelTimestamp <= block.timestamp);
        Duelist.Character memory deffender = duelist.getCharData(_deffenderIds[0]);
        (uint[3][16] memory rounds, uint[6] memory data) = pvpCalculations.processRounds(_attackerIds, _deffenderIds);

        // 0 - attacker, 1 - deffender
        uint[2] memory attCoins = [attacker.mintCoins, attacker.coins];
        uint[2] memory deffCoins = [deffender.mintCoins, deffender.coins];
//        uint[2][2] memory coins = [[attacker.mintCoins, attacker.coins],[deffender.mintCoins, deffender.coins]];
        bool[2] memory playersPvp = [attacker.pvp, deffender.pvp];
        uint[2] memory duelTimestamps = [attacker.duelTimestamp, deffender.duelTimestamp];

        if (data[2] == 1) {
            treasury.updateWeeklyStats(msg.sender, 1, 0, 0, 1, 0);
            treasury.updateWeeklyStats(opponent_dl_playerOwner, 1, 0, 0, 1, 0);
            updateStats(msg.sender, 1, 0, 0, 1, 0);
            updateStats(opponent_dl_playerOwner, 1, 0, 0, 1, 0);
        } else {
            if (data[4] == _attackerIds[0]) {
                // attacker wins
                treasury.updateWeeklyStats(msg.sender, 1, 1, 0, 0, int(oracle.battleReward()));
                treasury.updateWeeklyStats(opponent_dl_playerOwner, 1, 0, 1, 0, -int(oracle.battleReward()));
                updateStats(msg.sender, 1, 1, 0, 0, int(oracle.battleReward()));
                updateStats(opponent_dl_playerOwner, 1, 0, 1, 0, -int(oracle.battleReward()));
                opponent_dl.losesCounter += 1;
                attCoins[1] = attCoins[1] + battleReward;
                // check  mint coins and withdraw from them
                if (deffCoins[0] >= battleReward) {
                    deffCoins[0] = deffCoins[0] - battleReward;
                } else {
                    deffCoins[1] = deffCoins[1] - battleReward;
                }
                //knockout
                if (data[3] > 0) {
                    duelTimestamps[1] = block.timestamp + oracle.duelKnockoutWaitTime();
                }
                if ((deffCoins[0] + deffCoins[1] < battleReward) || (opponent_dl.autoDisableLoses > 0 && opponent_dl.autoDisableLoses == opponent_dl.losesCounter)) {
                    // disable deffenders lobby
                    opponent_dl.isActive = false;
                    playersPvp[1] = false;
                    weapon.setPvPData(_deffenderIds[1], false);
                }
            } else if(data[4] == _deffenderIds[0]) {
                // deffender wins
                treasury.updateWeeklyStats(opponent_dl_playerOwner, 1, 1, 0, 0, int(oracle.battleReward()));
                treasury.updateWeeklyStats(msg.sender, 1, 0, 1, 0, -int(oracle.battleReward()));
                updateStats(msg.sender, 1, 0, 1, 0, -int(oracle.battleReward()));
                updateStats(opponent_dl_playerOwner, 1, 1, 0, 0, int(oracle.battleReward()));
                player_dl.losesCounter += 1;
                deffCoins[1] = deffCoins[1] + battleReward;
                // check mint coins and withdraw from them
                if (attCoins[0] >= battleReward) {
                    attCoins[0] = attCoins[0] - battleReward;
                } else {
                    attCoins[1] = attCoins[1] - battleReward;
                }
                //knockout
                if (data[3] > 0) {
                    duelTimestamps[0] = block.timestamp + oracle.duelKnockoutWaitTime();
                    duelist.drainHealth(_attackerIds[0], duelist.getHealthPoints(_attackerIds[0]));
                }
                if ((attCoins[0] + attCoins[1] < battleReward) || (player_dl.autoDisableLoses > 0 && player_dl.autoDisableLoses == player_dl.losesCounter)) {
                    // disable attackers lobby
                    player_dl.isActive = false;
                    playersPvp[0] = false;
                    weapon.setPvPData(_attackerIds[1], false);
                }
            }

        }
        if (data[5] <= duelist.getHealthPoints(_attackerIds[0])) {
            duelist.drainHealth(_attackerIds[0], data[5]);
        }
        // TODO claim exp
//        duelist.claimExp(_attackerIds[0], (duelist.experienceTable(attacker.level) / 100) * oracle.ExpMultiplier ) // count damage + win or loss multiplier
//        duelist.claimExp(_deffenderIds[0], )
        duelist.drainEnergy(_attackerIds[0], 20);
        duelist.setPvPData(_attackerIds[0], attCoins[0], attCoins[1], playersPvp[0], attacker.withdrawTimestamp, duelTimestamps[0]);
        duelist.setPvPData(_deffenderIds[0], deffCoins[0], deffCoins[1], playersPvp[1], deffender.withdrawTimestamp, duelTimestamps[1]);

        // push round to both players
        addressToBattles[currentWeek][msg.sender].push(Battle(block.timestamp, true, _attackerIds[0], _attackerIds[1], _deffenderIds[0], _deffenderIds[1], data[2], data[3], data[4], rounds));
        addressToBattles[currentWeek][opponent_dl_playerOwner].push(Battle(block.timestamp, false, _deffenderIds[0], _deffenderIds[1], _attackerIds[0], _attackerIds[1], data[2], data[3], data[4], rounds));
        emit BattleE(msg.sender, true, data[0], currentWeek, data[4], utils.parseRounds(rounds), block.timestamp, data[3], data[2]);
        emit BattleE(opponent_dl_playerOwner, false, data[1], currentWeek, data[4], utils.parseRounds(rounds),block.timestamp, data[3], data[2]);
        emit UpdateLobby(player_dl.index, msg.sender, playersPvp[0]);
        emit UpdateLobby(opponent_dl.index, opponent_dl_playerOwner, playersPvp[1]);
    }


    function withdrawCoins(uint _id) public {
        require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));
        require(msg.sender == duelist.ownerOf(_id));
        Duelist.Character memory char = duelist.getCharData(_id);
        require(char.coins > 0 && char.pvp == false);
        uint fee = 0;
        if (block.timestamp < char.withdrawTimestamp) {
            fee = (char.withdrawTimestamp - block.timestamp)/60/60/24;
        }
        uint coins = char.coins - utils.percentage(char.coins, fee);
        uint feeCoins = char.coins - coins;
        duelist.setPvPData(_id, char.mintCoins, 0, char.pvp, block.timestamp + oracle.withdrawFeeDays(), char.duelTimestamp);
        if (feeCoins > 0) {
//            token.transferFrom(address(this), treasure_addr, feeCoins*1e18);
            token.transfer(treasure_addr, feeCoins*1e18);
            treasury.updateRewards(feeCoins);
        }
//        token.transferFrom(address(this), msg.sender, coins*1e18);
        token.transfer(msg.sender, coins*1e18);
    }
}