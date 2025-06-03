import React from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useChainId } from "wagmi";
import { getContractAddress, BASE_MAINNET, ANVIL_LOCAL } from "./config";
import AllLocksPanel from "./components/AllLocksPanel";
import LPBalancePanel from "./components/LPBalancePanel";
import ClaimableFeesPanel from "./components/ClaimableFeesPanel";
import DepositPanel from "./components/DepositPanel";
import WithdrawalPanel from "./components/WithdrawalPanel";
import EmergencyRecoveryPanel from "./components/EmergencyRecoveryPanel";

const App: React.FC = () => {
    const chainId = useChainId();

    const getNetworkInfo = () => {
        switch (chainId) {
            case BASE_MAINNET.id:
                return { name: "Base Mainnet", color: "text-blue" };
            case ANVIL_LOCAL.id:
                return { name: "Anvil Local", color: "text-green" };
            default:
                return { name: "Unknown Network", color: "text-error" };
        }
    };

    const networkInfo = getNetworkInfo();
    let contractAddress = "";
    try {
        contractAddress = getContractAddress(chainId, 'lpLocker');
    } catch {
        // Handle unsupported network
    }

    return (
        <div className="min-h-screen bg-gradient-to-br from-[#18181b] to-[#23232a] text-gray-200 font-sans flex flex-col">
            {/* Navbar */}
            <nav className="w-full bg-[#18181b] border-b border-[#23232a] flex items-center justify-between px-6 md:px-10 py-3 md:py-4 shadow-lg z-10 font-sans">
                <div className="flex flex-col">
                    <span className="text-lg md:text-2xl font-bold tracking-tight text-salmon select-none">LPLocker Admin</span>
                    <div className="flex items-center gap-4 text-xs md:text-sm">
                        <span className={`font-medium ${networkInfo.color}`}>
                            {networkInfo.name}
                        </span>
                        {contractAddress && (
                            <span className="text-gray-3 font-mono">
                                {contractAddress.slice(0, 6)}...{contractAddress.slice(-4)}
                            </span>
                        )}
                    </div>
                </div>
                <div className="flex items-center">
                    <ConnectButton />
                </div>
            </nav>

            {/* Dashboard */}
            <main className="flex-1 flex flex-col items-center px-4 py-8">
                <div className="w-full max-w-7xl space-y-6">
                    {/* Header */}
                    <div className="text-center mb-8">
                        <h1 className="text-3xl font-bold text-gray-1 mb-2">LP Token Locker Dashboard</h1>
                        <p className="text-gray-3">Monitor and manage your locked liquidity provider tokens with 30-day withdrawal timelock</p>
                    </div>

                    {/* Grid Layout */}
                    <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
                        {/* Main locks display - spans full width on smaller screens */}
                        <div className="lg:col-span-2 xl:col-span-2">
                            <AllLocksPanel />
                        </div>

                        {/* Side panels */}
                        <div className="space-y-6">
                            <LPBalancePanel />
                            <DepositPanel />
                        </div>

                        {/* Withdrawal and Fee claiming - spans multiple columns */}
                        <div className="lg:col-span-2 xl:col-span-2">
                            <WithdrawalPanel />
                        </div>

                        <div className="space-y-6">
                            <ClaimableFeesPanel />
                        </div>

                        {/* Emergency Recovery - spans full width */}
                        <div className="lg:col-span-2 xl:col-span-3">
                            <EmergencyRecoveryPanel />
                        </div>
                    </div>
                </div>
            </main>
        </div>
    );
};

export default App; 