# LPLocker Smart Contract API Documentation

Complete reference for the LPLocker smart contract functions, events, and errors.

## 📋 Contract Overview

The LPLocker contract enables secure time-locked storage of Aerodrome LP tokens with advanced fee management capabilities. It supports multiple independent locks, each with its own ID and management lifecycle.

**Contract Address (Anvil)**: `0x09635F643e140090A9A8Dcd712eD6285858ceBef`  
**LP Token Address (Anvil)**: `0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f`

## 🔧 Core Functions

### Lock Management

#### `lockLiquidity(uint256 amount) → bytes32 lockId`
Creates a new lock with the specified LP token amount.

- **Access**: Owner only
- **Parameters**: 
  - `amount`: Amount of LP tokens to lock (in wei)
- **Returns**: Unique lock ID (keccak256 hash)
- **Events**: `LiquidityLocked(lockId, amount)`
- **Errors**: `LPAmountZero`, `OnlyOwnerCanCall`

```solidity
// Lock 1000 LP tokens
bytes32 lockId = lpLocker.lockLiquidity(1000 * 1e18);
```

#### `triggerWithdrawal(bytes32 lockId)`
Initiates the 30-day withdrawal timelock for a specific lock.

- **Access**: Owner only
- **Parameters**: 
  - `lockId`: ID of the lock to trigger withdrawal for
- **Events**: `WithdrawalTriggered(lockId, unlockTime)`
- **Errors**: `LPNotLocked`, `WithdrawalAlreadyTriggered`, `OnlyOwnerCanCall`

```solidity
lpLocker.triggerWithdrawal(lockId);
```

#### `cancelWithdrawalTrigger(bytes32 lockId)`
Cancels a pending withdrawal, resetting the lock to normal state.

- **Access**: Owner only
- **Parameters**: 
  - `lockId`: ID of the lock to cancel withdrawal for
- **Events**: `WithdrawalCancelled(lockId)`
- **Errors**: `LPNotLocked`, `WithdrawalNotTriggered`, `OnlyOwnerCanCall`

```solidity
lpLocker.cancelWithdrawalTrigger(lockId);
```

#### `withdrawLP(bytes32 lockId, uint256 amount)`
Withdraws LP tokens after the timelock expires (30 days after trigger).

- **Access**: Owner only
- **Parameters**: 
  - `lockId`: ID of the lock to withdraw from
  - `amount`: Amount of LP tokens to withdraw (in wei)
- **Events**: `LPWithdrawn(lockId, amount)`, `LockFullyWithdrawn(lockId)` (if fully withdrawn)
- **Errors**: `LPNotLocked`, `WithdrawalNotTriggered`, `LockupNotEnded`, `OnlyOwnerCanCall`

```solidity
// Withdraw all tokens
uint256 amount = lpLocker.getLockInfo(lockId).amount;
lpLocker.withdrawLP(lockId, amount);
```

#### `topUpLock(bytes32 lockId, uint256 amount)`
Adds more LP tokens to an existing unlocked position.

- **Access**: Owner only
- **Parameters**: 
  - `lockId`: ID of the lock to top up
  - `amount`: Additional LP tokens to add (in wei)
- **Events**: `LiquidityLocked(lockId, newTotalAmount)`
- **Errors**: `LPNotLocked`, `WithdrawalAlreadyTriggered`, `LPAmountZero`, `OnlyOwnerCanCall`

```solidity
// Add 500 more LP tokens to existing lock
lpLocker.topUpLock(lockId, 500 * 1e18);
```

### Fee Management

#### `claimLPFees(bytes32 lockId)`
Claims accumulated fees from the Aerodrome LP pool. Automatically updates fee tracking before claiming.

- **Access**: Owner only
- **Parameters**: 
  - `lockId`: ID of the lock to claim fees for
- **Events**: `FeesClaimed(lockId, token0, amount0, token1, amount1)`
- **Errors**: `LPNotLocked`, `OnlyOwnerCanCall`

```solidity
lpLocker.claimLPFees(lockId);
```

