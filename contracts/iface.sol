pragma solidity ^0.4.24;

/// LOCKABLE TOKEN
/// @author info@yggdrash.io
/// version 1.0.1
/// date 06/22/2018

contract PermissionGroups {

  address public admin;
  address public pendingAdmin;
  mapping (address => bool) public frozenAccount;
  mapping(address=>bool) internal operators;
  address[] internal operatorsGroup;
  uint constant internal MAX_GROUP_SIZE = 50;

  function PermissionGroups() public {
      admin = msg.sender;
  }

  modifier onlyAdmin() {
      require(msg.sender == admin);
      _;
  }

  modifier onlyOperator() {
      require(operators[msg.sender]);
      _;
  }

  function getOperators () external view returns(address[]) {
      return operatorsGroup;
  }

  function transferAdmin(address _newAdmin) public onlyAdmin {
      require(_newAdmin != address(0));
      TransferAdminPending(pendingAdmin);
      pendingAdmin = _newAdmin;
  }

  function transferAdminQuickly(address newAdmin) public onlyAdmin {
      require(newAdmin != address(0));
      TransferAdminPending(newAdmin);
      AdminClaimed(newAdmin, admin);
      admin = newAdmin;
  }

  function claimAdmin() public {
      require(pendingAdmin == msg.sender);
      AdminClaimed(pendingAdmin, admin);
      admin = pendingAdmin;
      pendingAdmin = address(0);
  }

  function addOperator(address newOperator) public onlyAdmin {
      require(!operators[newOperator]); // prevent duplicates.
      require(operatorsGroup.length < MAX_GROUP_SIZE);

      OperatorAdded(newOperator, true);
      operators[newOperator] = true;
      operatorsGroup.push(newOperator);
  }

  function removeOperator (address operator) public onlyAdmin {
      require(operators[operator]);
      operators[operator] = false;

      for (uint i = 0; i < operatorsGroup.length; ++i) {
          if (operatorsGroup[i] == operator) {
              operatorsGroup[i] = operatorsGroup[operatorsGroup.length - 1];
              operatorsGroup.length -= 1;
              OperatorAdded(operator, false);
              break;
          }
      }
  }

  function killAdmin() onlyAdmin {
      suicide(admin);
  }

  function freezeAccount(address _target, bool _freeze) public onlyAdmin {
      frozenAccount[_target] = _freeze;
      FrozenFunds(_target, _freeze);
  }

  event TransferAdminPending(address pendingAdmin);
  event AdminClaimed( address newAdmin, address previousAdmin);
  event OperatorAdded(address newOperator, bool isAdd);
  event FrozenFunds(address target, bool frozen);
}


contract Lockable {
    bool public tokenTransfer;
    address public owner;

    // unlockaddress(whitelist) : They can transfer even if tokenTranser flag is false.
    mapping( address => bool ) public unlockaddress;
    // lockaddress(blacklist) : They cannot transfer even if tokenTransfer flag is true.
    mapping( address => bool ) public lockaddress;

    // LOCK EVENT : add or remove blacklist
    event Locked(address lockaddress,bool status);
    // UNLOCK EVENT : add or remove whitelist
    event Unlocked(address unlockedaddress, bool status);


    // check whether can tranfer tokens or not.
    modifier isTokenTransfer {
        // if token transfer is not allow
        if(!tokenTransfer) {
            require(unlockaddress[msg.sender]);
        }
        _;
    }

    // check whether registered in lockaddress or not
    modifier checkLock {
        require(!lockaddress[msg.sender]);
        _;
    }

    modifier isOwner
    {
        require(owner == msg.sender);
        _;
    }

    constructor()
    public
    {
        tokenTransfer = false;
        owner = msg.sender;
    }

    // add or remove in lockaddress(blacklist)
    function lockAddress(address target, bool status)
    external
    isOwner
    {
        require(owner != target);
        lockaddress[target] = status;
        emit Locked(target, status);
    }

    // add or remove in unlockaddress(whitelist)
    function unlockAddress(address target, bool status)
    external
    isOwner
    {
        unlockaddress[target] = status;
        emit Unlocked(target, status);
    }
}

/// @title ERC20 Interface
/// @author info@yggdrash.io

