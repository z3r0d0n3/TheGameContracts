// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Utils.sol";
import "./Duelist.sol";
import "./Weapon.sol";
import "./DuelCalculations.sol";


contract Tournament {
    modifier restricted(address requester) {
        require(utils.GameContracts(requester) == true);
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

    address owner;
    Utils utils;
    ERC20 token;
    Duelist duelist;
    DuelWeapon weapon;
    PvPGameplay calculations;

    uint roomIndex = 1;
    
    struct Room {
        bool isActive;
        uint entryPrice;
        uint totalRewards;
        uint maxParticipants;
        uint winnerCharId;
        TParticipant[] participants;
    }

    struct TParticipant {
        address player;
        uint weaponId;
        uint characterId;
    }

    struct Battle {
        uint[3][16] rounds;
        uint attackerId;
        uint deffenderId;
        uint winnerId;
        uint draw;
        uint knockoutRound;
    }

    mapping(uint => Room) public idToRooms;
    mapping(uint => mapping(address => Battle)) public roomIdToAddressToBattle;

    constructor () {
        owner = msg.sender;
    }

    function setContracts(address _utils, address _token, address _calculations) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
        token = ERC20(_token);
        calculations = PvPGameplay(_calculations);
    }

    function createTournamentRoom(uint _entryPrice, uint _maxParticipants, uint _charId, uint _wpnId) public {
        require(_maxParticipants % 2 == 0);
        require(duelist.ownerOf(_charId) == msg.sender && weapon.ownerOf(_wpnId) == msg.sender && token.balanceOf(msg.sender) > _entryPrice*1e18);
        token.transferFrom(msg.sender, address(this), _entryPrice);
        Room storage tournamentRoom = idToRooms[roomIndex];
        TParticipant memory _participant;
        _participant.player = msg.sender;
        _participant.characterId = _charId;
        _participant.weaponId = _wpnId;
        tournamentRoom.isActive = true;
        tournamentRoom.entryPrice = _entryPrice;
        tournamentRoom.totalRewards = 0;
        tournamentRoom.maxParticipants = _maxParticipants;
        tournamentRoom.participants.push(_participant);
        //  = tournamentRoom;
        roomIndex++;
        // idToRooms[roomIndex] = Room(true, _entryPrice, 0, _maxParticipants, _participants);
        // emit event
    }

    function joinTournamentRoom(uint _roomId, uint _charId, uint _wpnId) public {
        require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));
        require(duelist.ownerOf(_charId) == msg.sender && weapon.ownerOf(_wpnId) == msg.sender);
        Room storage room = idToRooms[_roomId];
        require(room.participants.length < room.maxParticipants);
        require(room.isActive == true && token.balanceOf(msg.sender) >= room.entryPrice * 1e18);
        token.transferFrom(msg.sender, address(this), room.entryPrice * 1e18);
        // Room storage tournamentRoom = idToRooms[_roomId];
        TParticipant memory _participant;
        _participant.player = msg.sender;
        _participant.characterId = _charId;
        _participant.weaponId = _wpnId;
        room.participants.push(_participant);
        if (room.participants.length == room.maxParticipants) {
            // TODO process tournament, distribute rewards
            processTournament(_roomId);
        }

    }

    function processTournament(uint _roomId) private {
        Room storage room = idToRooms[_roomId];
        room.isActive = false;
        // for (uint i=0; i<room.participants.length; i++) {
        //     room.participants[i]
        // }

    }

    function processTournamentBattles(uint[2] memory _attackerIds, uint[2] memory _deffenderIds) private {
        // if (_charId && _wpnId)
        uint[3][16] memory rounds;
        uint[6] memory data;
        (rounds, data) = calculations.processRounds(_attackerIds, _deffenderIds);
    }

    // function getParticipants(uint _roomId) public view returns (TParticipant[] memory) {
    //     TParticipant[] memory participants = idToRooms[_roomId].participants;
    //     return participants;
    //     // return idToRooms
    // }
}