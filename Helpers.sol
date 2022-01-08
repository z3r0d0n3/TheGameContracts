// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Utils.sol";
import "./Oracle.sol";
import "./Randoms.sol";
import "./Treasury.sol";
import "./Duelist.sol";
import "./Weapon.sol";

contract Helpers {
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
    Utils utils;
    Oracle oracle;
    Randoms random;
    ERC20 token;
    Treasury treasury;
    Duelist duelist;
    DuelWeapon weapon;
    address treasury_addr;

    // ERC20 token;

    constructor () {
        owner = msg.sender;
    }

    function setContracts (address _utils, address _oracle, address _randoms, address _token, address _treasury, address _duelist, address _weapon) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
        oracle = Oracle(_oracle);
        random = Randoms(_randoms);
        token = ERC20(_token);
        treasury = Treasury(_treasury);
        treasury_addr = _treasury;
        duelist = Duelist(_duelist);
        weapon = DuelWeapon(_weapon);
    }

    function setCharacterAttributes (uint _charId, uint[4][3] memory _attributes) public {
        require(duelist.ownerOf(_charId) == msg.sender && !utils.isContract(msg.sender) && !utils.isContract(tx.origin));
        Duelist.Character memory c = duelist.getCharData(_charId);
        require(_attributes[0][0]+_attributes[1][0]+_attributes[2][0] <= c.attribute_points);
        uint _skill_points = 0;

        for (uint i = 0; i < _attributes.length; i++) {
            for (uint j = 1; j < _attributes[i].length; j++) {   
                _skill_points = _skill_points + _attributes[i][j];
            }
        }
        
        require(_skill_points <= c.skill_points);
        
        uint[4][3] memory _newAttributes = c.attributes;
        uint newHealth = c.maxHealth;
        uint newSPerHealth;
        uint newAttPoints = c.attribute_points - (_attributes[0][0]+_attributes[1][0]+_attributes[2][0]);
        uint newSkPoints = c.skill_points - _skill_points;

        for (uint i = 0; i < c.attributes.length; i ++) {
            for (uint j = 0; j < _attributes[i].length; j++) {
                _newAttributes[i][j] = _newAttributes[i][j] + _attributes[i][j];
                if (i == 0 && j == 3) {
                    newHealth = newHealth + _attributes[0][3]*20;
                }
            }
            if (_attributes[i][0] > 0) {
                newHealth = newHealth + _attributes[0][0]*20;
                
                for (uint y = 1; y < 4; y ++) {
                _newAttributes[i][y] = _newAttributes[i][y] + _attributes[i][0];
                }
            }
        }
        
        if (duelist.fullTimeHp() / newHealth > 0) {
            newSPerHealth = duelist.fullTimeHp() / newHealth;
        } else {
            newSPerHealth = 1;
        }
        duelist.setCharacterAttributes (_charId, _newAttributes, newHealth, newSPerHealth, newAttPoints, newSkPoints);
    }

    function setCharacterOffensiveAndDefensivePoints (uint _charId, uint[5][4] memory _offPoints, uint[5][4] memory _defPoints) public {
        require(duelist.ownerOf(_charId) == msg.sender);
        //off points
        for (uint i = 0; i < _offPoints.length; i++) {
            uint local_sum_a = 0;
            for (uint j = 0; j < _offPoints[i].length; j++) {
                if (_offPoints[i][j] > 0 ) {
                    local_sum_a += _offPoints[i][j];
                }
            }
            require(local_sum_a == 1);
        }

        for (uint i = 0; i < _defPoints.length; i++) {
            uint local_sum = 0;
            for (uint j = 0; j < _defPoints[i].length; j++) {
                if (_defPoints[i][j] > 0 ) {
                    local_sum += _defPoints[i][j];
                }
            }
            require(local_sum == 2);
            // debug
//            require(((_defPoints[i][0] == 1 && _defPoints[i][1] == 1) || (_defPoints[i][4] == 1 && _defPoints[i][3] == 1) || (_defPoints[i][4] == 1 && _defPoints[i][1] == 1)));
        }
        duelist.setCharOffDefPoints(_charId, _offPoints, _defPoints);

    }


    // TODO clean code
    function mintWeaponsN (uint _n) public {
        require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));

        uint priceFor1Weapon = oracle.weapon1MintPrice();
        uint priceFor5Weapons = oracle.weapon5MintPrice();
        uint priceFor10Weapons = oracle.weapon10MintPrice();
        if (_n == 5) {
            require(token.balanceOf(msg.sender) >= priceFor5Weapons*1e18);
            token.transferFrom(msg.sender, treasury_addr, priceFor5Weapons*1e18);
            treasury.updateRewards(priceFor5Weapons);
        } else if (_n == 10) {
            require( token.balanceOf(msg.sender) >= priceFor10Weapons*1e18);
            token.transferFrom(msg.sender, treasury_addr, priceFor10Weapons*1e18);
            treasury.updateRewards(priceFor10Weapons);
        } else {
            require(token.balanceOf(msg.sender) >= _n * priceFor1Weapon*1e18);
            token.transferFrom(msg.sender, treasury_addr, _n * priceFor1Weapon*1e18);
            treasury.updateRewards(_n * priceFor1Weapon);
        }


        for (uint i = 0; i < _n; i++) {
            (uint weaponTier, uint weaponType, uint weaponQuality, uint weaponDamage, uint weaponLevel, uint[4][3] memory weaponPerks) = random.rollWeaponData();
            weapon._mintWeapon(msg.sender, weaponTier, weaponType, weaponQuality, weaponDamage, weaponLevel, weaponPerks);
        }
    }

}