// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Utils.sol";

contract Oracle {
    address owner;
    
    Utils utils;
    
    uint public rand = 0;
    uint public rrand = 0;
    
    uint public characterMintPrice = 1000;
    
    uint public reforgePrice = 100;
    
    uint public marketSellFeePercentage = 2;
    uint public marketBuyFeePercentage = 3;
    
    uint public weapon1MintPrice = 250;
    uint public weapon5MintPrice = 1000;
    uint public weapon10MintPrice = 1750;
    
    uint public battleReward = 200;

    uint public duelKnockoutWaitTime = 60*10 + 10;
    
    uint public PvPLevelDifference = 1;

    // Features Market
    uint public ReceivedShardsPerWeapon = 1000;
    uint public CharPerksResetPriceTokens = 1000;
    uint public CharPerksResetPriceShards = 10000;

    uint public SmallEnergyRestoreShards = 500;
    uint public MediumEnergyRestoreShards = 1000;
    uint public BigEnergyRestoreShards = 1500;
    uint public SmallHealthRestoreShards = 500;
    uint public MediumHealthRestoreShards = 1000;
    uint public BigHealthRestoreShards = 1500;

    uint public SmallEnergyRestoreTokens = 50;
    uint public MediumEnergyRestoreTokens = 100;
    uint public BigEnergyRestoreTokens = 150;
    uint public SmallHealthRestoreTokens = 50;
    uint public MediumHealthRestoreTokens = 100;
    uint public BigHealthRestoreTokens = 150;

    uint public smallPvPDisclosureFee = 25;
    uint public mediumPvPDisclosureFee = 50;
    uint public bigPvPDisclosureFee = 75;

    modifier restricted {
        for (uint i = 0; i < utils.getGameContracts().length; i++) {
            if (msg.sender == utils.getGameContracts()[i]) {
                _;
                return;
            }
        }
        revert();
    }
    
    constructor() {
        owner = msg.sender;
    }

    function setUtils(address _utils) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
    }
    
    function setCharacterMintPrice(uint _price) external restricted {
        characterMintPrice = _price;
    }
    
    function setWeaponsMintPrice(uint _price1, uint _price5, uint _price10) external restricted {
        weapon1MintPrice = _price1;
        weapon5MintPrice = _price5;
        weapon10MintPrice = _price10;
    }
    
    function setReforgePrice(uint _price) external restricted {
        reforgePrice = _price;
    }
    
    function setMarketFees(uint _marketSellFee, uint _marketBuyFee) external restricted {
        marketSellFeePercentage = _marketSellFee;
        marketBuyFeePercentage = _marketBuyFee;
        
    }
    
    function setBattleReward(uint _price) external restricted {
        battleReward = _price;
    }
    
    function setSmallDisclosureFee(uint _fee) external restricted {
        smallPvPDisclosureFee = _fee;
    }
    function setMediumDisclosureFee(uint _fee) external restricted {
        mediumPvPDisclosureFee = _fee;
    }
    function setBigDisclosureFee(uint _fee) external restricted {
        bigPvPDisclosureFee = _fee;
    }
    function setDuelKnockoutWaitTime (uint _time) external restricted {
        duelKnockoutWaitTime = _time + 10;
    }
    function setLevelDifference(uint _level) external restricted {
        PvPLevelDifference = _level;
    }
    function setReceivedShardsPerWeapon(uint _shards) external restricted {
        ReceivedShardsPerWeapon = _shards;
    }
    
    function incrementRand() external restricted {
        if (rand == 115792089237316195423570985008687907853269984665640564039457584007913129639935) {
            incrementRrand();
            rand = 0;
        }
        rand = rand + 1;
    }
    function incrementRrand() private {
        rrand = rrand + 1;
    }
}