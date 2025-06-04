# LP Locker - Geth + Clef Ledger Integration

This guide explains how to use Geth + Clef for more robust Ledger hardware wallet integration with the LP Locker smart contract.

## Why Geth + Clef?

**Geth + Clef** provides a more robust and feature-rich Ledger integration compared to Foundry's built-in Ledger support:

### Advantages over Forge's Ledger Integration

| Feature | Forge `--ledger` | Geth + Clef |
|---------|------------------|-------------|
| **Connection Stability** | Sometimes flaky | More reliable |
| **Error Handling** | Limited | Comprehensive |
| **Multiple Derivation Paths** | Basic | Full support |
| **Custom Rules** | Not available | JavaScript rule engine |
| **External Tool Support** | Foundry only | Any Ethereum tool |
| **Transaction Batching** | No | Yes |
| **Advanced Features** | Limited | Full Clef feature set |

### Key Benefits

1. **Better Connection Management**: Clef maintains a persistent connection to the Ledger
2. **Rule-based Auto-approval**: JavaScript rules can auto-approve trusted contracts
3. **Enhanced Security**: Detailed transaction logging and approval workflows
4. **Universal Compatibility**: Works with any tool that supports external signers
5. **Advanced Features**: Support for EIP-712 signing, batch transactions, etc.

## Installation

### Prerequisites

1. **Geth Installation** (includes Clef):
   ```bash
   # macOS
   brew install ethereum
   
   # Linux (Ubuntu/Debian)
   sudo apt-get install ethereum
   
   # Or download from: https://geth.ethereum.org/downloads/
   ```

2. **jq** (for JSON parsing):
   ```bash
   # macOS
   brew install jq
   
   # Linux
   sudo apt-get install jq
   ```

3. **Ledger Device**:
   - Firmware updated to latest version
   - Ethereum app installed and updated
   - "Contract data" enabled in Ethereum app settings

## Usage

### Quick Start

```bash
# Use the Geth + Clef interface
make ledger-clef
```

This will:
1. Check for required dependencies
2. Set up Clef configuration
3. Start Clef with Ledger support
4. Discover your Ledger accounts
5. Provide an interactive menu for contract operations

### Manual Setup (Advanced)

If you want to run Clef manually:

```bash
# 1. Create Clef configuration directory
mkdir -p ~/.clef

# 2. Start Clef with Ledger support
clef --ledger --rpc --rpcaddr 127.0.0.1 --rpcport 8550 --chainid 31337

# 3. In another terminal, use cast with Clef
cast send --rpc-url http://127.0.0.1:8545 \
    --signer http://127.0.0.1:8550 \
    $CONTRACT_ADDRESS \
    "functionName(uint256)" \
    123
```

## How It Works

### Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Your Script   │───▶│      Clef       │───▶│  Ledger Device  │
│   (ledger-clef) │    │   (Signer RPC)  │    │   (Hardware)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ethereum      │    │   Transaction   │    │   User Approval │
│   Network       │    │   Signing       │    │   on Device     │
│   (Anvil/Base)  │    │   & Broadcast   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Transaction Flow

1. **Script Preparation**: Your script prepares transaction data
2. **Clef Request**: Transaction sent to Clef via JSON-RPC
3. **Rule Evaluation**: Clef evaluates JavaScript rules for auto-approval
4. **Ledger Display**: Transaction details shown on Ledger screen
5. **User Approval**: You approve/reject on Ledger device
6. **Signing**: Clef signs transaction with Ledger private key
7. **Broadcast**: Signed transaction broadcast to network

## Configuration

### Clef Rules (Auto-approval)

The script creates a `rules.js` file that can auto-approve certain operations:

```javascript
function ApproveTransaction(req) {
    // Auto-approve transactions to LP Locker contract
    if (req.transaction.to && 
        req.transaction.to.toLowerCase() === process.env.LP_LOCKER_ADDRESS.toLowerCase()) {
        console.log("Auto-approving transaction to LP Locker contract")
        return "Approve"
    }
    
    // Manual approval for everything else
    return "Approve" // or "Reject"
}
```

You can customize these rules for enhanced security:

```javascript
function ApproveTransaction(req) {
    const to = req.transaction.to?.toLowerCase()
    const value = parseInt(req.transaction.value || "0", 16)
    
    // Only approve transactions to known contracts
    if (to === process.env.LP_LOCKER_ADDRESS.toLowerCase()) {
        // Only approve if no ETH is being sent
        if (value === 0) {
            return "Approve"
        }
    }
    
    // Reject all other transactions
    return "Reject"
}
```

### Network Configuration

The script automatically configures Clef for your selected network:

- **Anvil Local**: Chain ID 31337
- **Base Mainnet**: Chain ID 8453

## Available Functions

The Clef interface supports all LP Locker functions that were made public:

