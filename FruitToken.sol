pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

interface StoreHubInterface { 
    function deployStore() external; 
    function isStoreValid(address _store) external view returns (bool); 
    function addStake(address payable _store, uint256 _amount) external;
    function removeStake(address payable _store, uint256 _amount) external;
    function provideCollateralRelief(address _store, uint256 _amount, uint256 _rate) external;
    function removeCollateralRelief(address _store, uint256 _amount, uint256 _rate) external;
    function sellCollateral(address _fromStore, address payable _toStore, uint256 _amount, uint16 _rate) external;
    function transferCollateral(address _fromStore, address payable _toStore, uint256 _amount) external;
    function setMetaData(address _store, string[6] calldata _metaData) external;
    function updateExtension(address payable _store, address _newExtension) external;
    function updateStoreOwner(address payable _store, address _owner) external;
}


interface StoreExtensionInterface {
    function setRequiredAmount(uint256 _amount) external;
    function processPayment(address _sender) external payable;
}


abstract contract Proxy {
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
    function mint(uint256 _amount, uint256 _updatedStake, uint256 _updatedAvailableFunds) virtual external; 
    function withdraw(uint256 _amount) virtual external returns (bool);
}


contract Store {
    
    StoreExtensionInterface public storeExtension;
    Proxy public storeHub;
    address public owner;
    uint256 public stake;
    
    constructor(address _storeHubAddress) { 
        owner = msg.sender;
        storeHub = Proxy(_storeHubAddress);
    }
    
    function sendERC20Token(address _tokenContract, address _to, uint256 _amount) external { 
        require(msg.sender == owner);
        Proxy erc20Contract = Proxy(_tokenContract);
        erc20Contract.transferFrom(address(this), _to, _amount);
    }
    
    function sendETH(address _to, uint256 _amount) external {
        require(msg.sender == owner);
        (bool success1) = storeHub.withdraw(_amount);
        require(success1 == true);
        (bool success2,) = _to.call{value: _amount}(""); 
        require(success2 == true);
    }
    
    function updateData(uint256 _stake, address _owner, address _storeExtension) external {
        require(msg.sender == address(storeHub));
        stake = _stake;
        owner = _owner;
        storeExtension = StoreExtensionInterface(_storeExtension);
    }
    
    fallback() external payable {
        _createPoints();
    }
    
    receive() external payable {
        _createPoints();
    }
    
    function _createPoints() private {
        uint256 sevenPercentOfPayment = (msg.value * 700) / 10000;
        
        if(address(storeExtension) == address(0)) {
            if(stake > 0) {
                require(sevenPercentOfPayment <= stake);
                stake -= sevenPercentOfPayment;
                storeHub.mint(sevenPercentOfPayment, stake, (msg.value - sevenPercentOfPayment));
            }
            storeHub.mint(0, stake, msg.value);
        }
        else {
            if(stake > 0) {
                uint256 balance = msg.value - sevenPercentOfPayment;
                require(sevenPercentOfPayment <= stake);
                stake -= sevenPercentOfPayment;
                storeHub.mint(sevenPercentOfPayment, stake, (msg.value - sevenPercentOfPayment));
                storeExtension.processPayment{value: balance}(msg.sender);
            }
            storeExtension.processPayment{value: msg.value}(msg.sender);
        }
    }
}


abstract contract StoreHub is StoreHubInterface, Proxy {
    
    event StoreCreated(address indexed store, address owner, uint256 creationDate); 
    event OwnerUpdated(address indexed store, address newOwner);
    event StakeUpdated(address indexed store, uint256 stake, uint256 availableFunds);
    event BalanceUpdated(address indexed store, uint256 amount);
    event CollateralReliefUpdated(address indexed store, uint256 collateralRelief, uint256 availableFunds, uint256 rate);
    event CollateralGenerated(address indexed store, uint256 amountGenerated, uint256 collateral, uint256 stake, uint256 availableFunds);
    event CollateralReleased(address indexed store, uint256 amountReleased, uint256 collateral, uint256 availableFunds); 
    event ExtensionUpdated(address indexed store, address extension);
    event MetaDataUpdated(address indexed store, string[6] metaData);
    
    address public malusTokenAddress;
    address public firstStoreAddress;
    
    mapping(address => bool) isValidStore;
    mapping(address => mapping(address => bool)) isStoreOwner;
    mapping(address => uint256) availableEthInsideStore; 
    mapping(address => uint256) stakeInsideStore;
    mapping(address => uint256) collateralInsideStore; 
    mapping(address => mapping(uint256 => uint256)) collateralReliefInsideStore; 
    mapping(address => address) extensionInsideStore;
    
    function deployStore() override external {
        Store newStore = new Store(address(this));
        isValidStore[address(newStore)] = true;
        isStoreOwner[address(newStore)][msg.sender] = true;
        emit StoreCreated(address(newStore), msg.sender, block.timestamp);
    }
    
    function isStoreValid(address _store) override external view returns (bool) {
        return isValidStore[_store];
    }
    
    function withdraw(uint256 _amount) override external returns (bool) {
        require(isValidStore[msg.sender] == true);
        availableEthInsideStore[msg.sender] -= _amount;
        return true;
    }
}


