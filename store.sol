pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

abstract contract ERC20 {
    function balanceOf(address _owner) virtual public view returns (uint256 balance);
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
}


interface StoreInterface {
    function receiveCollateral(uint256 _amount, uint256 _rate, uint _option, bool _isTrade) external;
}


interface StoreHubInterface {
    function withdraw(address _to) external;
    function isStoreValid(address _store) external view returns (bool);
}


contract Store {
    uint256[3] public collateral;
    uint256[3] public totalRelief;
    uint256[3] public stake;
    address[3] public storeHub;
    address[3] public aToken;
    address public extension;
    address public owner;
    
    mapping(uint => mapping(uint256 => uint256)) collateralRelief;
    
    function init(address _owner, address usdtHub, address daiHub) external {
        require(storeHub[0] == address(0));
        owner = _owner;
        storeHub = [msg.sender, usdtHub, daiHub];
        aToken = [
            0x9bA00D6856a4eDF4665BcA2C2309936572473B7E, 
            0x71fc860F7D3A592A4a98740e39dB31d25db65ae8,
            0x028171bCA77440897B824Ca71D1c56caC55b68A3
        ];
    }
}


contract Assets is Store {
    
    function _getAvailableFunds(ERC20 erc20Contract, uint256 _option) internal view returns (uint256) {
        return erc20Contract.balanceOf(address(this)) - (collateral[_option] + stake[_option] + totalRelief[_option]);
    }
    
    function sendERC20(address _tokenContract, address _to, uint256 _amount) external {
        require(msg.sender == owner);
        ERC20 erc20Contract = ERC20(_tokenContract);
        
        if(storeHub[0] == _tokenContract) {
            require(_getAvailableFunds(erc20Contract, 0) >= _amount);
        }
        else if(storeHub[1] == _tokenContract) {
            require(_getAvailableFunds(erc20Contract, 1) >= _amount);
        }
        else if(storeHub[2] == _tokenContract) {
            require(_getAvailableFunds(erc20Contract, 2) >= _amount);
        }
        
        erc20Contract.transferFrom(address(this), _to, _amount);
    }
}


contract Stake is Assets {
    
    function getExtensionStake(uint _option) external view returns(uint256, address) {
        return (stake[_option], extension);
    }
    
    function updateStake(uint256 _option, uint256 _amount, bool _addStake) external {
        require(msg.sender == owner);
        StoreHubInterface hub = StoreHubInterface(storeHub[_option]);
        if(_addStake == true) {
            require(stake[_option] == 0);
            stake[_option] = _amount;
            
        }
        else {
            stake[_option] = 0;
            hub.withdraw(address(this));
            
        }
    }
}


contract Collateral is Stake {
    
    function getExtensionCollateral(uint _option) external view returns(uint256, address) {
        return (collateral[_option], extension);
    }
    
    function provideCollateralRelief(uint256 _amount, uint256 _rate, uint _option, bool _addRelief) external {
        require(msg.sender == owner);
        require(_rate > 0 && _rate <= 10000);
        
        if(_addRelief == true) {
            require(_getAvailableFunds(ERC20(address(aToken[_option])), _option) >= _amount);
            collateralRelief[_option][_rate] += _amount;
            totalRelief[_option] += _amount;
            
        }
        else {
            require(collateralRelief[_option][_rate] >= _amount);
            collateralRelief[_option][_rate] -= _amount;
            totalRelief[_option] -= _amount;
            
        }
    }
    
    function transferCollateral(StoreInterface _store, uint256 _amount, uint _option) external {
        require(msg.sender == owner);
        require(StoreHubInterface(storeHub[0]).isStoreValid(address(_store)) == true);
        require(collateral[_option] >= _amount);
        collateral[_option] -= _amount;
        _store.receiveCollateral(_amount, 0, _option, false);
        ERC20(aToken[_option]).transferFrom(address(this), address(_store), _amount);
        
    }
    
    function sellCollateral(StoreInterface _store, uint256 _amount, uint256 _rate, uint _option) external {
        uint256 lost = (_amount * _rate) / 10000;
        require(msg.sender == owner);
        require(StoreHubInterface(storeHub[0]).isStoreValid(address(_store)) == true);
        require(lost >= 1);
        require(collateral[_option] >= _amount);
        collateral[_option] -= (_amount - lost);
        _store.receiveCollateral(_amount + lost, _rate, _option, true);
        ERC20(aToken[_option]).transferFrom(address(this), address(_store), lost);
        
    }
    
    function receiveCollateral(uint256 _amount, uint256 _rate, uint _option, bool _isTrade) external {
        require(StoreHubInterface(storeHub[0]).isStoreValid(address(msg.sender))  == true);
        
        if(_isTrade == true){
            require(collateralRelief[_option][_rate] == _amount);
            collateralRelief[_option][_rate] = 0;
            totalRelief[_option] -= _amount;
        }
        collateral[_option] += _amount;
        
    }
    
    function updateCollateral(uint256 _amount, uint256 _option) external {
        require(msg.sender == storeHub[_option]);
        collateral[_option] -= _amount;
    }
}