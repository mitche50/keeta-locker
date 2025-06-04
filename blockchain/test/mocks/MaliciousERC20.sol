// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MaliciousERC20 {
    string public name = "Malicious LP";
    string public symbol = "MLP";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public shouldRevert;
    bool public shouldReturnFalse;
    bool public shouldReenter;
    address public locker;

    function setBehavior(bool _revert, bool _returnFalse, bool _reenter, address _locker) external {
        shouldRevert = _revert;
        shouldReturnFalse = _returnFalse;
        shouldReenter = _reenter;
        locker = _locker;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (shouldRevert) revert("MaliciousERC20: revert");
        if (shouldReturnFalse) return false;
        if (shouldReenter && locker != address(0)) {
            // Reenter locker's topUpLock with 1 wei
            (bool success,) = locker.call(abi.encodeWithSignature("topUpLock(uint256)", 1));
            require(success, "Reentrancy failed");
        }
        require(balanceOf[from] >= amount, "Insufficient");
        require(allowance[from][msg.sender] >= amount, "Not allowed");
        balanceOf[from] -= amount;
        allowance[from][msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
