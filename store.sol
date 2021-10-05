pragma solidity ^0.8.4;
//SPDX-License-Identifier: MIT


abstract contract ERC20 {
    function balanceOf(address owner) virtual public view returns (uint256 balance);
    function transfer(address to, uint256 amount) virtual public returns (bool success); 
}


abstract contract StoreHubInterface {
    mapping(address => bool) public isValidStore;
    mapping(address => uint256) public storeBalance;
    function withdraw(uint256 collateral) virtual external;
    function callEvent(address value1, uint256 value2, uint256 value3, bool value4, uint option) virtual external;
}


interface StoreInterface {
    function receiveCollateral(uint256 amount, uint256 rate, uint option, bool isTrade) external;
}


contract Store {
    uint256[3] public collateral;
    uint256[3] public totalRelief;
    uint256[3] public stake;
    address[3] public storeHub;
    address[3] public aToken;
    address public extension;
    address public owner;
    
    mapping(uint => mapping(uint256 => uint256)) public collateralRelief;
    
    function init(address firstOwner, address usdtHub, address daiHub) external {
        require(storeHub[0] == address(0));
        owner = firstOwner;
        storeHub = [msg.sender, usdtHub, daiHub];
        aToken = [
            0xBcca60bB61934080951369a648Fb03DF4F96263C, 
            0x3Ed3B47Dd13EC9a98b44e6204A523E766B225811,
            0x028171bCA77440897B824Ca71D1c56caC55b68A3
        ];
    }
}


contract Assets is Store {
    
    function _getAvailableFunds(ERC20 _erc20Contract, uint256 _option) internal view returns (uint256) {
        require(address(_erc20Contract) == aToken[_option]);
        return _erc20Contract.balanceOf(address(this)) - (collateral[_option] + stake[_option] + totalRelief[_option]);
    }
    
    function sendERC20(address tokenContract, address to, uint256 amount) external {
        require(msg.sender == owner);
        uint option = 4;
        ERC20 erc20Contract = ERC20(tokenContract);
        
        if(aToken[0] == tokenContract) {
            require(_getAvailableFunds(erc20Contract, 0) >= amount);
            option = 0;
        }
        else if(aToken[1] == tokenContract) {
            require(_getAvailableFunds(erc20Contract, 1) >= amount);
            option = 1;
        }
        else if(aToken[2] == tokenContract) {
            require(_getAvailableFunds(erc20Contract, 2) >= amount);
            option = 2;
        }
        
        erc20Contract.transfer(to, amount);
        if(option < 4) {
            StoreHubInterface(storeHub[option]).callEvent(to, amount, 0, false, 3);
        }
    }
    
    function claimStoreHubBalance(uint option) public {
        require(msg.sender == owner);
        uint256 storeBalance = StoreHubInterface(storeHub[option]).storeBalance(address(this)) - 1;
        collateral[option] += ((storeBalance * 700)/10000);
        stake[option] = 0;
        StoreHubInterface(storeHub[option]).withdraw(((storeBalance * 700)/10000));
    }
}


contract Stake is Assets {
    
    function getExtensionStake(uint option) external view returns(uint256, address) {
        return (stake[option], extension);
    }
    
    function addStake(uint256 amount, uint option) external {
        require(msg.sender == owner);
        require(_getAvailableFunds(ERC20(aToken[option]), option) >= amount);
        stake[option] += amount;
        StoreHubInterface(storeHub[option]).callEvent(address(0), amount, 0, false, 0);
    }
}


contract Collateral is Stake {
    
    function getExtensionCollateral(uint option) external view returns(uint256, address) {
        return (collateral[option], extension);
    }
    
    function provideCollateralRelief(uint256 amount, uint256 rate, uint option, bool didAddRelief) external {
        require(msg.sender == owner);
        require(rate > 0 && rate <= 10000);
        
        if(didAddRelief == true) {
            require(_getAvailableFunds(ERC20(aToken[option]), option) >= amount);
            collateralRelief[option][rate] += amount;
            totalRelief[option] += amount;
            StoreHubInterface(storeHub[option]).callEvent(address(0), amount, rate, true, 1);
        }
        else {
            require(collateralRelief[option][rate] >= amount);
            collateralRelief[option][rate] -= amount;
            totalRelief[option] -= amount;
            StoreHubInterface(storeHub[option]).callEvent(address(0), amount, rate, false, 1);
        }
    }
    
    function transferCollateral(StoreInterface store, uint256 amount, uint option) external {
        require(msg.sender == owner);
        require(StoreHubInterface(storeHub[0]).isValidStore(address(store)) == true);
        require(collateral[option] >= amount);
        collateral[option] -= amount;
        store.receiveCollateral(amount, 0, option, false);
        ERC20(aToken[option]).transfer(address(store), amount);
        StoreHubInterface(storeHub[option]).callEvent(address(store), amount, 0, false, 2);
    }
    
    function sellCollateral(StoreInterface store, uint256 amount, uint256 rate, uint option) external {
        uint256 lost = (amount * rate) / 10000;
        require(msg.sender == owner);
        require(StoreHubInterface(storeHub[0]).isValidStore(address(store)) == true);
        require(lost >= 1);
        require(collateral[option] >= amount);
        collateral[option] -= amount;
        store.receiveCollateral(amount, rate, option, true);
        ERC20(aToken[option]).transfer(address(store), lost);
        StoreHubInterface(storeHub[option]).callEvent(address(store), amount, rate, true, 2);
    }
    
    function receiveCollateral(uint256 amount, uint256 rate, uint option, bool isTrade) external {
        require(StoreHubInterface(storeHub[0]).isValidStore(address(msg.sender))  == true);
        
        if(isTrade == true){
            require(collateralRelief[option][rate] == amount);
            collateralRelief[option][rate] = 0;
            totalRelief[option] -= amount;
        }
        
        collateral[option] += amount;
    }
    
    function updateCollateral(uint256 amount, uint option) external {
        require(msg.sender == storeHub[option]);
        collateral[option] -= amount;
    }
}


contract General is Collateral {
    
    function updateExtension(address newExtension) external {
        require(msg.sender == owner);
        extension = newExtension;
        StoreHubInterface(storeHub[0]).callEvent(extension, 0, 0, false, 4);
    }
    
    function updateOwner(address newOwner) external {
        require(msg.sender == owner);
        owner = newOwner;
        StoreHubInterface(storeHub[0]).callEvent(owner, 0, 0, false, 5);
    }
}