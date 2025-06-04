// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/LPLocker.sol";

contract LedgerInteractionScript is Script {
    LPLocker public lpLocker;
    
    function setUp() public {
        string memory contractAddress = vm.envString("LP_LOCKER_ADDRESS");
        lpLocker = LPLocker(vm.parseAddress(contractAddress));
    }

    // 1. Lock Liquidity
    function lockLiquidity(uint256 amount) public {
        vm.startBroadcast();
        lpLocker.lockLiquidity(amount);
        vm.stopBroadcast();
    }

    // 2. Trigger Withdrawal
    function triggerWithdrawal(bytes32 lockId) public {
        vm.startBroadcast();
        lpLocker.triggerWithdrawal(lockId);
        vm.stopBroadcast();
    }

    // 3. Cancel Withdrawal
    function cancelWithdrawalTrigger(bytes32 lockId) public {
        vm.startBroadcast();
        lpLocker.cancelWithdrawalTrigger(lockId);
        vm.stopBroadcast();
    }

    // 4. Withdraw LP Tokens
    function withdrawLP(bytes32 lockId, uint256 amount) public {
        vm.startBroadcast();
        lpLocker.withdrawLP(lockId, amount);
        vm.stopBroadcast();
    }

    // 5. Top Up Lock
    function topUpLock(bytes32 lockId, uint256 amount) public {
        vm.startBroadcast();
        lpLocker.topUpLock(lockId, amount);
        vm.stopBroadcast();
    }

    // 6. Claim LP Fees
    function claimLPFees(bytes32 lockId) public {
        vm.startBroadcast();
        lpLocker.claimLPFees(lockId);
        vm.stopBroadcast();
    }

    // 7. Update Claimable Fees
    function updateClaimableFees(bytes32 lockId) public {
        vm.startBroadcast();
        lpLocker.updateClaimableFees(lockId);
        vm.stopBroadcast();
    }

    // 8. Change Fee Receiver
    function changeFeeReceiver(address newFeeReceiver) public {
        vm.startBroadcast();
        lpLocker.changeFeeReceiver(newFeeReceiver);
        vm.stopBroadcast();
    }

    // 9. Recover Token
    function recoverToken(address token, uint256 amount) public {
        vm.startBroadcast();
        lpLocker.recoverToken(token, amount);
        vm.stopBroadcast();
    }

    // 10. Approve LP Token (for locking)
    function approveLPToken(uint256 amount) public {
        address lpToken = lpLocker.tokenContract();
        vm.startBroadcast();
        IERC20(lpToken).approve(address(lpLocker), amount);
        vm.stopBroadcast();
    }

    // View functions for contract state
    function getAllLockIds() public view returns (bytes32[] memory) {
        return lpLocker.getAllLockIds();
    }

    function getLockInfo(bytes32 lockId) public view returns (
        address owner,
        address feeReceiver,
        address tokenContract,
        uint256 amount,
        uint256 lockUpEndTime,
        bool isLiquidityLocked,
        bool isWithdrawalTriggered
    ) {
        return lpLocker.getLockInfo(lockId);
    }

    function getClaimableFees(bytes32 lockId) public view returns (
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    ) {
        return lpLocker.getClaimableFees(lockId);
    }

    function getTotalAccumulatedFees(bytes32 lockId) public view returns (
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    ) {
        return lpLocker.getTotalAccumulatedFees(lockId);
    }

    function getLPBalance() public view returns (uint256) {
        return lpLocker.getLPBalance();
    }
} 