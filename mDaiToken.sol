
//////////////////////////////////////////////////
// WARNING!!! THIS VERSION HAS BUGS AND HAS BEEN DEPRECATED
/////////////////////////////////////////////////

/*
pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT


interface StoreExtensionInterface {
    function processPayment(address _customer, uint256 _amount) external;
}


abstract contract Proxy {
    function balanceOf(address _owner) virtual public view returns (uint balance);
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
    function mint(address _customer, uint256 _paymentReceived) virtual external returns (bool success, uint256 balance); 
    function withdraw(uint256 _amount) virtual external returns (bool);
}


contract Store {
    
    StoreExtensionInterface public storeExtension;
    Proxy public storeHub;
    Proxy public daiContract;
    address public owner;
    
    constructor(address _owner) { 
        owner = _owner;
        storeHub = Proxy(msg.sender);
        daiContract = Proxy(0xaD6D458402F60fD3Bd25163575031ACDce07538D);
    }
    
    function sendERC20Token(address _tokenContract, address _to, uint256 _amount) external {
        require(msg.sender == owner && _tokenContract != address(daiContract));
        Proxy erc20Contract = Proxy(_tokenContract);
        erc20Contract.transferFrom(address(this), _to, _amount);
    }
    
    function sendDAI(address _to, uint256 _amount, bool isExtension) external returns (bool success) {
        require(msg.sender == address(storeHub) || msg.sender == owner);
        
        if(isExtension == true && msg.sender == address(storeHub)) { 
            (bool success1) = daiContract.transferFrom(address(this), address(storeExtension), _amount);
            require(success1 == true);
            storeExtension.processPayment(_to, _amount); 
            return true;
        }
        else if(msg.sender == owner) {
            (bool success1) = storeHub.withdraw(_amount);
            require(success1 == true);
        }
        (bool success2) = daiContract.transferFrom(address(this), _to, _amount);
        require(success2 == true);
        return true;
    }
    
    function updateData(address _owner, address _storeExtension) external {
        require(msg.sender == address(storeHub));
        owner = _owner;
        storeExtension = StoreExtensionInterface(_storeExtension);
    }

    function completePurchase(uint256 _amount) external {
        daiContract.transferFrom(msg.sender, address(this), _amount);
        _createPoints(_amount);
    }
    
    function _createPoints(uint256 _amount) private {
        (bool success1, uint256 balance) = storeHub.mint(msg.sender, _amount);
        require(success1 == true);
        
        if(address(storeExtension) != address(0)) {
            (bool success2) = daiContract.transferFrom(address(this), address(storeExtension), balance);
            require(success2 == true);
            storeExtension.processPayment(msg.sender, balance);
        }
    }
}


abstract contract StoreHub is Proxy {
    
    event StoreCreated(address indexed store, address owner, uint256 creationDate); 
    event OwnerUpdated(address indexed store, address newOwner);
    event StoreBalancesUpdated(address indexed store, uint256 collateral, uint256 stake, uint256 availableFunds);
    event CollateralReliefUpdated(address indexed store, uint256 collateralRelief, uint256 availableFunds, uint256 rate, bool didAdd);
    event ExtensionUpdated(address indexed store, address extension);
    event MetaDataUpdated(address indexed store, string[7] metaData);
    
    mapping(address => bool) isValidStore;
    mapping(address => mapping(address => bool)) isStoreOwner;
    mapping(address => uint256) availableDaiInsideStore; 
    mapping(address => uint256) stakeInsideStore;
    mapping(address => uint256) collateralInsideStore; 
    mapping(address => mapping(uint256 => uint256)) collateralReliefInsideStore; 
    mapping(address => address) extensionInsideStore;
    
    function deployStore() external {
        Store newStore = new Store(msg.sender);
        isValidStore[address(newStore)] = true;
        isStoreOwner[address(newStore)][msg.sender] = true;
        emit StoreCreated(address(newStore), msg.sender, block.timestamp);
    }
    
    function isOwner(address _store, address _owner) public view returns (bool) {
        return isStoreOwner[_store][_owner];
    }
    
    function isStoreValid(address _store) public view returns (bool) {
        return isValidStore[_store];
    }
    
    function withdraw(uint256 _amount) override external returns (bool) {
        require(isValidStore[msg.sender] == true);
        require(availableDaiInsideStore[msg.sender] >= _amount);
        availableDaiInsideStore[msg.sender] -= _amount;
        emit StoreBalancesUpdated(msg.sender, collateralInsideStore[msg.sender], stakeInsideStore[msg.sender], availableDaiInsideStore[msg.sender]);
        return true;
    }
}


abstract contract Stake is StoreHub {
    
    function addStake(address _store, uint256 _amount) external {  
        require(isStoreOwner[_store][msg.sender] == true);
        require(availableDaiInsideStore[_store] >= _amount);
        availableDaiInsideStore[_store] -= _amount;
        stakeInsideStore[_store] += _amount;
        emit StoreBalancesUpdated(_store, collateralInsideStore[_store], stakeInsideStore[_store], availableDaiInsideStore[_store]);
    }
    
    function removeStake(address _store, uint256 _amount) external {
        require(isStoreOwner[_store][msg.sender] == true);
        require(stakeInsideStore[_store] >= _amount);
        stakeInsideStore[_store] -= _amount;
        availableDaiInsideStore[_store] += _amount;
        emit StoreBalancesUpdated(_store, collateralInsideStore[_store], stakeInsideStore[_store], availableDaiInsideStore[_store]);
    }
}


 abstract contract Collateral is Stake {
    
    function provideCollateralRelief(address _store, uint256 _amount, uint256 _rate) external { 
        require(isStoreOwner[_store][msg.sender] == true);
        require(availableDaiInsideStore[_store] >= _amount);
        require(_rate > 0 && _rate <= 10000);
        availableDaiInsideStore[_store] -= _amount;
        collateralReliefInsideStore[_store][_rate] += _amount;
        emit CollateralReliefUpdated(_store, collateralReliefInsideStore[_store][_rate], availableDaiInsideStore[_store], _rate, true);
    }
    
    function removeCollateralRelief(address _store, uint256 _amount, uint256 _rate) external {
        require(isStoreOwner[_store][msg.sender] == true);
        require(collateralReliefInsideStore[_store][_rate] >= _amount);
        collateralReliefInsideStore[_store][_rate] -= _amount;
        availableDaiInsideStore[_store] += _amount;
        emit CollateralReliefUpdated(_store, collateralReliefInsideStore[_store][_rate], availableDaiInsideStore[_store], _rate, false);
    }
    
    function sellCollateral(address _fromStore, address _toStore, uint256 _amount, uint16 _rate) external {
        uint256 lost = (_amount * _rate) / 10000;
        require(isStoreOwner[_fromStore][msg.sender] == true);
        require(isValidStore[_toStore] == true);
        require(collateralInsideStore[_fromStore] >= _amount);
        require(collateralReliefInsideStore[_toStore][_rate] == _amount);
        collateralInsideStore[_fromStore] -= _amount;
        collateralInsideStore[_toStore] += _amount;
        availableDaiInsideStore[_fromStore] += (_amount - lost);
        availableDaiInsideStore[_toStore] += lost;
        collateralReliefInsideStore[_toStore][_rate] = 0;
        Store currentStore = Store(_fromStore);
        currentStore.sendDAI(_toStore, lost, false);
        emit StoreBalancesUpdated(_toStore, collateralInsideStore[_toStore], stakeInsideStore[_toStore], availableDaiInsideStore[_toStore]);
        emit StoreBalancesUpdated(_fromStore, collateralInsideStore[_fromStore], stakeInsideStore[_fromStore], availableDaiInsideStore[_fromStore]);
    }
    
    function transferCollateral(address _fromStore, address _toStore, uint256 _amount) external {
        require(isStoreOwner[_fromStore][msg.sender] == true);
        require(isValidStore[_toStore] == true);
        require(collateralInsideStore[_fromStore] >= _amount);
        collateralInsideStore[_fromStore] -= _amount;
        collateralInsideStore[_toStore] += _amount;
        Store currentStore = Store(_fromStore);
        currentStore.sendDAI(_toStore, _amount, false);
        emit StoreBalancesUpdated(_toStore, collateralInsideStore[_toStore], stakeInsideStore[_toStore], availableDaiInsideStore[_toStore]);
        emit StoreBalancesUpdated(_fromStore, collateralInsideStore[_fromStore], stakeInsideStore[_fromStore], availableDaiInsideStore[_fromStore]);
    }
}


abstract contract General is Collateral {
    
    function setMetaData(address _store, string[7] calldata _metaData) external {
        require(isStoreOwner[_store][msg.sender] == true);
        emit MetaDataUpdated(_store, _metaData);
    }
    
    function updateExtension(address _store, address _newExtension) external {
        require(isStoreOwner[_store][msg.sender] == true);
        Store currentStore = Store(_store);
        extensionInsideStore[_store] = _newExtension;
        currentStore.updateData(msg.sender, _newExtension);
        emit ExtensionUpdated(_store, _newExtension);
    }
    
    function updateStoreOwner(address _store, address _newOwner) external {
        require(isStoreOwner[_store][msg.sender] == true);
        Store currentStore = Store(_store);
        isStoreOwner[_store][msg.sender] = false;
        isStoreOwner[_store][_newOwner] = true;
        currentStore.updateData(_newOwner, extensionInsideStore[_store]);
        emit OwnerUpdated(_store, _newOwner);
    }
}


contract mDaiToken is General {
    
    string public name = "mDAI Token";
    string public symbol = "mDAI";
    uint public decimals = 18; 
    uint256 public totalSupply;
    
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    
    constructor() {
        
    }
    
    function balanceOf(address _owner) override public view returns (uint balance) {
        return balances[_owner];
    }
    
    function transfer(address _to, uint256 _amount) public returns (bool success) {
        return transferFrom(msg.sender, _to, _amount);
    }
    
    function transferFrom(address _from, address _to, uint256 _amount) override public returns (bool success) {
        require(balances[_from] >= _amount);
        
        if(isValidStore[_to] == true) {
            if(collateralInsideStore[_to] >= _amount) { 
                _burn(_from, _to, _amount); 
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
    
    function mint(address _customer, uint256 _paymentReceived) override external returns (bool success, uint256 balance) {
        require(isValidStore[msg.sender] == true);
        uint256 sevenPercentOfPayment = (_paymentReceived * 700) / 10000;
        
        if(stakeInsideStore[msg.sender] > 0) {
            require(isValidStore[_customer] == false);
            require(stakeInsideStore[msg.sender] >= sevenPercentOfPayment);
            stakeInsideStore[msg.sender] -= sevenPercentOfPayment;
            collateralInsideStore[msg.sender] += sevenPercentOfPayment;
            balances[_customer] += sevenPercentOfPayment;
            totalSupply += sevenPercentOfPayment;
            
            if(extensionInsideStore[msg.sender] == address(0)) {
                availableDaiInsideStore[msg.sender] += (_paymentReceived - sevenPercentOfPayment);
            }
            
            emit Transfer(address(0), _customer, sevenPercentOfPayment);
            emit StoreBalancesUpdated(msg.sender, collateralInsideStore[msg.sender], stakeInsideStore[msg.sender], availableDaiInsideStore[msg.sender]);
            return(true, (_paymentReceived - sevenPercentOfPayment)); 
        }
        else {
            
            if(extensionInsideStore[msg.sender] == address(0)) {
                availableDaiInsideStore[msg.sender] += _paymentReceived;
            }
            
            emit StoreBalancesUpdated(msg.sender, collateralInsideStore[msg.sender], stakeInsideStore[msg.sender], availableDaiInsideStore[msg.sender]);
            return(true, _paymentReceived);
        }
    }
    
    function _burn(address _from, address _store, uint256 _amount) private { 
        
        if (_from != msg.sender && allowed[_from][msg.sender] > 0) {
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] -= _amount;
        }
        
        collateralInsideStore[_store] -= _amount;
        availableDaiInsideStore[_store] += _amount;
        balances[_from] -= _amount;
        totalSupply -= _amount;
        
        if(extensionInsideStore[_store] != address(0)) {
            availableDaiInsideStore[_store] -= _amount;
            Store currentStore = Store(_store);
            currentStore.sendDAI(msg.sender, _amount, true);
        }
        emit Transfer(_from, address(0), _amount);
        emit StoreBalancesUpdated(_store, collateralInsideStore[_store], stakeInsideStore[_store], availableDaiInsideStore[_store]);
    }
}

contract Deployer {
    address public mDaiTokenAddress;
    
    constructor() {
        mDaiToken mDai = new mDaiToken();
        mDaiTokenAddress = address(mDai);
    }
}
*/