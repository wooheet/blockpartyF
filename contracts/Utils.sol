pragma solidity 0.4.19;

import "./ERC20Interface.sol";

contract Utils {
    ERC20 constant internal ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
    uint  constant internal MAX_DECIMALS = 18;
    uint  constant internal ETH_DECIMALS = 18;
    mapping(address=>uint) internal decimals;

    function getBalance(ERC20 _token, address _user) public view returns(uint) {
      if (_token == ETH_TOKEN_ADDRESS)
          return _user.balance;
      else
          return _token.balanceOf(_user);
    }
}