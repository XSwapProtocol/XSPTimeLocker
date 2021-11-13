pragma solidity ^0.5.0;


library SafeMath {
    function add(uint a, uint b) internal pure returns(uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns(uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns(uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns(uint c) {
        require(b > 0);
        c = a / b;
    }
}

contract ERC20Interface {
    function totalSupply() public view returns(uint);
    function balanceOf(address tokenOwner) public view returns(uint balance);
    function allowance(address tokenOwner, address spender) public view returns(uint remaining);
    function transfer(address to, uint tokens) public returns(bool success);
    function approve(address spender, uint tokens) public returns(bool success);
    function transferFrom(address from, address to, uint tokens) public returns(bool success);
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract XSPTimeLocker {

    using SafeMath for uint;

    ERC20Interface public tokenContract;


    uint constant maxWithdrawalAmount =  130_000_000 * 10**18;
    uint constant timeBetweenWithdrawals = 90 days;
    uint unfreezeDate;

    mapping (address => uint) balance;
    mapping (address => uint) lastWithdrawal;

    event TokensFrozen (
        address indexed addr,
        uint256 amt,
        uint256 time
    );

    event TokensUnfrozen (
        address indexed addr,
        uint256 amt,
        uint256 time
    );

    constructor() public {
        unfreezeDate = now + timeBetweenWithdrawals;
        tokenContract = ERC20Interface(0x36726235dAdbdb4658D33E62a249dCA7c4B2bC68);
    }

    function withdraw(uint _amount) public {
        require(balance[msg.sender] >= _amount, "You do not have enough tokens!");
        require(now >= unfreezeDate, "Tokens are locked!");
        require(_amount <= maxWithdrawalAmount, "Trying to withdraw too much at once!");
        require(now >= lastWithdrawal[msg.sender] + timeBetweenWithdrawals, "Trying to withdraw too frequently!");
        require(tokenContract.transfer(msg.sender, _amount), "Could not withdraw!");

        balance[msg.sender] -= _amount;
        lastWithdrawal[msg.sender] = now;
        emit TokensUnfrozen(msg.sender, _amount, now);
    }

    function getBalance(address _addr) public view returns (uint256 _balance) {
        return balance[_addr];
    }

    function getLastWithdrawal(address _addr) public view returns (uint256 _lastWithdrawal) {
        return lastWithdrawal[_addr];
    }

    function getTimeLeft() public view returns (uint256 _timeLeft) {
        require(unfreezeDate > now, "The future is here!");
        return unfreezeDate - now;
    }

    function receiveApproval(address _sender, uint256 _value, address _tokenContract) public {
        require(ERC20Interface(_tokenContract) == tokenContract, "Can only deposit into this contract!");
        require(_value > 100, "Should be greater than 100!");
        require(tokenContract.transferFrom(_sender, address(this), _value), "Could not transfer to Time Lock contract address.");

        uint _adjustedValue = _value.mul(99).div(100);
        balance[_sender] += _adjustedValue;
        emit TokensFrozen(_sender, _adjustedValue, now);
    }

    function deposit(uint256 _value) public {
        require(tokenContract.transferFrom(msg.sender, address(this), _value), "Could not transfer to Time Lock contract address.");

        balance[msg.sender] += _value;
        emit TokensFrozen(msg.sender, _value, now);
    }
}