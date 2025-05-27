// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Interface for external reward sources (e.g. gauges, bribes)
interface IRewardSource {
    function claimable(address user, address token) external view returns (uint256);
    function claim(address user) external;
    function rewardTokens() external view returns (address[] memory);
} 