### Public Functions (Anyone Can Call)
- **`claimLPFees`** - Claim fees (go to designated receiver)
- **`updateClaimableFees`** - Update fee tracking

### Owner-Only Functions
- **`lockLiquidity`** - Create new locks
- **`triggerWithdrawal`** - Start withdrawal timer
- **`withdrawLP`** - Withdraw LP tokens
- **`cancelWithdrawalTrigger`** - Cancel withdrawals
- **`changeFeeReceiver`** - Change fee destination
- **`topUpLock`** - Add tokens to locks

### LP Token Functions
- **`approve`** - Approve LP tokens for locking

## Troubleshooting

### Common Issues

#### "Clef failed to start"
```bash
# Check if another Clef instance is running
ps aux | grep clef

# Kill existing instances
pkill clef

# Check logs
cat ~/.clef/clef.log
```

#### "No accounts found"
- Ensure Ledger is connected and unlocked
- Open Ethereum app on Ledger
- Enable "Contract data" in Ethereum app settings
- Try unplugging and reconnecting Ledger

#### "Connection refused to 127.0.0.1:8550"
```bash
# Check if Clef is running
curl -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"account_list","params":[],"id":1}' \
    http://127.0.0.1:8550
```

#### "Transaction rejected"
- Check Clef logs: `cat ~/.clef/clef.log`
- Verify transaction parameters on Ledger screen
- Ensure sufficient gas and balance

### Advanced Debugging

#### Enable Verbose Logging
```bash
# Start Clef with debug logging
clef --ledger --rpc --verbosity 4 --chainid 31337
```

#### Manual Transaction Testing
```bash
# Test account listing
curl -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"account_list","params":[],"id":1}' \
    http://127.0.0.1:8550

# Test transaction signing
curl -X POST -H "Content-Type: application/json" \
    --data '{
        "jsonrpc":"2.0",
        "method":"account_signTransaction",
        "params":[{
            "from":"0x...",
            "to":"0x...",
            "gas":"0x5208",
            "gasPrice":"0x3b9aca00",
            "value":"0x0",
            "data":"0x"
        }],
        "id":1
    }' \
    http://127.0.0.1:8550
```

## Security Best Practices

### 1. Rule Configuration
- Use restrictive rules for mainnet
- Only auto-approve known contract addresses
- Log all transaction details for audit

### 2. Network Separation
- Use different Clef instances for mainnet vs testnet
- Separate configuration directories
- Different rule sets for different networks

### 3. Transaction Verification
- Always verify contract addresses on Ledger
- Check transaction amounts and gas settings
- Review function calls and parameters

### 4. Backup and Recovery
- Keep backup of Clef configuration
- Document custom rule configurations
- Test recovery procedures

## Comparison with Forge Approach

### When to Use Clef

**Use Geth + Clef when:**
- You need more reliable Ledger connections
- You want auto-approval rules for trusted contracts
- You're building production systems
- You need advanced signing features
- You want better error handling and logging

### When to Use Forge

**Use Forge `--ledger` when:**
- You're doing simple testing/development
- You prefer simpler setup
- You're already using Foundry ecosystem exclusively
- You don't need advanced features

## Example Workflows

### Setting Up for Production Use

```bash
# 1. Create production Clef configuration
mkdir -p ~/.clef-mainnet

# 2. Create restrictive rules for mainnet
cat > ~/.clef-mainnet/rules.js << 'EOF'
function ApproveTransaction(req) {
    const to = req.transaction.to?.toLowerCase()
    
    // Only approve LP Locker operations with no ETH value
    if (to === "0x09635F643e140090A9A8Dcd712eD6285858ceBef".toLowerCase() &&
        parseInt(req.transaction.value || "0", 16) === 0) {
        return "Approve"
    }
    
    console.log("Transaction rejected by rules")
    return "Reject"
}
EOF

# 3. Start Clef for mainnet
clef --configdir ~/.clef-mainnet \
     --rules ~/.clef-mainnet/rules.js \
     --ledger \
     --rpc \
     --chainid 8453
```

### Automated Fee Claiming

```bash
# Create a simple fee claiming script
cat > claim-fees.sh << 'EOF'
#!/bin/bash
LOCK_ID="0x1234..." # Your lock ID
curl -s -X POST -H "Content-Type: application/json" \
    --data "{
        \"jsonrpc\":\"2.0\",
        \"method\":\"account_signTransaction\",
        \"params\":[{
            \"from\":\"$LEDGER_ADDRESS\",
            \"to\":\"$LP_LOCKER_ADDRESS\",
            \"data\":\"$(cast calldata 'claimLPFees(bytes32)' $LOCK_ID)\",
            \"gas\":\"0x30d40\"
        }],
        \"id\":1
    }" \
    http://127.0.0.1:8550
EOF
```

This Clef-based approach provides a more robust, feature-rich, and production-ready solution for Ledger integration with your LP Locker contract. 