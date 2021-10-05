pragma solidity ^0.8.4;
//SPDX-License-Identifier: MIT


abstract contract ERC20 {
    function balanceOf(address owner) virtual public view returns (uint256 balance);
    function transfer(address to, uint256 amount) virtual public returns (bool success);
    function transferFrom(address from, address to, uint256 amount) virtual public returns (bool success); 
}


interface StoreInterface {
    function getExtensionStake(uint option) external view returns(uint256, address);
    function getExtensionCollateral(uint option) external view returns(uint256, address);
    function updateCollateral(uint256 amount, uint256 option) external;
}


interface StoreExtension {
    function processPayment(address customer, uint256 tokenID, uint256 amount) external;
}


interface StoreHubInterface {
    function initBalance(address store) external;
    function withdraw(address to) external;
}


interface StoreProxy {
    function init(address owner, address usdtHub, address daiHub) external;
}


contract StoreHub {
    event CollateralTransfer(address indexed store, address to, uint256 amount, uint256 rate, bool didTrade);
    event CollateralReliefUpdated(address indexed store, uint256 amount, uint256 rate, bool didAdd);
    event StoreCreated(address indexed store, address owner, uint256 creationDate); 
    event AtokenTransfer(address indexed store, address to, uint256 amount);
    event ExtensionUpdated(address indexed store, address extension);
    event OwnerUpdated(address indexed store, address newOwner);
    event StakeUpdated(address indexed store, uint256 stake);
    
    ERC20 public usdcContract;
    address public usdtStoreHub;
    address public daiStoreHub;
    address public storeImplementation;
    uint256 public totalSupply;
    
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
        StoreHubInterface(usdtStoreHub).initBalance(newStore);
        StoreHubInterface(daiStoreHub).initBalance(newStore);
        emit StoreCreated(newStore, msg.sender, block.timestamp);
    }
    
    function withdraw(uint256 collateral) external {
        require(isValidStore[msg.sender] == true);
        uint256 balance = storeBalance[msg.sender] - 1;
        storeBalance[msg.sender] = 1;
        totalSupply += collateral;
        usdcContract.transfer(msg.sender, balance);
        emit CollateralTransfer(address(0), msg.sender, collateral, 0, false);
    }
    
    function callEvent(
        address value1,
        uint256 value2, 
        uint256 value3, 
        bool value4,
        uint option
    ) external {
        require(isValidStore[msg.sender] == true);
        
        if(option == 0) {
            emit StakeUpdated(msg.sender, value2);
        }
        else if(option == 1) {
            emit CollateralReliefUpdated(msg.sender, value2, value3, value4);
        }
        else if(option == 2) {
            emit CollateralTransfer(msg.sender, value1, value2, value3, value4);
        }
        else if(option == 3) {
            emit AtokenTransfer(msg.sender, value1, value2);
        }
        else if(option == 4) {
            emit ExtensionUpdated(msg.sender, value1);
        }
        else {
            emit OwnerUpdated(msg.sender, value1);
        }
    }
}


contract mUSDC is StoreHub {
    
    string public name = "Malus USDC Token";
    string public symbol = "mUSDC";
    uint public decimals = 6;
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    
    constructor(address _usdcContract, address _usdtStoreHub, address _daiStoreHub, address _implementation) {
        usdcContract = ERC20(_usdcContract);
        usdtStoreHub = _usdtStoreHub;
        daiStoreHub = _daiStoreHub;
        storeImplementation = _implementation;
    }
    
    function balanceOf(address owner) public view returns (uint256 balance) {
        return balances[owner];
    }
    
    function transfer(address to, uint256 amount) public returns (bool success) {
        require(balances[msg.sender] >= amount);
        
        if(isValidStore[to] == true) {
            StoreInterface store = StoreInterface(to);
            burn(store, msg.sender, 0, amount); 
            return true;
        }
        
        balances[to] += amount;
        balances[msg.sender] -= amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public returns (bool success) {
        require(balances[from] >= amount);
        
        if(isValidStore[to] == true) {
            StoreInterface store = StoreInterface(to);
            burn(store, from, 0, amount); 
            return true;
        }
        
        if(from != msg.sender && allowed[from][msg.sender] < (2**256 - 1)) {
            require(allowed[from][msg.sender] >= amount);
            allowed[from][msg.sender] -= amount;
        }
        
        balances[to] += amount;
        balances[from] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool success) {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
   
    function allowance(address owner, address spender) public view returns (uint remaining) {
        return allowed[owner][spender];
    }
    
    function mint(StoreInterface store, uint256 tokenID, uint256 amount) external {
        (uint256 stake, address extensionAddress) = store.getExtensionStake(0);
        uint256 cashbackAmount = ((amount * 700) / 10000);
        uint256 prevStoreBalance = (storeBalance[address(store)] += amount) - amount;
        require(cashbackAmount >= 1);
        require((stake - (((prevStoreBalance - 1) * 700) / 10000)) >= cashbackAmount); 
        balances[msg.sender] += cashbackAmount;
        usdcContract.transferFrom(msg.sender, address(this), amount);
        
        if(extensionAddress != address(0)) {
            StoreExtension(extensionAddress).processPayment(msg.sender, tokenID, amount);
        }
        emit Transfer(address(store), msg.sender, cashbackAmount);
    }
    
    function burn(StoreInterface store, address from, uint256 tokenID, uint256 amount) public {
        (uint256 collateral, address extensionAddress) = store.getExtensionCollateral(0);
        require(isValidStore[address(store)] == true);
        require(collateral >= amount);
        require(balances[from] >= amount);
        
        if(from != msg.sender && allowed[from][msg.sender] < (2**256 - 1)) {
            require(allowed[from][msg.sender] >= amount);
            allowed[from][msg.sender] -= amount;
        }
        
        store.updateCollateral(amount, 0);
        balances[from] -= amount; 
        totalSupply -= amount;
        
        if(extensionAddress != address(0)) {
            StoreExtension(extensionAddress).processPayment(msg.sender, tokenID, amount);
        }
        emit Transfer(msg.sender, address(store), amount);
    }
}
