pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

interface StoreHubInterface { 
    function deployStore() external; 
    function isStoreValid(address _store) external view returns (bool); 
    function addStake(address payable _store, uint256 _amount) external;
    function removeStake(address payable _store, uint256 _amount) external;
    function provideCollateralRelief(address _store, uint256 _amount, uint256 _rate) external;
    function removeCollateralRelief(address _store, uint256 _amount, uint256 _rate) external;
    function sellCollateral(address _fromStore, address _toStore, uint256 _amount, uint16 _rate) external;
    function transferCollateral(address _fromStore, address _toStore, uint256 _amount) external;
    function setMetaData(address _store, string[6] calldata _metaData) external;
    function updateExtension(address payable _store, address _newExtension) external;
    function updateStoreOwner(address payable _store, address _owner) external;
}


interface StoreExtensionInterface {
    function setRequiredAmount(uint256 _amount) external;
    function processPayment(address _sender) external payable;
}


abstract contract ERC20 {
    function transferFrom(address _from, address _to, uint256 _amount) virtual public returns (bool success); 
    function mint(uint256 _amount, uint256 _updatedStake) virtual external payable; 
}


contract Store {
    
    StoreExtensionInterface public storeExtension;
    ERC20 public storeHub;
    address public owner;
    uint256 public stake;
    
    constructor(address _storeHubAddress) { 
        owner = msg.sender;
        storeHub = ERC20(_storeHubAddress);
    }
    
    function sendERC20Token(address _tokenContract, address _receiver, uint256 _value) external { 
        require(msg.sender == owner);
        ERC20 erc20Contract = ERC20(_tokenContract);
        erc20Contract.transferFrom(address(this), _receiver, _value);
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
                storeHub.mint{value: msg.value}(sevenPercentOfPayment, stake); 
            }
            storeHub.mint{value: msg.value}(0, stake);
        }
        else {
            if(stake > 0) {
                uint256 balance = msg.value - sevenPercentOfPayment;
                require(sevenPercentOfPayment <= stake);
                stake -= sevenPercentOfPayment;
                storeHub.mint{value: sevenPercentOfPayment}(sevenPercentOfPayment, stake); 
                storeExtension.processPayment{value: balance}(msg.sender);
            }
            storeExtension.processPayment{value: msg.value}(msg.sender);
        }
    }
}


abstract contract StoreHub is StoreHubInterface {
    
    event StoreCreated(address indexed store, address owner, uint256 creationDate); 
    event OwnerUpdated(address indexed store, address newOwner);
    event StakeUpdated(address indexed store, uint256 stake, uint256 availableFunds);
    event BalanceUpdated(address indexed store, uint256 amount);
    event CollateralReliefUpdated(address indexed store, uint256 collateralRelief, uint256 availableFunds, uint256 rate);
    event CollateralGenerated(address indexed store, uint256 amountGenerated, uint256 collateral, uint256 stake, uint256 availableFunds);
    event CollateralReleased(address indexed store, uint256 amountReleased, uint256 collateral, uint256 availableFunds); 
    event MetaDataUpdated(address indexed store, string[6] metaData);
    
    address public malusTokenAddress;
    address public firstStoreAddress;
    
    mapping(address => bool) isValidStore;
    mapping(address => mapping(address => bool)) isStoreOwner;
    mapping(address => uint256) availableEthInsideStore; //
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
    
    function sellCollateral(address _fromStore, address _toStore, uint256 _amount, uint16 _rate) override external {
        uint256 lost = (_amount * _rate) / 10000;
        require(isStoreOwner[_fromStore][msg.sender] == true);
        require(_amount <= collateralInsideStore[_fromStore]);
        require((_amount - lost) == collateralReliefInsideStore[_toStore][_rate]);
        collateralInsideStore[_toStore] = (collateralReliefInsideStore[_toStore][_rate] + lost);
        collateralInsideStore[_fromStore] -= _amount;
        availableEthInsideStore[_fromStore] = collateralReliefInsideStore[_toStore][_rate];
        collateralReliefInsideStore[_toStore][_rate] = 0;
        //emit CollateralGenerated(_toStore, _amount, collateralInsideStore[_toStore], stakeInsideStore[_toStore], availableEthInsideStore[_toStore]);
        //emit CollateralReleased(_fromStore, _amount, collateralInsideStore[_fromStore], availableEthInsideStore[_fromStore]);
    }
    
    function transferCollateral(address _fromStore, address _toStore, uint256 _amount) override external {
        require(isStoreOwner[_fromStore][msg.sender] == true);
        require(_amount <= collateralInsideStore[_fromStore]);
        collateralInsideStore[_toStore] += _amount;
        collateralInsideStore[_fromStore] -= _amount;
        emit CollateralGenerated(_toStore, _amount, collateralInsideStore[_toStore], stakeInsideStore[_toStore], availableEthInsideStore[_toStore]);
        emit CollateralReleased(_fromStore, _amount, collateralInsideStore[_fromStore], availableEthInsideStore[_fromStore]);
    }
}


contract General is Collateral {
    
    function setMetaData(address _store, string[6] calldata _metaData) override external {
       
        
    }
    
    function updateExtension(address payable _store, address _newExtension) override external {
   
        
    }
    
    function updateStoreOwner(address payable _store, address _owner) override external {
     
        
    }
}


contract FruitToken is General {
    
}
