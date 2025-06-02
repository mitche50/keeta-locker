# LPLocker - Liquidity Provider Token Locker

A comprehensive smart contract system and admin dashboard for locking Aerodrome LP tokens with time-based withdrawal mechanisms and fee collection.

## 🏗️ Architecture

- **Smart Contracts**: Solidity contracts built with Foundry (located in `blockchain/`)
- **Frontend**: Modern React + TypeScript dashboard with wagmi, RainbowKit, and Tailwind CSS
- **Networks**: Supports Base mainnet and local Anvil development
- **CREATE2 Deployment**: Support for vanity addresses using deterministic deployment

## 📋 Features

### Smart Contract Features
- ✅ Lock LP tokens with configurable time periods
- ✅ Trigger withdrawal with time delay mechanism
- ✅ Cancel withdrawal before unlock time
- ✅ Partial and full withdrawals
- ✅ Fee collection from LP positions

## 🚀 Quick Start

### Prerequisites

- **Node.js** (v18+)
- **Bun** (latest version)
- **Foundry** (latest version)
- **Git**

### 1. Clone and Setup

```bash
# Clone the repository
git clone git@github.com:mitche50/keeta-locker.git
cd keeta-locker

# Install smart contract dependencies
cd blockchain
forge install
cd ..

# Install frontend dependencies
cd frontend
bun install
cd ..
```

### 2. Environment Configuration

Create your environment file in the blockchain directory:

```bash
cd blockchain
cp env.example .env
```

#### Required Environment Variables

Edit `blockchain/.env` with the following values:

| Variable | Description | Example Value | Required For |
|----------|-------------|---------------|--------------|
| `PRIVATE_KEY` | Deployment wallet private key (without 0x) | `ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` | All deployments |
| `LP_TOKEN_ADDRESS` | Aerodrome LP token contract address | `0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAEE4e7e` | All deployments |
| `BASESCAN_API_KEY` | BaseScan API key for contract verification | `ABC123DEF456GHI789` | Base mainnet only |
| `CREATE2_SALT` | Salt for vanity address deployment | `0xef147623f0c32a935f6b61bb948358636259ebf0fff6b90881f565ffd3a73c78` | CREATE2 deployment only |

#### Where to Get These Values:

**PRIVATE_KEY**:
- For testing: Use Anvil's default key: `ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- For production: Export from your wallet (MetaMask → Account Details → Export Private Key)
- ⚠️ **Never commit real private keys to version control**

**LP_TOKEN_ADDRESS**:
- Find Aerodrome LP token addresses at: https://aerodrome.finance/
- For testing: Will be auto-generated when deploying to Anvil
- Example Base mainnet LP tokens:
  - USDC/ETH: `0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAEE4e7e`
  - WETH/USDC: `0x4C1462C2181961D6C9F71108B8E8e8C6F1F2E8A1`

**BASESCAN_API_KEY**:
- Get free API key at: https://basescan.org/apis
- Sign up → API Keys → Create New Key
- Only needed for contract verification on Base mainnet

**CREATE2_SALT**:
- Generated automatically by running: `make generate-vanity`
- Used for deploying contracts with vanity addresses (e.g., starting with "5AF3" for "SAFE")

### 3. Local Development

```bash
# Terminal 1: Start Anvil local blockchain
cd blockchain
make anvil

# Terminal 2: Deploy contracts to Anvil and start frontend
make deploy-anvil-update
cd ../frontend
bun run dev
```

The dashboard will be available at `http://localhost:5173`

### 4. Connect MetaMask to Anvil

1. Add Anvil network to MetaMask:
   - **Network Name**: Anvil Local
   - **RPC URL**: `http://127.0.0.1:8545`
   - **Chain ID**: `31337`
   - **Currency Symbol**: `ETH`

2. Import Anvil test account:
   - **Private Key**: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
   - This account will have test ETH and LP tokens

## 🛠️ Development Workflow

### Available Make Commands

All smart contract commands should be run from the `blockchain/` directory:

