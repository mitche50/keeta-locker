# LP Locker - Ledger Hardware Wallet Integration

This guide explains how to use your Ledger hardware wallet to interact with the LP Locker smart contract safely and securely.

## Two Integration Approaches

We provide **two different approaches** for Ledger integration:

### 1. Foundry Native (Simple)
- **Command**: `make ledger-interact`
- **Technology**: Foundry's built-in `--ledger` support
- **Best for**: Development, testing, simple operations
- **Setup**: Minimal - just connect Ledger and run
- **Documentation**: This guide

### 2. Geth + Clef (Robust)
- **Command**: `make ledger-clef`  
- **Technology**: Geth's Clef signing service
- **Best for**: Production use, automated operations, advanced features
- **Setup**: Requires Geth installation
- **Documentation**: [LEDGER_CLEF_GUIDE.md](./LEDGER_CLEF_GUIDE.md)

**Quick Decision Guide:**
- 🚀 **Just want to try it?** → Use `make ledger-interact`
- 🏗️ **Building production systems?** → Use `make ledger-clef`
- 🔧 **Need auto-approval rules?** → Use `make ledger-clef`
- 🐛 **Having connection issues with Foundry?** → Try `make ledger-clef`

---

## Foundry Native Integration (This Guide)

This guide covers the Foundry-based approach using `make ledger-interact`.

## Prerequisites

### Hardware Requirements
1. **Ledger Device**: Nano S, Nano S Plus, Nano X, or Ledger Stax
2. **USB Connection**: Stable USB connection to your computer (USB-C for Stax)
3. **Latest Firmware**: Ensure your Ledger has the latest firmware

### Software Requirements
1. **Ethereum App**: Installed on your Ledger device
2. **Foundry**: Cast and Forge tools installed
3. **Environment Setup**: Properly configured `.env` file

## Setup Instructions

### 1. Ledger Device Setup

1. **Connect your Ledger** to your computer via USB (USB-C for Stax)
2. **Unlock your device** with your PIN
3. **Open the Ethereum app** on your Ledger
4. **Enable Contract Data** in Ethereum app settings:
   - Navigate to Settings in the Ethereum app
   - Enable "Contract data"
   - Enable "Debug data" (optional, for better transaction details)

**For Ledger Stax users:**
- The large touchscreen will display transaction details more clearly
- Contract data and function calls will be easier to read and verify
- Touch navigation makes confirming transactions more intuitive
- The device may show additional context about the contract interaction

### 2. Environment Configuration

Copy the example environment file and configure it:

```bash
cp env.example .env
```

Update the `.env` file with the correct contract addresses:

```bash
# Deployed LP Locker contract address
LP_LOCKER_ADDRESS=0x09635F643e140090A9A8Dcd712eD6285858ceBef

# Aerodrome LP token contract address  
LP_TOKEN_ADDRESS=0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f
```

### 3. Test Ledger Connection

```bash
make ledger-check
```

This command will:
- Test connection to your Ledger device
- Display your Ledger's Ethereum address
- Verify the device is properly configured

## Usage Guide

### Interactive Interface (Recommended)

For the full interactive experience with menu-driven interface:

```bash
make ledger-interact
```

This launches an interactive menu with all available actions:

```
============================================
          LP Locker - Ledger Interface      
============================================

Available Actions:
1)  View Contract State
2)  View Lock Details
3)  Approve LP Tokens
4)  Lock Liquidity
5)  Trigger Withdrawal
6)  Cancel Withdrawal
7)  Withdraw LP Tokens
8)  Top Up Lock
9)  Claim Fees
10) Update Fees
11) Change Fee Receiver
12) Recover Token
0)  Exit
```

### Quick Commands

For specific actions without the full interface:

#### Check Your Balances
```bash
make ledger-view-state
```

#### Approve LP Tokens
```bash
make ledger-approve
# Enter amount when prompted
```

