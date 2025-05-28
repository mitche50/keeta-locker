import React, { useState } from "react";
import { useLPLocker } from "../hooks/useLPLocker";
import ErrorDisplay from "./ErrorDisplay";

function shorten(addr: string) {
    return addr ? addr.slice(0, 6) + "..." + addr.slice(-4) : "-";
}

const LockInfoPanel: React.FC = () => {
    const { lockInfo } = useLPLocker();
    const [copied, setCopied] = useState<string | null>(null);

    if (lockInfo.isLoading) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6 animate-pulse">
                <div className="h-6 w-32 bg-[#3a3a3f] rounded mb-6" />
                <div className="space-y-4">
                    <div className="h-16 bg-[#3a3a3f] rounded" />
                    <div className="h-16 bg-[#3a3a3f] rounded" />
                    <div className="h-12 bg-[#3a3a3f] rounded" />
                </div>
            </div>
        );
    }

    if (lockInfo.isError) {
        return (
            <ErrorDisplay
                error={lockInfo.error as Error & { code?: string }}
                title="Error loading lock info"
                onRetry={() => window.location.reload()}
            />
        );
    }

    const lockData = lockInfo.data;
    if (!lockData || !Array.isArray(lockData)) {
        return (
            <div className="bg-[#2a2a2f] border border-gray-4/20 text-gray-3 rounded-xl p-6">
                <div className="flex items-center gap-2">
                    <span>ℹ️</span>
                    <span className="font-medium">No lock data available</span>
                </div>
            </div>
        );
    }

    const [owner, feeReceiver, tokenContract, lockedAmount, lockUpEndTime, isLiquidityLocked, isWithdrawalTriggered] = lockData;

    function handleCopy(val: string) {
        navigator.clipboard.writeText(val);
        setCopied(val);
        setTimeout(() => setCopied(null), 1200);
    }

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <h2 className="text-xl font-semibold mb-6 text-salmon">Lock Info</h2>

            <div className="space-y-6">
                {/* Contract Addresses Section */}
                <div className="space-y-4">
                    <h3 className="text-sm font-medium text-gray-3 uppercase tracking-wide">Contract Details</h3>

                    <div className="bg-[#23232a] rounded-lg p-4 space-y-3">
                        <div className="flex justify-between items-center">
                            <span className="text-sm text-gray-3">Owner</span>
                            <div className="flex items-center gap-2">
                                <span className="text-gray-1 font-mono text-sm" title={owner}>
                                    {shorten(owner)}
                                </span>
                                <button
                                    className="text-xs text-salmon hover:text-salmon/80 transition-colors px-2 py-1 rounded bg-salmon/10 hover:bg-salmon/20"
                                    onClick={() => handleCopy(owner)}
                                >
                                    {copied === owner ? "✓" : "Copy"}
                                </button>
                            </div>
                        </div>

                        <div className="flex justify-between items-center">
                            <span className="text-sm text-gray-3">Fee Receiver</span>
                            <div className="flex items-center gap-2">
                                <span className="text-gray-1 font-mono text-sm" title={feeReceiver}>
                                    {shorten(feeReceiver)}
                                </span>
                                <button
                                    className="text-xs text-salmon hover:text-salmon/80 transition-colors px-2 py-1 rounded bg-salmon/10 hover:bg-salmon/20"
                                    onClick={() => handleCopy(feeReceiver)}
                                >
                                    {copied === feeReceiver ? "✓" : "Copy"}
                                </button>
                            </div>
                        </div>

                        <div className="flex justify-between items-center">
                            <span className="text-sm text-gray-3">LP Token</span>
                            <div className="flex items-center gap-2">
                                <span className="text-gray-1 font-mono text-sm" title={tokenContract}>
                                    {shorten(tokenContract)}
                                </span>
                                <button
                                    className="text-xs text-salmon hover:text-salmon/80 transition-colors px-2 py-1 rounded bg-salmon/10 hover:bg-salmon/20"
                                    onClick={() => handleCopy(tokenContract)}
                                >
                                    {copied === tokenContract ? "✓" : "Copy"}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Lock Status Section */}
                <div className="space-y-4">
                    <h3 className="text-sm font-medium text-gray-3 uppercase tracking-wide">Lock Status</h3>

                    <div className="bg-[#23232a] rounded-lg p-4 space-y-4">
                        <div className="flex justify-between items-center">
                            <span className="text-sm text-gray-3">Locked Amount</span>
                            <span className="text-gray-1 font-mono font-bold">
                                {lockedAmount?.toString?.() ?? "0"}
                            </span>
                        </div>

                        <div className="flex justify-between items-center">
                            <span className="text-sm text-gray-3">Status</span>
                            <span className={`font-medium px-3 py-1 rounded-full text-xs ${isLiquidityLocked
                                ? "text-green bg-green/10 border border-green/20"
                                : "text-gray-3 bg-gray-4/10 border border-gray-4/20"
                                }`}>
                                {isLiquidityLocked ? "🔒 Locked" : "🔓 Unlocked"}
                            </span>
                        </div>

                        <div className="flex justify-between items-center">
                            <span className="text-sm text-gray-3">Withdrawal</span>
                            <span className={`font-medium px-3 py-1 rounded-full text-xs ${isWithdrawalTriggered
                                ? "text-blue bg-blue/10 border border-blue/20"
                                : "text-gray-3 bg-gray-4/10 border border-gray-4/20"
                                }`}>
                                {isWithdrawalTriggered ? "⏰ Triggered" : "❌ Not Triggered"}
                            </span>
                        </div>

                        {(lockUpEndTime && Number(lockUpEndTime) > 0) && (
                            <div className="pt-2 border-t border-[#3a3a3f]">
                                <div className="flex justify-between items-center">
                                    <span className="text-sm text-gray-3">Unlock Time</span>
                                    <span className="text-gray-1 font-mono text-sm">
                                        {new Date(Number(lockUpEndTime) * 1000).toLocaleDateString()}
                                    </span>
                                </div>
                                <div className="text-xs text-gray-4 text-right mt-1">
                                    {new Date(Number(lockUpEndTime) * 1000).toLocaleTimeString()}
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
};

export default LockInfoPanel; 