pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

interface StoreHubInterface { 
    function deployStore() external; 
    function isStoreValid(address _store) external view returns (bool); 
}


interface StoreExtensionInterface {
    function setRequiredAmount(uint256 _amount) external;
    function processPayment(address _sender) external payable;
}


abstract contract ERC20 {
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
    function mint(uint256 _amount, uint256 _updatedStake) virtual external payable; 
}


contract Store {
    ERC20 public storeHub;
    address public owner;
    uint256 public stake;
    
    constructor(address _storeHubAddress) {  
        storeHub = ERC20(_storeHubAddress);
    }
    
    function sendERC20Token(address _tokenContract, address _receiver, uint256 _value) external { 
        require(msg.sender == owner);
        ERC20 erc20Contract = ERC20(_tokenContract);
        erc20Contract.transferFrom(address(this), _receiver, _value);
    }
    
    function updateData(uint256 _stake, address _owner) external {
        require(msg.sender == address(storeHub));
        stake = _stake;
        owner = _owner;
    }
    
    fallback() external payable {
        _createPoints();
    }
    
    receive() external payable {
        _createPoints();
    }
    
    function _createPoints() private {
        if(stake > 0) {
              uint256 sevenPercentOfPayment = (msg.value * 700) / 10000;
              stake -= sevenPercentOfPayment;
              require(sevenPercentOfPayment <= stake);  
              storeHub.mint{value: msg.value}(sevenPercentOfPayment, stake); 
        }
        else {
            storeHub.mint{value: msg.value}(0, stake);
        }
    }
}


contract StoreHub is StoreHubInterface {
    
    address public deployer;
    address public malusTokenAddress;
    address public firstStoreAddress;
    
    function deployStore() override external {
        
    }
    
    function isStoreValid(address _store) override external view returns (bool) {
        
    }
}


contract FruitToken is StoreHub {
    
}