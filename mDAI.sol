pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT


abstract contract ERC20 {
    function balanceOf(address _owner) virtual public view returns (uint256 balance);
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
}


abstract contract StoreHubInterface {
    mapping(address => bool) public isValidStore;
}


interface StoreInterface {
    function getExtensionStake(uint _option) external view returns(uint256, address);
    function getExtensionCollateral(uint _option) external view returns(uint256, address);
    function updateCollateral(uint256 _amount, uint256 _option) external;
}


interface StoreExtension {
    function processPayment(address _customer, uint256 _tokenID, uint256 _amount) external;
}


contract StoreHub {
    event CollateralReliefUpdated(address indexed store, uint256 collateralRelief, uint256 rate, bool didAdd);
    event StakeCollateralUpdated(address indexed store, uint256 stake, uint256 collateral);
    
    ERC20 public daiContract;
    address public usdcStoreHub;

    mapping(address => uint256) public storeBalance;
    
    
    function initUSDCHub(address _usdcStoreHub) external {
        require(usdcStoreHub == address(0));
        usdcStoreHub = _usdcStoreHub;
    }
    
    function withdraw(uint256 _collateral) external {
        require(StoreHubInterface(usdcStoreHub).isValidStore(msg.sender) == true);
        uint256 balance = storeBalance[msg.sender] - 1;
        storeBalance[msg.sender] = 1;
        daiContract.transferFrom(address(this), msg.sender, balance);
        emit StakeCollateralUpdated(msg.sender, 0, _collateral);
    }
    
    function initBalance(address _store) external {
        require(usdcStoreHub != address(0));
        require(msg.sender == usdcStoreHub);
        storeBalance[_store] = 1;
    }
    
    function callEvent(
        address _value1,
        uint256 _value2, 
        uint256 _value3, 
        bool _value4,
        uint _option
    ) external {
        require(StoreHubInterface(usdcStoreHub).isValidStore(msg.sender) == true);
        _value1;
        
        if(_option == 0) {
            emit CollateralReliefUpdated(msg.sender, _value2, _value3, _value4);
        }
        else if(_option == 1) {
            emit StakeCollateralUpdated(msg.sender, _value2, _value3);
        }
    }
}


contract mDAI is StoreHub {
    
    string public name = "Malus DAI Token";
    string public symbol = "mDAI";
    uint public decimals = 18;
    
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
    
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    
    constructor(address _daiContract) {
        daiContract = ERC20(_daiContract);
    }
    
    function totalSupply() public view returns (uint256) {
        return (daiContract.balanceOf(address(this)) * 700)/10000;
    }
    
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
    
    function transfer(address _to, uint256 _amount) public returns (bool success) {
        return transferFrom(msg.sender, _to, _amount);
    }
    
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        require(balances[_from] >= _amount);
        
        if(StoreHubInterface(usdcStoreHub).isValidStore(_to) == true) {
            StoreInterface store = StoreInterface(_to);
            burn(store, _from, 0, _amount); 
            return true;
        }
        
        if (_from != msg.sender && allowed[_from][msg.sender] < (2**256 - 1)) {
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] -= _amount;
        }
        
        balances[_to] += _amount;
        balances[_from] -= _amount;
        emit Transfer(_from, _to, _amount);
        return true;
    }
    
    function approve(address _spender, uint256 _amount) public returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }
   
    function allowance(address _owner, address _spender) public view returns (uint remaining) {
        return allowed[_owner][_spender];
    }
    
    function mint(StoreInterface _store, uint256 _tokenID, uint256 _amount) external {
        (uint256 stake, address extensionAddress) = _store.getExtensionStake(2);
        uint256 cashbackAmount = ((_amount * 700) / 10000);
        uint256 prevStoreBalance = (storeBalance[address(_store)] += _amount) - _amount;
        require(cashbackAmount >= 1);
        require((stake - (((prevStoreBalance - 1) * 700) / 10000)) >= cashbackAmount); 
        balances[msg.sender] += cashbackAmount;
        daiContract.transferFrom(msg.sender, address(this), _amount);
        
        if(extensionAddress != address(0)) {
            StoreExtension(extensionAddress).processPayment(msg.sender, _tokenID, _amount);
        }
        emit Transfer(address(_store), msg.sender, _amount);
    }
    
    function burn(StoreInterface _store, address _from, uint256 _tokenID, uint256 _amount) public {
        (uint256 collateral, address extensionAddress) = _store.getExtensionCollateral(2);
        require(collateral >= _amount);
        require(balances[_from] >= _amount);
        
        if (_from != msg.sender && allowed[_from][msg.sender] < (2**256 - 1)) {
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] -= _amount;
        }
        
        _store.updateCollateral(_amount, 2);
        balances[_from] -= _amount; 
        
        if(extensionAddress != address(0)) {
            StoreExtension(extensionAddress).processPayment(msg.sender, _tokenID, _amount);
        }
        emit Transfer(msg.sender, address(_store), _amount);
    }
}