abstract contract Stake is StoreHub {
    
    function addStake(address payable _store, uint256 _amount) override external { //add check malusToken later collect fee.. 
        require(isStoreOwner[_store][msg.sender] == true);
        require(_amount <= availableEthInsideStore[_store]);
        Store currentStore = Store(_store);
        stakeInsideStore[_store] += _amount;
        availableEthInsideStore[_store] -= _amount;
        currentStore.updateData(stakeInsideStore[_store], msg.sender, extensionInsideStore[_store]);
        emit StakeUpdated(_store, stakeInsideStore[_store], availableEthInsideStore[_store]);
    }
    
    function removeStake(address payable _store, uint256 _amount) override external {
        require(isStoreOwner[_store][msg.sender] == true);
        require(_amount <= stakeInsideStore[_store]);
        Store currentStore = Store(_store);
        stakeInsideStore[_store] -= _amount;
        availableEthInsideStore[_store] += _amount;
        currentStore.updateData(stakeInsideStore[_store], msg.sender, extensionInsideStore[_store]);
        emit StakeUpdated(_store, stakeInsideStore[_store], availableEthInsideStore[_store]);
    }
}


 abstract contract Collateral is Stake {
    
    function provideCollateralRelief(address _store, uint256 _amount, uint256 _rate) override external { //add check malusToken later collect fee..
        require(isStoreOwner[_store][msg.sender] == true);
        require(_amount <= availableEthInsideStore[_store]);
        require(_rate > 0 && _rate <= 10000);
        availableEthInsideStore[_store] -= _amount;
        collateralReliefInsideStore[_store][_rate] += _amount;
        emit CollateralReliefUpdated(_store, collateralReliefInsideStore[_store][_rate], availableEthInsideStore[_store], _rate);
    }
    
    function removeCollateralRelief(address _store, uint256 _amount, uint256 _rate) override external {
        require(isStoreOwner[_store][msg.sender] == true);
        require(_amount <= collateralReliefInsideStore[_store][_rate]);
        availableEthInsideStore[_store] -= _amount;
        collateralReliefInsideStore[_store][_rate] += _amount;
        emit CollateralReliefUpdated(_store, collateralReliefInsideStore[_store][_rate], availableEthInsideStore[_store], _rate);
    }
    
    function sellCollateral(address _fromStore, address payable _toStore, uint256 _amount, uint16 _rate) override external {
        uint256 lost = (_amount * _rate) / 10000;
        require(isStoreOwner[_fromStore][msg.sender] == true);
        require(_amount <= collateralInsideStore[_fromStore]);
        require((_amount - lost) == collateralReliefInsideStore[_toStore][_rate]);
        collateralInsideStore[_toStore] = (collateralReliefInsideStore[_toStore][_rate] + lost);
        collateralInsideStore[_fromStore] -= _amount;
        availableEthInsideStore[_fromStore] = collateralReliefInsideStore[_toStore][_rate];
        collateralReliefInsideStore[_toStore][_rate] = 0;
        emit CollateralGenerated(_toStore, _amount, collateralInsideStore[_toStore], stakeInsideStore[_toStore], availableEthInsideStore[_toStore]);
        emit CollateralReleased(_fromStore, _amount, collateralInsideStore[_fromStore], availableEthInsideStore[_fromStore]);
    }
    
    function transferCollateral(address _fromStore, address payable _toStore, uint256 _amount) override external {
        require(isStoreOwner[_fromStore][msg.sender] == true);
        require(_amount <= collateralInsideStore[_fromStore]);
        collateralInsideStore[_toStore] += _amount;
        collateralInsideStore[_fromStore] -= _amount;
        emit CollateralGenerated(_toStore, _amount, collateralInsideStore[_toStore], stakeInsideStore[_toStore], availableEthInsideStore[_toStore]);
        emit CollateralReleased(_fromStore, _amount, collateralInsideStore[_fromStore], availableEthInsideStore[_fromStore]);
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
        currentStore.updateData(stakeInsideStore[_store], msg.sender, extensionInsideStore[_store]);
        emit ExtensionUpdated(_store, _newExtension);
    }
    
    function updateStoreOwner(address payable _store, address _newOwner) override external {
        require(isStoreOwner[_store][msg.sender] == true);
        Store currentStore = Store(_store);
        isStoreOwner[_store][msg.sender] = false;
        isStoreOwner[_store][_newOwner] = true;
        currentStore.updateData(stakeInsideStore[_store], _newOwner, extensionInsideStore[_store]);
        emit OwnerUpdated(_store, _newOwner);
    }
}


contract FruitToken is General {
    
    function transferFrom(address _from, address _to, uint256 _amount) override public returns (bool success) {
        
    }
    
    function mint(uint256 _amount, uint256 _updatedStake, uint256 _updatedAvailableFunds) override external {
        
    }
    
}
