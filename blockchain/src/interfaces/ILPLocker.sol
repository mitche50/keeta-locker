// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ILPLocker
 * @notice Interface for LPLocker events, custom errors, and external functions
 */
interface ILPLocker {
    /// @notice Emitted when liquidity is locked
    /// @param amount The amount of LP tokens locked
    event LiquidityLocked(uint256 amount);
    /// @notice Emitted when withdrawal is triggered
    /// @param unlockTime The timestamp when withdrawal becomes available
    event WithdrawalTriggered(uint256 unlockTime);
    /// @notice Emitted when withdrawal trigger is cancelled
    event WithdrawalCancelled();
    /// @notice Emitted when LP tokens are withdrawn
    /// @param amount The amount of LP tokens withdrawn
    event LPWithdrawn(uint256 amount);
    /// @notice Emitted when LP fees are claimed
    /// @param token0 The address of token0 in the LP
    /// @param amount0 The amount of token0 claimed
    /// @param token1 The address of token1 in the LP
    /// @param amount1 The amount of token1 claimed
    event FeesClaimed(address token0, uint256 amount0, address token1, uint256 amount1);
    /// @notice Emitted when the owner is changed
    /// @param newOwner The new owner address
    event OwnerChanged(address newOwner);
    /// @notice Emitted when the fee receiver is changed
    /// @param newFeeReceiver The new fee receiver address
    event FeeReceiverChanged(address newFeeReceiver);

    /// @notice Thrown when attempting to set owner to the zero address
    error CannotAssignOwnerToAddressZero();
    /// @notice Thrown when attempting to withdraw before the lockup ends
    error LockupNotEnded();
    /// @notice Thrown when attempting to lock liquidity that is already locked
    error LPAlreadyLocked();
    /// @notice Thrown when attempting to act when liquidity is not locked
    error LPNotLocked();
    /// @notice Thrown when a non-owner attempts a restricted action
    error OnlyOwnerCanCall();
    /// @notice Thrown when attempting to trigger withdrawal before 2 years
    error TwoYearMinimum();
    /// @notice Thrown when withdrawal is already triggered
    error WithdrawalAlreadyTriggered();
    /// @notice Thrown when withdrawal is not triggered but required
    error WithdrawalNotTriggered();
    /// @notice Thrown when attempting to lock zero LP tokens
    error LPAmountZero();
    /// @notice Thrown when attempting to set the owner to the zero address
    error OwnerCannotBeZeroAddress();
    /// @notice Thrown when attempting to set the fee receiver to the zero address
    error FeeReceiverCannotBeZeroAddress();

    /**
     * @notice Locks a specified amount of LP tokens in the contract
     * @dev Only callable by the owner. Can only be called once until all tokens are withdrawn.
     * @param amount The amount of LP tokens to lock
     * @custom:error LPAlreadyLocked if already locked, LPAmountZero if amount is zero
     */
    function lockLiquidity(uint256 amount) external;

    /**
     * @notice Triggers the 90-day withdrawal window
     * @dev Only callable by the owner if liquidity is locked and not already triggered
     * @custom:error LPNotLocked if not locked, WithdrawalAlreadyTriggered if already triggered
     */
    function triggerWithdrawal() external;

    /**
     * @notice Cancels the withdrawal trigger, resetting the 90-day window
     * @dev Only callable by the owner if withdrawal is triggered
     * @custom:error LPNotLocked if not locked, WithdrawalNotTriggered if not triggered
     */
    function cancelWithdrawalTrigger() external;

    /**
     * @notice Withdraws a specified amount of LP tokens during the withdrawal window
     * @dev Only callable by the owner during the 90-day window. Resets state if all tokens withdrawn.
     * @param amount The amount of LP tokens to withdraw
     * @custom:error LPNotLocked if not locked, WithdrawalNotTriggered if not triggered, LockupNotEnded if window expired
     */
    function withdrawLP(uint256 amount) external;

    /**
     * @notice Changes the owner of the contract
     * @dev Only callable by the current owner
     * @param newOwner The new owner address
     * @custom:error CannotAssignOwnerToAddressZero if newOwner is zero
     */
    function changeOwner(address newOwner) external;

    /**
     * @notice Changes the fee receiver address
     * @dev Only callable by the owner
     * @param newFeeReceiver The new fee receiver address
     * @custom:error Reverts if newFeeReceiver is zero (uses require)
     */
    function changeFeeReceiver(address newFeeReceiver) external;

    /**
     * @notice Claims accumulated fees from the Aerodrome LP pool and sends them to the fee receiver
     * @dev Only callable by the owner. Only works if the LP is an Aerodrome pool.
     * @custom:error Reverts if not locked (uses require)
     */
    function claimLPFees() external;

    /**
     * @notice Returns all relevant lock state information for monitoring
     * @return owner_ The current owner
     * @return feeReceiver_ The current fee receiver
     * @return tokenContract_ The address of the locked LP token
     * @return lockedAmount_ The amount of LP tokens locked
     * @return lockUpEndTime_ The time when the 90-day withdrawal window ends (0 if not triggered)
     * @return isLiquidityLocked_ True if liquidity is currently locked
     * @return isWithdrawalTriggered_ True if withdrawal has been triggered
     */
    function getLockInfo()
        external
        view
        returns (
            address owner_,
            address feeReceiver_,
            address tokenContract_,
            uint256 lockedAmount_,
            uint256 lockUpEndTime_,
            bool isLiquidityLocked_,
            bool isWithdrawalTriggered_
        );

    /**
     * @notice Returns the current LP token balance held by the contract
     * @return lpBalance The LP token balance
     */
    function getLPBalance() external view returns (uint256 lpBalance);

    /**
     * @notice Returns the unlock time for the withdrawal window
     * @return lockUpEndTime_ The time when the 90-day withdrawal window ends (0 if not triggered)
     */
    function getUnlockTime() external view returns (uint256 lockUpEndTime_);

    /**
     * @notice Returns the amount of fees currently claimable from the Aerodrome LP pool
     * @dev Returns token0, amount0, token1, amount1 as would be claimable by claimFees()
     * @return token0 The address of token0 in the LP
     * @return amount0 The amount of token0 claimable
     * @return token1 The address of token1 in the LP
     * @return amount1 The amount of token1 claimable
     */
    function getClaimableFees()
        external
        view
        returns (address token0, uint256 amount0, address token1, uint256 amount1);

    /**
     * @notice Tops up the locked LP tokens with additional amount
     * @dev Only callable by the owner when liquidity is already locked
     * @param amount The amount of LP tokens to add to the lock
     */
    function topUpLock(uint256 amount) external;
}
