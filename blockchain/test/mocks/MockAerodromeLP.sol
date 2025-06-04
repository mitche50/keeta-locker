// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/interfaces/IAerodromePool.sol";
import "./MockERC20.sol";

contract MockAerodromeLP is MockERC20, IAerodromePool {
    address public override token0;
    address public override token1;
    uint256 public claim0;
    uint256 public claim1;
    address public override factory;
    bool public override stable;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public reserveTimestamp;
    
    // Index-based fee tracking (like real Aerodrome)
    uint256 public override index0;  // Global fee index for token0
    uint256 public override index1;  // Global fee index for token1
    mapping(address => uint256) public override supplyIndex0;  // User's last index for token0
    mapping(address => uint256) public override supplyIndex1;  // User's last index for token1
    mapping(address => uint256) internal _claimable0;
    mapping(address => uint256) internal _claimable1;

    function setTokens(address _token0, address _token1) external {
        token0 = _token0;
        token1 = _token1;
    }

    function setClaimAmounts(uint256 _claim0, uint256 _claim1) external {
        claim0 = _claim0;
        claim1 = _claim1;
    }

    function claimFees() external override returns (uint256 claimed0, uint256 claimed1) {
        return (claim0, claim1);
    }

    function setReserves(uint256 _r0, uint256 _r1, uint256 _ts) external {
        reserve0 = _r0;
        reserve1 = _r1;
        reserveTimestamp = _ts;
    }

    function getReserves() external view override returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) {
        return (reserve0, reserve1, reserveTimestamp);
    }

    function setStable(bool _stable) external {
        stable = _stable;
    }

    function setFactory(address _factory) external {
        factory = _factory;
    }

    function setClaimable(address user, uint256 amount0, uint256 amount1) external {
        _claimable0[user] = amount0;
        _claimable1[user] = amount1;
    }

    // Set global fee indices (simulates fee accumulation)
    function setGlobalIndices(uint256 _index0, uint256 _index1) external {
        index0 = _index0;
        index1 = _index1;
    }

    // Set user's supply indices (simulates when user last claimed/updated)
    function setUserIndices(address user, uint256 _supplyIndex0, uint256 _supplyIndex1) external {
        supplyIndex0[user] = _supplyIndex0;
        supplyIndex1[user] = _supplyIndex1;
    }

    function claimable0(address user) external view override returns (uint256) {
        return _claimable0[user];
    }

    function claimable1(address user) external view override returns (uint256) {
        return _claimable1[user];
    }

    // Test helper function to set total supply
    function _setTotalSupply(uint256 _totalSupply) external {
        totalSupply = _totalSupply;
    }
    
    /// @notice Override transfer to simulate fee index updates (like real Aerodrome)
    /// @dev In real Aerodrome, any transfer triggers _updateFor() which updates user indices
    function transfer(address to, uint256 amount) public override(MockERC20, IAerodromePool) returns (bool) {
        // Update the sender's supply indices to current global indices (simulates _updateFor)
        supplyIndex0[msg.sender] = index0;
        supplyIndex1[msg.sender] = index1;
        
        // If transferring to a different address, update their indices too
        if (to != msg.sender) {
            supplyIndex0[to] = index0;
            supplyIndex1[to] = index1;
        }
        
        // Implement transfer logic directly (copied from MockERC20)
        require(balanceOf[msg.sender] >= amount, "Insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}