#### Lock LP Tokens
```bash
make ledger-lock
# Enter amount when prompted
```

#### Claim Fees
```bash
make ledger-claim
# Enter Lock ID when prompted
```

### All Available Commands

| Command | Description |
|---------|-------------|
| `make ledger-help` | Show help and requirements |
| `make ledger-check` | Test Ledger connection |
| `make ledger-balance` | Check Ledger ETH balance |
| `make ledger-view-state` | View contract state |
| `make ledger-interact` | Full interactive interface |
| `make ledger-approve` | Approve LP tokens |
| `make ledger-lock` | Lock LP tokens |
| `make ledger-claim` | Claim fees |

## Transaction Process

### 1. Transaction Preparation
- Script validates inputs and shows transaction details
- You'll see function name and parameters before signing

### 2. Confirmation Prompt
- Terminal will ask for confirmation: `Confirm transaction? (y/N)`
- Type `y` and press Enter to proceed

### 3. Ledger Signing
- Ledger device will display transaction details
- **Carefully review** all transaction data on your Ledger screen:
  - Contract address
  - Function being called
  - Parameters (amounts, addresses, etc.)
  - Gas settings

### 4. Transaction Broadcast
- After Ledger confirmation, transaction is broadcast to the network
- You'll see transaction hash and status

## Available Actions

### 1. View Contract State
- **Function**: Read-only operations
- **Purpose**: Check balances, allowances, and lock information
- **Ledger Required**: No (view functions only)

### 2. Approve LP Tokens
- **Function**: `approve(spender, amount)`
- **Purpose**: Allow LP Locker contract to spend your LP tokens
- **Required Before**: Locking liquidity or topping up locks
- **Ledger Confirms**: Spender address and amount

### 3. Lock Liquidity
- **Function**: `lockLiquidity(amount)`
- **Purpose**: Create a new lock with specified LP token amount
- **Prerequisites**: Must have approved sufficient tokens
- **Ledger Confirms**: Amount being locked

### 4. Trigger Withdrawal
- **Function**: `triggerWithdrawal(lockId)`
- **Purpose**: Start withdrawal timer for a lock
- **Access**: Owner only
- **Time Lock**: Must wait 30 days after triggering
- **Ledger Confirms**: Lock ID

### 5. Cancel Withdrawal
- **Function**: `cancelWithdrawalTrigger(lockId)`
- **Purpose**: Cancel a pending withdrawal
- **Access**: Owner only
- **Ledger Confirms**: Lock ID

### 6. Withdraw LP Tokens
- **Function**: `withdrawLP(lockId, amount)`
- **Purpose**: Withdraw tokens after withdrawal period
- **Access**: Owner only
- **Prerequisites**: Must have triggered withdrawal 30+ days ago
- **Ledger Confirms**: Lock ID and amount

### 7. Top Up Lock
- **Function**: `topUpLock(lockId, amount)`
- **Purpose**: Add more LP tokens to existing lock
- **Access**: Owner only
- **Prerequisites**: Must have approved sufficient tokens
- **Ledger Confirms**: Lock ID and amount

### 8. Claim Fees
- **Function**: `claimLPFees(lockId)`
- **Purpose**: Claim accumulated trading fees
- **Access**: Can be called by anyone (fees go to designated receiver)
- **Ledger Confirms**: Lock ID

### 9. Update Fees
- **Function**: `updateClaimableFees(lockId)`
- **Purpose**: Sync fee tracking with Aerodrome pool
- **Access**: Can be called by anyone
- **Ledger Confirms**: Lock ID

### 10. Change Fee Receiver
- **Function**: `changeFeeReceiver(newReceiver)`
- **Purpose**: Change where claimed fees are sent
- **Owner Only**: Only contract owner can change
- **Ledger Confirms**: New receiver address

