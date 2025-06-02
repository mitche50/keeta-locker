// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
        locker.lockLiquidity(withdrawn);
        assertEq(locker.lockedAmount(), withdrawn);
        assertEq(locker.isLiquidityLocked(), true);
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
        locker.lockLiquidity(withdrawn);
        lp.mint(BENEFICIARY, 2);
        lp.approve(address(locker), 2);
        locker.topUpLock(2);
        assertEq(locker.lockedAmount(), withdrawn + 2);
        assertEq(lp.balanceOf(address(locker)), withdrawn + 2);
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
        locker.lockLiquidity(withdrawn);
        assertEq(locker.lockedAmount(), withdrawn);
        assertEq(locker.isLiquidityLocked(), true);
        assertEq(lp.balanceOf(address(locker)), withdrawn);
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

    function testCannotLockTwice() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 5);
        locker.lockLiquidity(5);
        lp.mint(BENEFICIARY, 5);
        lp.approve(address(locker), 5);
        vm.expectRevert();
        locker.lockLiquidity(5);
        vm.stopPrank();
    }

    function testOnlyOwnerCanTopUp() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 5);
        locker.lockLiquidity(5);
        vm.stopPrank();
        lp.mint(address(0xBAD), 2);
        vm.startPrank(address(0xBAD));
        lp.approve(address(locker), 2);
        vm.expectRevert();
        locker.topUpLock(2);
        vm.stopPrank();
    }

    function testCannotTopUpIfNotLocked() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 2);
        vm.expectRevert();
        locker.topUpLock(2);
        vm.stopPrank();
    }

    function testCannotTopUpZero() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 5);
        locker.lockLiquidity(5);
        vm.expectRevert();
        locker.topUpLock(0);
        vm.stopPrank();
    }

    function testCannotWithdrawMoreThanLocked() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 5);
        locker.lockLiquidity(5);
        vm.expectRevert();
        locker.withdrawLP(6);
        vm.stopPrank();
    }

    function testCannotWithdrawZero() public {
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), 5);
        locker.lockLiquidity(5);
        vm.expectRevert();
        locker.withdrawLP(0);
        vm.stopPrank();
    }

    function testFuzzLockLiquidity(uint128 amount) public {
        vm.assume(amount > 0 && amount <= 1e24);
        lp.mint(BENEFICIARY, amount);
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), amount);
        locker.lockLiquidity(amount);
        assertEq(locker.lockedAmount(), amount);
        assertEq(locker.isLiquidityLocked(), true);
        vm.stopPrank();
    }

    function testFuzzTopUpLock(uint128 initial, uint128 topup) public {
        vm.assume(initial > 0 && topup > 0 && initial <= type(uint128).max - topup);
        lp.mint(BENEFICIARY, initial + topup);
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), initial);
        locker.lockLiquidity(initial);
        lp.approve(address(locker), topup);
        locker.topUpLock(topup);
        assertEq(locker.lockedAmount(), initial + topup);
        vm.stopPrank();
    }

    function testFuzzWithdrawLP(uint128 initial, uint128 withdrawAmount) public {
        vm.assume(initial > 0 && withdrawAmount > 0 && withdrawAmount <= initial && initial <= 1e24);
        lp.mint(BENEFICIARY, initial);
        vm.startPrank(BENEFICIARY);
        lp.approve(address(locker), initial);
        locker.lockLiquidity(initial);
        locker.triggerWithdrawal();
        vm.warp(locker.lockUpEndTime() + 1);
        locker.withdrawLP(withdrawAmount);
        assertEq(locker.lockedAmount(), initial - withdrawAmount);
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

    function testChangeOwnerCannotBeZeroAddress() public {
        vm.startPrank(BENEFICIARY);
        vm.expectRevert(ILPLocker.OwnerCannotBeZeroAddress.selector);
        locker.changeOwner(address(0));
        vm.stopPrank();
    }

    function testChangeFeeReceiverCannotBeZeroAddress() public {
        vm.startPrank(BENEFICIARY);
        vm.expectRevert(ILPLocker.FeeReceiverCannotBeZeroAddress.selector);
        locker.changeFeeReceiver(address(0));
        vm.stopPrank();
    }

    function testChangeOwnerValid() public {
        address newOwner = address(0x1234);
        vm.startPrank(BENEFICIARY);
        locker.changeOwner(newOwner);
        assertEq(locker.owner(), newOwner);
        vm.stopPrank();
    }

    function testChangeFeeReceiverValid() public {
        address newFeeReceiver = address(0x5678);
        vm.startPrank(BENEFICIARY);
        locker.changeFeeReceiver(newFeeReceiver);
        assertEq(locker.feeReceiver(), newFeeReceiver);
        vm.stopPrank();
    }
}
