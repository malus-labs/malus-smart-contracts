pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

interface StoreHubInterface { 
    function deployStore() external; 
    function isStoreValid(address _store) external view returns (bool); 
    function addStake(address payable _store, uint256 _amount) external;
    function removeStake(address payable _store, uint256 _amount) external;
    function provideCollateralRelief(address payable _store, uint256 _amount, uint256 _rate) external;
    function removeCollateralRelief(address _store, uint256 _amount, uint256 _rate) external;
    function sellCollateral(address payable _fromStore, address payable _toStore, uint256 _amount, uint16 _rate) external;
    function transferCollateral(address payable _fromStore, address payable _toStore, uint256 _amount) external;
    function setMetaData(address _store, string[6] calldata _metaData) external;
    function updateExtension(address payable _store, address _newExtension) external;
    function updateStoreOwner(address payable _store, address _owner) external;
}


interface StoreExtensionInterface {
    function processPayment(address _customer) external payable;
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
    address public owner;
    
    constructor(address _owner) { 
        owner = _owner;
        storeHub = Proxy(msg.sender);
    }
    
    function sendERC20Token(address _tokenContract, address _to, uint256 _amount) external { 
        require(msg.sender == owner);
        Proxy erc20Contract = Proxy(_tokenContract);
        erc20Contract.transferFrom(address(this), _to, _amount);
    }
    
    function sendETH(address _to, uint256 _amount) external returns (bool success) {
        require(msg.sender == address(storeHub) || msg.sender == owner);
        
        if(_to != address(storeHub) && msg.sender == address(storeHub)) { 
            storeExtension.processPayment{value: _amount}(_to);
            return true;
        }
        else if(msg.sender == owner) {
            require(_to != address(storeHub));
            (bool success1) = storeHub.withdraw(_amount);
            require(success1 == true);
        }

        (bool success2,) = _to.call{value: _amount}(""); 
        require(success2 == true);
        return true;
    }
    
    function updateData(address _owner, address _storeExtension) external {
        require(msg.sender == address(storeHub));
        owner = _owner;
        storeExtension = StoreExtensionInterface(_storeExtension);
    }
    
    function sendCollateral(address payable _toStore, uint256 _amount) external {
        require(msg.sender == address(storeHub));
        Store currentStore = Store(_toStore);
        currentStore.receiveCollateral{value: _amount}();
    }
    
    function receiveCollateral() external payable {
        
    }
    
    receive() external payable {
        _createPoints();
    }
    
    function _createPoints() private {
        (bool success, uint256 balance) = storeHub.mint(msg.sender, msg.value);
        require(success == true);
        
        if(address(storeExtension) != address(0)) {
            storeExtension.processPayment{value: balance}(msg.sender);
        }
    }
}


abstract contract StoreHub is StoreHubInterface, Proxy {
    
    event StoreCreated(address indexed store, address owner, uint256 creationDate); 
    event OwnerUpdated(address indexed store, address newOwner);
    event StoreBalancesUpdated(address indexed store, uint256 collateral, uint256 stake, uint256 availableFunds);
    event CollateralReliefUpdated(address indexed store, uint256 collateralRelief, uint256 availableFunds, uint256 rate, bool didAdd);
    event ExtensionUpdated(address indexed store, address extension);
    event MetaDataUpdated(address indexed store, string[6] metaData);
    
    Proxy public malusToken;
    address public feeCollector;
    
    mapping(address => bool) isValidStore;
    mapping(address => mapping(address => bool)) isStoreOwner;
    mapping(address => uint256) availableEthInsideStore; 
    mapping(address => uint256) stakeInsideStore;
    mapping(address => uint256) collateralInsideStore; 
    mapping(address => mapping(uint256 => uint256)) collateralReliefInsideStore; 
    mapping(address => address) extensionInsideStore;
    
    receive() external payable {
        require(isValidStore[msg.sender] == true);
    }
    
    function deployStore() override external {
        Store newStore = new Store(msg.sender);
        isValidStore[address(newStore)] = true;
        isStoreOwner[address(newStore)][msg.sender] = true;
        emit StoreCreated(address(newStore), msg.sender, block.timestamp);
    }
    
    function isStoreValid(address _store) override external view returns (bool) {
        return isValidStore[_store];
    }
    
    function getAvailableEth(address _store) public view returns (uint256) {
        return availableEthInsideStore[_store];
    }
    
    function getStake(address _store) public view returns (uint256) {
        return stakeInsideStore[_store];
    }
    
    function getCollateral(address _store) public view returns (uint256) {
        return collateralInsideStore[_store];
    }
    
    function getcollateralRelief(address _store, uint256 _rate) public view returns (uint256) {
        return collateralReliefInsideStore[_store][_rate];
    }
    
    function withdraw(uint256 _amount) override external returns (bool) {
        require(isValidStore[msg.sender] == true);
        require(availableEthInsideStore[msg.sender] >= _amount);
        availableEthInsideStore[msg.sender] -= _amount;
        return true;
    }
    
    function collectFee(address _to, uint256 _amount) external {
        require(msg.sender == address(feeCollector));
        (bool success2,) = _to.call{value: _amount}(""); 
        require(success2 == true);
    }
}


