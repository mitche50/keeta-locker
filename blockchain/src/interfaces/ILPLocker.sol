// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./IAerodromePool.sol";

/**
 * @title ILPLocker
 * @notice Interface for LPLocker events, custom errors, and external functions
 */
interface ILPLocker {
    /// @notice Emitted when liquidity is locked
    /// @param lockId The ID of the lock
    /// @param amount The amount of LP tokens locked
    event LiquidityLocked(bytes32 lockId, uint256 amount);
    /// @notice Emitted when withdrawal is triggered
    /// @param lockId The ID of the lock
    /// @param unlockTime The timestamp when withdrawal becomes available
    event WithdrawalTriggered(bytes32 lockId, uint256 unlockTime);
    /// @notice Emitted when withdrawal trigger is cancelled
    /// @param lockId The ID of the lock
    event WithdrawalCancelled(bytes32 lockId);
    /// @notice Emitted when LP tokens are withdrawn
    /// @param lockId The ID of the lock
    /// @param amount The amount of LP tokens withdrawn
    event LPWithdrawn(bytes32 indexed lockId, uint256 amount);
    /// @notice Emitted when LP fees are claimed
    /// @param lockId The ID of the lock
    /// @param token0 The address of token0 in the LP
    /// @param amount0 The amount of token0 claimed
    /// @param token1 The address of token1 in the LP
    /// @param amount1 The amount of token1 claimed
    event FeesClaimed(bytes32 indexed lockId, address token0, uint256 amount0, address token1, uint256 amount1);
    /// @notice Emitted when the fee receiver is changed
    /// @param newFeeReceiver The new fee receiver address
    event FeeReceiverChanged(address indexed newFeeReceiver);
    /// @notice Emitted when the lock is fully withdrawn and deleted
    /// @param lockId The ID of the lock
    event LockFullyWithdrawn(bytes32 indexed lockId);
    /// @notice Emitted when claimable fees are updated
    /// @param lockId The ID of the lock
    event ClaimableFeesUpdated(bytes32 indexed lockId);

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
    /// @notice Thrown when attempting to set the token contract to the zero address
    error TokenContractCannotBeZeroAddress();
    /// @notice Thrown when attempting to recover the locked LP token
    error CannotRecoverLPToken();
    /// @notice Thrown when the LP token doesn't support fee updates
    error UpdateNotSupported();

    /**
     * @notice Locks a specified amount of LP tokens in the contract
     * @dev Only callable by the owner. Can only be called once until all tokens are withdrawn.
     * @param amount The amount of LP tokens to lock
     * @return lockId The ID of the lock
     * @custom:error LPAlreadyLocked if already locked, LPAmountZero if amount is zero
     */
    function lockLiquidity(uint256 amount) external returns (bytes32 lockId);

    /**
     * @notice Triggers the timelocked withdrawal
     * @dev Only callable by the owner if liquidity is locked and not already triggered
     * @param lockId The ID of the lock
     * @custom:error LPNotLocked if not locked, WithdrawalAlreadyTriggered if already triggered
     */
    function triggerWithdrawal(bytes32 lockId) external;

    /**
     * @notice Cancels the withdrawal trigger, resetting the timelock
     * @dev Only callable by the owner if withdrawal is triggered
     * @param lockId The ID of the lock
     * @custom:error LPNotLocked if not locked, WithdrawalNotTriggered if not triggered
     */
    function cancelWithdrawalTrigger(bytes32 lockId) external;

    /**
     * @notice Withdraws a specified amount of LP tokens during the withdrawal window
     * @dev Only callable by the owner during the timelock. Resets state if all tokens withdrawn.
     * @param lockId The ID of the lock
     * @param amount The amount of LP tokens to withdraw
     * @custom:error LPNotLocked if not locked, WithdrawalNotTriggered if not triggered, LockupNotEnded if timelock not complete
     */
    function withdrawLP(bytes32 lockId, uint256 amount) external;

    /**
     * @notice Changes the fee receiver
     * @dev Only callable by the owner
     * @param newFeeReceiver The new fee receiver address
     * @custom:error FeeReceiverCannotBeZeroAddress if new fee receiver is zero address
     */
    function changeFeeReceiver(address newFeeReceiver) external;

