// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Utils.sol";
import "./Oracle.sol";
import "./Randoms.sol";
import "./Treasury.sol";
import "./Duelist.sol";
import "./Weapon.sol";
import "./FeaturesMarket.sol";

contract Helpers {
    modifier restricted(address requester) {
        require(utils.GameContracts(requester) == true);
        _;
    }

    address owner;
    Utils utils;
    Oracle oracle;
    Randoms random;
    ERC20 token;
    Treasury treasury;
    Duelist duelist;
    DuelWeapon weapon;
    FeaturesMarket featuresMarket;
    address treasury_addr;

    constructor () {
        owner = msg.sender;
    }

    function setContracts (address _utils, address _oracle, address _randoms, address _token, address _treasury, address _duelist, address _weapon, address _featuresMarket) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
        oracle = Oracle(_oracle);
        random = Randoms(_randoms);
        token = ERC20(_token);
        treasury = Treasury(_treasury);
        treasury_addr = _treasury;
        duelist = Duelist(_duelist);
        weapon = DuelWeapon(_weapon);
        featuresMarket = FeaturesMarket(_featuresMarket);
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
                for (uint y = 1; y < 4; y ++) {
                    _newAttributes[i][y] = _newAttributes[i][y] + _attributes[i][0];
                }
            }
        }

        if (_attributes[0][0] > 0) {
            newHealth = newHealth + _attributes[0][0]*20;
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


    /* 
        Additional Weapons Features
    */

    // TODO clean code
    // function mintWeaponsN (uint _n) public {
    //     require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));
    //     uint priceFor1Weapon = oracle.weapon1MintPrice();
    //     uint priceFor5Weapons = oracle.weapon5MintPrice();
    //     uint priceFor10Weapons = oracle.weapon10MintPrice();
    //     if (_n == 5) {
    //         require(token.balanceOf(msg.sender) >= priceFor5Weapons*1e18);
    //         token.transferFrom(msg.sender, treasury_addr, priceFor5Weapons*1e18);
    //         treasury.updateRewards(priceFor5Weapons);
    //     } else if (_n == 10) {
    //         require( token.balanceOf(msg.sender) >= priceFor10Weapons*1e18);
    //         token.transferFrom(msg.sender, treasury_addr, priceFor10Weapons*1e18);
    //         treasury.updateRewards(priceFor10Weapons);
    //     } else {
    //         require(token.balanceOf(msg.sender) >= _n * priceFor1Weapon*1e18);
    //         token.transferFrom(msg.sender, treasury_addr, _n * priceFor1Weapon*1e18);
    //         treasury.updateRewards(_n * priceFor1Weapon);
    //     }
    //     for (uint i = 0; i < _n; i++) {
    //         (uint weaponTier, uint weaponType, uint weaponQuality, uint weaponDamage, uint weaponLevel, uint[4][3] memory weaponPerks) = random.rollWeaponData();
    //         weapon._mintWeapon(msg.sender, weaponTier, weaponType, weaponQuality, weaponDamage, weaponLevel, weaponPerks);
    //     }
    // }

    function mintWeaponWithShards() public {
        uint mintPrice = oracle.ReceivedShardsPerWeapon()*oracle.ShardsWeaponMintPriceMultiplier();
        require(featuresMarket.shardsPerAddress(msg.sender) >= mintPrice);
        featuresMarket.removeShardsFromPlayer(msg.sender, mintPrice);
        (uint weaponTier, uint weaponType, uint weaponQuality, uint weaponDamage, uint weaponLevel, uint[4][3] memory weaponPerks) = random.rollWeaponData();
        weapon._mintWeapon(msg.sender, weaponTier, weaponType, weaponQuality, weaponDamage, weaponLevel, weaponPerks);
    }

    function mergeWeapons(uint[3] memory _weaponIdsToMerge) public {
        uint reforgePrice = oracle.reforgePrice();
        require(_weaponIdsToMerge[0] < _weaponIdsToMerge[1] && _weaponIdsToMerge[1] < _weaponIdsToMerge[2] && token.balanceOf(msg.sender) >= reforgePrice*1e18);
        require(weapon.ownerOf(_weaponIdsToMerge[0]) == msg.sender && weapon.ownerOf(_weaponIdsToMerge[1]) == msg.sender && weapon.ownerOf(_weaponIdsToMerge[2]) == msg.sender);
        require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));
        DuelWeapon.Weapon memory w1 = weapon.getWeaponData(_weaponIdsToMerge[0]);
        DuelWeapon.Weapon memory w2 = weapon.getWeaponData(_weaponIdsToMerge[1]);
        DuelWeapon.Weapon memory w3 = weapon.getWeaponData(_weaponIdsToMerge[2]);
        require(w1.pvp == false && w2.pvp == false && w3.pvp == false);
        require(w1.tier == w2.tier && w2.tier == w3.tier);
        require(w1.wtype == w2.wtype && w2.wtype == w3.wtype);
        require(w1.quality == w2.quality && w2.quality == w3.quality);
        token.transferFrom(msg.sender, treasury_addr, reforgePrice*1e18);
        treasury.updateRewards(reforgePrice);
        uint[4][3] memory mergedPerks = utils.sumAttributes(w1.perks, w2.perks);
        mergedPerks = utils.sumAttributes(mergedPerks, w3.perks);
        uint newWeaponTier = w1.tier + 1;
        uint newWeaponDamage = ((w1.damage + w2.damage + w3.damage) / 3) + utils.percentage(((w1.damage + w2.damage + w3.damage) / 3), 33);
        weapon.burnWeapon(_weaponIdsToMerge[0]);
        weapon.burnWeapon(_weaponIdsToMerge[1]);
        weapon.burnWeapon(_weaponIdsToMerge[2]);
        weapon._mintWeapon(msg.sender, newWeaponTier, w1.wtype, w1.quality, newWeaponDamage, w1.level, mergedPerks);
    }



}