// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Randoms.sol";
import "./Utils.sol";
import "./Oracle.sol";
import "./Treasury.sol";
import "./FeaturesMarket.sol";


contract DuelWeapon is ERC721Enumerable {
    Randoms random;
    Utils utils;
    Oracle oracle;
    Treasury treasury;
    ERC20 token;
    FeaturesMarket featuresMarket;
    address owner;
    address marketplace;
    address treasury_addr;

    uint index = 1;

    modifier restricted {
        require(utils.GameContracts(msg.sender) == true);
        _;
    }
    
    struct Weapon {
        uint index;
        bool pvp;
        uint tier;
        uint wtype;        // 0 firearm, 1 whitearm
        uint quality;   // 0 poor, 1 common, 2 uncommon, 3 rare, 4 epic, 5 legendary, 6 artifact
        uint damage;
        uint level;
        uint[4][3] perks;
    }
    mapping(uint => Weapon) weapons;

    constructor () ERC721("TheGameWeapons", "TGW") {
        owner = msg.sender;
    }

    function setContracts (address _utils, address _oracle, address _random, address _token, address _treasury, address _marketplace, address _featuresMarket) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
        oracle = Oracle(_oracle);
        random = Randoms(_random);
        token = ERC20(_token);
        treasury = Treasury(_treasury);
        treasury_addr = _treasury;
        marketplace = _marketplace;
        featuresMarket = FeaturesMarket(_featuresMarket);
    }

    function __mintWeapon(address _owner, uint _tier, uint _type, uint _quality, uint _damage, uint _level, uint[4][3] memory _perks) private {
        Weapon memory new_weapon;
        new_weapon.index = index;
        new_weapon.pvp = false;
        new_weapon.tier = _tier;
        new_weapon.wtype = _type;
        new_weapon.quality = _quality;
        new_weapon.damage = _damage;
        new_weapon.perks = _perks;
        new_weapon.level = _level;
        weapons[index] = new_weapon;
        _mint(_owner, index);
        setApprovalForAll(marketplace, true);
        // emit NewWeapon(id, msg.sender);
        index++;
    }

    function _mintWeapon(address _owner, uint _tier, uint _type, uint _quality, uint _damage, uint _level, uint[4][3] memory _perks) external restricted {
        __mintWeapon(_owner, _tier, _type, _quality, _damage, _level, _perks);
    }

    function getWeaponsOwnedBy(address _owner) public view returns(Weapon[] memory) { 
        require(msg.sender == _owner);
        Weapon[] memory wpns = new Weapon[](balanceOf(_owner));
        for (uint i = 0; i < wpns.length; i++) {
            uint wid = tokenOfOwnerByIndex(_owner, i);
            Weapon storage currentItem = weapons[wid];
            wpns[i] = currentItem;
        }
        return wpns;    
    }

    function getWeaponData(uint _id) external view restricted returns(Weapon memory) {
        Weapon memory w = weapons[_id];
        return w;
    }
    

    function burnWeapon(uint wpnId) external restricted {
        _burn(wpnId);
    }
    
    function setPvPData(uint _weaponId, bool _pvp) external restricted {
        Weapon storage weapon = weapons[_weaponId];
        weapon.pvp = _pvp;
    }

    function sellWeaponForShards(uint[] memory _weaponIds) public {
        for (uint i = 0; i < _weaponIds.length; i++) {
            require(ownerOf(_weaponIds[i]) == msg.sender);
            Weapon memory w = weapons[_weaponIds[i]];
            require(w.pvp == false);
            _burn(_weaponIds[i]);
            featuresMarket.addShardsToPlayer(msg.sender, oracle.ReceivedShardsPerWeapon());
        }
    }   
    

    function mintTestWeapon() public {
        uint[4][3] memory weaponPerks;
        __mintWeapon(msg.sender, 0, 0, 0, 50, 0, weaponPerks);
        __mintWeapon(msg.sender, 0, 1, 0, 50, 0, weaponPerks);
    }

    function mintWeaponsN (uint _n) public {
        require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));
        uint priceFor1Weapon = oracle.weapon1MintPrice();
        uint priceFor5Weapons = oracle.weapon5MintPrice();
        uint priceFor10Weapons = oracle.weapon10MintPrice();
        if (_n == 5) {
            // require(token.balanceOf(msg.sender) >= priceFor5Weapons*1e18);
            token.transferFrom(msg.sender, treasury_addr, priceFor5Weapons*1e18);
            treasury.updateRewards(priceFor5Weapons);
        } else if (_n == 10) {
            // require( token.balanceOf(msg.sender) >= priceFor10Weapons*1e18);
            token.transferFrom(msg.sender, treasury_addr, priceFor10Weapons*1e18);
            treasury.updateRewards(priceFor10Weapons);
        } else {
            // require(token.balanceOf(msg.sender) >= _n * priceFor1Weapon*1e18);
            token.transferFrom(msg.sender, treasury_addr, _n * priceFor1Weapon*1e18);
            treasury.updateRewards(_n * priceFor1Weapon);
        }
        for (uint i = 0; i < _n; i++) {
            (uint weaponTier, uint weaponType, uint weaponQuality, uint weaponDamage, uint weaponLevel, uint[4][3] memory weaponPerks) = random.rollWeaponData();
            __mintWeapon(msg.sender, weaponTier, weaponType, weaponQuality, weaponDamage, weaponLevel, weaponPerks);
        }
    }

    // TODO add gems improvements for weapons
    // common gem +1 perk 60 %
    // rare gem +1 attribute 30 %
    // legendary gem +3 attributes 10 %

    // gems can be bought in features market with shards and tokens
    
}