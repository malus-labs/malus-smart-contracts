pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT


abstract contract ERC20 {
    function balanceOf(address _owner) virtual public view returns (uint balance);
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
}


interface StoreInterface {
    function getExtensionStake() external view returns(uint256, address);
    function getExtensionCollateral() external view returns(uint256, address);
    function setCollateral(uint256 _amount) external view;
}


interface StoreExtension {
    function processPayment(address _customer, uint256 _amount) external;
}


contract StoreProxy {
    
    uint256 public collateral;
    uint256 public stake = 70;
    address public storeHub;
    address public extension;
    address public owner;
    
    function getExtensionStake() external view returns(uint256, address) {
        return (stake, extension);
    }
    
    function getExtensionCollateral() external view returns(uint256, address) {
        return (collateral, extension);
    }
}


contract StoreHub {
    
    event StoreCreated(address indexed store, address owner, uint256 creationDate); 
    event PaymentReceived(address indexed store, uint256 amount);
    event BurnTokens(address indexed store, uint256 amount);
    event CollateralReliefUpdated(address indexed store, uint256 collateralRelief, uint256 availableFunds, uint256 rate, bool didAdd);
    event MetaDataUpdated(address indexed store, string[7] metaData);
    
    ERC20 public usdcContract;
    mapping(address => bool) public isValidStore;
    mapping(address => uint256) public availableUSDC;
    
    function deployStore() external {
        StoreProxy newStore = new StoreProxy();
        isValidStore[address(newStore)] = true;
        availableUSDC[address(newStore)] = 1;
        emit StoreCreated(address(newStore), msg.sender, block.timestamp);
    }
    
    function withdraw(address _to, uint256 _amount) external {
        require(isValidStore[msg.sender] == true);
        require(availableUSDC[msg.sender] >= _amount);
        availableUSDC[msg.sender] -= _amount;
        usdcContract.transferFrom(address(this), _to, _amount);
    }
}


contract mUSDC is StoreHub {
    
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
    
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    
    constructor(address _usdcContract) {
        usdcContract = ERC20(_usdcContract);
    }
    
    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }
    
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        require(balances[_from] >= _amount);
        
        if(isValidStore[_to] == true) {
            StoreInterface store = StoreInterface(_to);
            (uint256 collateral, address extensionAddress) = store.getExtensionCollateral();
            if(collateral >= _amount) { 
                _burn(store, _from, extensionAddress, _amount); 
                return true;
            }
            else { return false; }
        }
        
        if (_from != msg.sender && allowed[_from][msg.sender] > 0) {
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
    
    function mint(StoreInterface _store, uint256 _amount) external {
        (uint256 stake, address extensionAddress) = _store.getExtensionStake();
        require((stake - (((availableUSDC[address(_store)] - 1) * 700) / 10000)) >= ((_amount * 700) / 10000)); 
        usdcContract.transferFrom(msg.sender, address(this), _amount);
        availableUSDC[address(_store)] += _amount;
        balances[msg.sender] += _amount;
        
        if(extensionAddress != address(0)) {
            StoreExtension extension = StoreExtension(extensionAddress);
            extension.processPayment(msg.sender, _amount);
        }
        emit PaymentReceived(address(_store), _amount);
    }
    
    function _burn(StoreInterface _store, address _from, address extensionAddress, uint256 _amount) private {
        if (_from != msg.sender && allowed[_from][msg.sender] > 0) {
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] -= _amount;
        }
        
        _store.setCollateral(_amount);
        balances[_from] -= _amount; 
        
        if(extensionAddress != address(0)) {
            StoreExtension extension = StoreExtension(extensionAddress);
            extension.processPayment(_from, _amount);
        }
        emit BurnTokens(address(_store), _amount);
    }
}

