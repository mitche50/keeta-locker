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
    function claimFees() external view override returns (uint256, uint256) {
        return (claim0, claim1);
    }
    function setReserves(uint256 _r0, uint256 _r1, uint256 _ts) external {
        reserve0 = _r0;
        reserve1 = _r1;
        reserveTimestamp = _ts;
    }
    function getReserves() external view override returns (uint256, uint256, uint256) {
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
    function claimable0(address user) external view override returns (uint256) {
        return _claimable0[user];
    }
    function claimable1(address user) external view override returns (uint256) {
        return _claimable1[user];
    }
} 