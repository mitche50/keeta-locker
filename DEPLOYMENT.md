# LPLocker Production Deployment Guide

This guide covers deploying the LPLocker system to production environments.

## 🚀 Quick Deployment Checklist

- [ ] Environment variables configured
- [ ] Smart contracts deployed and verified
- [ ] Frontend built and deployed
- [ ] DNS configured (if using custom domain)
- [ ] Monitoring and alerts set up

## 📋 Prerequisites

### Required Tools
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest)
- [Bun](https://bun.sh/) (latest)
- [Vercel CLI](https://vercel.com/cli) (optional, for CLI deployment)

### Required Accounts
- **Ethereum Wallet**: With sufficient ETH for deployment gas
- **Basescan Account**: For contract verification
- **Vercel Account**: For frontend hosting (or alternative hosting provider)

## 🔧 Environment Setup

### 1. Clone and Install Dependencies

```bash
git clone git@github.com:mitche50/keeta-locker.git
cd keeta-timelock

# Install smart contract dependencies
cd blockchain
forge install

# Install frontend dependencies
cd ../frontend && bun install && cd ..
```

### 2. Configure Environment Variables

Create `.env` file in the `blockchain/` directory:

```bash
# Copy example environment file
cd blockchain
cp env.example .env
```

Edit `blockchain/.env` with your values:

```bash
# Deployment wallet private key (with ETH for gas)
PRIVATE_KEY=your_private_key_here

# Basescan API key for contract verification
BASESCAN_API_KEY=your_basescan_api_key_here

# Aerodrome LP token address you want to lock
LP_TOKEN_ADDRESS=0x1234567890123456789012345678901234567890

# Optional: Custom RPC endpoint
BASE_RPC_URL=https://mainnet.base.org

# Optional: CREATE2 salt for vanity address deployment
# CREATE2_SALT=0x1234567890123456789012345678901234567890123456789012345678901234
```

### 3. Verify Environment Setup

```bash
cd blockchain
make check-env
```

## 🏗️ Smart Contract Deployment

### Option 1: Standard Deployment

Deploy to Base mainnet with a standard address:

```bash
cd blockchain
make deploy-base
```

This will:
1. Deploy the LPLocker contract
2. Verify the contract on Basescan
3. Display deployment addresses

### Option 2: CREATE2 Vanity Address Deployment

Deploy with a custom vanity address (e.g., starting with "5AF3" for "SAFE"):

```bash
cd blockchain

# Generate vanity address and salt
make generate-vanity

# Deploy using CREATE2 with the generated salt
make deploy-create2-base
```

The vanity address generator offers these options:
1. **5AF3** (SAFE) - Perfect for locker contracts
2. **Custom pattern** - Enter your own hex pattern
3. **Random address** - Deploy with any address

### Manual Deployment (Alternative)

```bash
cd blockchain

# Standard deployment
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url base \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY

# OR CREATE2 deployment (if CREATE2_SALT is set in .env)
forge script script/DeployCreate2.s.sol:DeployCreate2Script \
  --rpc-url base \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

### Verify Deployment

After deployment, verify:

1. **Contract Address**: Note the deployed LPLocker address
2. **Verification**: Check contract is verified on [Basescan](https://basescan.org)
3. **Ownership**: Confirm your wallet is the owner
4. **LP Token**: Verify correct LP token is configured

## 🌐 Frontend Deployment

### Update Contract Configuration

Edit `frontend/src/config.ts` with your deployed contract address:

```typescript
export const CONTRACT_ADDRESSES = {
    [BASE_MAINNET.id]: {
        lpLocker: "0xYourDeployedLockerAddress", // ← Update this
        lpToken: "0xYourAerodromeLPTokenAddress",  // ← Update this
    },
    // ... other networks
};
```

### Option 1: Deploy to Vercel (Recommended)

#### Via Vercel CLI

```bash
cd frontend

# Install Vercel CLI (if not already installed)
bun add -g vercel

# Deploy to production
vercel --prod
```

#### Via GitHub Integration

1. **Push to GitHub**:
```bash
git add .
git commit -m "Production deployment"
git push origin main
```

2. **Connect to Vercel**:
   - Go to [vercel.com](https://vercel.com)
   - Click "New Project"
   - Import your GitHub repository
   - Configure settings:
     - **Framework Preset**: Vite
     - **Root Directory**: `frontend`
     - **Build Command**: `bun run build`
     - **Output Directory**: `dist`

3. **Deploy**: Click "Deploy"

### Option 2: Deploy to Netlify

```bash
cd frontend

# Build the project
bun run build

# Install Netlify CLI
bun add -g netlify-cli

# Deploy
netlify deploy --prod --dir=dist
```

### Option 3: Deploy to AWS S3 + CloudFront

```bash
cd frontend

# Build the project
bun run build

# Upload to S3 (requires AWS CLI configured)
aws s3 sync dist/ s3://your-bucket-name --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"
```

## 🔍 Post-Deployment Verification

### Smart Contract Verification

1. **Visit Basescan**: Go to your contract address on [basescan.org](https://basescan.org)
2. **Check Verification**: Ensure "Contract" tab shows verified source code
3. **Test Read Functions**: Try calling view functions like `getLockInfo()`
4. **Check Events**: Verify deployment events are logged

### Frontend Verification

1. **Load Application**: Visit your deployed URL
2. **Connect Wallet**: Test wallet connection with MetaMask
3. **Network Detection**: Verify it detects Base mainnet correctly
4. **Contract Interaction**: Check that contract data loads properly
5. **Responsive Design**: Test on mobile and desktop
6. **Error Handling**: Test comprehensive error handling system

### Integration Testing

1. **Connect to Base**: Switch MetaMask to Base mainnet
2. **View Contract Data**: Verify all panels load correctly
3. **Owner Functions**: Test owner-only functions (if you're the owner)
4. **Error Handling**: Test with wrong network/disconnected wallet
5. **Toast Notifications**: Verify user feedback system works
6. **Loading States**: Check loading indicators during transactions

## 🔒 Security Checklist

### Smart Contract Security

- [ ] Contract verified on Basescan
- [ ] Owner address is secure (hardware wallet recommended)
- [ ] Fee receiver address is correct
- [ ] LP token address is correct
- [ ] No admin keys or backdoors
- [ ] Emergency functions work as expected
- [ ] CREATE2 deployment salt is secure (if used)

### Frontend Security

- [ ] HTTPS enabled (automatic with Vercel/Netlify)
- [ ] No sensitive data in client-side code
- [ ] Proper error handling for failed transactions
- [ ] Input validation on all forms
- [ ] Secure wallet connection handling
- [ ] Content Security Policy headers configured

## 📊 Monitoring and Maintenance

### Contract Monitoring

Set up monitoring for:
- **Lock Events**: New liquidity locks
- **Withdrawal Events**: Triggered and completed withdrawals
- **Fee Claims**: Fee collection events
- **Reward Claims**: Reward distribution events
- **Owner Changes**: Ownership transfers

### Frontend Monitoring

- **Uptime Monitoring**: Use services like UptimeRobot
- **Error Tracking**: Implement Sentry or similar
- **Analytics**: Google Analytics or Plausible
- **Performance**: Monitor Core Web Vitals
- **User Experience**: Monitor toast notifications and error states

### Recommended Tools

- **Tenderly**: Smart contract monitoring and alerting
- **OpenZeppelin Defender**: Automated security monitoring
- **Vercel Analytics**: Frontend performance monitoring
- **Sentry**: Error tracking and performance monitoring

## 🚨 Emergency Procedures

### Smart Contract Issues

1. **Pause Operations**: Use emergency functions if available
2. **Contact Users**: Notify users via official channels
3. **Investigate**: Use Tenderly or similar tools to debug
4. **Coordinate Fix**: Deploy fixes if necessary

### Frontend Issues

1. **Rollback**: Use Vercel/Netlify rollback features
2. **Hotfix**: Deploy emergency fixes quickly
3. **Status Page**: Update users on status
4. **Monitor**: Watch for resolution

## 🛠️ Development Commands Reference

All commands should be run from the `blockchain/` directory:

```bash
# Environment check
make check-env

# Standard deployment
make deploy-base

# Vanity address deployment
make generate-vanity
make deploy-create2-base

# Testing
make test
make test-gas
make coverage

# Frontend (from blockchain/ directory)
make frontend-install
make frontend-build
```

## 📞 Support and Resources

### Documentation
- [Foundry Book](https://book.getfoundry.sh/)
- [Vercel Documentation](https://vercel.com/docs)
- [Base Network Documentation](https://docs.base.org/)
- [Bun Documentation](https://bun.sh/docs)

### Community
- [Base Discord](https://discord.gg/buildonbase)
- [Foundry Telegram](https://t.me/foundry_rs)

### Emergency Contacts
- **Team Lead**: [Your contact info]
- **DevOps**: [DevOps contact info]
- **Security**: [Security contact info]

---

## 🎯 Production Deployment Summary

1. **Setup Environment**: Configure `blockchain/.env` with required variables
2. **Choose Deployment Method**: 
   - Standard: `make deploy-base`
   - Vanity Address: `make generate-vanity && make deploy-create2-base`
3. **Update Frontend Config**: Edit contract addresses in `frontend/src/config.ts`
4. **Deploy Frontend**: `vercel --prod` or GitHub integration
5. **Verify Everything**: Test all functionality including error handling
6. **Set Up Monitoring**: Implement monitoring and alerts
7. **Document**: Update team documentation

**🎉 Your LPLocker is now live in production!** 