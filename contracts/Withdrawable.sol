pragma solidity 0.4.19;


import "./PermissionGroups.sol";


contract Withdrawable is PermissionGroups {

    function withdrawToken(ERC20 _token, uint _amount, address _sendTo) public {
        require(_token.transfer(_sendTo, _amount));
        TokenWithdraw(_token, _amount, _sendTo);
    }

    function withdrawEther(uint _amount, address _sendTo) public {
        _sendTo.transfer(_amount);
        EtherWithdraw(_amount, _sendTo);
    }

    event TokenWithdraw(ERC20 token, uint amount, address sendTo);
    event EtherWithdraw(uint amount, address sendTo);
}