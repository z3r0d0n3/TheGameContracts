pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import './Token.sol';

contract PreSale is ReentrancyGuard {
    struct Sale {
        address investor;
        uint amount;
        bool tokensWithdrawn;
    }
    mapping(address => Sale) public sales;
    address payable owner;
    uint public end;
    uint public duration;
    uint public price;
    uint public hardPrice;
    // uint public availableTokens;
    uint public minPurchase;
    uint public maxPurchase;
    
    uint public softCap;
    uint public hardCap;
    
    
    GameToken public token;

    constructor (
        address tokenAddress
        ) payable {
        token = GameToken(tokenAddress);

        owner = payable(msg.sender);
        duration = 2368800; // 2368800 4 weeks
        price = 100000000000000000; // 1 harmony ~ 0.3 $ - 15 tokens  if total supply 10M   0.015 matic 1 token 15000000000000000 // TODO recalc for HarmonyOne prices
        hardPrice = 150000000000000000;
        softCap = 1000000000000000000000000; // 10 % 1M
        hardCap = 2000000000000000000000000; // 20 % 2M
                
        minPurchase = 150000000000000000000; // in Harmony One 150 = 
        maxPurchase = 3000000000000000000000; // 3000 Harmony
    }
    
    function startPreSale() external onlyOwner() preSaleNotActive() {
        end = block.timestamp + duration;
    }
    
    function buy() external payable preSaleActive() nonReentrant {
        require(msg.value >= minPurchase && msg.value <= maxPurchase, 'should buy between minPurchase and maxPurchase');
        require(sales[msg.sender].amount == 0);
        uint tokenSoftAmount;
        uint tokenHardAmount;
        uint value;
        if (msg.value / price <= softCap) {
            tokenSoftAmount = msg.value / price;
            token.mint(address(this), tokenSoftAmount);
            sales[msg.sender] = Sale(
                msg.sender,
                sales[msg.sender].amount+tokenSoftAmount,
                false
            );
            softCap = softCap - tokenSoftAmount;
        } else if (softCap > 0 && msg.value / price > softCap) {
            tokenSoftAmount = softCap * price;
            token.mint(address(this), tokenSoftAmount);
            sales[msg.sender] = Sale(
                msg.sender,
                sales[msg.sender].amount+tokenSoftAmount,
                false
            );
            softCap = 0;
            value = msg.value - (softCap * price);
            tokenHardAmount = value / hardPrice;
            token.mint(address(this), tokenHardAmount);
            sales[msg.sender] = Sale(
                msg.sender,
                sales[msg.sender].amount+tokenHardAmount,
                false
            );
            hardCap = hardCap - tokenHardAmount;
        } else if (softCap == 0 && msg.value / hardPrice <= hardCap) {
            tokenHardAmount = msg.value / hardPrice;
            token.mint(address(this), tokenHardAmount);
            sales[msg.sender] = Sale(
                msg.sender,
                sales[msg.sender].amount+tokenHardAmount,
                false
            );
            hardCap = hardCap - tokenHardAmount;
        } else {
            tokenHardAmount = msg.value / hardPrice;
            token.mint(address(this), tokenHardAmount);
            sales[msg.sender] = Sale(
                msg.sender,
                sales[msg.sender].amount+tokenHardAmount,
                false
            );
            hardCap = 0;
        }
    }
    
    function withdrawTokens() external preSaleEnded nonReentrant {
        Sale storage sale = sales[msg.sender];
        require(sale.amount > 0, 'only investors');
        require(sale.tokensWithdrawn == false, 'tokens were already withdrawn');
        sale.tokensWithdrawn = true;
        token.transfer(sale.investor, sale.amount);
    }
    
    function withdrawLiquidity() external onlyOwner preSaleEnded {
        payable(address(owner)).transfer(address(this).balance);
    }
    
    modifier preSaleActive() {
        require(
          end > 0 && block.timestamp < end && softCap > 0  || end > 0 && block.timestamp < end && hardCap > 0, 
          'Pre Sale must be active'
        );
        _;
    }
    
    modifier preSaleNotActive() {
        require(end == 0, 'Pre Sale should not be active');
        _;
    }
    
    modifier preSaleEnded() {
        require(
          end > 0 && (block.timestamp >= end || (softCap == 0 && hardCap == 0)), 
          'Pre Sale must have ended'
        );
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}