import React from "react";
import { useLPLocker } from "../hooks/useLPLocker";
import ErrorDisplay from "./ErrorDisplay";

const LPBalancePanel: React.FC = () => {
    const { lpBalance } = useLPLocker();

    if (lpBalance.isLoading) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6 animate-pulse">
                <div className="h-6 w-32 bg-[#3a3a3f] rounded mb-4" />
                <div className="h-8 w-1/2 bg-[#3a3a3f] rounded" />
            </div>
        );
    }

    if (lpBalance.isError) {
        return (
            <ErrorDisplay
                error={lpBalance.error as Error & { code?: string }}
                title="Error loading LP balance"
                onRetry={() => window.location.reload()}
            />
        );
    }

    const balance = lpBalance.data?.toString?.() ?? "0";
    const hasBalance = balance !== "0" && balance !== "-";

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <h2 className="text-xl font-semibold mb-6 text-salmon">LP Token Balance</h2>
            <div className="flex items-center justify-between">
                <div className="flex flex-col">
                    <div className={`text-3xl font-bold font-mono ${hasBalance ? "text-gray-1" : "text-gray-3"}`}>
                        {balance}
                    </div>
                    <div className="text-sm text-gray-3 mt-1">
                        {hasBalance ? "LP Tokens" : "No tokens in contract"}
                    </div>
                </div>
                <div className={`px-3 py-2 rounded-lg text-sm font-medium ${hasBalance
                    ? "bg-green/10 text-green"
                    : "bg-gray-4/10 text-gray-3"
                    }`}>
                    {hasBalance ? "💰 Has Balance" : "📭 Empty"}
                </div>
            </div>
        </div>
    );
};

export default LPBalancePanel; 