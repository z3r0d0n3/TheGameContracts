// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Utils.sol";
import "./Oracle.sol";

contract Duelist is ERC721Enumerable {
    
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
    
    Utils utils;
    ERC20 token;
    Oracle oracle;

    uint[25] public experienceTable = [1000];
    uint public constant secondsPerEnergy = 288; //5 * 60
    uint public constant fullTimeHp = 28800; // seconds // 60 * 60 * 8; // 8 hours TODO rename

    uint index = 1;
    address owner;
    address marketplace;
    address saloon;

    struct Character {
        uint index;
        // string tokenUri;
        uint mintCoins;
        uint coins;
        bool pvp;
        
        uint maxHealth; 
        uint secondsPerHealth; // 8 hours 100 % hp regen 28800 seconds 60*60*8 /  maxHealth

        uint maxEnergy;

        uint healthTimestamp;
        uint energyTimestamp; // standard timestamp in seconds-resolution marking regen start from 0
        uint duelTimestamp;
        uint withdrawTimestamp;
        
        uint level;
        uint exp;
    
        uint attribute_points;
        uint skill_points;

        uint[4][3] attributes; 
        uint[5][4] defensive_points;
        uint[5][4] ofensive_points;
        
    }    

    // mapping(address => uint[]) public tokenIds;
    mapping(uint => Character) characters;

    
    constructor () ERC721("TheGameCharacter", "TGC") {
        owner = msg.sender;
        // _setBaseURI('test');
        for (uint i = 1; i < experienceTable.length; i ++) {
            uint requiredExperiencePerLevel = experienceTable[i - 1] + (experienceTable[i - 1] * 1000 / 10000);
            experienceTable[i] = requiredExperiencePerLevel;
        }
    }

    function setContracts (address _utils, address _oracle, address _token, address _saloon, address _marketplace) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
        oracle = Oracle(_oracle);
        token = ERC20(_token);
        saloon = _saloon;
        marketplace = _marketplace;

    }
    
    function mintCharacter() public {
        uint mintFee = oracle.characterMintPrice();
        require(balanceOf(msg.sender) < 4 && token.balanceOf(msg.sender) >= mintFee*1e18);
        token.transferFrom(msg.sender, saloon, mintFee*1e18);
        Character memory new_char;
        new_char.index = index;
        new_char.mintCoins = mintFee;
        new_char.coins = 0;
        new_char.pvp = false;
        // 8 hours 100 % hp regen 28800 seconds 60*60*8 /  maxHealth
        new_char.maxHealth = 300;
        new_char.secondsPerHealth = fullTimeHp / new_char.maxHealth; 
        new_char.maxEnergy = 100;
        new_char.healthTimestamp = uint(block.timestamp - (new_char.maxHealth*new_char.secondsPerHealth));
        new_char.energyTimestamp = uint(block.timestamp - (new_char.maxEnergy*secondsPerEnergy));
        new_char.duelTimestamp = uint(block.timestamp);
        new_char.withdrawTimestamp = uint(block.timestamp + oracle.withdrawFeeDays());
        new_char.level = 1;
        new_char.exp = 0;
        new_char.attribute_points = 3;
        new_char.skill_points = 9;
        // TODO clean this code, export function to helpers
        for (uint i = 0; i < 3; i ++) {
            for (uint j = 0; j < 4; j++) {
                new_char.attributes[i][j] = 1;
            }
        }
        for (uint i = 0; i < 4; i++) {
            for (uint j = 0; j < 5; j++) {
                new_char.defensive_points[i][j] = 1;
            }
        }

        characters[index] = new_char;
        _mint(msg.sender, index);
        // _setTokenUri
        // _setTokenURI(id, tokenURI);
        setApprovalForAll(marketplace, true);
        index++;
    }

    function setEnergyTimestamp(uint _charId, uint _newEnergyTimestamp) external restricted {
        Character storage char = characters[_charId];
        char.energyTimestamp = _newEnergyTimestamp;
    }

    function setHealthTimestamp(uint _charId, uint _newHealthTimestamp) external restricted {
        Character storage char = characters[_charId];
        char.healthTimestamp = _newHealthTimestamp;
    }

    function getEnergyPoints(uint256 id) public view returns (uint) {
        return getEnergyPointsFromTimestamp(characters[id].energyTimestamp, characters[id].maxEnergy);
    }

    function getHealthPoints(uint256 id) public view returns (uint) {
        return getHealthPointsFromTimestamp(characters[id].healthTimestamp, characters[id].maxHealth, characters[id].secondsPerHealth);
    }

    function getEnergyPointsFromTimestamp(uint timestamp, uint maxEnergy) public view returns (uint) {
        if(timestamp  > block.timestamp)
            return 0;
        uint points = (block.timestamp - timestamp) / secondsPerEnergy;
        if(points > maxEnergy) {
            points = maxEnergy;
        }
        return points;
    }

    function getHealthPointsFromTimestamp(uint timestamp, uint maxHealth, uint secondsPerHealth) public view returns (uint) {
        if(timestamp  > block.timestamp)
            return 0;
        uint points = (block.timestamp - timestamp) / secondsPerHealth;
        if(points > maxHealth) {
            points = maxHealth;
        }
        return points;
    }
    
    
    function drainEnergy(uint id, uint amount) external restricted {
        Character storage c = characters[id];
        uint energyPoints = getEnergyPointsFromTimestamp(c.energyTimestamp, c.maxEnergy);
        require(energyPoints >= amount);
        uint drainTime = uint(amount * secondsPerEnergy);
        if(energyPoints >= c.maxEnergy) { // if energy full, we reset timestamp and drain from that
            c.energyTimestamp = uint(block.timestamp - (c.maxEnergy*secondsPerEnergy) + drainTime);
        }
        else {
            c.energyTimestamp = uint(c.energyTimestamp + drainTime);
        }
    }
    
    function drainHealth(uint id, uint amount) external restricted {
       Character storage c = characters[id];
       uint healthPoints = getHealthPointsFromTimestamp(c.healthTimestamp, c.maxHealth, c.secondsPerHealth);
       require(healthPoints >= amount);
       uint drainTime = uint(amount * c.secondsPerHealth);
       if(healthPoints >= c.maxHealth) { // if health full, we reset timestamp and drain from that
            c.healthTimestamp = uint(block.timestamp - (c.maxHealth*c.secondsPerHealth) + drainTime);
        }
        else {
            c.healthTimestamp = uint(c.healthTimestamp + drainTime);
        }
    }
    
    function setCharOffDefPoints (uint _charId, uint[5][4] memory _offPoints, uint[5][4] memory _defPoints) external restricted {
        Character storage char = characters[_charId];
        char.ofensive_points = _offPoints;
        char.defensive_points = _defPoints;
    }
    

    // TODO add this function in helpers, clean code here
    function claimExp(uint _charId, uint _exp) external restricted {
        Character storage c = characters[_charId];
        uint _claimedXP = _exp;
        uint _totalExp = _claimedXP + c.exp;
        
        if (c.level < experienceTable.length) { // TODO test
            while (_totalExp > 0) {
                if (_totalExp >= experienceTable[c.level - 1]) {
                    _totalExp = _totalExp - experienceTable[c.level - 1];
                    // level up
                    c.level += 1;
                    c.maxHealth += 30;
                    c.exp = 0;
                    c.attribute_points += 3;
                    c.skill_points += 9;

                    if (fullTimeHp / c.maxHealth > 0) {
                        c.secondsPerHealth = fullTimeHp / c.maxHealth;
                    } else {
                        c.secondsPerHealth = 1;
                    }

                    c.healthTimestamp = uint(block.timestamp - (c.maxHealth*c.secondsPerHealth));
                } else {
                    c.exp = _totalExp;
                    _totalExp = _totalExp - c.exp;
                }
            }
        }
    }
    
    // function levelUp(uint _charId) private {
    //     Character storage c = characters[_charId];
        // c.level += 1;
        // c.maxHealth += 10;
        // c.exp = 0;
        // c.attribute_points += 1;
        // c.skill_points += 3;
    // }
    
    function setCharacterAttributes (uint _charId, uint[4][3] memory _perks, uint _maxHealth, uint _secondsPerHealth, uint _attributePoints, uint _perksPoints) external restricted {
        Character storage c = characters[_charId];
        c.attributes = _perks;
        c.attribute_points = _attributePoints;
        c.skill_points = _perksPoints;
        c.maxHealth = _maxHealth;
        c.secondsPerHealth = _secondsPerHealth;
    }
    
    function getCharsOwnedBy(address _owner) public view returns(Character[] memory) {
        require(msg.sender == _owner);
        Character[] memory chars = new Character[](balanceOf(_owner));
        for (uint8 i = 0; i < chars.length; i++) {
            uint cid = tokenOfOwnerByIndex(_owner, i);
            Character storage currentItem = characters[cid];
            chars[i] = currentItem;
        }
        return chars;
    }

    function getCharData(uint _charId) external restricted view returns(Character memory) {
        Character memory char = characters[_charId];
        return char;
    }

    function setPvPData(uint _charId, uint _mintCoins, uint _coins, bool _pvp, uint _withdrawTimestamp, uint _duelTimestamp) external restricted {
        Character storage c = characters[_charId];
        c.mintCoins = _mintCoins;
        c.coins = _coins;
        c.pvp = _pvp;
        c.withdrawTimestamp = _withdrawTimestamp;
        c.duelTimestamp = _duelTimestamp;
    }

}