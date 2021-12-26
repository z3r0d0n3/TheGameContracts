// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Utils.sol";
import "./Oracle.sol";
import "./Treasury.sol";
import "./Saloon.sol";
import "./Duelist.sol";
import "./Weapon.sol";

contract FeaturesMarket {
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
    ERC20 token;
    Treasury treasury;
    Saloon saloon;
    Duelist duelist;
    DuelWeapon weapon;
    address treasury_addr;
    address saloon_addr;
    mapping(address => uint) public shardsPerAddress;

    constructor() {
        owner = msg.sender;
    }

    function setContracts (address _utils, address _oracle, address _token, address _treasury, address _saloon, address _duelist, address _weapon) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
        oracle = Oracle(_oracle);
        token = ERC20(_token);
        treasury = Treasury(_treasury);
        treasury_addr = _treasury;
        saloon = Saloon(_saloon);
        saloon_addr = _saloon;
        duelist = Duelist(_duelist);
        weapon = DuelWeapon(_weapon);
    }

    function addShardsToPlayer(address _player, uint _amount) external restricted {
        shardsPerAddress[_player] = shardsPerAddress[_player] + _amount;
    }

    function removeShardsFromPlayer(address _player, uint _amount) public restricted {
        if (shardsPerAddress[_player] > _amount) {
            shardsPerAddress[_player] = shardsPerAddress[_player] - _amount;
        } else {
            shardsPerAddress[_player] = 0;
        }
    }

    function _resetCharPerks(uint _charId) private {
        Duelist.Character memory char = duelist.getCharData(_charId);
        uint[4][3] memory _perks;
        uint _maxHealth = 270 + char.level * 30;
        uint _secondsPerHealth = duelist.fullTimeHp() / _maxHealth;
        uint _attributePoints = char.level * 3;
        uint _perksPoints = char.level * 9;
        duelist.setCharacterAttributes(_charId, _perks, _maxHealth, _secondsPerHealth, _attributePoints, _perksPoints);
    }

    function resetCharPerksWithTokens(uint _charId) public {
        uint CharPerksResetTokensPrice = oracle.CharPerksResetPriceTokens();
        require(msg.sender == duelist.ownerOf(_charId));
        require(token.balanceOf(msg.sender) >= CharPerksResetTokensPrice*1e18);
        // TODO send tokens to the Treasury, Update weekly treasure with 70 %, Update week + 1 treasure with 30 %
        token.transferFrom(msg.sender, treasury_addr, CharPerksResetTokensPrice*1e18);
        treasury.updateRewards(CharPerksResetTokensPrice);
        _resetCharPerks(_charId);
    }

    function resetCharPerksWithShards(uint _charId) public {
        uint CharPerksResetShardsPrice = oracle.CharPerksResetPriceShards();
        require(msg.sender == duelist.ownerOf(_charId));
        require(shardsPerAddress[msg.sender] >= CharPerksResetShardsPrice);
        removeShardsFromPlayer(msg.sender, CharPerksResetShardsPrice);
        _resetCharPerks(_charId);
    }

    function energyRestorePotionShards(address _playerAddress, uint _charId, uint _restorePercentage, uint _potionPriceShards) private {
        require(shardsPerAddress[_playerAddress] >= _potionPriceShards);
        require(duelist.ownerOf(_charId) == _playerAddress);
        removeShardsFromPlayer(_playerAddress, _potionPriceShards);
        Duelist.Character memory char = duelist.getCharData(_charId);
        require(char.energyTimestamp > block.timestamp);
        uint _newEnergyTimestamp = char.energyTimestamp - ((char.energyTimestamp - block.timestamp) * _restorePercentage / 100); // current energy + 25 % of max energy
        duelist.setEnergyTimestamp(_charId, _newEnergyTimestamp);
    }

    function healthRestorePotionShards(address _playerAddress, uint _charId, uint _restorePercentage, uint _potionPriceShards) private {
        require(shardsPerAddress[_playerAddress] >= _potionPriceShards);
        require(duelist.ownerOf(_charId) == _playerAddress);
        removeShardsFromPlayer(_playerAddress, _potionPriceShards);
        Duelist.Character memory char = duelist.getCharData(_charId);
        require(char.healthTimestamp > block.timestamp);
        uint _newHealthTimestamp = char.healthTimestamp - ((char.healthTimestamp - block.timestamp) * _restorePercentage / 100); // current hp + 25 % of max hp
        duelist.setHealthTimestamp(_charId, _newHealthTimestamp);
    }

    function smallEnergyRestorePotionShards(uint _charId) public {
        uint PotionPriceShards = oracle.SmallEnergyRestoreShards();
        energyRestorePotionShards(msg.sender, _charId, 25, PotionPriceShards);
    }

    function mediumEnergyRestorePotionShards(uint _charId) public {
        uint PotionPriceShards = oracle.MediumEnergyRestoreShards();
        energyRestorePotionShards(msg.sender, _charId, 50, PotionPriceShards);
    }

    function bigEnergyRestorePotionShards(uint _charId) public {
        uint PotionPriceShards = oracle.BigEnergyRestoreShards();
        energyRestorePotionShards(msg.sender, _charId, 75, PotionPriceShards);
    }

    function smallHealthRestorePotionShards(uint _charId) public {
        uint PotionPriceShards = oracle.SmallHealthRestoreShards();
        healthRestorePotionShards(msg.sender, _charId, 25, PotionPriceShards);
    }

    function mediumHealthRestorePotionShards(uint _charId) public {
        uint PotionPriceShards = oracle.SmallHealthRestoreShards();
        healthRestorePotionShards(msg.sender, _charId, 50, PotionPriceShards);
    }

    function bigHealthRestorePotionShards(uint _charId) public {
        uint PotionPriceShards = oracle.SmallHealthRestoreShards();
        healthRestorePotionShards(msg.sender, _charId, 75, PotionPriceShards);
    }

    function energyRestorePotionTokens(address _playerAddress, uint _charId, uint _restorePercentage, uint _potionPriceTokens) private {
        require(token.balanceOf(_playerAddress) >= _potionPriceTokens*1e18);
        require(duelist.ownerOf(_charId) == _playerAddress);
        Duelist.Character memory char = duelist.getCharData(_charId);
        require(char.energyTimestamp > block.timestamp);
        token.transferFrom(_playerAddress, treasury_addr, _potionPriceTokens*1e18);
        treasury.updateRewards(_potionPriceTokens);
        uint _newEnergyTimestamp = char.energyTimestamp - ((char.energyTimestamp - block.timestamp) * _restorePercentage / 100);
        duelist.setEnergyTimestamp(_charId, _newEnergyTimestamp);
    }

    function healthRestorePotionTokens(address _playerAddress, uint _charId, uint _restorePercentage, uint _potionPriceTokens) private {
        require(token.balanceOf(_playerAddress) >= _potionPriceTokens*1e18);
        require(duelist.ownerOf(_charId) == _playerAddress);
        Duelist.Character memory char = duelist.getCharData(_charId);
        require(char.healthTimestamp > block.timestamp);
        token.transferFrom(_playerAddress, treasury_addr, _potionPriceTokens*1e18);
        treasury.updateRewards(_potionPriceTokens);
        uint _newHealthTimestamp = char.healthTimestamp - ((char.healthTimestamp - block.timestamp) * _restorePercentage / 100);
        duelist.setHealthTimestamp(_charId, _newHealthTimestamp);
    }

    function smallEnergyRestorePotionTokens(uint _charId) public {
        uint PotionPriceShards = oracle.SmallEnergyRestoreTokens();
        energyRestorePotionTokens(msg.sender, _charId, 25, PotionPriceShards);
    }

    function mediumEnergyRestorePotionTokens(uint _charId) public {
        uint PotionPriceTokens = oracle.MediumEnergyRestoreTokens();
        energyRestorePotionTokens(msg.sender, _charId, 50, PotionPriceTokens);
    }

    function bigEnergyRestorePotionTokens(uint _charId) public {
        uint PotionPriceTokens = oracle.BigEnergyRestoreTokens();
        energyRestorePotionTokens(msg.sender, _charId, 75, PotionPriceTokens);
    }

    function smallHealthRestorePotionTokens(uint _charId) public {
        uint PotionPriceTokens = oracle.SmallHealthRestoreTokens();
        healthRestorePotionTokens(msg.sender, _charId, 25, PotionPriceTokens);
    }

    function mediumHealthRestorePotionTokens(uint _charId) public {
        uint PotionPriceTokens = oracle.SmallHealthRestoreTokens();
        healthRestorePotionTokens(msg.sender, _charId, 50, PotionPriceTokens);
    }

    function bigHealthRestorePotionTokens(uint _charId) public {
        uint PotionPriceTokens = oracle.SmallHealthRestoreTokens();
        healthRestorePotionTokens(msg.sender, _charId, 75, PotionPriceTokens);
    }

    function PvPOpponentDisclosure(address _player, uint _disclosureFee, uint _opponentLobbyId) private returns (Duelist.Character memory, DuelWeapon.Weapon memory) {
        require(token.balanceOf(_player) >= _disclosureFee*1e18);
        token.transferFrom(msg.sender, saloon_addr, _disclosureFee*1e18);
        (,,uint opponentCharId,,uint opponentWeaponId,,,,) = saloon.duelsLobby(_opponentLobbyId);
        Duelist.Character memory opponent = duelist.getCharData(opponentCharId);
        DuelWeapon.Weapon memory opponentWpn = weapon.getWeaponData(opponentWeaponId);
        duelist.setPvPData(opponentCharId, opponent.mintCoins, opponent.coins + _disclosureFee, opponent.pvp, opponent.withdrawTimestamp, opponent.duelTimestamp);
        return (opponent, opponentWpn);
    }

    function smallPvPOpponentDisclosure(uint _opponentLobbyId) public returns (uint, uint, uint, uint) {
        uint disclosureFee = oracle.smallPvPDisclosureFee();
        // opponent level
        // opponent HP
        // weapon quality
        // weapon tier
        (Duelist.Character memory opponent, DuelWeapon.Weapon memory opponentWpn) = PvPOpponentDisclosure(msg.sender, disclosureFee, _opponentLobbyId);
        return (opponent.level, opponent.maxHealth, opponentWpn.quality, opponentWpn.tier);
    }

    function mediumPvPOpponentDisclosure(uint _opponentLobbyId) public returns (uint, uint, uint, uint, uint, uint) {
        uint disclosureFee = oracle.mediumPvPDisclosureFee();
        // opponent level
        // opponent HP
        // opponent aim perk

        // weapon quality
        // weapon tier
        // weapon damage
        (Duelist.Character memory opponent, DuelWeapon.Weapon memory opponentWpn) = PvPOpponentDisclosure(msg.sender, disclosureFee, _opponentLobbyId);
        return (opponent.level, opponent.maxHealth, opponent.attributes[2][1], opponentWpn.quality, opponentWpn.tier, opponentWpn.damage);
    }

    function bigPvPOpponentDisclosure(uint _opponentLobbyId) public returns (uint, uint, uint, uint, uint, uint, uint, uint) {
        uint disclosureFee = oracle.bigPvPDisclosureFee();
        // opponent level
        // opponent HP
        // opponent aim
        // opponent dodge

        // weapon quality
        // weapon tier
        // weapon damage
        // weapon type
        (Duelist.Character memory opponent, DuelWeapon.Weapon memory opponentWpn) = PvPOpponentDisclosure(msg.sender, disclosureFee, _opponentLobbyId);
        return (opponent.level, opponent.maxHealth, opponent.attributes[2][1], opponent.attributes[1][1], opponentWpn.quality, opponentWpn.tier, opponentWpn.damage, opponentWpn.wtype);
    }
}