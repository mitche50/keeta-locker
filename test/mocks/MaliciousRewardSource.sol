// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRewardSource} from "src/interfaces/IRewardSource.sol";

contract MaliciousRewardSource is IRewardSource {
    bool public shouldRevert;
    bool public shouldGasBomb;
    bool public shouldReenter;
    address public locker;
    address[] public _rewardTokens;
    uint256 public bomb; // Used for gas bomb storage writes

    function setBehavior(bool _revert, bool _gasBomb, bool _reenter, address _locker) external {
        shouldRevert = _revert;
        shouldGasBomb = _gasBomb;
        shouldReenter = _reenter;
        locker = _locker;
    }

    function setRewardTokens(address[] calldata tokens) external {
        _rewardTokens = tokens;
    }

    function claimable(address, address) external pure override returns (uint256) {
        return 1e18;
    }

    function claim(address) external override {
        if (shouldRevert) revert("MaliciousRewardSource: revert");
        if (shouldGasBomb) {
            // This loop with a storage write is intended to consume real gas and may revert due to out-of-gas.
            // However, if the test runner provides an unrealistic gas limit, this may not revert.
            for (uint256 i = 0; i < 1_000_000; ++i) {
                bomb = i;
            }
        }
        if (shouldReenter && locker != address(0)) {
            // Reenter locker's topUpLock with 1 wei
            (bool success,) = locker.call(abi.encodeWithSignature("topUpLock(uint256)", 1));
            require(success, "Reentrancy failed");
        }
    }

    function rewardTokens() external view override returns (address[] memory) {
        return _rewardTokens;
    }
}
