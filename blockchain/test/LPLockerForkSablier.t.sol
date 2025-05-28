// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/LPLocker.sol";
import "src/interfaces/ILPLocker.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ISablierNFT {
    function withdrawMax(uint256 streamId, address to) external payable returns (uint128 withdrawnAmount);
    function balanceOf(address owner) external view returns (uint256);
    function statusOf(uint256 streamId) external view returns (uint8);
}

contract LPLockerForkSablierTest is Test {
    address constant SABLIER = 0xb5D78DD3276325f5FAF3106Cc4Acc56E28e0Fe3B;
    address constant BENEFICIARY = 0xbb767517C6FCbbbB8CeF73769d4034e77A9692A3;
    address constant LP = 0xd9eDC75a3a797Ec92Ca370F19051BAbebfb2edEe;
    uint256 constant TOKEN_ID = 422;
    address constant FEE_RECEIVER = address(0xBEEF);

    LPLocker locker;

    function setUp() public {
        vm.createSelectFork("base", 30759400);

        // Warp to after unlock (June 5, 2025)
        vm.warp(1759536000); // 2025-06-05 00:00:00 UTC

        // Deploy LPLocker as beneficiary
        vm.startPrank(BENEFICIARY);
        locker = new LPLocker(LP, BENEFICIARY, FEE_RECEIVER);
        vm.stopPrank();
    }

    function testWithdrawAndLockFromSablier() public {
        vm.startPrank(BENEFICIARY);

        // Check stream ownership
        address owner = IERC721(SABLIER).ownerOf(TOKEN_ID);

        // Check stream status
        uint8 status = ISablierNFT(SABLIER).statusOf(TOKEN_ID);

        // Withdraw all LP from Sablier
        uint256 balBefore = IERC20(LP).balanceOf(BENEFICIARY);
        ISablierNFT(SABLIER).withdrawMax(TOKEN_ID, BENEFICIARY);
        uint256 balAfter = IERC20(LP).balanceOf(BENEFICIARY);
        uint256 withdrawn = balAfter - balBefore;
        assertGt(withdrawn, 0, "No LP withdrawn from Sablier");

        // Approve and lock in LPLocker
        IERC20(LP).approve(address(locker), withdrawn);
        locker.lockLiquidity(withdrawn);

        // Assert LPLocker state
        assertEq(locker.lockedAmount(), withdrawn);
        assertEq(locker.isLiquidityLocked(), true);
        assertEq(IERC20(LP).balanceOf(address(locker)), withdrawn);

        vm.stopPrank();
    }

    function testGetStablierStatus() public {
        uint8 status = ISablierNFT(SABLIER).statusOf(TOKEN_ID);
        console2.log("status", status);
        address owner = IERC721(SABLIER).ownerOf(TOKEN_ID);
        console2.log("owner", owner);
        uint256 balance = ISablierNFT(SABLIER).balanceOf(owner);
        console2.log("balance", balance);
    }
}