```bash
cd blockchain

# Blockchain Development
make anvil                    # Start Anvil local testnet
make deploy-anvil            # Deploy to Anvil
make deploy-anvil-update     # Deploy to Anvil + update frontend config
make deploy-base             # Deploy to Base mainnet
make test                    # Run smart contract tests
make test-gas               # Run tests with gas reporting

# CREATE2 Vanity Address Deployment
make generate-vanity         # Generate vanity address (adds salt to .env)
make deploy-create2-anvil    # Deploy with vanity address to Anvil
make deploy-create2-base     # Deploy with vanity address to Base

# Code Quality
make fmt                    # Format Solidity code
make fmt-check             # Check Solidity formatting
make clean                 # Clean build artifacts
make coverage              # Generate test coverage report
```

Frontend commands should be run from the `frontend/` directory:

```bash
cd frontend

# Frontend Development
bun run dev                 # Start frontend dev server
bun install                 # Install frontend dependencies
bun run build              # Build frontend for production
bun run lint               # Lint frontend code
bun run preview            # Preview production build
```

### Smart Contract Development

```bash
cd blockchain

# Run tests
forge test

# Run specific test
forge test --match-test testLockLiquidity

# Deploy with verification
forge script script/Deploy.s.sol:DeployScript --rpc-url base --broadcast --verify

# Generate gas report
forge test --gas-report
```

### CREATE2 Vanity Address Deployment

Generate a vanity address for your contract:

```bash
cd blockchain

# Generate vanity address (interactive)
make generate-vanity

# Choose from available options:
# 1) 5AF3 (SAFE) - Perfect for locker contracts
# 2) Custom pattern - Enter your own hex pattern
# 3) Random address - Deploy with any address

# Deploy with generated vanity address
make deploy-create2-anvil    # For testing
make deploy-create2-base     # For production
```

Popular vanity patterns for custom option:
- `5AF3` - "SAFE" (perfect for locker contracts)
- `CAFE` - "CAFE" (crypto-friendly)
- `FEED` - "FEED" (DeFi growth theme)
- `DEAD` - Classic crypto vanity address

## 🎲 Salt Generation


### Example: Generating "SAFE" Address

```bash
cd blockchain

# 1. Run vanity generator
make generate-vanity

# 2. Choose option 1 (5AF3 - SAFE)

# Output:
# ✅ Found vanity address!
# Address: 0x5AF39fdDB1F0eFA26e881a6317a4bdb04cae6677
# Salt: 0xef147623f0c32a935f6b61bb948358636259ebf0fff6b90881f565ffd3a73c78
# ✅ Salt added to .env file!

# 3. Deploy with vanity address:
make deploy-create2-anvil
```

### Constructor Values & Init Code Hash

The init code hash depends on both the contract bytecode AND constructor arguments. If you change any constructor parameters, you'll need to regenerate the salt.

#### Current LPLocker Constructor

```solidity
constructor(address tokenContract_, address owner_, address feeReceiver_)
```

#### When to Regenerate Salt

You must regenerate the vanity address salt when:

1. **Contract Code Changes**: Any modification to the smart contract
2. **Constructor Arguments Change**: Different LP token, owner, or fee receiver
3. **Compiler Settings Change**: Different Solidity version or optimization settings

#### Example: Changing LP Token Address

```bash
# Original deployment with USDC/ETH LP token
LP_TOKEN_ADDRESS=0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAEE4e7e

# Want to deploy with different LP token (WETH/USDC)
LP_TOKEN_ADDRESS=0x4C1462C2181961D6C9F71108B8E8e8C6F1F2E8A1

# Steps to update:
# 1. Update .env with new LP_TOKEN_ADDRESS
# 2. Remove old salt from .env
sed -i '' '/CREATE2_SALT/d' .env

# 3. Regenerate vanity address with new parameters
make generate-vanity

# 4. Deploy with new salt
make deploy-create2-base
```

#### Verifying Constructor Arguments

Before deploying, verify your constructor arguments match your expectations:

```bash
# Check current .env values
cat .env | grep -E "(LP_TOKEN_ADDRESS|PRIVATE_KEY)"

# Verify deployer address matches private key
cast wallet address $PRIVATE_KEY

# Preview deployment (dry run)
forge script script/DeployCreate2.s.sol:DeployCreate2Script \
  --rpc-url base --sender $(cast wallet address $PRIVATE_KEY)
```

