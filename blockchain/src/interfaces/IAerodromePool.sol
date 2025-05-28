// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAerodromePool {
    function claimFees() external returns (uint256, uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256, uint256, uint256);
    function stable() external view returns (bool);
    function factory() external view returns (address);
    /// @notice Returns the amount of token0 claimable by a user
    function claimable0(address user) external view returns (uint256);
    /// @notice Returns the amount of token1 claimable by a user
    function claimable1(address user) external view returns (uint256);
}
