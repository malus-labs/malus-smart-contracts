pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT


abstract contract ERC20 {
    function balanceOf(address _owner) virtual public view returns (uint256 balance);
    function transfer(address _to, uint256 _amount) virtual public returns (bool success); 
}


abstract contract StoreHubInterface {
    mapping(address => bool) public isValidStore;
    mapping(address => uint256) public storeBalance;
    function withdraw(uint256 _collateral) virtual external;
    function callEvent(address _value1, uint256 _value2, uint256 _value3, bool _value4, uint _option) virtual external;
}


interface StoreInterface {
    function receiveCollateral(uint256 _amount, uint256 _rate, uint _option, bool _isTrade) external;
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
            0xd9145CCE52D386f254917e481eB44e9943F39138, 
            0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8,
            0xf8e81D47203A594245E36C48e151709F0C19fBe8
        ];
    }
}


contract Assets is Store {
    
    function _getAvailableFunds(ERC20 erc20Contract, uint256 _option) public view returns (uint256) {
        require(address(erc20Contract) == aToken[_option]);
        return erc20Contract.balanceOf(address(this)) - (collateral[_option] + stake[_option] + totalRelief[_option]);
    }
    
    function sendERC20(address _tokenContract, address _to, uint256 _amount) external {
        require(msg.sender == owner);
        ERC20 erc20Contract = ERC20(_tokenContract);
        
        if(aToken[0] == _tokenContract) {
            require(_getAvailableFunds(erc20Contract, 0) >= _amount);
        }
        else if(aToken[1] == _tokenContract) {
            require(_getAvailableFunds(erc20Contract, 1) >= _amount);
        }
        else if(aToken[2] == _tokenContract) {
            require(_getAvailableFunds(erc20Contract, 2) >= _amount);
        }
        
        erc20Contract.transfer(_to, _amount);
    }
    
    function claimStoreHubBalance(uint _option) public {
        require(msg.sender == owner);
        uint256 storeBalance = StoreHubInterface(storeHub[_option]).storeBalance(address(this)) - 1;
        collateral[_option] += ((storeBalance * 700)/10000);
        stake[_option] = 0;
        StoreHubInterface(storeHub[_option]).withdraw(collateral[_option]);
    }
}


contract Stake is Assets {
    
    function getExtensionStake(uint _option) external view returns(uint256, address) {
        return (stake[_option], extension);
    }
    
    function updateStake(uint256 _amount, uint _option, bool _addStake) external {
        require(msg.sender == owner);
        require(_getAvailableFunds(ERC20(aToken[_option]), _option) >= _amount);

        if(_addStake == true) {
            stake[_option] += _amount;
            StoreHubInterface(storeHub[_option]).callEvent(address(0), stake[_option], collateral[_option], false, 1);
        }
        else {
            claimStoreHubBalance(_option);
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
            require(_getAvailableFunds(ERC20(aToken[_option]), _option) >= _amount);
            collateralRelief[_option][_rate] += _amount;
            totalRelief[_option] += _amount;
            StoreHubInterface(storeHub[_option]).callEvent(address(0), collateralRelief[_option][_rate], _rate, true, 0);
        }
        else {
            require(collateralRelief[_option][_rate] >= _amount);
            collateralRelief[_option][_rate] -= _amount;
            totalRelief[_option] -= _amount;
            StoreHubInterface(storeHub[_option]).callEvent(address(0), collateralRelief[_option][_rate], _rate, false, 0);
        }
    }
    
    function transferCollateral(StoreInterface _store, uint256 _amount, uint _option) external {
        require(msg.sender == owner);
        require(StoreHubInterface(storeHub[0]).isValidStore(address(_store)) == true);
        require(collateral[_option] >= _amount);
        collateral[_option] -= _amount;
        _store.receiveCollateral(_amount, 0, _option, false);
        ERC20(aToken[_option]).transfer(address(_store), _amount);
        StoreHubInterface(storeHub[_option]).callEvent(address(0), stake[_option], collateral[_option], false, 1);
    }
    
    function sellCollateral(StoreInterface _store, uint256 _amount, uint256 _rate, uint _option) external {
        uint256 lost = (_amount * _rate) / 10000;
        require(msg.sender == owner);
        require(StoreHubInterface(storeHub[0]).isValidStore(address(_store)) == true);
        require(lost >= 1);
        require(collateral[_option] >= _amount);
        collateral[_option] -= (_amount - lost);
        _store.receiveCollateral(_amount + lost, _rate, _option, true);
        ERC20(aToken[_option]).transfer(address(_store), lost);
        StoreHubInterface(storeHub[_option]).callEvent(address(0), stake[_option], collateral[_option], false, 1);
    }
    
    function receiveCollateral(uint256 _amount, uint256 _rate, uint _option, bool _isTrade) external {
        require(StoreHubInterface(storeHub[0]).isValidStore(address(msg.sender))  == true);
        
        if(_isTrade == true){
            require(collateralRelief[_option][_rate] == _amount);
            collateralRelief[_option][_rate] = 0;
            totalRelief[_option] -= _amount;
        }
        collateral[_option] += _amount;
    }
    
    function updateCollateral(uint256 _amount, uint _option) external {
        require(msg.sender == storeHub[_option]);
        collateral[_option] -= _amount;
    }
}


contract General is Collateral {
    
    function updateExtension(address _newExtension) external {
        require(msg.sender == owner);
        extension = _newExtension;
        StoreHubInterface(storeHub[0]).callEvent(extension, 0, 0, false, 2);
    }
    
    function updateOwner(address _newOwner) external {
        require(msg.sender == owner);
        owner = _newOwner;
        StoreHubInterface(storeHub[0]).callEvent(owner, 0, 0, false, 3);
    }
}