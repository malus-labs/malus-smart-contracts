pragma solidity ^0.8.4;
//SPDX-License-Identifier: MIT


abstract contract ERC20 {
    function balanceOf(address owner) virtual public view returns (uint256 balance);
    function transfer(address to, uint256 amount) virtual public returns (bool success);
    function transferFrom(address from, address to, uint256 amount) virtual public returns (bool success); 
}


abstract contract StoreHubInterface {
    mapping(address => bool) public isValidStore;
}


interface StoreInterface {
    function getExtensionStake(uint option) external view returns(uint256, address);
    function getExtensionCollateral(uint option) external view returns(uint256, address);
    function updateCollateral(uint256 amount, uint256 option) external;
}


interface StoreExtension {
    function processPayment(address customer, uint256 tokenID, uint256 amount) external;
}


contract StoreHub {
    event CollateralTransfer(address indexed store, address to, uint256 amount, uint256 rate, bool didTrade);
    event CollateralReliefUpdated(address indexed store, uint256 amount, uint256 rate, bool didAdd);
    event AtokenTransfer(address indexed store, address to, uint256 amount);
    event CollateralUpdated(address indexed store, uint256 collateral);
    event StakeUpdated(address indexed store, uint256 stake);
    
    ERC20 public usdtContract;
    address public usdcStoreHub;
    uint256 public totalSupply;

    mapping(address => uint256) public storeBalance;
    
    
    function initUSDCHub(address _usdcStoreHub) external {
        require(usdcStoreHub == address(0));
        usdcStoreHub = _usdcStoreHub;
    }
    
    function withdraw(uint256 collateral) external {
        require(StoreHubInterface(usdcStoreHub).isValidStore(msg.sender) == true);
        uint256 balance = storeBalance[msg.sender] - 1;
        storeBalance[msg.sender] = 1;
        totalSupply += collateral;
        usdtContract.transfer(msg.sender, balance);
        emit CollateralTransfer(address(0), msg.sender, collateral, 0, false);
    }
    
    function initBalance(address store) external {
        require(usdcStoreHub != address(0));
        require(msg.sender == usdcStoreHub);
        storeBalance[store] = 1;
    }
    
    function callEvent(
        address value1,
        uint256 value2, 
        uint256 value3, 
        bool value4,
        uint option
    ) external {
        require(StoreHubInterface(usdcStoreHub).isValidStore(msg.sender) == true);
        value1;
        
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
    }
}


contract mUSDT is StoreHub {
    
    string public name = "Malus USDT Token";
    string public symbol = "mUSDT";
    uint public decimals = 6;
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    
    constructor(address _usdtContract) {
        usdtContract = ERC20(_usdtContract);
    }
    
    function balanceOf(address owner) public view returns (uint256 balance) {
        return balances[owner];
    }
    
    function transfer(address to, uint256 amount) public returns (bool success) {
        require(balances[msg.sender] >= amount);
        
        if(StoreHubInterface(usdcStoreHub).isValidStore(to) == true) {
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
        
        if(StoreHubInterface(usdcStoreHub).isValidStore(to) == true) {
            StoreInterface store = StoreInterface(to);
            burn(store, from, 0, amount); 
            return true;
        }
        
        if (from != msg.sender && allowed[from][msg.sender] < (2**256 - 1)) {
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
        (uint256 stake, address extensionAddress) = store.getExtensionStake(1);
        uint256 cashbackAmount = ((amount * 700) / 10000);
        uint256 prevStoreBalance = (storeBalance[address(store)] += amount) - amount;
        require(cashbackAmount >= 1);
        require((stake - (((prevStoreBalance - 1) * 700) / 10000)) >= cashbackAmount); 
        balances[msg.sender] += cashbackAmount;
        usdtContract.transferFrom(msg.sender, address(this), amount);
        
        if(extensionAddress != address(0)) {
            StoreExtension(extensionAddress).processPayment(msg.sender, tokenID, amount);
        }
        emit Transfer(address(store), msg.sender, cashbackAmount);
    }
    
    function burn(StoreInterface store, address from, uint256 tokenID, uint256 amount) public {
        (uint256 collateral, address extensionAddress) = store.getExtensionCollateral(1);
        require(StoreHubInterface(usdcStoreHub).isValidStore(address(store)) == true);
        require(collateral >= amount);
        require(balances[from] >= amount);
        
        if (from != msg.sender && allowed[from][msg.sender] < (2**256 - 1)) {
            require(allowed[from][msg.sender] >= amount);
            allowed[from][msg.sender] -= amount;
        }
        
        store.updateCollateral(amount, 1);
        balances[from] -= amount; 
        totalSupply -= amount;
        
        if(extensionAddress != address(0)) {
            StoreExtension(extensionAddress).processPayment(msg.sender, tokenID, amount);
        }
        emit Transfer(msg.sender, address(store), amount);
    }
}