#### Constructor Argument Encoding

The vanity generator automatically encodes constructor arguments:

```bash
# For LPLocker(tokenContract, owner, feeReceiver):
CONSTRUCTOR_ARGS = abi.encode(
    LP_TOKEN_ADDRESS,    # address tokenContract_
    DEPLOYER_ADDRESS,    # address owner_ 
    DEPLOYER_ADDRESS     # address feeReceiver_
)

# This creates the init code:
INIT_CODE = CONTRACT_BYTECODE + CONSTRUCTOR_ARGS
INIT_CODE_HASH = keccak256(INIT_CODE)
```

#### Multi-Network Deployment Considerations

Since CREATE2 addresses are deterministic, the same salt will produce the same address across all networks IF:

- ✅ Same deployer address
- ✅ Same contract bytecode  
- ✅ Same constructor arguments

**Important**: If you want the same vanity address on multiple networks but with different LP tokens, you'll need different salts for each network.

```bash
# Example: Different LP tokens per network
# Mainnet: USDC/ETH LP
# Testnet: Mock LP token

# Generate separate salts for each network
# 1. Set mainnet LP token
LP_TOKEN_ADDRESS=0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAEE4e7e
make generate-vanity
# Save salt as MAINNET_SALT

# 2. Set testnet LP token  
LP_TOKEN_ADDRESS=0x1234567890123456789012345678901234567890
make generate-vanity
# Save salt as TESTNET_SALT
```

### Custom Salt Generation

For advanced users, you can generate salts manually:

```bash
# Using cast directly
cast create2 \
  --starts-with CAFE \
  --deployer 0xYourDeployerAddress \
  --init-code-hash 0xYourInitCodeHash

# Using a specific salt
cast create2 \
  --salt 0x1234567890123456789012345678901234567890123456789012345678901234 \
  --deployer 0xYourDeployerAddress \
  --init-code-hash 0xYourInitCodeHash
```

### Security Considerations

1. **Deterministic**: Same salt + deployer + bytecode = same address across all networks
2. **Public**: Salts are visible on-chain after deployment
3. **Collision Resistant**: Extremely unlikely to find two salts producing the same address
4. **Network Agnostic**: Address will be identical on mainnet, testnets, and L2s

### Troubleshooting Salt Generation

**"Invalid prefix hex provided"**:
- Only use valid hex characters: 0-9, A-F
- Example: `CAFE` ✅, `HELLO` ❌

**Generation taking too long**:
- Try shorter prefixes (3-4 characters)
- Use option 3 for random address if vanity isn't critical

**"Init code hash mismatch"**:
- Ensure your `.env` variables match the deployment
- Rebuild contracts: `forge build`

## 🌐 Production Deployment

### Base Mainnet Deployment

1. **Set Environment Variables**:
```bash
cd blockchain
cp env.example .env

# Edit .env with your production values:
PRIVATE_KEY=your_actual_private_key_here
BASESCAN_API_KEY=your_basescan_api_key
LP_TOKEN_ADDRESS=0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAEE4e7e
```

2. **Deploy to Base**:
```bash
# Standard deployment
make deploy-base

# OR deploy with vanity address
make generate-vanity  # Generate salt first
make deploy-create2-base
```

3. **Update Frontend Config**:
```typescript
// frontend/src/config.ts
export const CONTRACT_ADDRESSES = {
    [BASE_MAINNET.id]: {
        lpLocker: "0xYourDeployedLockerAddress",
        lpToken: "0xYourAerodromeLPTokenAddress",
    },
    // ... other networks
};
```

### Vercel Deployment

#### Option 1: Vercel CLI (Recommended)

1. **Install Vercel CLI**:
```bash
npm i -g vercel
```

2. **Deploy**:
```bash
cd frontend
vercel --prod
```

#### Option 2: GitHub Integration

1. **Push to GitHub**:
```bash
git add .
git commit -m "Ready for production"
git push origin main
```

