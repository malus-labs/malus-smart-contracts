pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

interface StoreHubInterface { 
    function deployStore() external; 
    function isStoreValid(address _store) external view returns (bool); 
    function addStake(address _store, uint256 _amount) external;
    function removeStake(address _store, uint256 _amount) external;
    /*
    function provideColateralRelief(uint256 _amount, uint256 _rate) external;
    function removeColateralRelief(uint256 _amount) external;
    function sellCollateral(address _store, uint256 _amount, uint16 _rate) external;
    function transferCollateral(address _store, uint256 _amount) external;
    function setMetaData(string[6] calldata _metaData) external;
    function updateExtension(address payable _newExtension) external;
    function updateStoreOwner(address payable _owner) external;
    function depositEther() external payable;
    */
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
    event StakeUpdated(address indexed store, uint256 stake, uint256 avaiableFunds);
    event BalanceUpdated(address indexed store, uint256 amount);
    event CollateralReliefUpdated(address indexed store, uint256 collateralRelief, uint256 avaiableFunds, uint256 rate);
    event CollateralGenerated(address indexed store, uint256 amountGenerated, uint256 collateral, uint256 stake, uint256 avaiableFunds);
    event CollateralReleased(address indexed store, uint256 amountReleased, uint256 collateral, uint256 avaiableFunds); 
    event MetaDataUpdated(address indexed store, string[6] metaData);
    
    Store currentStore;
    address public malusTokenAddress;
    address public firstStoreAddress;
    
    mapping(address => bool) isValidStore;
    mapping(address => bool) isStoreOwner;
    mapping(address => uint256) stakePerStore;
    
    modifier onlyOwner() {
        require(isStoreOwner[msg.sender] == true);
        _;
    }
    
    function deployStore() override external {
        Store newStore = new Store(address(this));
        isValidStore[address(newStore)] = true;
        isStoreOwner[address(newStore)] = true;
        emit StoreCreated(address(newStore), msg.sender, block.timestamp);
    }
    
    function isStoreValid(address _store) override external view returns (bool) {
        return isValidStore[_store];
    }
}


contract Stake is StoreHub {
    
    function addStake(address _store, uint256 _amount) onlyOwner override external {
        
    }
    
    function removeStake(address _store, uint256 _amount) onlyOwner override external {
        
    }
}


contract FruitToken is Stake {
    
}
