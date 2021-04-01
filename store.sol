pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

interface StoreHubInterface {
    function withdraw(address _to) external;
}

contract Store {
    
    uint256[3] public collateral;
    uint256[3] public stake;
    address[3] public storeHub;
    address[3] public aTokenAddress;
    address public extension;
    address public owner;
    
    mapping(uint256 => uint256) collateralReliefUSDC;
    mapping(uint256 => uint256) collateralReliefUSDT;
    mapping(uint256 => uint256) collateralReliefDAI;
    
    function init(address _owner, address usdcHub, address usdtHub, address daiHub) external {
        require(storeHub[0] == address(0));
        owner = _owner;
        storeHub = [usdcHub, usdtHub, daiHub];
        aTokenAddress = [
            0x9bA00D6856a4eDF4665BcA2C2309936572473B7E, 
            0x71fc860F7D3A592A4a98740e39dB31d25db65ae8,
            0x028171bCA77440897B824Ca71D1c56caC55b68A3
        ];
    }
    
    function getExtensionStake(uint256 _selector) external view returns(uint256, address) {
        return (stake[_selector], extension);
    }
    
    function getExtensionCollateral(uint256 _selector) external view returns(uint256, address) {
        return (collateral[_selector], extension);
    }
    
    function updateStake(uint256 _selector, uint256 _amount, bool _addStake) external {
        require(msg.sender == owner);
        StoreHubInterface hub = StoreHubInterface(storeHub[_selector]);
        if(_addStake == true) {
            require(stake[_selector] == 0);
            stake[_selector] = _amount;
        }
        else {
            stake[_selector] = 0;
            hub.withdraw(address(this));
        }
    }
    
    function setCollateral(uint256 _amount, uint256 _selector) external {
        require(msg.sender == storeHub[0] || msg.sender == storeHub[1] || msg.sender == storeHub[2]);
        collateral[_selector] -= _amount;
    }
}