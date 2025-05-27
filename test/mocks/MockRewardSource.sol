// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../src/interfaces/IRewardSource.sol";

contract MockRewardSource is IRewardSource {
    mapping(address => mapping(address => uint256)) public rewards;
    address[] public rewardTokenList;
    bool public claimed;
    function setReward(address user, address token, uint256 amount) external {
        rewards[user][token] = amount;
    }
    function setRewardTokens(address[] memory tokens) external {
        rewardTokenList = tokens;
    }
    function claimable(address user, address token) external view override returns (uint256) {
        return rewards[user][token];
    }
    function claim(address user) external override {
        claimed = true;
        // For test, just zero out all rewards for the user
        for (uint256 i = 0; i < rewardTokenList.length; ++i) {
            rewards[user][rewardTokenList[i]] = 0;
        }
    }
    function rewardTokens() external view override returns (address[] memory) {
        return rewardTokenList;
    }
} 