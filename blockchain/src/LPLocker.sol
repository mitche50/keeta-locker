// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IAerodromePool.sol";
import "./interfaces/ILPLocker.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LPLocker
 * @notice Locks an ERC20 LP Token, then allows a 90-day withdrawal window after a trigger. Supports Aerodrome LP fee claiming.
 * @dev Only the owner can lock, trigger withdrawal, cancel, withdraw, claim fees, or change owner/fee receiver.
 */
contract LPLocker is ILPLocker {
    using SafeERC20 for IERC20;

    /// @notice The address with exclusive control over the locker
    address public owner;
    /// @notice The address that receives claimed LP fees
    address public feeReceiver;
    /// @notice The address of the locked LP token (must be Aerodrome LP for fee claiming)
    address public immutable tokenContract;
    /// @notice The amount of LP tokens currently locked
    uint256 public lockedAmount;
    /// @notice The timestamp when the 90-day withdrawal window ends (0 if not triggered)
    uint256 public lockUpEndTime;
    /// @notice True if liquidity is currently locked
    bool public isLiquidityLocked;
    /// @notice True if withdrawal has been triggered
    bool public isWithdrawalTriggered;

    /// @notice The delay for the withdrawal window
    uint256 public constant WITHDRAW_DELAY = 30 days;

    constructor(address tokenContract_, address owner_, address feeReceiver_) {
        tokenContract = tokenContract_;
        owner = owner_;
        feeReceiver = feeReceiver_;
    }

    // ----------- VIEW FUNCTIONS -----------

    /// @inheritdoc ILPLocker
    function getLockInfo()
        external
        view
        override
        returns (
            address owner_,
            address feeReceiver_,
            address tokenContract_,
            uint256 lockedAmount_,
            uint256 lockUpEndTime_,
            bool isLiquidityLocked_,
            bool isWithdrawalTriggered_
        )
    {
        return
            (owner, feeReceiver, tokenContract, lockedAmount, lockUpEndTime, isLiquidityLocked, isWithdrawalTriggered);
    }

    /// @inheritdoc ILPLocker
    function getLPBalance() external view override returns (uint256 lpBalance) {
        return IERC20(tokenContract).balanceOf(address(this));
    }

    /// @inheritdoc ILPLocker
    function getUnlockTime() external view returns (uint256 lockUpEndTime_) {
        return lockUpEndTime;
    }

    /// @inheritdoc ILPLocker
    function getClaimableFees()
        external
        view
        override
        returns (address token0, uint256 amount0, address token1, uint256 amount1)
    {
        IAerodromePool pool = IAerodromePool(tokenContract);
        token0 = pool.token0();
        token1 = pool.token1();
        amount0 = pool.claimable0(address(this));
        amount1 = pool.claimable1(address(this));
        return (token0, amount0, token1, amount1);
    }

    // ----------- STATE-CHANGING FUNCTIONS -----------

    /// @inheritdoc ILPLocker
    function lockLiquidity(uint256 amount) external {
        _requireIsOwner();
        if (isLiquidityLocked) {
            revert LPAlreadyLocked();
        }
        if (amount == 0) {
            revert LPAmountZero();
        }
        IERC20(tokenContract).safeTransferFrom(msg.sender, address(this), amount);
        lockedAmount = amount;
        isLiquidityLocked = true;
        emit LiquidityLocked(amount);
    }

    /// @inheritdoc ILPLocker
    function triggerWithdrawal() external {
        _requireIsOwner();
        if (!isLiquidityLocked) {
            revert LPNotLocked();
        }
        if (lockUpEndTime != 0) {
            revert WithdrawalAlreadyTriggered();
        }
        lockUpEndTime = block.timestamp + WITHDRAW_DELAY;
        isWithdrawalTriggered = true;
        emit WithdrawalTriggered(lockUpEndTime);
    }

    /// @inheritdoc ILPLocker
    function cancelWithdrawalTrigger() external {
        _requireIsOwner();
        if (!isLiquidityLocked) {
            revert LPNotLocked();
        }
        if (lockUpEndTime == 0) {
            revert WithdrawalNotTriggered();
        }
        lockUpEndTime = 0;
        isWithdrawalTriggered = false;
        emit WithdrawalCancelled();
    }

    /// @inheritdoc ILPLocker
    function withdrawLP(uint256 amount) external {
        _requireIsOwner();
        if (!isLiquidityLocked) {
            revert LPNotLocked();
        }
        if (lockUpEndTime == 0) {
            revert WithdrawalNotTriggered();
        }
        if (block.timestamp < lockUpEndTime) {
            revert LockupNotEnded();
        }
        IERC20(tokenContract).safeTransfer(owner, amount);
        lockedAmount -= amount;
        emit LPWithdrawn(amount);
        if (lockedAmount == 0) {
            isLiquidityLocked = false;
            lockUpEndTime = 0;
            isWithdrawalTriggered = false;
        }
    }

    /// @inheritdoc ILPLocker
    function changeOwner(address newOwner) external {
        _requireIsOwner();
        if (newOwner == address(0)) {
            revert OwnerCannotBeZeroAddress();
        }
        owner = newOwner;
        emit OwnerChanged(newOwner);
    }

    /// @inheritdoc ILPLocker
    function changeFeeReceiver(address newFeeReceiver) external {
        _requireIsOwner();
        if (newFeeReceiver == address(0)) {
            revert FeeReceiverCannotBeZeroAddress();
        }
        feeReceiver = newFeeReceiver;
        emit FeeReceiverChanged(newFeeReceiver);
    }

    /// @inheritdoc ILPLocker
    function claimLPFees() external {
        _requireIsOwner();
        require(isLiquidityLocked, "LP not locked");
        IAerodromePool pool = IAerodromePool(tokenContract);
        (uint256 amount0, uint256 amount1) = pool.claimFees();
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 bal0 = IERC20(token0).balanceOf(address(this));
        if (bal0 > 0) {
            IERC20(token0).safeTransfer(feeReceiver, bal0);
        }
        uint256 bal1 = IERC20(token1).balanceOf(address(this));
        if (bal1 > 0) {
            IERC20(token1).safeTransfer(feeReceiver, bal1);
        }
        emit FeesClaimed(token0, amount0, token1, amount1);
    }

    /// @inheritdoc ILPLocker
    function topUpLock(uint256 amount) external {
        _requireIsOwner();
        if (!isLiquidityLocked) {
            revert LPNotLocked();
        }
        if (amount == 0) {
            revert LPAmountZero();
        }
        IERC20(tokenContract).safeTransferFrom(msg.sender, address(this), amount);
        lockedAmount += amount;
        emit LiquidityLocked(amount);
    }

    /**
     * @notice Internal helper to check if msg.sender is the owner
     * @dev Reverts with OnlyOwnerCanCall if not owner
     */
    function _requireIsOwner() internal view {
        if (msg.sender != owner) {
            revert OnlyOwnerCanCall();
        }
    }
}
