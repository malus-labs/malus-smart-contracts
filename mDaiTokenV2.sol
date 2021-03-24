pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT


abstract contract ERC20 {
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
}

interface StorePayment {
    function completePayment(uint256 _amount) external;
}

contract Store {
    uint256 public availableDai;
    uint256 public availableADai;
    uint256 public stake;
    uint256 public collateral;
    address public extension;
    address public storeHub;
    address public owner;
    
    mapping(uint256 => uint256) public collateralRelief;
    
    constructor(address _owner) { 
        owner = _owner;
        storeHub = msg.sender;
        availableDai = 1;
        stake = 1;
        collateral = 1;
    }
    
    function sendERC20Token(address _tokenContract, address _to, uint256 _amount) external returns (bool success) {
        require(msg.sender == owner);
        ERC20 erc20Contract = ERC20(_tokenContract);
        erc20Contract.transferFrom(address(this), _to, _amount);
        return true;
    }
    
    function completePayment(uint256 _amount) external {
        require(msg.sender == storeHub);
        require(stake - 1 >= _amount);
        availableDai += _amount;
        stake += _amount;
        collateral += _amount;
    }
}