#### `updateClaimableFees(bytes32 lockId)`
Manually triggers fee tracking update by calling the LP pool's internal `_updateFor()` function.

- **Access**: Owner only
- **Parameters**: 
  - `lockId`: ID of the lock to update fees for
- **Events**: `ClaimableFeesUpdated(lockId)`
- **Errors**: `LPNotLocked`, `UpdateNotSupported`, `OnlyOwnerCanCall`

```solidity
lpLocker.updateClaimableFees(lockId);
```

### Administrative Functions

#### `changeFeeReceiver(address newFeeReceiver)`
Changes the address that receives claimed fees.

- **Access**: Owner only
- **Parameters**: 
  - `newFeeReceiver`: New address to receive fees
- **Events**: `FeeReceiverChanged(newFeeReceiver)`
- **Errors**: `FeeReceiverCannotBeZeroAddress`, `OnlyOwnerCanCall`

#### `recoverToken(address token, uint256 amount)`
Recovers accidentally sent tokens (except the locked LP token).

- **Access**: Owner only
- **Parameters**: 
  - `token`: Address of token to recover
  - `amount`: Amount to recover
- **Errors**: `CannotRecoverLPToken`, `OnlyOwnerCanCall`

## 📊 View Functions

### Lock Information

#### `getLockInfo(bytes32 lockId) → (address, address, address, uint256, uint256, bool, bool)`
Returns comprehensive information about a specific lock.

- **Returns**:
  1. `owner`: Current contract owner
  2. `feeReceiver`: Address receiving claimed fees
  3. `tokenContract`: LP token contract address
  4. `amount`: Current locked amount
  5. `lockUpEndTime`: Timestamp when withdrawal becomes available (0 if not triggered)
  6. `isLiquidityLocked`: Whether the lock exists
  7. `isWithdrawalTriggered`: Whether withdrawal has been triggered

```solidity
(
    address owner,
    address feeReceiver,
    address tokenContract,
    uint256 amount,
    uint256 lockUpEndTime,
    bool isLiquidityLocked,
    bool isWithdrawalTriggered
) = lpLocker.getLockInfo(lockId);
```

#### `getAllLockIds() → bytes32[]`
Returns array of all lock IDs for enumeration.

```solidity
bytes32[] memory lockIds = lpLocker.getAllLockIds();
```

#### `lockExists(bytes32 lockId) → bool`
Checks if a lock exists.

```solidity
bool exists = lpLocker.lockExists(lockId);
```

#### `getUnlockTime(bytes32 lockId) → uint256`
Returns the timestamp when withdrawal becomes available.

```solidity
uint256 unlockTime = lpLocker.getUnlockTime(lockId);
```

### Fee Information

#### `getClaimableFees(bytes32 lockId) → (address, uint256, address, uint256)`
Returns fees currently claimable from the LP pool.

- **Returns**:
  1. `token0`: Address of first token in the pair
  2. `amount0`: Claimable amount of token0
  3. `token1`: Address of second token in the pair
  4. `amount1`: Claimable amount of token1

```solidity
(
    address token0,
    uint256 amount0,
    address token1,
    uint256 amount1
) = lpLocker.getClaimableFees(lockId);
```

#### `getTotalAccumulatedFees(bytes32 lockId) → (address, uint256, address, uint256)`
Returns total accumulated fees based on index differences (since last update).

- **Returns**: Same format as `getClaimableFees`
- **Note**: Returns (0, 0) for non-Aerodrome LP tokens

```solidity
(
    address token0,
    uint256 totalAmount0,
    address token1,
    uint256 totalAmount1
) = lpLocker.getTotalAccumulatedFees(lockId);
```

### Contract State

#### `getLPBalance() → uint256`
Returns total LP token balance held by the contract.

```solidity
uint256 totalBalance = lpLocker.getLPBalance();
```

#### `WITHDRAW_DELAY() → uint256`
Returns the withdrawal delay constant (30 days).

```solidity
uint256 delay = lpLocker.WITHDRAW_DELAY(); // 2592000 seconds (30 days)
```

## 📡 Events

