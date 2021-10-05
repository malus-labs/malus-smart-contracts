/*pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

//This is for a future release.. 
contract MalusToken {
     
    uint256 public totalSupply;
    
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    constructor(uint256 _totalSupply) {
        totalSupply = _totalSupply;
        balances[msg.sender] = totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }
    
    function transfer(address _to, uint256 _amount) public returns (bool success) {
        return transferFrom(msg.sender, _to, _amount);
    }
    
    function transferFrom(address _from, address _to, uint256 _amount)public returns (bool success) {
        require(balances[_from] >= _amount);
        
        if (_from != msg.sender && allowed[_from][msg.sender] < (2**256 - 1)) {
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] -=_amount;
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
}
*/