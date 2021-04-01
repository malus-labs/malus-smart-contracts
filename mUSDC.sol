pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT


abstract contract ERC20 {
    function balanceOf(address _owner) virtual public view returns (uint balance);
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
}


interface StoreInterface {
    function getExtensionStake(uint256 _selector) external view returns(uint256, address);
    function getExtensionCollateral(uint256 _selector) external view returns(uint256, address);
    function setCollateral(uint256 _amount, uint256 _selector) external;
}


interface StoreExtension {
    function processPayment(address _customer, uint256 _amount) external;
}


interface StoreHubInterface {
    function initializeBalance(address _store) external;
    function withdraw(address _to) external;
}


interface StoreProxy {
    function init(address _owner, address usdtHub, address daiHub) external;
}


contract StoreHub {
    event StoreCreated(address indexed store, address owner, uint256 creationDate); 
    event PaymentReceived(address indexed store, uint256 amount);
    event BurnTokens(address indexed store, uint256 amount);
    event CollateralReliefUpdated(address indexed store, uint256 collateralRelief, uint256 availableFunds, uint256 rate, bool didAdd);
    
    ERC20 public usdcContract;
    address public usdtStoreHub;
    address public daiStoreHub;
    address public storeImplementation;
    
    mapping(address => bool) public isValidStore;
    mapping(address => uint256) public storeBalance;
    
    function deployStore() external {
        address newStore;
        bytes20 targetBytes = bytes20(storeImplementation);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            newStore := create(0, clone, 0x37)
        }
        StoreProxy(newStore).init(msg.sender, usdtStoreHub, daiStoreHub);
        isValidStore[newStore] = true;
        storeBalance[newStore] = 1;

        emit StoreCreated(newStore, msg.sender, block.timestamp);
    }
    
    function withdraw(address _to) external {
        require(isValidStore[msg.sender] == true);
        usdcContract.transferFrom(address(this), _to, storeBalance[msg.sender]);
        storeBalance[msg.sender] = 1;
    }
}


contract mUSDC is StoreHub {
    
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
    
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    
    constructor(address _usdcContract, address _implementation) {
        usdcContract = ERC20(_usdcContract);
        storeImplementation = _implementation;
    }
    
    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }
    
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        require(balances[_from] >= _amount);
        
        if(isValidStore[_to] == true) {
            StoreInterface store = StoreInterface(_to);
            (uint256 collateral, address extensionAddress) = store.getExtensionCollateral(0);
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
        (uint256 stake, address extensionAddress) = _store.getExtensionStake(0);
        uint256 cashbackAmount = ((_amount * 700) / 10000);
        uint256 prevStoreBalance = (storeBalance[address(_store)] += _amount) - _amount;
        require(cashbackAmount >= 1);
        require((stake - (((prevStoreBalance - 1) * 700) / 10000)) >= cashbackAmount); 
        usdcContract.transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender] += cashbackAmount;
        
        if(extensionAddress != address(0)) {
            StoreExtension(extensionAddress).processPayment(msg.sender, _amount);
        }
        emit PaymentReceived(address(_store), _amount);
    }
    
    function _burn(StoreInterface _store, address _from, address extensionAddress, uint256 _amount) private {
        if (_from != msg.sender && allowed[_from][msg.sender] > 0) {
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] -= _amount;
        }
        
        _store.setCollateral(_amount, 0);
        balances[_from] -= _amount; 
        
        if(extensionAddress != address(0)) {
            StoreExtension extension = StoreExtension(extensionAddress);
            extension.processPayment(_from, _amount);
        }
        emit BurnTokens(address(_store), _amount);
    }
}