abstract contract Stake is StoreHub {
    
    function addStake(address payable _store, uint256 _amount) override external {  
        require(isStoreOwner[_store][msg.sender] == true);
        require(availableEthInsideStore[_store] >= _amount);
        uint256 balanceAfterFee = _amount;
        availableEthInsideStore[_store] -= _amount;
        
        if(malusToken.balanceOf(_store) < 25000000000000000000) {
            Store currentStore = Store(_store);
            uint256 fee = (_amount * 200) / 10000;
            currentStore.sendETH(address(this), fee);
            balanceAfterFee = _amount - fee;
        }
        
        stakeInsideStore[_store] += balanceAfterFee;
        emit StoreBalancesUpdated(_store, collateralInsideStore[_store], stakeInsideStore[_store], availableEthInsideStore[_store]);
    }
    
    function removeStake(address payable _store, uint256 _amount) override external {
        require(isStoreOwner[_store][msg.sender] == true);
        require(stakeInsideStore[_store] >= _amount);
        stakeInsideStore[_store] -= _amount;
        availableEthInsideStore[_store] += _amount;
        emit StoreBalancesUpdated(_store, collateralInsideStore[_store], stakeInsideStore[_store], availableEthInsideStore[_store]);
    }
}


 abstract contract Collateral is Stake {
    
    function provideCollateralRelief(address payable _store, uint256 _amount, uint256 _rate) override external { 
        require(isStoreOwner[_store][msg.sender] == true);
        require(availableEthInsideStore[_store] >= _amount);
        require(collateralReliefInsideStore[_store][_rate] == 0);
        require(_rate > 0 && _rate <= 10000);
        uint256 balanceAfterFee = _amount;
        availableEthInsideStore[_store] -= _amount;
        
        if(malusToken.balanceOf(_store) < 25000000000000000000) {
            uint256 fee = (_amount * 200) / 10000;
            Store currentStore = Store(_store);
            currentStore.sendETH(address(this), fee);
            balanceAfterFee = _amount - fee;
        }
        
        collateralReliefInsideStore[_store][_rate] += balanceAfterFee;
        emit CollateralReliefUpdated(_store, collateralReliefInsideStore[_store][_rate], availableEthInsideStore[_store], _rate, true);
    }
    
    function removeCollateralRelief(address _store, uint256 _amount, uint256 _rate) override external {
        require(isStoreOwner[_store][msg.sender] == true);
        require(collateralReliefInsideStore[_store][_rate] >= _amount);
        collateralReliefInsideStore[_store][_rate] -= _amount;
        availableEthInsideStore[_store] += _amount;
        emit CollateralReliefUpdated(_store, collateralReliefInsideStore[_store][_rate], availableEthInsideStore[_store], _rate, false);
    }
    
    function sellCollateral(address payable _fromStore, address payable _toStore, uint256 _amount, uint16 _rate) override external {
        uint256 lost = (_amount * _rate) / 10000;
        require(isStoreOwner[_fromStore][msg.sender] == true);
        require(isValidStore[_toStore] == true);
        require(collateralInsideStore[_fromStore] >= _amount);
        require((_amount - lost) == collateralReliefInsideStore[_toStore][_rate]);
        collateralInsideStore[_fromStore] -= _amount;
        collateralInsideStore[_toStore] += _amount;
        availableEthInsideStore[_fromStore] = (_amount - lost);
        collateralReliefInsideStore[_toStore][_rate] = 0;
        Store currentStore = Store(_fromStore);
        currentStore.sendCollateral(_toStore, lost);
        emit StoreBalancesUpdated(_toStore, collateralInsideStore[_toStore], stakeInsideStore[_toStore], availableEthInsideStore[_toStore]);
        emit StoreBalancesUpdated(_fromStore, collateralInsideStore[_fromStore], stakeInsideStore[_fromStore], availableEthInsideStore[_fromStore]);
    }
    
    function transferCollateral(address payable _fromStore, address payable _toStore, uint256 _amount) override external {
        require(isStoreOwner[_fromStore][msg.sender] == true);
        require(isValidStore[_toStore] == true);
        require(collateralInsideStore[_fromStore] >= _amount);
        collateralInsideStore[_fromStore] -= _amount;
        collateralInsideStore[_toStore] += _amount;
        Store currentStore = Store(_fromStore);
        currentStore.sendCollateral(_toStore, _amount);
        emit StoreBalancesUpdated(_toStore, collateralInsideStore[_toStore], stakeInsideStore[_toStore], availableEthInsideStore[_toStore]);
        emit StoreBalancesUpdated(_fromStore, collateralInsideStore[_fromStore], stakeInsideStore[_fromStore], availableEthInsideStore[_fromStore]);
    }
}


