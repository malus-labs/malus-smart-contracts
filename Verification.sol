pragma solidity ^0.8.0;
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
    
    function changeContoller(address _newContoller) onlyContoller external {
        controller = _newContoller;
    }
    
    function addVerification(bytes32 _node) onlyContoller public {
        emit UpdateVerification(_node, true);
    }
    
    function removeVerification(bytes32 _node) onlyContoller public {
        emit UpdateVerification(_node, false);
    }
}