### 11. Recover Token
- **Function**: `recoverToken(token, amount)`
- **Purpose**: Emergency recovery of accidentally sent tokens
- **Owner Only**: Only contract owner can recover
- **Ledger Confirms**: Token address and amount

## Security Best Practices

### 1. Always Verify on Ledger
- **Never** approve transactions without carefully reading the Ledger screen
- **Double-check** all addresses and amounts on the device
- **Verify** the contract address matches the expected LP Locker

### 2. Network Selection
- **Confirm** you're on the correct network (Anvil Local vs Base Mainnet)
- **Double-check** contract addresses for the selected network

### 3. Amount Verification
- **Review** all amounts carefully (in wei and formatted units)
- **Ensure** you have sufficient balance for transactions + gas fees
- **Check** allowances before locking or topping up

### 4. Lock ID Management
- **Keep track** of your lock IDs for future reference
- **Use** the view functions to verify lock details before operations
- **Copy/paste** lock IDs to avoid typos (they're long hex strings)

### 5. Fee Operations
- **Fee Claiming**: Anyone can claim fees, but they always go to the designated fee receiver
- **Fee Updates**: Anyone can update fee tracking to ensure accurate calculations  
- **Fee Receiver**: Only the contract owner can change where fees are sent
- **Update** fees before claiming to get the most recent amounts
- **Verify** fee amounts before claiming

## Troubleshooting

### Common Issues

#### "Could not connect to Ledger"
- **Solution**: Ensure Ledger is connected, unlocked, and Ethereum app is open
- **Check**: Contract data is enabled in Ethereum app settings
- **Try**: Unplugging and reconnecting the Ledger
- **For Stax**: Ensure USB-C cable supports data transfer (not just charging)
- **For Stax**: Try different USB-C ports if connection issues persist

#### "Transaction failed" 
- **Check**: Sufficient ETH balance for gas fees
- **Verify**: Correct network selection
- **Ensure**: Required approvals are in place for token operations

#### "Invalid Lock ID"
- **Solution**: Use `View Contract State` to get valid lock IDs
- **Format**: Lock IDs should be 32-byte hex strings starting with 0x

#### "Insufficient allowance"
- **Solution**: Run `Approve LP Tokens` with sufficient amount before locking
- **Check**: Current allowance with `View Contract State`

#### "Withdrawal not triggered" or "Still in time lock"
- **Solution**: Use `Trigger Withdrawal` first, then wait 30 days
- **Check**: Current lock status with `View Lock Details`

### Getting Help

1. **Check this guide** for common solutions
2. **Review error messages** carefully - they often indicate the exact issue
3. **Use view functions** to understand current contract state
4. **Verify** all prerequisites are met for the desired action

## Network Information

### Anvil Local (Development)
- **Chain ID**: 31337
- **RPC URL**: http://127.0.0.1:8545
- **Purpose**: Testing and development

### Base Mainnet (Production)
- **Chain ID**: 8453
- **RPC URL**: https://mainnet.base.org
- **Purpose**: Live trading with real funds

⚠️ **Warning**: Always test on Anvil Local before using Base Mainnet with real funds.

## Example Workflow

### Creating Your First Lock

1. **Check balances**:
   ```bash
   make ledger-view-state
   ```

2. **Approve tokens** (if needed):
   ```bash
   make ledger-approve
   # Enter: 100 (for 100 LP tokens)
   ```

3. **Lock liquidity**:
   ```bash
   make ledger-lock
   # Enter: 50 (to lock 50 LP tokens)
   ```

4. **View your new lock**:
   ```bash
   make ledger-view-state
   # Note the Lock ID for future reference
   ```

### Claiming Fees (Owner Only)

1. **Update fees**:
   ```bash
   make ledger-interact
   # Choose: 10) Update Fees
   # Enter your Lock ID
   ```

2. **Claim fees**:
   ```bash
   make ledger-claim
   # Enter your Lock ID
   ```

Remember: Only the contract owner can claim fees. Regular users can only manage their locks. 