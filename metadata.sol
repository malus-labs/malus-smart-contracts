pragma solidity ^0.8.4;
//SPDX-License-Identifier: MIT


abstract contract StoreHubInterface {
    mapping(address => bool) public isValidStore;
}

abstract contract StoreProxy {
    address public owner;
}

contract Metadata {
    event MetaDataUpdated(address indexed store, string[7] metaData);
    
    StoreHubInterface usdcHub;
    
    constructor(address hub) {
        usdcHub = StoreHubInterface(hub);
    }
    
    function setMetaData(address store, string[7] calldata metaData) external {
        require(usdcHub.isValidStore(store) == true);
        require(StoreProxy(store).owner() == msg.sender);
        emit MetaDataUpdated(store, metaData);
    }
}