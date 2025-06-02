// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LPLocker.sol";
import "../src/interfaces/ILPLocker.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockAerodromeLP.sol";

contract LPLockerTest is Test {
    LPLocker locker;
    MockAerodromeLP lpToken;
    MockERC20 token0;
    MockERC20 token1;
    address owner = address(0xA11CE);
    address feeReceiver = address(0xBEEF);
    address user = address(0xCAFE);

    uint256 constant LOCK_AMOUNT = 1000 ether;

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
        assertEq(locker.isLiquidityLocked(), false);
        assertEq(locker.lockedAmount(), 0);
    }

    function testOnlyOwnerCanLock() public {
        lpToken.mint(owner, LOCK_AMOUNT);
        vm.prank(user);
        lpToken.approve(address(locker), LOCK_AMOUNT);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.lockLiquidity(LOCK_AMOUNT);
    }

    function testCannotLockTwice() public {
        lpToken.mint(owner, LOCK_AMOUNT);
        vm.prank(owner);
        lpToken.approve(address(locker), LOCK_AMOUNT);
        vm.prank(owner);
        locker.lockLiquidity(LOCK_AMOUNT);
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPAlreadyLocked.selector);
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
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.LiquidityLocked(LOCK_AMOUNT);
        vm.prank(owner);
        locker.lockLiquidity(LOCK_AMOUNT);
    }

    function testOnlyOwnerCanTriggerWithdrawal() public {
        _lock();
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.triggerWithdrawal();
    }

    function testCannotTriggerIfNotLocked() public {
        vm.warp(block.timestamp + 2 * 365 days + 1);
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.triggerWithdrawal();
    }

    function testCannotTriggerIfAlreadyTriggered() public {
        _lock();
        vm.warp(block.timestamp + 2 * 365 days + 1);
        vm.prank(owner);
        locker.triggerWithdrawal();
        vm.prank(owner);
        vm.expectRevert(ILPLocker.WithdrawalAlreadyTriggered.selector);
        locker.triggerWithdrawal();
    }

    function testEmitsWithdrawalTriggered() public {
        _lock();
        vm.warp(block.timestamp + 2 * 365 days + 1);
        vm.prank(owner);
        uint256 before = block.timestamp;
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.WithdrawalTriggered(before + 30 days);
        locker.triggerWithdrawal();
    }

    function testOnlyOwnerCanCancelWithdrawal() public {
        _lockAndTrigger();
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.cancelWithdrawalTrigger();
    }

    function testCannotCancelIfNotLocked() public {
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.cancelWithdrawalTrigger();
    }

    function testCannotCancelIfNotTriggered() public {
        _lock();
        vm.prank(owner);
        vm.expectRevert(ILPLocker.WithdrawalNotTriggered.selector);
        locker.cancelWithdrawalTrigger();
    }

    function testEmitsWithdrawalCancelled() public {
        _lockAndTrigger();
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.WithdrawalCancelled();
        vm.prank(owner);
        locker.cancelWithdrawalTrigger();
    }

    function testOnlyOwnerCanWithdrawLP() public {
        _lockAndTrigger();
        vm.warp(block.timestamp + 91 days);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.withdrawLP(LOCK_AMOUNT);
    }

    function testCannotWithdrawIfNotLocked() public {
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.withdrawLP(LOCK_AMOUNT);
    }

    function testCannotWithdrawIfNotTriggered() public {
        _lock();
        vm.prank(owner);
        vm.expectRevert(ILPLocker.WithdrawalNotTriggered.selector);
        locker.withdrawLP(LOCK_AMOUNT);
    }

    function testCanWithdrawPartialOrFullAmount() public {
        _lockAndTrigger();
        vm.warp(locker.lockUpEndTime() + 1);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT / 2);
        assertEq(locker.lockedAmount(), LOCK_AMOUNT / 2);
        assertEq(locker.isLiquidityLocked(), true);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT / 2);
        assertEq(locker.lockedAmount(), 0);
        assertEq(locker.isLiquidityLocked(), false);
    }

    function testCannotWithdrawBeforeUnlockTime() public {
        _lockAndTrigger();
        // Try to withdraw just before unlock time
        vm.warp(locker.lockUpEndTime() - 1);
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LockupNotEnded.selector);
        locker.withdrawLP(LOCK_AMOUNT);
    }

    function testCanWithdrawAfterUnlockTime() public {
        _lockAndTrigger();
        // Warp to just after unlock time
        vm.warp(locker.lockUpEndTime() + 1);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT);
        assertEq(locker.lockedAmount(), 0);
        assertEq(locker.isLiquidityLocked(), false);
    }

    function testEmitsLPWithdrawn() public {
        _lockAndTrigger();
        vm.warp(locker.lockUpEndTime() + 1);
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.LPWithdrawn(LOCK_AMOUNT);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT);
    }

    function testResetsStateIfAllWithdrawn() public {
        _lockAndTrigger();
        vm.warp(locker.lockUpEndTime() + 1);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT);
        assertEq(locker.isLiquidityLocked(), false);
        assertEq(locker.lockedAmount(), 0);
        assertEq(locker.lockUpEndTime(), 0);
        assertEq(locker.isWithdrawalTriggered(), false);
    }

    function testOnlyOwnerCanChangeOwner() public {
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.changeOwner(user);
    }

    function testCannotSetOwnerToZero() public {
        vm.startPrank(owner);
        vm.expectRevert(ILPLocker.OwnerCannotBeZeroAddress.selector);
        locker.changeOwner(address(0));
        vm.stopPrank();
    }

    function testEmitsOwnerChanged() public {
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.OwnerChanged(user);
        vm.prank(owner);
        locker.changeOwner(user);
    }

    function testOnlyOwnerCanChangeFeeReceiver() public {
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.changeFeeReceiver(user);
    }

    function testCannotSetFeeReceiverToZero() public {
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

    function testOnlyOwnerCanClaimFees() public {
        _lock();
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.claimLPFees();
    }

    function testCannotClaimIfNotLocked() public {
        vm.prank(owner);
        vm.expectRevert(bytes("LP not locked"));
        locker.claimLPFees();
    }

    function testCallsClaimFeesOnPool() public {
        _lock();
        lpToken.setClaimAmounts(123, 456);
        vm.prank(owner);
        locker.claimLPFees();
    }

    function testTransfersAllToken0AndToken1ToFeeReceiver() public {
        _lock();
        token0.mint(address(locker), 100);
        token1.mint(address(locker), 200);
        lpToken.setClaimAmounts(0, 0);
        uint256 bal0Before = token0.balanceOf(feeReceiver);
        uint256 bal1Before = token1.balanceOf(feeReceiver);
        vm.prank(owner);
        locker.claimLPFees();
        assertEq(token0.balanceOf(feeReceiver), bal0Before + 100);
        assertEq(token1.balanceOf(feeReceiver), bal1Before + 200);
    }

    function testEmitsFeesClaimed() public {
        _lock();
        lpToken.setClaimAmounts(123, 456);
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.FeesClaimed(address(token0), 123, address(token1), 456);
        vm.prank(owner);
        locker.claimLPFees();
    }

    function testClaimLPFeesTransfersCorrectAmountsToFeeReceiver() public {
        _lock();
        uint256 claim0 = 123;
        uint256 claim1 = 456;
        lpToken.setTokens(address(token0), address(token1));
        lpToken.setClaimAmounts(claim0, claim1);
        token0.mint(address(locker), claim0);
        token1.mint(address(locker), claim1);
        uint256 before0 = token0.balanceOf(feeReceiver);
        uint256 before1 = token1.balanceOf(feeReceiver);
        vm.prank(owner);
        locker.claimLPFees();
        assertEq(token0.balanceOf(feeReceiver), before0 + claim0);
        assertEq(token1.balanceOf(feeReceiver), before1 + claim1);
        assertEq(token0.balanceOf(address(locker)), 0);
        assertEq(token1.balanceOf(address(locker)), 0);
    }

    function testRestrictedFunctionsRevertForNonOwner() public {
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.lockLiquidity(LOCK_AMOUNT);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.triggerWithdrawal();
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.cancelWithdrawalTrigger();
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.withdrawLP(LOCK_AMOUNT);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.changeOwner(user);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.changeFeeReceiver(user);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.claimLPFees();
    }

    function testGetLockInfoReturnsCorrectState() public {
        (
            address owner_,
            address feeReceiver_,
            address tokenContract_,
            uint256 lockedAmount_,
            uint256 lockUpEndTime_,
            bool isLiquidityLocked_,
            bool isWithdrawalTriggered_
        ) = locker.getLockInfo();
        assertEq(owner_, owner);
        assertEq(feeReceiver_, feeReceiver);
        assertEq(tokenContract_, address(lpToken));
        assertEq(lockedAmount_, 0);
        assertEq(lockUpEndTime_, 0);
        assertEq(isLiquidityLocked_, false);
        assertEq(isWithdrawalTriggered_, false);
        _lock();
        (
            owner_,
            feeReceiver_,
            tokenContract_,
            lockedAmount_,
            lockUpEndTime_,
            isLiquidityLocked_,
            isWithdrawalTriggered_
        ) = locker.getLockInfo();
        assertEq(lockedAmount_, LOCK_AMOUNT);
        assertEq(isLiquidityLocked_, true);
        assertEq(isWithdrawalTriggered_, false);
    }

    function testGetUnlockTimeReturnsCorrectValue() public {
        assertEq(locker.getUnlockTime(), 0);
        _lockAndTrigger();
        assertEq(locker.getUnlockTime(), locker.lockUpEndTime());
    }

    function testGetLPBalanceReturnsCorrectAmount() public {
        assertEq(locker.getLPBalance(), 0);
        _lock();
        assertEq(locker.getLPBalance(), LOCK_AMOUNT);
        vm.prank(owner);
        locker.triggerWithdrawal();
        vm.warp(locker.lockUpEndTime() + 1);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT);
        assertEq(locker.getLPBalance(), 0);
    }

    function testGetClaimableFeesReturnsTokensAndZeroAmounts() public {
        lpToken.setTokens(address(token0), address(token1));
        (address t0, uint256 a0, address t1, uint256 a1) = locker.getClaimableFees();
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
        locker.lockLiquidity(lockAmt);
        vm.prank(owner);
        locker.triggerWithdrawal();
        vm.warp(locker.lockUpEndTime() + 1);
        vm.prank(owner);
        locker.withdrawLP(withdrawAmt);
        assertEq(locker.lockedAmount(), lockAmt - withdrawAmt);
    }

    function testCannotWithdrawMoreThanLocked() public {
        _lockAndTrigger();
        vm.warp(block.timestamp + 1 days);
        vm.prank(owner);
        vm.expectRevert();
        locker.withdrawLP(LOCK_AMOUNT + 1);
    }

    function testCannotWithdrawZeroAmount() public {
        _lockAndTrigger();
        vm.warp(locker.lockUpEndTime() + 1);
        uint256 before = locker.lockedAmount();
        vm.prank(owner);
        locker.withdrawLP(0);
        assertEq(locker.lockedAmount(), before);
    }

    function testCanLockAfterFullWithdrawal() public {
        _lockAndTrigger();
        vm.warp(locker.lockUpEndTime() + 1);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT);
        lpToken.mint(owner, LOCK_AMOUNT);
        vm.prank(owner);
        lpToken.approve(address(locker), LOCK_AMOUNT);
        vm.prank(owner);
        locker.lockLiquidity(LOCK_AMOUNT);
        assertEq(locker.lockedAmount(), LOCK_AMOUNT);
        assertEq(locker.isLiquidityLocked(), true);
    }

    function testStateAfterPartialThenFullWithdrawal() public {
        _lockAndTrigger();
        vm.warp(locker.lockUpEndTime() + 1);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT / 2);
        assertEq(locker.lockedAmount(), LOCK_AMOUNT / 2);
        assertEq(locker.isLiquidityLocked(), true);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT / 2);
        assertEq(locker.lockedAmount(), 0);
        assertEq(locker.isLiquidityLocked(), false);
        assertEq(locker.lockUpEndTime(), 0);
        assertEq(locker.isWithdrawalTriggered(), false);
    }

    function testOnlyOwnerCanTopUpLock() public {
        _lock();
        uint256 topUp = 100 ether;
        lpToken.mint(user, topUp);
        vm.prank(user);
        lpToken.approve(address(locker), topUp);
        vm.prank(user);
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.topUpLock(topUp);
    }

    function testCannotTopUpIfNotLocked() public {
        uint256 topUp = 100 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.topUpLock(topUp);
    }

    function testCannotTopUpZero() public {
        _lock();
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPAmountZero.selector);
        locker.topUpLock(0);
    }

    function testTopUpIncreasesLockedAmount() public {
        _lock();
        uint256 topUp = 123 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        vm.prank(owner);
        locker.topUpLock(topUp);
        assertEq(locker.lockedAmount(), LOCK_AMOUNT + topUp);
    }

    function testTopUpEmitsLiquidityLocked() public {
        _lock();
        uint256 topUp = 42 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        vm.expectEmit(true, false, false, true);
        emit ILPLocker.LiquidityLocked(topUp);
        vm.prank(owner);
        locker.topUpLock(topUp);
    }

    function testTopUpAfterPartialWithdrawal() public {
        _lockAndTrigger();
        vm.warp(locker.lockUpEndTime() + 1);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT / 2);
        uint256 topUp = 50 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        vm.prank(owner);
        locker.topUpLock(topUp);
        assertEq(locker.lockedAmount(), (LOCK_AMOUNT / 2) + topUp);
    }

    function testCannotTopUpAfterFullWithdrawal() public {
        _lockAndTrigger();
        vm.warp(locker.lockUpEndTime() + 1);
        vm.prank(owner);
        locker.withdrawLP(LOCK_AMOUNT);
        uint256 topUp = 10 ether;
        lpToken.mint(owner, topUp);
        vm.prank(owner);
        lpToken.approve(address(locker), topUp);
        vm.prank(owner);
        vm.expectRevert(ILPLocker.LPNotLocked.selector);
        locker.topUpLock(topUp);
    }

    function _lock() internal {
        lpToken.mint(owner, LOCK_AMOUNT);
        vm.prank(owner);
        lpToken.approve(address(locker), LOCK_AMOUNT);
        vm.prank(owner);
        locker.lockLiquidity(LOCK_AMOUNT);
    }

    function _lockAndTrigger() internal {
        _lock();
        vm.warp(block.timestamp + 2 * 365 days + 1);
        vm.prank(owner);
        locker.triggerWithdrawal();
    }
}