abstract contract General is Collateral {
    
    function setMetaData(address _store, string[6] calldata _metaData) override external {
        require(isStoreOwner[_store][msg.sender] == true);
        emit MetaDataUpdated(_store, _metaData);
    }
    
    function updateExtension(address payable _store, address _newExtension) override external {
        require(isStoreOwner[_store][msg.sender] == true);
        Store currentStore = Store(_store);
        extensionInsideStore[_store] = _newExtension;
        currentStore.updateData(msg.sender, _newExtension);
        emit ExtensionUpdated(_store, _newExtension);
    }
    
    function updateStoreOwner(address payable _store, address _newOwner) override external {
        require(isStoreOwner[_store][msg.sender] == true);
        Store currentStore = Store(_store);
        isStoreOwner[_store][msg.sender] = false;
        isStoreOwner[_store][_newOwner] = true;
        currentStore.updateData(_newOwner, extensionInsideStore[_store]);
        emit OwnerUpdated(_store, _newOwner);
    }
}


contract FruitToken is General {
    
    string public name = "Fruit Token";
    string public symbol = "FRUT";
    uint public decimals = 18; 
    uint256 public totalSupply;
    
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    
    constructor(address malusTokenAddress, address _sender) {
        malusToken = Proxy(malusTokenAddress);
        feeCollector = _sender;
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
                availableEthInsideStore[msg.sender] += (_paymentReceived - sevenPercentOfPayment);
            }
            
            emit Transfer(address(0), _customer, sevenPercentOfPayment);
            emit StoreBalancesUpdated(msg.sender, collateralInsideStore[msg.sender], stakeInsideStore[msg.sender], availableEthInsideStore[msg.sender]);
            return(true, (_paymentReceived - sevenPercentOfPayment)); 
        }
        else {
            
            if(extensionInsideStore[msg.sender] == address(0)) {
                availableEthInsideStore[msg.sender] += _paymentReceived;
            }
            
            emit StoreBalancesUpdated(msg.sender, collateralInsideStore[msg.sender], stakeInsideStore[msg.sender], availableEthInsideStore[msg.sender]);
            return(true, _paymentReceived);
        }
    }
    
    function _burn(address _from, address _store, uint256 _amount) private { 
        require(collateralInsideStore[_store] >= _amount);
        
        if (_from != msg.sender && allowed[_from][msg.sender] > 0) {
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] -= _amount;
        }
        
        collateralInsideStore[_store] -= _amount;
        availableEthInsideStore[_store] += _amount;
        balances[_from] -= _amount;
        totalSupply -= _amount;
        
        if(extensionInsideStore[_store] != address(0)) {
            address payable wallet = payable(_store);
            availableEthInsideStore[_store] -= _amount;
            Store currentStore = Store(wallet);
            currentStore.sendETH(msg.sender, _amount);
        }
        emit Transfer(_from, address(0), _amount);
        emit StoreBalancesUpdated(_store, collateralInsideStore[_store], stakeInsideStore[_store], availableEthInsideStore[_store]);
    }
}

contract Deployer {
    address public fruitTokenAddress;
    
    constructor(address malusTokenAddress) {
        FruitToken fruitToken = new FruitToken(malusTokenAddress, msg.sender);
        fruitTokenAddress = address(fruitToken);
    }
}