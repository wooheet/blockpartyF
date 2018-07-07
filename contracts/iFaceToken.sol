pragma solidity 0.4.19;

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

    function getFaceId(address who)
    public
    view
    returns (string) {
        return _faceID[who];
    }
    
    function getFingerId(address who)
    public
    view
    returns (string) {
        return _fingerID[who];
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
    isTokenTransfer
    checkLock
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