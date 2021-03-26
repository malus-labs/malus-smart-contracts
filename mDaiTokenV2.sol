pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT


abstract contract ERC20 {
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
}

interface StorePayment {
    function completePayment(uint256 _amount) external;
}

contract Store {
    uint256[3] public payment;
    uint256 public availableADai;
    address public extension;
    address public storeHub;
    address public owner;
    
    mapping(uint256 => uint256) public collateralRelief;
    
    constructor(address _owner) { 
        owner = _owner;
        storeHub = msg.sender;
        payment = [1, 1, 1];
    }
    
    function sendERC20Token(ERC20 erc20Contract, address _to, uint256 _amount) external returns (bool success) {
        require(msg.sender == owner);
        erc20Contract.transferFrom(address(this), _to, _amount);
        return true;
    }
    
    function completePayment(uint256 _amount) external {
        payment = [100, 100, 100];
    }
}


contract StoreHub {
    
    event StoreCreated(address indexed store, address owner, uint256 creationDate); 
    event OwnerUpdated(address indexed store, address newOwner);
    event StoreBalancesUpdated(address indexed store, uint256 collateral, uint256 stake, uint256 availableFunds);
    event CollateralReliefUpdated(address indexed store, uint256 collateralRelief, uint256 availableFunds, uint256 rate, bool didAdd);
    event ExtensionUpdated(address indexed store, address extension);
    event MetaDataUpdated(address indexed store, string[7] metaData);
    
    ERC20 public daiContract;
    mapping(address => bool) isValidStore;
    
    function deployStore() external {
        Store newStore = new Store(msg.sender);
        isValidStore[address(newStore)] = true;
        emit StoreCreated(address(newStore), msg.sender, block.timestamp);
    }
    
}


contract mDaiToken is StoreHub {
    
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
    
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    
    constructor(address _daiContract) {
        daiContract = ERC20(_daiContract);
    }
    
    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }
    
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        require(balances[_from] >= _amount);
        
        if(isValidStore[_to] == true) {
            //
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
    
    function mint(StorePayment store, uint256 _amount) external {
        daiContract.transferFrom(msg.sender, address(this), _amount);
        store.completePayment(_amount);
        balances[msg.sender] += _amount;
    }
    
    function _burn(StorePayment store, address _from, uint256 _amount) private {
        if (_from != msg.sender && allowed[_from][msg.sender] > 0) {
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] -= _amount;
        }
        balances[msg.sender] -= _amount;
        emit Transfer(_from, address(0), _amount);
    }
}

