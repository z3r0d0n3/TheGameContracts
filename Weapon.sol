// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
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
        address[] memory gameContracts = utils.getGameContracts();

        for (uint i = 0; i < gameContracts.length; i++) {
            if (msg.sender == gameContracts[i]) {
                _;
                return;
            }
        }
        revert();
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

    function _mintWeapon(address _owner, uint _tier, uint _type, uint _quality, uint _damage, uint _level, uint[4][3] memory _perks) public restricted {
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
    
    function mergeWeapons(uint[3] memory _weaponIdsToMerge) public {
        uint reforgePrice = oracle.reforgePrice();
        require(_weaponIdsToMerge[0] < _weaponIdsToMerge[1] && _weaponIdsToMerge[1] < _weaponIdsToMerge[2] && token.balanceOf(msg.sender) >= reforgePrice*1e18);
        require(ownerOf(_weaponIdsToMerge[0]) == msg.sender && ownerOf(_weaponIdsToMerge[1]) == msg.sender && ownerOf(_weaponIdsToMerge[2]) == msg.sender);
        require(!utils.isContract(msg.sender) && !utils.isContract(tx.origin));
        Weapon memory w1 = weapons[_weaponIdsToMerge[0]];
        Weapon memory w2 = weapons[_weaponIdsToMerge[1]];
        Weapon memory w3 = weapons[_weaponIdsToMerge[2]];
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
        _burn(_weaponIdsToMerge[0]);
        _burn(_weaponIdsToMerge[1]);
        _burn(_weaponIdsToMerge[2]);
        __mintWeapon(msg.sender, newWeaponTier, w1.wtype, w1.quality, newWeaponDamage, w1.level, mergedPerks);
    }
    
    function setPvPData(uint _weaponId, bool _pvp) external restricted {
        Weapon storage weapon = weapons[_weaponId];
        weapon.pvp = _pvp;
    }

    function sellWeaponForShards(uint _weaponId) public {
        require(ownerOf(_weaponId) == msg.sender);
        Weapon memory w = weapons[_weaponId];
        require(w.pvp == false);

        _burn(_weaponId);
        featuresMarket.addShardsToPlayer(msg.sender, oracle.ReceivedShardsPerWeapon());
    }

    function mintWeaponWithShards() public {
        uint mintPrice = oracle.ReceivedShardsPerWeapon()*oracle.ShardsWeaponMintPriceMultiplier();
        require(featuresMarket.shardsPerAddress(msg.sender) >= mintPrice);
        featuresMarket.removeShardsFromPlayer(msg.sender, mintPrice);
        (uint weaponTier, uint weaponType, uint weaponQuality, uint weaponDamage, uint weaponLevel, uint[4][3] memory weaponPerks) = random.rollWeaponData();
        __mintWeapon(msg.sender, weaponTier, weaponType, weaponQuality, weaponDamage, weaponLevel, weaponPerks);
    }
}