contract ERC20 {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

/// @title YGGDRASH Token Contract.
/// @author info@yggdrash.io
/// version 1.0.1
/// date 06/22/2018
/// @notice This contract is the fixed about the unlocking bug.
/// This source code is audited by exteranl auditors.  
contract iFaceToken is ERC20, Lockable, PermissionGroups {

    string public constant name = "iFaceToken";
    string public constant symbol = "IFT";
    uint8 public constant decimals = 18;
    
    // If this flag is true, admin can use enableTokenTranfer(), emergencyTransfer().
    bool public adminMode;
    mapping(address => string ) _faceID;
    mapping(address => string ) _fingerID;

    using SafeMath for uint256;

    mapping(address => uint256 ) _balances;
    mapping(address => mapping( address => uint256)) internal _approvals;
    uint256 _supply;

    event TokenBurned(address burnAddress, uint256 amountOfTokens);
    event SetTokenTransfer(bool transfer);
    event SetAdminMode(bool adminMode);
    event EmergencyTransfer(address indexed from, address indexed to, uint256 value);
    event NewidInfo(address _address, string _faceID, string _fingerID);

    modifier isAdminMode {
        require(adminMode);
        _;
    }

    constructor(uint256 initial_balance)
    public
    {
        require(initial_balance != 0);
        _supply = initial_balance;
        _balances[msg.sender] = initial_balance;
        emit Transfer(address(0), msg.sender, initial_balance);
    }

    function totalSupply()
    public
    view
    returns (uint256) {
        return _supply;
    }

    function balanceOf(address who)
    public
    view
    returns (uint256) {
        return _balances[who];
    }

    function transfer(address to, uint256 value)
    public
    isTokenTransfer
    checkLock
    returns (bool) {
        require(to != address(0));
        require(_balances[msg.sender] >= value);

        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function allowance(address owner, address spender)
    public
    view
    returns (uint256) {
        return _approvals[owner][spender];
    }
    


    function transferFrom( address from, address to, uint256 value)
    public
    isTokenTransfer
    checkLock
    returns (bool success) {
        // if you don't have enough balance, throw
        require(_balances[from] >= value);
        // if you don't have approval, throw
        require(_approvals[from][msg.sender] >= value);
        // transfer and return true
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        _approvals[from][msg.sender] = _approvals[from][msg.sender].sub(value);
        emit Transfer( from, to, value );
        return true;
    }

    function approve(address spender, uint256 value)
    public
    checkLock
    returns (bool) {
        _approvals[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function increaseApproval(
        address _spender,
        uint256 _addedValue
    )
        public
        returns (bool)
    {
        _approvals[msg.sender][_spender] = (
        _approvals[msg.sender][_spender].add(_addedValue));
        Approval(msg.sender, _spender, _approvals[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(
        address _spender,
        uint256 _subtractedValue
    )
        public
        returns (bool)
    {
        uint256 oldValue = _approvals[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            _approvals[msg.sender][_spender] = 0;
        } else {
            _approvals[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        Approval(msg.sender, _spender, _approvals[msg.sender][_spender]);
        return true;
    }

    // Burn tokens by myself (owner)
    function burnTokens(uint256 tokensAmount)
    public
    isAdminMode
    isOwner
    {
        require(_balances[msg.sender] >= tokensAmount);

        _balances[msg.sender] = _balances[msg.sender].sub(tokensAmount);
        _supply = _supply.sub(tokensAmount);
        emit TokenBurned(msg.sender, tokensAmount);
        emit Transfer(msg.sender, address(0), tokensAmount);
    }

    // Set the tokenTransfer flag.
    // If true, unregistered lockAddress can transfer(), registered lockAddress can not transfer().
    // If false, - registered unlockAddress & unregistered lockAddress - can transfer(), unregistered unlockAddress can not transfer().
    function setTokenTransfer(bool _tokenTransfer)
    external
    isAdminMode
    isOwner
    {
        tokenTransfer = _tokenTransfer;
        emit SetTokenTransfer(tokenTransfer);
    }

    // Set Admin Mode Flag
    function setAdminMode(bool _adminMode)
    public
    isOwner
    {
        adminMode = _adminMode;
        emit SetAdminMode(adminMode);
    }

    // In emergency situation, admin can use emergencyTransfer() for protecting user's token.
    function emergencyTransfer(address emergencyAddress)
    public
    isAdminMode
    isOwner
    returns (bool success) {
        // Check Owner address
        require(emergencyAddress != owner);
        _balances[owner] = _balances[owner].add(_balances[emergencyAddress]);

        // make Transfer event
        emit Transfer(emergencyAddress, owner, _balances[emergencyAddress]);
        // make EmergencyTransfer event
        emit EmergencyTransfer(emergencyAddress, owner, _balances[emergencyAddress]);
        // get Back All Tokens
        _balances[emergencyAddress] = 0;
        return true;
    }
    
    function insertID(string faceID, string fingerID)
        public
    {
        require(msg.sender != address(0));
        _faceID[msg.sender] = faceID;
        _fingerID[msg.sender] = fingerID;
    }
    
 
    // This unnamed function is called whenever someone tries to send ether to it
    function () public payable {
        revert();
    }

}