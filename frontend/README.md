# LPLocker Frontend

Modern React dashboard for managing Aerodrome LP token locks with time-based withdrawal mechanisms.

## 🚀 Features

- **Multi-Lock Management**: View and manage multiple independent LP locks
- **Real-time Updates**: Live blockchain data with 2-5 second refresh intervals
- **Dual Fee Tracking**: Monitor both claimable and accumulated fees
- **Blockchain Time Sync**: Uses actual blockchain timestamps for accurate unlock times
- **Responsive Design**: Clean, modern interface optimized for desktop and mobile
- **Wallet Integration**: RainbowKit with MetaMask, WalletConnect, and other wallets

## 🛠️ Tech Stack

- **React 18** with TypeScript
- **Vite** for fast development and building
- **Wagmi v2** for Ethereum interactions
- **RainbowKit** for wallet connections
- **Tailwind CSS** for styling
- **React Hot Toast** for notifications

## 🏁 Quick Start

```bash
# Install dependencies
bun install

# Start development server
bun run dev

# Build for production
bun run build

# Preview production build
bun run preview
```

## 🔧 Configuration

The frontend automatically connects to deployed contracts based on the network:

```typescript
// src/config.ts
export const CONTRACT_ADDRESSES = {
    [BASE_MAINNET.id]: {
        lpLocker: "0xYourProductionAddress",
        lpToken: "0xYourAerodromeLPToken",
    },
    [ANVIL_LOCAL.id]: {
        lpLocker: "0x09635F643e140090A9A8Dcd712eD6285858ceBef",
        lpToken: "0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f",
    },
};
```

## 📱 Components Overview

- **AllLocksPanel**: Main dashboard showing all locks with management options
- **DepositPanel**: Create new LP locks with amount input and approval flow
- **ClaimableFeesPanel**: Monitor and claim both types of fees with update functionality  
- **LockInfoPanel**: Detailed view of individual lock information
- **LPBalancePanel**: Display total LP balance and contract information
- **EmergencyRecoveryPanel**: Recover accidentally sent tokens (owner only)

## 🔗 Wallet Connection

The app supports multiple wallet connections through RainbowKit:
- MetaMask
- WalletConnect
- Coinbase Wallet
- Rainbow Wallet
- And more...

## 🌐 Network Support

- **Base Mainnet**: Production Aerodrome LP tokens
- **Anvil Local**: Development with mock LP tokens

## 🎨 Styling

Built with Tailwind CSS using a custom dark theme:
- **Salmon** (#ff6b6b) - Primary accent color
- **Dark grays** - Modern dark theme throughout
- **Responsive design** - Works on all screen sizes

## 📦 Build & Deploy

```bash
# Production build
bun run build

# Deploy to Vercel
vercel --prod

# Or deploy build folder to any static host
```

The build outputs to `dist/` and can be deployed to:
- Vercel (recommended)
- Netlify
- AWS S3 + CloudFront
- Any static hosting service