2. **Connect to Vercel**:
   - Go to [vercel.com](https://vercel.com)
   - Import your GitHub repository
   - Configure build settings:
     - **Framework Preset**: Vite
     - **Root Directory**: `frontend`
     - **Build Command**: `bun run build`
     - **Output Directory**: `dist`

3. **Environment Variables** (if needed):
   - Add any required environment variables in Vercel dashboard
   - For this project, no additional env vars are typically needed

#### Option 3: Manual Deployment

1. **Build the frontend**:
```bash
cd frontend
bun run build
```

2. **Deploy the `dist` folder** to any static hosting service:
   - Vercel
   - Netlify
   - AWS S3 + CloudFront
   - GitHub Pages

### Vercel Configuration

Create `frontend/vercel.json` for advanced configuration:

```json
{
  "buildCommand": "bun run build",
  "outputDirectory": "dist",
  "framework": "vite",
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

## 🔧 Configuration

### Network Configuration

Update `frontend/src/config.ts` for different networks:

```typescript
export const CONTRACT_ADDRESSES = {
    [BASE_MAINNET.id]: {
        lpLocker: "0xYourLockerAddress",
        lpToken: "0xYourLPTokenAddress",
    },
    [ANVIL_LOCAL.id]: {
        lpLocker: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
        lpToken: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    },
};
```

### RPC Configuration

Update RPC endpoints in `foundry.toml`:

```toml
[rpc_endpoints]
base = "https://your-base-rpc-url"
anvil = "http://127.0.0.1:8545"
```

## 🧪 Testing

### Smart Contract Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/LPLocker.t.sol

# Generate coverage
forge coverage
```

### Frontend Testing

```bash
cd frontend

# Type checking
bun run build

# Linting
bun run lint
```

## 📁 Project Structure

```
keeta-timelock/
├── blockchain/             # Smart contract development
│   ├── src/               # Smart contracts
│   │   ├── LPLocker.sol   # Main locker contract
│   │   ├── Create2Factory.sol # CREATE2 deployment factory
│   │   └── interfaces/    # Contract interfaces
│   ├── test/              # Smart contract tests
│   ├── script/            # Deployment and utility scripts
│   │   ├── Deploy.s.sol   # Standard deployment
│   │   ├── DeployCreate2.s.sol # CREATE2 deployment
│   │   └── generate-vanity.sh # Vanity address generator
│   ├── lib/               # Foundry dependencies
│   ├── .env               # Environment variables
│   ├── env.example        # Environment template
│   ├── foundry.toml       # Foundry configuration
│   └── Makefile           # Development commands
├── frontend/              # React frontend application
│   ├── src/
│   │   ├── components/    # React components
│   │   │   ├── LockInfoPanel.tsx
│   │   │   ├── DepositPanel.tsx
│   │   │   ├── WithdrawalPanel.tsx
│   │   │   └── ...
│   │   ├── hooks/         # Custom React hooks
│   │   ├── config.ts      # Contract addresses & network config
│   │   └── main.tsx       # Application entry point
│   ├── public/            # Static assets
│   ├── package.json       # Frontend dependencies
│   └── vercel.json        # Vercel deployment config
├── README.md              # This file
├── DEPLOYMENT.md          # Detailed deployment guide
└── LICENSE                # MIT License
```

## 🔒 Security Considerations

### Smart Contract Security
- ✅ Owner-only access controls
- ✅ Time-based withdrawal delays
- ✅ Safe ERC20 transfers
- ✅ Comprehensive test coverage

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes in the appropriate directory:
   - Smart contracts: `blockchain/src/`
   - Tests: `blockchain/test/`
   - Frontend: `frontend/src/`
4. Run tests: `cd blockchain && make test`
5. Commit changes: `git commit -m 'Add amazing feature'`
6. Push to branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Troubleshooting

### Common Issues

**"forge not found"**
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**"bun not found"**
```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash
```

**"Contract not deployed"**
```bash
# Check if Anvil is running
cd blockchain
make anvil

# In another terminal, deploy contracts
cd blockchain
make deploy-anvil
```

### Getting Help

- 📖 Check the [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions
- 🐛 Open an issue on GitHub for bugs
- 💡 Start a discussion for feature requests
- 📧 Contact the team for security concerns

---
