pragma solidity ^0.8.4;
//SPDX-License-Identifier: MIT


contract Verification {
    event UpdateVerification(bytes32 indexed node, bool didVerify);
    
    address controller;
    
    modifier onlyContoller() {
        require(msg.sender == controller);
        _;
    }
    
    constructor() {
        controller = msg.sender;
    }
    
    function changeContoller(address newContoller) onlyContoller external {
        controller = newContoller;
    }
    
    function addVerification(bytes32 node) onlyContoller public {
        emit UpdateVerification(node, true);
    }
    
    function removeVerification(bytes32 node) onlyContoller public {
        emit UpdateVerification(node, false);
    }
}
