// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./Utils.sol";
import "./Oracle.sol";
import "./Token.sol";
import "./Duelist.sol";
import "./Weapon.sol";

contract TheGameMarket is ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;
  Counters.Counter private _itemsSold;

  address payable owner;
//   uint256 listingPrice = 0.025 ether;
  Utils utils;
  Oracle oracle;
  GameToken token;
  Duelist duelist;
  DuelWeapon weapon;

  constructor() {
    owner = payable(msg.sender);
  }

  struct MarketItem {
    uint itemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
  }

  mapping(uint256 => MarketItem) private idToMarketItem;

  event MarketItemCreated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
  );
  event MarketItemUpdated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address owner,
    uint256 price,
    bool sold
  );

  function setContracts(address _utils, address _oracle, address _token, address _duelist, address _weapon) public {
      require(msg.sender == owner);
      utils = Utils(_utils);
      oracle = Oracle(_oracle);
      token = GameToken(_token);
      duelist = Duelist(_duelist);
      weapon = DuelWeapon(_weapon);
  }
  /* Returns the listing price of the contract */
  function getListingFee(uint _listingPrice) public view returns (uint256) {
    uint sellP = oracle.marketSellFeePercentage();
    return _listingPrice = utils.percentage(_listingPrice*1e18, sellP);
  }
  function getBuyingFee(uint _listingPrice) public view returns (uint256) {
    uint buyP = oracle.marketBuyFeePercentage();
    return _listingPrice = utils.percentage(_listingPrice*1e18, buyP);
  }
  /* Places an item for sale on the marketplace */
  function createMarketItem(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) public payable nonReentrant {
    if (nftContract == address(duelist)) {
      Duelist.Character memory char = duelist.getCharData(tokenId);
      require(char.pvp == false);
    } else if (nftContract == address(weapon)) {
      DuelWeapon.Weapon memory wpn = weapon.getWeaponData(tokenId);
      require(wpn.pvp == false);
    }
    require(IERC721(nftContract).ownerOf(tokenId) == msg.sender);
    require(price > 0, "Price must be at least 1 wei");
    uint listingFee = getListingFee(price);
    require(token.balanceOf(msg.sender) >= listingFee, "Price must be equal to listing price");
    token.transferFrom(msg.sender, owner, listingFee);
    _itemIds.increment();
    uint256 itemId = _itemIds.current();
  
    idToMarketItem[itemId] =  MarketItem(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),
      payable(address(0)),
      price*1e18,
      false
    );

    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

    emit MarketItemCreated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      false
    );
  }

  /* Creates the sale of a marketplace item */
  /* Transfers ownership of the item, as well as funds between parties */
  function createMarketSale(
    address nftContract,
    uint256 itemId
    ) public payable nonReentrant {
    uint price = idToMarketItem[itemId].price;
    uint tokenId = idToMarketItem[itemId].tokenId;
    uint listingFee = getBuyingFee(price);
    require(token.balanceOf(msg.sender) >= price + listingFee, "Please submit the asking price + fee in order to complete the purchase");
    
    token.transferFrom(msg.sender, owner, listingFee);
    token.transferFrom(msg.sender, idToMarketItem[itemId].seller, price);
    // idToMarketItem[itemId].seller.transfer(msg.value);
    IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
    idToMarketItem[itemId].owner = payable(msg.sender);
    idToMarketItem[itemId].sold = true;
    _itemsSold.increment();

    emit MarketItemUpdated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
    //   address(0),
      price,
      true
    );
  }

  /* Returns all unsold market items */
  function fetchMarketItems() public view returns (MarketItem[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
    uint currentIndex = 0;

    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    for (uint i = 0; i < itemCount; i++) {
      if (idToMarketItem[i + 1].owner == address(0)) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns onlyl items that a user has purchased */
  function fetchMyNFTs() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items a user has created */
  function fetchItemsCreated() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }
}