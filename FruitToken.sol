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
    function transferFrom(address _from, address _to, uint256 _value) virtual public returns (bool success); 
    function mint(uint256 _value) virtual external payable; 
}


contract store {
    
}


contract storeHub is StoreHubInterface {
    
    address public deployer;
    address public malusTokenAddress;
    address public firstStoreAddress;
    
    function deployStore() override external {
        
    }
    
    function isStoreValid(address _store) override external view returns (bool) {
        
    }
}


contract FruitToken {
    
}