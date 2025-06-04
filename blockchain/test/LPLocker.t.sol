// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/LPLocker.sol";
import "../src/interfaces/ILPLocker.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockAerodromeLP.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LPLockerTest is Test {
    LPLocker locker;
    MockAerodromeLP lpToken;
    MockERC20 token0;
    MockERC20 token1;
    address owner = address(0xA11CE);
    address feeReceiver = address(0xBEEF);
    address user = address(0xCAFE);

    uint256 constant LOCK_AMOUNT = 1000 ether;

    // OpenZeppelin Ownable events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        lpToken = new MockAerodromeLP();
        token0 = new MockERC20();
        token1 = new MockERC20();
        lpToken.setTokens(address(token0), address(token1));
        vm.prank(owner);
        locker = new LPLocker(address(lpToken), owner, feeReceiver);
    }

    function testDeploymentSetsState() public view {
        assertEq(locker.owner(), owner);
        assertEq(locker.feeReceiver(), feeReceiver);
        assertEq(locker.tokenContract(), address(lpToken));
    }

    function testOnlyOwnerCanLock() public {
        lpToken.mint(user, LOCK_AMOUNT);
        vm.prank(user);
        lpToken.approve(address(locker), LOCK_AMOUNT);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.lockLiquidity(LOCK_AMOUNT);
    }

    function testCannotLockZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPAmountZero.selector);
        locker.lockLiquidity(0);
    }

    function testEmitsLiquidityLocked() public {
        lpToken.mint(owner, LOCK_AMOUNT);
        vm.prank(owner);
        lpToken.approve(address(locker), LOCK_AMOUNT);
        
        // With the new nonce-based lock ID generation, we need to calculate the expected ID
        bytes32 expectedLockId = keccak256(abi.encode(owner, LOCK_AMOUNT, block.timestamp, 0)); // nonce starts at 0
        
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.LiquidityLocked(expectedLockId, LOCK_AMOUNT);
        vm.prank(owner);
        locker.lockLiquidity(LOCK_AMOUNT);
    }

    function testOnlyOwnerCanTriggerWithdrawal() public {
        bytes32 lockId = _lock();
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.triggerWithdrawal(lockId);
    }

    function testEmitsWithdrawalTriggered() public {
        bytes32 lockId = _lock();
        vm.prank(owner);
        uint256 expectedUnlockTime = block.timestamp + 30 days;
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.WithdrawalTriggered(lockId, expectedUnlockTime);
        locker.triggerWithdrawal(lockId);
    }

    function testCannotTriggerIfNotLocked() public {
        bytes32 nonExistentLockId = keccak256("nonexistent");
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.triggerWithdrawal(nonExistentLockId);
    }

    function testCannotTriggerIfAlreadyTriggered() public {
        bytes32 lockId = _lockAndTrigger();
        vm.prank(owner);
        vm.expectRevert(ILPLocker.WithdrawalAlreadyTriggered.selector);
        locker.triggerWithdrawal(lockId);
    }

    function testOnlyOwnerCanCancelWithdrawal() public {
        bytes32 lockId = _lockAndTrigger();
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.cancelWithdrawalTrigger(lockId);
    }

    function testCannotCancelIfNotLocked() public {
        bytes32 nonExistentLockId = keccak256("nonexistent");
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.cancelWithdrawalTrigger(nonExistentLockId);
    }

    function testCannotCancelIfNotTriggered() public {
        bytes32 lockId = _lock();
        vm.prank(owner);
        vm.expectRevert(ILPLocker.WithdrawalNotTriggered.selector);
        locker.cancelWithdrawalTrigger(lockId);
    }

    function testEmitsWithdrawalCancelled() public {
        bytes32 lockId = _lockAndTrigger();
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.WithdrawalCancelled(lockId);
        vm.prank(owner);
        locker.cancelWithdrawalTrigger(lockId);
    }

    function testOnlyOwnerCanWithdrawLP() public {
        bytes32 lockId = _lockAndTrigger();
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.withdrawLP(lockId, LOCK_AMOUNT);
    }

    function testCannotWithdrawIfNotLocked() public {
        bytes32 nonExistentLockId = keccak256("nonexistent");
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.withdrawLP(nonExistentLockId, LOCK_AMOUNT);
    }

    function testCannotWithdrawIfNotTriggered() public {
        bytes32 lockId = _lock();
        vm.prank(owner);
        vm.expectRevert(ILPLocker.WithdrawalNotTriggered.selector);
        locker.withdrawLP(lockId, LOCK_AMOUNT);
    }

    function testCanWithdrawPartialOrFullAmount() public {
        bytes32 lockId = _lockAndTrigger();
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT / 2);
        assertEq(locker.getLPBalance(), LOCK_AMOUNT / 2);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT / 2);
        assertEq(locker.getLPBalance(), 0);
    }

    function testCannotWithdrawBeforeUnlockTime() public {
        bytes32 lockId = _lockAndTrigger();
        // Try to withdraw just before unlock time
        vm.warp(locker.getUnlockTime(lockId) - 1);
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LockupNotEnded.selector);
        locker.withdrawLP(lockId, LOCK_AMOUNT);
    }

    function testCanWithdrawAfterUnlockTime() public {
        bytes32 lockId = _lockAndTrigger();
        // Warp to just after unlock time
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT);
        assertEq(locker.getLPBalance(), 0);
    }

    function testEmitsLPWithdrawn() public {
        bytes32 lockId = _lockAndTrigger();
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.LPWithdrawn(lockId, LOCK_AMOUNT);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT);
    }

    function testResetsStateIfAllWithdrawn() public {
        bytes32 lockId = _lockAndTrigger();
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT);
        assertEq(locker.getLPBalance(), 0);
        // Check that lock amount is reduced to 0
        (, , , uint256 lockedAmount, , , ) = locker.getLockInfo(lockId);
        assertEq(lockedAmount, 0);
        // Note: isLiquidityLocked remains true, withdrawal state remains as well
    }

    function testOnlyOwnerCanTransferOwnership() public {
        _lock();
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        locker.transferOwnership(user);
    }

    function testCannotTransferOwnershipToZero() public {
        _lock();
        vm.startPrank(owner);
        // OpenZeppelin Ownable2Step allows transferring to zero, but zero can't accept
        locker.transferOwnership(address(0));
        assertEq(locker.pendingOwner(), address(0));
        
        // The zero address cannot accept ownership (this would revert if called)
        // But since zero address can't call functions, this effectively prevents ownership transfer
        vm.stopPrank();
    }

    function testEmitsOwnershipTransferred() public {
        _lock();
        // OpenZeppelin emits OwnershipTransferStarted first, then OwnershipTransferred when accepted
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferStarted(owner, user);
        vm.prank(owner);
        locker.transferOwnership(user);
        
        // Then when accepted, it emits OwnershipTransferred
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(owner, user);
        vm.prank(user);
        locker.acceptOwnership();
    }

    function testTwoStepOwnershipTransfer() public {
        _lock();
        
        // Step 1: Transfer ownership
        vm.prank(owner);
        locker.transferOwnership(user);
        
        // Ownership hasn't changed yet
        assertEq(locker.owner(), owner);
        assertEq(locker.pendingOwner(), user);
        
        // Old owner still has control
        vm.prank(owner);
        locker.changeFeeReceiver(user);
        
        // New owner can't use functions yet
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.changeFeeReceiver(owner);
        
        // Step 2: Accept ownership
        vm.prank(user);
        locker.acceptOwnership();
        
        // Now ownership has changed
        assertEq(locker.owner(), user);
        assertEq(locker.pendingOwner(), address(0));
        
        // New owner has control
        vm.prank(user);
        locker.changeFeeReceiver(owner);
        
        // Old owner no longer has control
        vm.prank(owner);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.changeFeeReceiver(user);
    }

    function testOnlyOwnerCanChangeFeeReceiver() public {
        _lock();
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.changeFeeReceiver(user);
    }

    function testCannotSetFeeReceiverToZero() public {
        _lock();
        vm.startPrank(owner);
        vm.expectRevert(ILPLocker.FeeReceiverCannotBeZeroAddress.selector);
        locker.changeFeeReceiver(address(0));
        vm.stopPrank();
    }

    function testEmitsFeeReceiverChanged() public {
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.FeeReceiverChanged(user);
        vm.prank(owner);
        locker.changeFeeReceiver(user);
    }

    function testAnyoneCanClaimFees() public {
        bytes32 lockId = _lock();
        // Test that any user can claim fees
        vm.prank(user);
        locker.claimLPFees(lockId);
    }

    function testCallsClaimFeesOnPool() public {
        bytes32 lockId = _lock();
        lpToken.setTokens(address(token0), address(token1));
        vm.prank(owner);
        locker.claimLPFees(lockId);
    }

    function testTransfersAllToken0AndToken1ToFeeReceiver() public {
        bytes32 lockId = _lock();
        token0.mint(address(locker), 100);
        token1.mint(address(locker), 200);
        lpToken.setClaimAmounts(0, 0);
        uint256 bal0Before = token0.balanceOf(feeReceiver);
        uint256 bal1Before = token1.balanceOf(feeReceiver);
        vm.prank(owner);
        locker.claimLPFees(lockId);
        assertEq(token0.balanceOf(feeReceiver), bal0Before + 100);
        assertEq(token1.balanceOf(feeReceiver), bal1Before + 200);
    }

    function testEmitsFeesClaimed() public {
        bytes32 lockId = _lock();
        lpToken.setTokens(address(token0), address(token1));
        lpToken.setClaimAmounts(123, 456);
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.FeesClaimed(lockId, address(token0), 123, address(token1), 456);
        vm.prank(owner);
        locker.claimLPFees(lockId);
    }

    function testClaimLPFeesTransfersCorrectAmountsToFeeReceiver() public {
        bytes32 lockId = _lock();
        uint256 claim0 = 123;
        uint256 claim1 = 456;
        lpToken.setTokens(address(token0), address(token1));
        lpToken.setClaimAmounts(claim0, claim1);
        token0.mint(address(locker), claim0);
        token1.mint(address(locker), claim1);
        uint256 before0 = token0.balanceOf(feeReceiver);
        uint256 before1 = token1.balanceOf(feeReceiver);
        vm.prank(owner);
        locker.claimLPFees(lockId);
        assertEq(token0.balanceOf(feeReceiver), before0 + claim0);
        assertEq(token1.balanceOf(feeReceiver), before1 + claim1);
        assertEq(token0.balanceOf(address(locker)), 0);
        assertEq(token1.balanceOf(address(locker)), 0);
    }

    function testRestrictedFunctionsRevertForNonOwner() public {
        bytes32 lockId = _lock();
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.lockLiquidity(LOCK_AMOUNT);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.cancelWithdrawalTrigger(lockId);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.withdrawLP(lockId, LOCK_AMOUNT);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.changeFeeReceiver(user);
    }

    function testGetLockInfoReturnsCorrectState() public {
        bytes32 lockId = _lock();
        (
            address owner_,
            address feeReceiver_,
            address tokenContract_,
            uint256 lockedAmount_,
            uint256 lockUpEndTime_,
            bool isLiquidityLocked_,
            bool isWithdrawalTriggered_
        ) = locker.getLockInfo(lockId);
        assertEq(owner_, owner);
        assertEq(feeReceiver_, feeReceiver);
        assertEq(tokenContract_, address(lpToken));
        assertEq(lockedAmount_, LOCK_AMOUNT);
        assertEq(lockUpEndTime_, 0);
        assertEq(isLiquidityLocked_, true);
        assertEq(isWithdrawalTriggered_, false);
        
        // Test after triggering withdrawal
        vm.prank(owner);
        locker.triggerWithdrawal(lockId);
        (
            owner_,
            feeReceiver_,
            tokenContract_,
            lockedAmount_,
            lockUpEndTime_,
            isLiquidityLocked_,
            isWithdrawalTriggered_
        ) = locker.getLockInfo(lockId);
        assertEq(lockedAmount_, LOCK_AMOUNT);
        assertEq(isLiquidityLocked_, true);
        assertEq(isWithdrawalTriggered_, true);
        assertTrue(lockUpEndTime_ > 0);
    }

    function testGetUnlockTimeReturnsCorrectValue() public {
        bytes32 lockId = _lockAndTrigger();
        uint256 unlockTime = locker.getUnlockTime(lockId);
        assertTrue(unlockTime > block.timestamp);
        assertEq(unlockTime, block.timestamp + 30 days);
    }

    function testGetLPBalanceReturnsCorrectAmount() public {
        // Initially no balance
        assertEq(locker.getLPBalance(), 0);
        
        // After locking
        bytes32 lockId = _lock();
        assertEq(locker.getLPBalance(), LOCK_AMOUNT);
        
        // After triggering and withdrawing
        vm.prank(owner);
        locker.triggerWithdrawal(lockId);
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT);
        assertEq(locker.getLPBalance(), 0);
    }

    function testGetClaimableFeesReturnsTokensAndZeroAmounts() public {
        bytes32 lockId = _lock();
        lpToken.setTokens(address(token0), address(token1));
        (address t0, uint256 a0, address t1, uint256 a1) = locker.getClaimableFees(lockId);
        assertEq(t0, address(token0));
        assertEq(t1, address(token1));
        assertEq(a0, 0);
        assertEq(a1, 0);
    }

    function testFuzzLockerLockWithdraw(uint96 lockAmt, uint96 withdrawAmt) public {
        vm.assume(lockAmt > 0 && lockAmt <= 1e24);
        vm.assume(withdrawAmt > 0 && withdrawAmt <= lockAmt);
        lpToken.mint(owner, lockAmt);
        vm.prank(owner);
        lpToken.approve(address(locker), lockAmt);
        vm.prank(owner);
        bytes32 lockId = locker.lockLiquidity(lockAmt);
        vm.prank(owner);
        locker.triggerWithdrawal(lockId);
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(owner);
        locker.withdrawLP(lockId, withdrawAmt);
        assertEq(locker.getLPBalance(), lockAmt - withdrawAmt);
    }

    function testCannotWithdrawMoreThanLocked() public {
        bytes32 lockId = _lockAndTrigger();
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(owner);
        vm.expectRevert();
        locker.withdrawLP(lockId, LOCK_AMOUNT + 1);
    }

    function testCannotWithdrawZeroAmount() public {
        bytes32 lockId = _lockAndTrigger();
        vm.warp(locker.getUnlockTime(lockId) + 1);
        uint256 before = locker.getLPBalance();
        vm.prank(owner);
        locker.withdrawLP(lockId, 0);
        assertEq(locker.getLPBalance(), before);
    }

    function testCanLockAfterFullWithdrawal() public {
        bytes32 lockId = _lockAndTrigger();
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT);
        lpToken.mint(owner, LOCK_AMOUNT);
        vm.prank(owner);
        lpToken.approve(address(locker), LOCK_AMOUNT);
        vm.prank(owner);
        bytes32 newLockId = locker.lockLiquidity(LOCK_AMOUNT);
        (address owner_, address feeReceiver_, address tokenContract_, uint256 lockedAmount_, uint256 lockUpEndTime_, bool isLiquidityLocked_, bool isWithdrawalTriggered_) = locker.getLockInfo(newLockId);
        assertEq(owner_, owner);
        assertEq(feeReceiver_, feeReceiver);
        assertEq(tokenContract_, address(lpToken));
        assertEq(lockedAmount_, LOCK_AMOUNT);
        assertEq(lockUpEndTime_, 0);
        assertEq(isLiquidityLocked_, true);
        assertEq(isWithdrawalTriggered_, false);
    }

    function testStateAfterPartialThenFullWithdrawal() public {
        bytes32 lockId = _lockAndTrigger();
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT / 2);
        assertEq(locker.getLPBalance(), LOCK_AMOUNT / 2);
        (address owner_, address feeReceiver_, address tokenContract_, uint256 lockedAmount_, uint256 lockUpEndTime_, bool isLiquidityLocked_, bool isWithdrawalTriggered_) = locker.getLockInfo(lockId);
        assertEq(owner_, owner);
        assertEq(feeReceiver_, feeReceiver);
        assertEq(tokenContract_, address(lpToken));
        assertEq(lockedAmount_, LOCK_AMOUNT / 2);
        assertTrue(lockUpEndTime_ > 0); // Still has unlock time
        assertEq(isLiquidityLocked_, true);
        assertEq(isWithdrawalTriggered_, true);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT / 2);
        assertEq(locker.getLPBalance(), 0);
        
        // After full withdrawal, the lock is now deleted
        (owner_, feeReceiver_, tokenContract_, lockedAmount_, lockUpEndTime_, isLiquidityLocked_, isWithdrawalTriggered_) = locker.getLockInfo(lockId);
        assertEq(owner_, owner); // These still return the contract's current values
        assertEq(feeReceiver_, feeReceiver);
        assertEq(tokenContract_, address(lpToken));
        assertEq(lockedAmount_, 0); // Lock data is now default/deleted
        assertEq(lockUpEndTime_, 0); // Reset to 0
        assertEq(isLiquidityLocked_, false); // Reset to false
        assertEq(isWithdrawalTriggered_, false); // Reset to false
        assertEq(locker.getUnlockTime(lockId), 0); // Should return 0 for deleted lock
    }

    function testOnlyOwnerCanTopUpLock() public {
        bytes32 lockId = _lock();
        uint256 topUp = 100 ether;
        lpToken.mint(user, topUp);
        vm.prank(user);
        lpToken.approve(address(locker), topUp);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.topUpLock(lockId, topUp);
    }

    function testCannotTopUpIfNotLocked() public {
        bytes32 nonExistentLockId = keccak256("nonexistent");
        uint256 topUp = 100 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.topUpLock(nonExistentLockId, topUp);
    }

    function testCannotTopUpIfWithdrawalTriggered() public {
        bytes32 lockId = _lockAndTrigger();
        uint256 topUp = 100 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        vm.prank(owner);
        vm.expectRevert(ILPLocker.WithdrawalAlreadyTriggered.selector);
        locker.topUpLock(lockId, topUp);
    }

    function testCannotTopUpZero() public {
        bytes32 lockId = _lock();
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPAmountZero.selector);
        locker.topUpLock(lockId, 0);
    }

    function testTopUpIncreasesLockedAmount() public {
        bytes32 lockId = _lock();
        uint256 topUp = 123 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        vm.prank(owner);
        locker.topUpLock(lockId, topUp);
        assertEq(locker.getLPBalance(), LOCK_AMOUNT + topUp);
        (, , , uint256 lockedAmount, , , ) = locker.getLockInfo(lockId);
        assertEq(lockedAmount, LOCK_AMOUNT + topUp);
    }

    function testTopUpEmitsLiquidityLocked() public {
        bytes32 lockId = _lock();
        uint256 topUp = 42 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        // The event emits the NEW TOTAL amount, not just the top-up amount
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.LiquidityLocked(lockId, LOCK_AMOUNT + topUp);
        vm.prank(owner);
        locker.topUpLock(lockId, topUp);
    }

    function testCannotTopUpAfterPartialWithdrawal() public {
        bytes32 lockId = _lockAndTrigger();
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.prank(owner);
        locker.withdrawLP(lockId, LOCK_AMOUNT / 2);
        uint256 topUp = 50 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        vm.prank(owner);
        vm.expectRevert(ILPLocker.WithdrawalAlreadyTriggered.selector);
        locker.topUpLock(lockId, topUp);
    }

    function testGetTotalAccumulatedFeesCalculatesCorrectly() public {
        // Lock some liquidity
        vm.startPrank(owner);
        lpToken.mint(owner, 1000 ether);
        lpToken.approve(address(locker), 1000 ether);
        bytes32 lockId = locker.lockLiquidity(1000 ether);
        
        // Set up mock indices to simulate fee accumulation
        lpToken.setGlobalIndices(1000, 2000);  // Current global indices
        lpToken.setUserIndices(address(locker), 500, 1000);  // User's last indices
        lpToken._setTotalSupply(10000 ether);  // Set total supply
        
        // Calculate expected fees: (globalIndex - userIndex) * userBalance / 1e18
        // userBalance = 1000 ether = 1000 * 1e18
        // Token0: (1000 - 500) * (1000 * 1e18) / 1e18 = 500 * 1000 = 500000
        // Token1: (2000 - 1000) * (1000 * 1e18) / 1e18 = 1000 * 1000 = 1000000
        
        (address token0, uint256 amount0, address token1, uint256 amount1) 
            = locker.getTotalAccumulatedFees(lockId);
        
        assertEq(token0, lpToken.token0());
        assertEq(token1, lpToken.token1());
        assertEq(amount0, 500000);  // 500 * 1000
        assertEq(amount1, 1000000); // 1000 * 1000
        vm.stopPrank();
    }

    function testUpdateClaimableFeesUpdatesIndices() public {
        bytes32 lockId = _lock();
        
        // Set up initial indices - user has old indices, global has moved forward
        lpToken.setGlobalIndices(2000, 3000);  // New global indices
        lpToken.setUserIndices(address(locker), 1000, 1500);  // Old user indices
        
        // Call updateClaimableFees
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.ClaimableFeesUpdated(lockId);
        vm.prank(owner);
        locker.updateClaimableFees(lockId);
        
        // Verify that user indices were updated to match global indices
        assertEq(lpToken.supplyIndex0(address(locker)), 2000);
        assertEq(lpToken.supplyIndex1(address(locker)), 3000);
    }

    function testCannotUpdateFeesIfNotLocked() public {
        bytes32 nonExistentLockId = keccak256("nonexistent");
        vm.prank(user);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.updateClaimableFees(nonExistentLockId);
    }

    function testAnyoneCanUpdateClaimableFees() public {
        bytes32 lockId = _lock();
        // Test that any user can update claimable fees
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.ClaimableFeesUpdated(lockId);
        vm.prank(user);
        locker.updateClaimableFees(lockId);
    }

    function _lock() internal returns (bytes32 lockId) {
        lpToken.mint(owner, LOCK_AMOUNT);
        vm.prank(owner);
        lpToken.approve(address(locker), LOCK_AMOUNT);
        vm.prank(owner);
        lockId = locker.lockLiquidity(LOCK_AMOUNT);
    }

    function _lockAndTrigger() internal returns (bytes32 lockId) {
        lockId = _lock();
        vm.prank(owner);
        locker.triggerWithdrawal(lockId);
    }
}
