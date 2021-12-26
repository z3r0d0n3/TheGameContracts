pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import "./Utils.sol";

contract GameToken is ERC20 {
    Utils utils;    

    modifier restricted {
        for (uint i = 0; i < utils.getGameContracts().length; i++) {
            if (msg.sender == utils.getGameContracts()[i]) {
                _;
                return;
            }
        }
        revert();
    }

    address public owner;
    address character;
    address weapon;

    uint public maxTotalSupply;
    
    constructor() ERC20("The Game Token", "TGT") {
        owner = msg.sender;
        maxTotalSupply = 10000000 * 1e18;
        _mint(msg.sender, 1000000 * 1e18);
    }
    
    function setUtils(address _utils) public {
        require(msg.sender == owner);
        utils = Utils(_utils);
    }

    function setGameContracts(address _character, address _weapon) public {
        require(msg.sender == owner);
        character = _character;
        weapon = _weapon;
    }

    function testMint(address account, uint256 amount) public {
        require(msg.sender == owner);
        uint totalSupply = totalSupply();
        require(totalSupply + amount <= maxTotalSupply, 'above maxTotalSupply limit');
        _mint(account, amount);
    }
    
    function mint(address account, uint256 amount) external restricted {        
        uint totalSupply = totalSupply();
        require(totalSupply + amount <= maxTotalSupply, 'above maxTotalSupply limit');
        _mint(account, amount);
    }
}