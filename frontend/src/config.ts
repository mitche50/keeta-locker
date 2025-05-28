export const BASE_MAINNET = {
    id: 8453,
    name: "Base Mainnet",
    network: "base",
    nativeCurrency: {
        name: "Ether",
        symbol: "ETH",
        decimals: 18,
    },
    rpcUrls: {
        default: { http: ["https://mainnet.base.org"] },
        public: { http: ["https://mainnet.base.org"] },
    },
    blockExplorers: {
        default: { name: "Basescan", url: "https://basescan.org" },
    },
    testnet: false,
};

export const ANVIL_LOCAL = {
    id: 31337,
    name: "Anvil Local",
    network: "anvil",
    nativeCurrency: {
        name: "Ether",
        symbol: "ETH",
        decimals: 18,
    },
    rpcUrls: {
        default: { http: ["http://127.0.0.1:8545"] },
        public: { http: ["http://127.0.0.1:8545"] },
    },
    blockExplorers: {
        default: { name: "Local Explorer", url: "http://localhost:8545" },
    },
    testnet: true,
};

// Contract addresses by chain ID
export const CONTRACT_ADDRESSES = {
    [BASE_MAINNET.id]: {
        lpLocker: "0xYourLockerAddressHere", // TODO: Replace with deployed Base address
        lpToken: "0xYourLPTokenAddressHere", // TODO: Replace with actual Aerodrome LP token
    },
    [ANVIL_LOCAL.id]: {
        lpLocker: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512", // Deployed LPLocker address
        lpToken: "0x5FbDB2315678afecb367f032d93F642f64180aa3", // Deployed MockERC20 address
    },
};

// Helper function to get contract address for current chain
export function getContractAddress(chainId: number, contract: 'lpLocker' | 'lpToken'): string {
    const addresses = CONTRACT_ADDRESSES[chainId as keyof typeof CONTRACT_ADDRESSES];
    if (!addresses) {
        throw new Error(`No contract addresses configured for chain ID ${chainId}`);
    }
    return addresses[contract];
} 