### Lock Events
```solidity
event LiquidityLocked(bytes32 indexed lockId, uint256 amount);
event WithdrawalTriggered(bytes32 indexed lockId, uint256 unlockTime);
event WithdrawalCancelled(bytes32 indexed lockId);
event LPWithdrawn(bytes32 indexed lockId, uint256 amount);
event LockFullyWithdrawn(bytes32 indexed lockId);
```

### Fee Events
```solidity
event FeesClaimed(
    bytes32 indexed lockId, 
    address token0, 
    uint256 amount0, 
    address token1, 
    uint256 amount1
);
event ClaimableFeesUpdated(bytes32 indexed lockId);
```

### Administrative Events
```solidity
event FeeReceiverChanged(address indexed newFeeReceiver);
```

## ❌ Custom Errors

### Access Control
```solidity
error OnlyOwnerCanCall();
```

### Lock State Errors
```solidity
error LPNotLocked();           // Lock doesn't exist
error LPAlreadyLocked();       // Attempting to create duplicate lock
error WithdrawalAlreadyTriggered(); // Withdrawal already in progress
error WithdrawalNotTriggered();     // No withdrawal to cancel/complete
error LockupNotEnded();        // Timelock still active
```

### Input Validation
```solidity
error LPAmountZero();          // Cannot lock 0 tokens
error FeeReceiverCannotBeZeroAddress();
error OwnerCannotBeZeroAddress();
error TokenContractCannotBeZeroAddress();
```

### Recovery & Fee Errors
```solidity
error CannotRecoverLPToken();  // Cannot recover the locked LP token
error UpdateNotSupported();    // LP doesn't support fee updates
```

## 🔐 Security Features

### Access Control
- **Owner-only functions**: All state-changing functions require owner authorization
- **Two-step ownership transfer**: Uses OpenZeppelin's `Ownable2Step` for secure ownership changes

### Time-based Security
- **30-day withdrawal delay**: Provides security window to cancel malicious withdrawals
- **Cancellable withdrawals**: Owner can cancel withdrawal before timelock expires

### Safe Token Handling
- **SafeERC20**: All token transfers use OpenZeppelin's SafeERC20 library
- **Recovery protection**: Cannot accidentally recover the locked LP token

## 📈 Gas Optimization

### Storage Efficiency
- **Packed structs**: Lock data efficiently packed in storage
- **Array management**: Efficient lock ID tracking with array compaction

### Function Efficiency
- **Batch operations**: Multiple locks can be managed independently
- **View function caching**: Minimal gas for reading lock information

## 🧪 Testing Integration

### Mock Support
The contract works with `MockAerodromeLP` for testing:

```solidity
// Deploy mock LP token
MockAerodromeLP mockLP = new MockAerodromeLP();

// Deploy LPLocker with mock
LPLocker locker = new LPLocker(
    address(mockLP),
    owner,
    feeReceiver
);
```

### Test Scenarios
- Multiple independent locks
- Fee accumulation simulation
- Time-based withdrawal testing
- Error condition verification

## 🔗 Integration Examples

### Frontend Integration
```typescript
// Create new lock
const { writeContract } = useWriteContract();
await writeContract({
    address: lpLockerAddress,
    abi: LPLockerABI,
    functionName: "lockLiquidity",
    args: [parseEther("1000")],
});

// Check lock status
const lockInfo = useReadContract({
    address: lpLockerAddress,
    abi: LPLockerABI,
    functionName: "getLockInfo",
    args: [lockId],
});
```

### Web3 Integration
```javascript
// Using ethers.js
const lockId = await lpLocker.lockLiquidity(ethers.parseEther("1000"));
const lockInfo = await lpLocker.getLockInfo(lockId);

// Check if ready to withdraw
const now = Math.floor(Date.now() / 1000);
const canWithdraw = lockInfo.lockUpEndTime > 0 && now >= lockInfo.lockUpEndTime;
```

---

For implementation examples and deployment instructions, see the main [README.md](README.md) and [DEPLOYMENT.md](DEPLOYMENT.md). 