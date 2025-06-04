// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/LPLocker.sol";
import "../src/interfaces/ILPLocker.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockAerodromeLP.sol";

contract LPLockerImprovementTest is Test {
    LPLocker locker;
    MockAerodromeLP lpToken;
    MockERC20 token0;
    MockERC20 token1;
    MockERC20 randomToken;
    address owner = address(0xA11CE);
    address feeReceiver = address(0xBEEF);

    function setUp() public {
        lpToken = new MockAerodromeLP();
        token0 = new MockERC20();
        token1 = new MockERC20();
        randomToken = new MockERC20();
        lpToken.setTokens(address(token0), address(token1));
        vm.prank(owner);
        locker = new LPLocker(address(lpToken), owner, feeReceiver);
    }

    // Test emergency token recovery
    function testRecoverToken() public {
        // Send some random tokens to the contract
        randomToken.mint(address(locker), 1000 ether);
        assertEq(randomToken.balanceOf(address(locker)), 1000 ether);
        
        // Owner can recover them
        vm.prank(owner);
        locker.recoverToken(address(randomToken), 1000 ether);
        assertEq(randomToken.balanceOf(owner), 1000 ether);
        assertEq(randomToken.balanceOf(address(locker)), 0);
    }

    function testCannotRecoverLPToken() public {
        // Lock some LP tokens
        lpToken.mint(owner, 1000 ether);
        vm.prank(owner);
        lpToken.approve(address(locker), 1000 ether);
        vm.prank(owner);
        locker.lockLiquidity(1000 ether);
        
        // Try to recover LP tokens - should fail
        vm.prank(owner);
        vm.expectRevert(ILPLocker.CannotRecoverLPToken.selector);
        locker.recoverToken(address(lpToken), 1000 ether);
    }

    function testOnlyOwnerCanRecover() public {
        randomToken.mint(address(locker), 1000 ether);
        
        // Non-owner cannot recover
        vm.prank(address(0xBAD));
        vm.expectRevert(ILPLocker.OnlyOwnerCanCall.selector);
        locker.recoverToken(address(randomToken), 1000 ether);
    }

    // Test lock enumeration
    function testGetAllLockIds() public {
        // Initially no locks
        bytes32[] memory lockIds = locker.getAllLockIds();
        assertEq(lockIds.length, 0);
        
        // Create 3 locks
        vm.startPrank(owner);
        lpToken.mint(owner, 3000 ether);
        lpToken.approve(address(locker), 3000 ether);
        
        bytes32 lockId1 = locker.lockLiquidity(1000 ether);
        bytes32 lockId2 = locker.lockLiquidity(1000 ether);
        bytes32 lockId3 = locker.lockLiquidity(1000 ether);
        vm.stopPrank();
        
        // Should have 3 locks
        lockIds = locker.getAllLockIds();
        assertEq(lockIds.length, 3);
        assertEq(lockIds[0], lockId1);
        assertEq(lockIds[1], lockId2);
        assertEq(lockIds[2], lockId3);
    }

    function testLockIdsRemovedOnFullWithdrawal() public {
        vm.startPrank(owner);
        lpToken.mint(owner, 2000 ether);
        lpToken.approve(address(locker), 2000 ether);
        
        bytes32 lockId1 = locker.lockLiquidity(1000 ether);
        bytes32 lockId2 = locker.lockLiquidity(1000 ether);
        
        // Should have 2 locks
        bytes32[] memory lockIds = locker.getAllLockIds();
        assertEq(lockIds.length, 2);
        
        // Withdraw first lock fully
        locker.triggerWithdrawal(lockId1);
        vm.warp(locker.getUnlockTime(lockId1) + 1);
        locker.withdrawLP(lockId1, 1000 ether);
        
        // Should have 1 lock remaining
        lockIds = locker.getAllLockIds();
        assertEq(lockIds.length, 1);
        assertEq(lockIds[0], lockId2);
        
        vm.stopPrank();
    }

    function testLockExists() public {
        bytes32 fakeLockId = keccak256("fake");
        assertFalse(locker.lockExists(fakeLockId));
        
        // Create a lock
        vm.startPrank(owner);
        lpToken.mint(owner, 1000 ether);
        lpToken.approve(address(locker), 1000 ether);
        bytes32 lockId = locker.lockLiquidity(1000 ether);
        vm.stopPrank();
        
        // Lock should exist
        assertTrue(locker.lockExists(lockId));
        
        // After full withdrawal, should not exist
        vm.startPrank(owner);
        locker.triggerWithdrawal(lockId);
        vm.warp(locker.getUnlockTime(lockId) + 1);
        locker.withdrawLP(lockId, 1000 ether);
        vm.stopPrank();
        
        assertFalse(locker.lockExists(lockId));
    }

    function testPartialWithdrawalKeepsLockId() public {
        vm.startPrank(owner);
        lpToken.mint(owner, 1000 ether);
        lpToken.approve(address(locker), 1000 ether);
        bytes32 lockId = locker.lockLiquidity(1000 ether);
        
        locker.triggerWithdrawal(lockId);
        vm.warp(locker.getUnlockTime(lockId) + 1);
        
        // Partial withdrawal
        locker.withdrawLP(lockId, 500 ether);
        
        // Lock should still exist
        assertTrue(locker.lockExists(lockId));
        bytes32[] memory lockIds = locker.getAllLockIds();
        assertEq(lockIds.length, 1);
        assertEq(lockIds[0], lockId);
        
        vm.stopPrank();
    }
} 