    /**
     * @notice Claims LP fees from the pool and sends them to the fee receiver
     * @dev Can be called by anyone when liquidity is locked. Fees always go to the designated fee receiver.
     * @param lockId The ID of the lock
     * @custom:error LPNotLocked if not locked
     */
    function claimLPFees(bytes32 lockId) external;

    /**
     * @notice Updates the claimable fees by triggering fee tracking update
     * @dev Can be called by anyone when liquidity is locked. Triggers _updateFor() in Aerodrome contracts.
     * @param lockId The ID of the lock
     * @custom:error LPNotLocked if not locked, UpdateNotSupported if LP doesn't support updates
     */
    function updateClaimableFees(bytes32 lockId) external;

    /**
     * @notice Returns all relevant lock state information for monitoring
     * @return owner_ The current owner
     * @return feeReceiver_ The current fee receiver
     * @return tokenContract_ The address of the locked LP token
     * @return lockedAmount_ The amount of LP tokens locked
     * @return lockUpEndTime_ The time when the timelock ends (0 if not triggered)
     * @return isLiquidityLocked_ True if liquidity is currently locked
     * @return isWithdrawalTriggered_ True if withdrawal has been triggered
     */
    function getLockInfo(bytes32 lockId)
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
     * @param lockId The ID of the lock
     * @return lockUpEndTime_ The time when the timelock ends (0 if not triggered)
     */
    function getUnlockTime(bytes32 lockId) external view returns (uint256 lockUpEndTime_);

    /**
     * @notice Returns the amount of fees claimable from the Aerodrome LP pool for a given lock.
     * @dev This reads the current claimable amounts directly from the pool contract.
     * @param lockId The ID of the lock
     * @return token0 The address of token0 in the LP
     * @return amount0 The amount of token0 claimable
     * @return token1 The address of token1 in the LP
     * @return amount1 The amount of token1 claimable
     */
    function getClaimableFees(bytes32 lockId)
        external
        view
        returns (address token0, uint256 amount0, address token1, uint256 amount1);

    /**
     * @notice Returns the total accumulated fees (based on index difference) for a given lock
     * @dev Total accumulated = (current global index - user's last index) * user's LP balance / total supply
     * @param lockId The ID of the lock
     * @return token0 The address of token0 in the LP
     * @return totalAmount0 The total amount of token0 that has accumulated since last update
     * @return token1 The address of token1 in the LP
     * @return totalAmount1 The total amount of token1 that has accumulated since last update
     */
    function getTotalAccumulatedFees(bytes32 lockId)
        external
        view
        returns (address token0, uint256 totalAmount0, address token1, uint256 totalAmount1);

    /**
     * @notice External view function to calculate index-based fees (for try-catch)
     * @dev This needs to be external to be called with try-catch. Returns 0,0 if LP doesn't support index-based fees.
     * @param pool The Aerodrome pool interface
     * @return totalAmount0 The total amount of token0 accumulated
     * @return totalAmount1 The total amount of token1 accumulated
     */
    function _calculateIndexBasedFeesView(IAerodromePool pool) external view returns (uint256 totalAmount0, uint256 totalAmount1);

    /**
     * @notice Tops up the locked LP tokens with additional amount
     * @dev Only callable by the owner when liquidity is already locked
     * @param amount The amount of LP tokens to add to the lock
     */
    function topUpLock(bytes32 lockId, uint256 amount) external;

    /**
     * @notice Recovers accidentally sent tokens (non-LP tokens only)
     * @dev Only callable by the owner. Cannot recover the locked LP token.
     * @param token The address of the token to recover
     * @param amount The amount of tokens to recover
     */
    function recoverToken(address token, uint256 amount) external;

    /**
     * @notice Returns all lock IDs for enumeration
     * @return An array of all lock IDs
     */
    function getAllLockIds() external view returns (bytes32[] memory);

    /**
     * @notice Checks if a lock exists
     * @param lockId The ID of the lock to check
     * @return True if the lock exists, false otherwise
     */
    function lockExists(bytes32 lockId) external view returns (bool);
}
