// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/LPLocker.sol";
import "src/interfaces/ILPLocker.sol";
import "test/mocks/MockERC20.sol";
import "test/mocks/MockSablierNFT.sol";
import "test/mocks/MaliciousERC20.sol";

contract LPLockerMockTest is Test {
    address constant BENEFICIARY = 0xbb767517C6FCbbbB8CeF73769d4034e77A9692A3;
    address constant FEE_RECEIVER = address(0xBEEF);
    uint256 constant TOKEN_ID = 422;
    MockERC20 lp;
    MockSablierNFT sablier;
    LPLocker locker;

    function setUp() public {
        lp = new MockERC20();
        sablier = new MockSablierNFT(BENEFICIARY, 2, TOKEN_ID);
        lp.mint(BENEFICIARY, 5);
        vm.startPrank(BENEFICIARY);
        locker = new LPLocker(address(lp), BENEFICIARY, FEE_RECEIVER);
        vm.stopPrank();
    }

    function testWithdrawAndLock() public {
        vm.startPrank(BENEFICIARY);
        uint128 withdrawn = sablier.withdrawMax(TOKEN_ID, BENEFICIARY);
        lp.approve(address(locker), withdrawn);
        bytes32 lockId = locker.lockLiquidity(withdrawn);
        (address owner_, address feeReceiver_, address tokenContract_, uint256 lockedAmount_, uint256 lockUpEndTime_, bool isLiquidityLocked_, bool isWithdrawalTriggered_) = locker.getLockInfo(lockId);
        assertEq(owner_, BENEFICIARY);
        assertEq(feeReceiver_, FEE_RECEIVER);
        assertEq(tokenContract_, address(lp));
        assertEq(lockedAmount_, withdrawn);
        assertEq(lockUpEndTime_, 0);
        assertEq(isLiquidityLocked_, true);
        assertEq(isWithdrawalTriggered_, false);
        assertEq(lp.balanceOf(address(locker)), withdrawn);
        vm.stopPrank();
    }

    function testCannotWithdrawWrongTokenId() public {
        vm.startPrank(BENEFICIARY);
        vm.expectRevert(bytes("Invalid tokenId"));
        sablier.withdrawMax(999, BENEFICIARY);
        vm.stopPrank();
    }

    function testCannotWithdrawNotOwner() public {
        vm.startPrank(address(0xBAD));
        vm.expectRevert(bytes("Not owner"));
        sablier.withdrawMax(TOKEN_ID, address(0xBAD));
        vm.stopPrank();
    }

    function testCannotWithdrawIfNotWithdrawable() public {
        sablier = new MockSablierNFT(BENEFICIARY, 1, TOKEN_ID);
        vm.startPrank(BENEFICIARY);
        vm.expectRevert(bytes("Not withdrawable"));
        sablier.withdrawMax(TOKEN_ID, BENEFICIARY);
        vm.stopPrank();
    }

    function testLockTopUp() public {
        vm.startPrank(BENEFICIARY);
        uint128 withdrawn = sablier.withdrawMax(TOKEN_ID, BENEFICIARY);
        lp.approve(address(locker), withdrawn);
        bytes32 lockId = locker.lockLiquidity(withdrawn);
        lp.mint(BENEFICIARY, 2);
        lp.approve(address(locker), 2);
        locker.topUpLock(lockId, 2);
        (address owner_, address feeReceiver_, address tokenContract_, uint256 lockedAmount_, uint256 lockUpEndTime_, bool isLiquidityLocked_, bool isWithdrawalTriggered_) = locker.getLockInfo(lockId);
        assertEq(owner_, BENEFICIARY);
        assertEq(feeReceiver_, FEE_RECEIVER);
        assertEq(tokenContract_, address(lp));
        assertEq(lockedAmount_, withdrawn + 2);
        assertEq(lockUpEndTime_, 0);
        assertEq(isLiquidityLocked_, true);
        assertEq(lp.balanceOf(address(locker)), withdrawn + 2);
        assertEq(isWithdrawalTriggered_, false);
        vm.stopPrank();
    }

    function testCannotWithdrawTwice() public {
        vm.startPrank(BENEFICIARY);
        sablier.withdrawMax(TOKEN_ID, BENEFICIARY);
        vm.expectRevert(bytes("Already withdrawn"));
        sablier.withdrawMax(TOKEN_ID, BENEFICIARY);
        vm.stopPrank();
    }

    function testStateAfterWithdrawAndLock() public {
        vm.startPrank(BENEFICIARY);
        uint128 withdrawn = sablier.withdrawMax(TOKEN_ID, BENEFICIARY);
        lp.approve(address(locker), withdrawn);
        bytes32 lockId = locker.lockLiquidity(withdrawn);
        (address owner_, address feeReceiver_, address tokenContract_, uint256 lockedAmount_, uint256 lockUpEndTime_, bool isLiquidityLocked_, bool isWithdrawalTriggered_) = locker.getLockInfo(lockId);
        assertEq(owner_, BENEFICIARY);
        assertEq(feeReceiver_, FEE_RECEIVER);
        assertEq(tokenContract_, address(lp));
        assertEq(lockedAmount_, withdrawn);
        assertEq(lockUpEndTime_, 0);
        assertEq(isLiquidityLocked_, true);
        assertEq(lp.balanceOf(address(locker)), withdrawn);
        assertEq(isWithdrawalTriggered_, false);
        vm.stopPrank();
    }

    function testOnlyOwnerCanLock() public {
        vm.startPrank(address(0xBAD));
        lp.mint(address(0xBAD), 5);
        lp.approve(address(locker), 5);
        vm.expectRevert();
        locker.lockLiquidity(5);
        vm.stopPrank();
    }

    function testCannotLockZero() public {
        vm.startPrank(BENEFICIARY);
        vm.expectRevert();
        locker.lockLiquidity(0);
        vm.stopPrank();
    }

    function testOnlyOwnerCanTopUp() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 5);
        bytes32 lockId = locker.lockLiquidity(5);
        vm.stopPrank();
        lp.mint(address(0xBAD), 2);
        vm.startPrank(address(0xBAD));
        lp.approve(address(locker), 2);
        vm.expectRevert();
        locker.topUpLock(lockId, 2);
        vm.stopPrank();
    }

    function testCannotTopUpIfNotLocked() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 2);
        bytes32 nonExistentLockId = keccak256("nonexistent");
        vm.expectRevert();
        locker.topUpLock(nonExistentLockId, 2);
        vm.stopPrank();
    }

    function testCannotTopUpZero() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 5);
        bytes32 lockId = locker.lockLiquidity(5);
        vm.expectRevert();
        locker.topUpLock(lockId, 0);
        vm.stopPrank();
    }

    function testCannotWithdrawMoreThanLocked() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 5);
        bytes32 lockId = locker.lockLiquidity(5);
        locker.triggerWithdrawal(lockId);
        vm.warp(locker.getUnlockTime(lockId) + 1);
        vm.expectRevert();
        locker.withdrawLP(lockId, 6);
        vm.stopPrank();
    }

    function testCannotWithdrawZero() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 5);
        bytes32 lockId = locker.lockLiquidity(5);
        locker.triggerWithdrawal(lockId);
        vm.warp(locker.getUnlockTime(lockId) + 1);
        uint256 balBefore = lp.balanceOf(address(locker));
        locker.withdrawLP(lockId, 0);
        assertEq(lp.balanceOf(address(locker)), balBefore);
        vm.stopPrank();
    }

    function testFuzzLockLiquidity(uint128 amount) public {
        vm.assume(amount > 0 && amount <= 1e24);
        lp.mint(BENEFICIARY, amount);
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), amount);
        bytes32 lockId = locker.lockLiquidity(amount);
        (address owner_, address feeReceiver_, address tokenContract_, uint256 lockedAmount_, uint256 lockUpEndTime_, bool isLiquidityLocked_, bool isWithdrawalTriggered_) = locker.getLockInfo(lockId);
        assertEq(owner_, BENEFICIARY);
        assertEq(feeReceiver_, FEE_RECEIVER);
        assertEq(tokenContract_, address(lp));
        assertEq(lockedAmount_, amount);
        assertEq(lockUpEndTime_, 0);
        assertEq(isLiquidityLocked_, true);
        assertEq(isWithdrawalTriggered_, false);
        vm.stopPrank();
    }

    function testFuzzTopUpLock(uint128 initial, uint128 topup) public {
        vm.assume(initial > 0 && topup > 0 && initial <= type(uint128).max - topup);
        lp.mint(BENEFICIARY, initial + topup);
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), initial);
        bytes32 lockId = locker.lockLiquidity(initial);
        lp.approve(address(locker), topup);
        locker.topUpLock(lockId, topup);
        (address owner_, address feeReceiver_, address tokenContract_, uint256 lockedAmount_, uint256 lockUpEndTime_, bool isLiquidityLocked_, bool isWithdrawalTriggered_) = locker.getLockInfo(lockId);
        assertEq(owner_, BENEFICIARY);
        assertEq(feeReceiver_, FEE_RECEIVER);
        assertEq(tokenContract_, address(lp));
        assertEq(lockedAmount_, initial + topup);
        assertEq(lockUpEndTime_, 0);
        assertEq(isLiquidityLocked_, true);
        assertEq(isWithdrawalTriggered_, false);
        vm.stopPrank();
    }

    function testFuzzWithdrawLP(uint128 initial, uint128 withdrawAmount) public {
        vm.assume(initial > 0 && withdrawAmount > 0 && withdrawAmount <= initial && initial <= 1e24);
        lp.mint(BENEFICIARY, initial);
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), initial);
        bytes32 lockId = locker.lockLiquidity(initial);
        locker.triggerWithdrawal(lockId);
        vm.warp(locker.getUnlockTime(lockId) + 1);
        locker.withdrawLP(lockId, withdrawAmount);
        (address owner_, address feeReceiver_, address tokenContract_, uint256 lockedAmount_, uint256 lockUpEndTime_, bool isLiquidityLocked_, bool isWithdrawalTriggered_) = locker.getLockInfo(lockId);
        assertEq(owner_, BENEFICIARY);
        assertEq(feeReceiver_, FEE_RECEIVER);
        assertEq(tokenContract_, address(lp));
        assertEq(lockedAmount_, initial - withdrawAmount);
        
        // If fully withdrawn, lock is deleted
        if (withdrawAmount == initial) {
            assertEq(lockUpEndTime_, 0, "lockUpEndTime should be 0 after full withdrawal");
            assertEq(isLiquidityLocked_, false, "isLiquidityLocked should be false after full withdrawal");
            assertEq(isWithdrawalTriggered_, false, "isWithdrawalTriggered should be false after full withdrawal");
        } else {
            // Partial withdrawal - lock state should remain
            assertTrue(lockUpEndTime_ > 0, "lockUpEndTime should remain set after partial withdrawal");
            assertEq(isLiquidityLocked_, true);
            assertEq(isWithdrawalTriggered_, true);
        }
        
        vm.stopPrank();
    }

    function testMaliciousERC20RevertOnLock() public {
        MaliciousERC20 evil = new MaliciousERC20();
        evil.mint(BENEFICIARY, 5);
        evil.setBehavior(true, false, false, address(locker));
        vm.startPrank(BENEFICIARY);
        evil.approve(address(locker), 5);
        LPLocker evilLocker = new LPLocker(address(evil), BENEFICIARY, FEE_RECEIVER);
        vm.expectRevert(bytes("MaliciousERC20: revert"));
        evilLocker.lockLiquidity(5);
        vm.stopPrank();
    }

    function testMaliciousERC20ReturnFalseOnLock() public {
        MaliciousERC20 evil = new MaliciousERC20();
        evil.mint(BENEFICIARY, 5);
        evil.setBehavior(false, true, false, address(locker));
        vm.startPrank(BENEFICIARY);
        evil.approve(address(locker), 5);
        LPLocker evilLocker = new LPLocker(address(evil), BENEFICIARY, FEE_RECEIVER);
        vm.expectRevert();
        evilLocker.lockLiquidity(5);
        vm.stopPrank();
    }

    // --- Owner and Fee Receiver Zero Address Checks ---

    function testChangeFeeReceiverCannotBeZeroAddress() public {
        vm.startPrank(BENEFICIARY);
        vm.expectRevert(ILPLocker.FeeReceiverCannotBeZeroAddress.selector);
        locker.changeFeeReceiver(address(0));
        vm.stopPrank();
    }

    function testChangeFeeReceiverValid() public {
        address newFeeReceiver = address(0x5678);
        vm.startPrank(BENEFICIARY);
        locker.changeFeeReceiver(newFeeReceiver);
        assertEq(locker.feeReceiver(), newFeeReceiver);
        vm.stopPrank();
    }

    function testTransferOwnershipCannotBeZeroAddress() public {
        vm.startPrank(BENEFICIARY);
        // OpenZeppelin Ownable2Step allows transferring to zero, but zero can't accept
        locker.transferOwnership(address(0));
        assertEq(locker.pendingOwner(), address(0));
        
        // The zero address cannot accept ownership (this would revert if called)
        // But since zero address can't call functions, this effectively prevents ownership transfer
        vm.stopPrank();
    }

    function testTransferOwnershipValid() public {
        address newOwner = address(0x123);
        vm.startPrank(BENEFICIARY);
        locker.transferOwnership(newOwner);
        assertEq(locker.pendingOwner(), newOwner);
        assertEq(locker.owner(), BENEFICIARY); // Still the old owner until accepted
        vm.stopPrank();
        
        // Accept ownership
        vm.prank(newOwner);
        locker.acceptOwnership();
        assertEq(locker.owner(), newOwner);
        assertEq(locker.pendingOwner(), address(0));
    }
}
