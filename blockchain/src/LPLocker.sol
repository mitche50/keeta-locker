// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IAerodromePool.sol";
import "./interfaces/ILPLocker.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title LPLocker
 * @notice Locks an ERC20 LP Token, then allows a 30-day withdrawal window after a trigger. Supports Aerodrome LP fee claiming.
 * @dev Only the owner can lock, trigger withdrawal, cancel, withdraw, claim fees, or change owner/fee receiver.
 */
contract LPLocker is ILPLocker, Ownable2Step {
    using SafeERC20 for IERC20;

    struct Lock {
        uint256 amount;
        uint256 lockUpEndTime;
        bool isLiquidityLocked;
        bool isWithdrawalTriggered;
    }

    /// @notice The address that receives claimed LP fees
    address public feeReceiver;
    /// @notice The address of the locked LP token (must be Aerodrome LP for fee claiming)
    address public immutable tokenContract;
    /// @notice mapping of lock ID to lock info. Lock ID is a hash of the lock parameters.
    mapping(bytes32 => Lock) public locks;

    /// @notice The delay for the withdrawal window
    uint256 public constant WITHDRAW_DELAY = 30 days;

    mapping(address => uint256) private _nonces;
    
    /// @notice Array of all lock IDs for enumeration
    bytes32[] private _allLockIds;

    constructor(address tokenContract_, address owner_, address feeReceiver_) Ownable(owner_) {
        if (tokenContract_ == address(0)) {
            revert TokenContractCannotBeZeroAddress();
        }
        if (owner_ == address(0)) {
            revert OwnerCannotBeZeroAddress();
        }
        tokenContract = tokenContract_;
        feeReceiver = feeReceiver_;
    }

    // ----------- VIEW FUNCTIONS -----------

    /// @inheritdoc ILPLocker
    function getLockInfo(bytes32 lockId)
        external
        view
        override
        returns (
            address owner_,
            address feeReceiver_,
            address tokenContract_,
            uint256 amount_,
            uint256 lockUpEndTime_,
            bool isLiquidityLocked_,
            bool isWithdrawalTriggered_
        )
    {
        Lock memory lock = locks[lockId];
        return
            (owner(), feeReceiver, tokenContract, lock.amount, lock.lockUpEndTime, lock.isLiquidityLocked, lock.isWithdrawalTriggered);
    }

    /// @inheritdoc ILPLocker
    function getLPBalance() external view override returns (uint256 lpBalance) {
        return IERC20(tokenContract).balanceOf(address(this));
    }

    /// @inheritdoc ILPLocker
    function getUnlockTime(bytes32 lockId) external view returns (uint256 lockUpEndTime_) {
        return locks[lockId].lockUpEndTime;
    }

    /// @inheritdoc ILPLocker
    function getClaimableFees(bytes32 lockId)
        external
        view
        returns (address token0, uint256 amount0, address token1, uint256 amount1)
    {
        Lock memory lock = locks[lockId];
        if (!lock.isLiquidityLocked) {
            revert LPNotLocked();
        }
        IAerodromePool pool = IAerodromePool(tokenContract);
        token0 = pool.token0();
        token1 = pool.token1();
        amount0 = pool.claimable0(address(this));
        amount1 = pool.claimable1(address(this));
        return (token0, amount0, token1, amount1);
    }

    /// @notice Returns the total accumulated fees (based on index difference) for a given lock
    /// @dev Returns 0,0 if the LP token doesn't support index-based fee tracking
    /// @param lockId The ID of the lock
    /// @return token0 The address of token0 in the LP
    /// @return totalAmount0 The total amount of token0 that has accumulated since last update
    /// @return token1 The address of token1 in the LP
    /// @return totalAmount1 The total amount of token1 that has accumulated since last update
    function getTotalAccumulatedFees(bytes32 lockId)
        external
        view
        returns (address token0, uint256 totalAmount0, address token1, uint256 totalAmount1)
    {
        Lock memory lock = locks[lockId];
        if (!lock.isLiquidityLocked) {
            revert LPNotLocked();
        }

        IAerodromePool pool = IAerodromePool(tokenContract);
        
        // Try to get token addresses (these should always work for any LP)
        try pool.token0() returns (address _token0) {
            token0 = _token0;
        } catch {
            token0 = address(0);
        }
        
        try pool.token1() returns (address _token1) {
            token1 = _token1;
        } catch {
            token1 = address(0);
        }
        
        // Try to calculate index-based fees, return 0,0 if not supported
        try this._calculateIndexBasedFeesView(pool) returns (uint256 amount0, uint256 amount1) {
            totalAmount0 = amount0;
            totalAmount1 = amount1;
        } catch {
            // LP doesn't support index-based fees, return 0
            totalAmount0 = 0;
            totalAmount1 = 0;
        }
        
        return (token0, totalAmount0, token1, totalAmount1);
    }

    /// @notice External view function to calculate index-based fees (for try-catch)
    /// @dev This needs to be external to be called with try-catch
    function _calculateIndexBasedFeesView(IAerodromePool pool) external view returns (uint256 totalAmount0, uint256 totalAmount1) {
        uint256 userBalance = IERC20(tokenContract).balanceOf(address(this));
        uint256 totalSupply = IERC20(tokenContract).totalSupply();
        
        if (userBalance > 0 && totalSupply > 0) {
            uint256 currentIndex0 = pool.index0();
            uint256 currentIndex1 = pool.index1();
            uint256 userSupplyIndex0 = pool.supplyIndex0(address(this));
            uint256 userSupplyIndex1 = pool.supplyIndex1(address(this));
            
            uint256 index0Diff = currentIndex0 > userSupplyIndex0 ? currentIndex0 - userSupplyIndex0 : 0;
            uint256 index1Diff = currentIndex1 > userSupplyIndex1 ? currentIndex1 - userSupplyIndex1 : 0;
            
            totalAmount0 = (index0Diff * userBalance) / 1e18;
            totalAmount1 = (index1Diff * userBalance) / 1e18;
        }
        
        return (totalAmount0, totalAmount1);
    }

    // ----------- STATE-CHANGING FUNCTIONS -----------

    /// @inheritdoc ILPLocker
    function lockLiquidity(uint256 amount) external returns (bytes32 lockId) {
        _requireIsOwner();
        if (amount == 0) {
            revert LPAmountZero();
        }
        uint256 nonce = _nonces[msg.sender]++;
        lockId = keccak256(abi.encode(msg.sender, amount, block.timestamp, nonce));
        IERC20(tokenContract).safeTransferFrom(msg.sender, address(this), amount);
        locks[lockId] = Lock({
            amount: amount, 
            lockUpEndTime: 0, 
            isLiquidityLocked: true, 
            isWithdrawalTriggered: false
        });
        _allLockIds.push(lockId);
        emit LiquidityLocked(lockId, amount);
    }

    /// @inheritdoc ILPLocker
    function triggerWithdrawal(bytes32 lockId) external {
        _requireIsOwner();
        Lock memory lock = locks[lockId];
        if (!lock.isLiquidityLocked) {
            revert LPNotLocked();
        }
        if (lock.lockUpEndTime != 0) {
            revert WithdrawalAlreadyTriggered();
        }
        lock.lockUpEndTime = block.timestamp + WITHDRAW_DELAY;
        lock.isWithdrawalTriggered = true;
        locks[lockId] = lock;
        emit WithdrawalTriggered(lockId, lock.lockUpEndTime);
    }

    /// @inheritdoc ILPLocker
    function cancelWithdrawalTrigger(bytes32 lockId) external {
        _requireIsOwner();
        Lock memory lock = locks[lockId];
        if (!lock.isLiquidityLocked) {
            revert LPNotLocked();
        }
        if (lock.lockUpEndTime == 0) {
            revert WithdrawalNotTriggered();
        }
        lock.lockUpEndTime = 0;
        lock.isWithdrawalTriggered = false;
        locks[lockId] = lock;
        emit WithdrawalCancelled(lockId);
    }

    /// @inheritdoc ILPLocker
    function withdrawLP(bytes32 lockId, uint256 amount) external {
        _requireIsOwner();
        Lock memory lock = locks[lockId];
        if (!lock.isLiquidityLocked) {
            revert LPNotLocked();
        }
        if (lock.lockUpEndTime == 0) {
            revert WithdrawalNotTriggered();
        }
        if (block.timestamp < lock.lockUpEndTime) {
            revert LockupNotEnded();
        }
        lock.amount -= amount;
        locks[lockId] = lock;
        IERC20(tokenContract).safeTransfer(owner(), amount);
        if (lock.amount == 0) {
            delete locks[lockId];
            _removeLockId(lockId);
            emit LockFullyWithdrawn(lockId);
        }
        emit LPWithdrawn(lockId, amount);
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
    function claimLPFees(bytes32 lockId) external {
        _requireIsOwner();
        Lock memory lock = locks[lockId];
        if (!lock.isLiquidityLocked) {
            revert LPNotLocked();
        }

        IAerodromePool pool = IAerodromePool(tokenContract);
        
        // First, try to update fee tracking by making a 0-transfer to ourselves
        // This triggers _updateFor() in real Aerodrome contracts
        try pool.transfer(address(this), 0) {
            // Update successful
        } catch {
            // Not an Aerodrome LP or transfer failed, continue anyway
        }
        
        // Then claim the fees
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
        emit FeesClaimed(lockId, token0, amount0, token1, amount1);
    }

    /// @inheritdoc ILPLocker
    function updateClaimableFees(bytes32 lockId) external {
        _requireIsOwner();
        Lock memory lock = locks[lockId];
        if (!lock.isLiquidityLocked) {
            revert LPNotLocked();
        }
        
        IAerodromePool pool = IAerodromePool(tokenContract);
        
        // Try to trigger fee update by making a 0-transfer to ourselves
        // This calls _updateFor() internally in real Aerodrome contracts
        try pool.transfer(address(this), 0) {
            emit ClaimableFeesUpdated(lockId);
        } catch {
            // Not an Aerodrome LP or function not available
            revert UpdateNotSupported();
        }
    }

    /// @inheritdoc ILPLocker
    function topUpLock(bytes32 lockId, uint256 amount) external {
        _requireIsOwner();
        Lock memory lock = locks[lockId];
        if (!lock.isLiquidityLocked) {
            revert LPNotLocked();
        }
        if (lock.isWithdrawalTriggered) {
            revert WithdrawalAlreadyTriggered();
        }
        if (amount == 0) {
            revert LPAmountZero();
        }
        IERC20(tokenContract).safeTransferFrom(msg.sender, address(this), amount);
        lock.amount += amount;
        locks[lockId] = lock;
        emit LiquidityLocked(lockId, lock.amount);
    }

    /**
     * @notice Internal helper to check if msg.sender is the owner
     * @dev Reverts with OnlyOwnerCanCall if not owner
     */
    function _requireIsOwner() internal view {
        if (msg.sender != owner()) {
            revert OnlyOwnerCanCall();
        }
    }

    /// @inheritdoc ILPLocker
    function recoverToken(address token, uint256 amount) external {
        _requireIsOwner();
        if (token == tokenContract) {
            revert CannotRecoverLPToken();
        }
        IERC20(token).safeTransfer(owner(), amount);
    }

    /// @inheritdoc ILPLocker
    function getAllLockIds() external view returns (bytes32[] memory) {
        return _allLockIds;
    }

    /// @inheritdoc ILPLocker
    function lockExists(bytes32 lockId) external view returns (bool) {
        return locks[lockId].isLiquidityLocked;
    }

    /**
     * @notice Internal helper to remove a lock ID from the tracking array
     * @param lockId The lock ID to remove
     */
    function _removeLockId(bytes32 lockId) internal {
        uint256 length = _allLockIds.length;
        for (uint256 i = 0; i < length; i++) {
            if (_allLockIds[i] == lockId) {
                // Move the last element to this position and pop
                _allLockIds[i] = _allLockIds[length - 1];
                _allLockIds.pop();
                break;
            }
        }
    }
}
