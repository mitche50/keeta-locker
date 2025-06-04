// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAerodromePool {
    function claimFees() external returns (uint256 claimed0, uint256 claimed1);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);
    function stable() external view returns (bool);
    function factory() external view returns (address);
    /// @notice Returns the amount of token0 claimable by a user
    function claimable0(address user) external view returns (uint256);
    /// @notice Returns the amount of token1 claimable by a user  
    function claimable1(address user) external view returns (uint256);
    /// @notice Global fee index for token0 (total fees accumulated per unit of total supply)
    function index0() external view returns (uint256);
    /// @notice Global fee index for token1 (total fees accumulated per unit of total supply)
    function index1() external view returns (uint256);
    /// @notice User's last recorded fee index for token0 when they last claimed/interacted
    function supplyIndex0(address user) external view returns (uint256);
    /// @notice User's last recorded fee index for token1 when they last claimed/interacted
    function supplyIndex1(address user) external view returns (uint256);
    /// @notice Transfers 0 tokens to trigger fee updates (available in real Aerodrome contracts)
    function transfer(address to, uint256 amount) external returns (bool);
}
