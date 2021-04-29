pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT


interface StoreHubInterface {
    function isStoreValid(address _store) external view returns (bool);
}

abstract contract StoreProxy {
    address public owner;
}

contract Metadata {
    event MetaDataUpdated(address indexed store, string[7] metaData);
    
    StoreHubInterface usdcHub;
    
    constructor(address _hub) {
        usdcHub = StoreHubInterface(_hub);
    }
    
    function setMetaData(address _store, string[7] calldata _metaData) external {
        require(usdcHub.isStoreValid(_store) == true);
        require(StoreProxy(_store).owner() == msg.sender);
        emit MetaDataUpdated(_store, _metaData);
    }
}