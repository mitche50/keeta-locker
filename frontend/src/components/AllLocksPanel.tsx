import React, { useState } from "react";
import { useLPLocker } from "../hooks/useLPLocker";
import ErrorDisplay from "./ErrorDisplay";

function shorten(addr: string) {
    return addr ? addr.slice(0, 6) + "..." + addr.slice(-4) : "-";
}

const LockCard: React.FC<{ lockId: string }> = ({ lockId }) => {
    const { lockInfo } = useLPLocker(lockId as `0x${string}`);
    const [expanded, setExpanded] = useState(false);

    if (lockInfo.isLoading) {
        return (
            <div className="bg-[#23232a] rounded-lg p-4 animate-pulse">
                <div className="h-4 w-20 bg-[#3a3a3f] rounded mb-2" />
                <div className="h-8 bg-[#3a3a3f] rounded" />
            </div>
        );
    }

    if (lockInfo.isError || !lockInfo.data) {
        return (
            <div className="bg-[#23232a] rounded-lg p-4 border border-red-500/20">
                <div className="text-red-400 text-sm">Error loading lock {shorten(lockId)}</div>
            </div>
        );
    }

    const [, , , amount, lockUpEndTime, isLiquidityLocked, isWithdrawalTriggered] = lockInfo.data as [string, string, string, bigint, bigint, boolean, boolean];

    const getStatusColor = () => {
        if (!isLiquidityLocked) return "bg-gray-500/20 text-gray-400";
        if (isWithdrawalTriggered) {
            const now = Date.now() / 1000;
            const unlockTimestamp = Number(lockUpEndTime);
            if (unlockTimestamp > 0 && now >= unlockTimestamp) {
                return "bg-green-500/20 text-green-400";
            }
            return "bg-yellow-500/20 text-yellow-400";
        }
        return "bg-blue-500/20 text-blue-400";
    };

    const getStatusText = () => {
        if (!isLiquidityLocked) return "Unlocked";
        if (isWithdrawalTriggered) {
            const now = Date.now() / 1000;
            const unlockTimestamp = Number(lockUpEndTime);
            if (unlockTimestamp > 0 && now >= unlockTimestamp) {
                return "Withdrawable";
            }
            return "Timelock Active";
        }
        return "Locked";
    };

    return (
        <div className="bg-[#23232a] rounded-lg border border-[#3a3a3f] overflow-hidden">
            <div
                className="p-4 cursor-pointer hover:bg-[#2a2a2f] transition-colors"
                onClick={() => setExpanded(!expanded)}
            >
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <span className="font-mono text-sm text-gray-3">
                            {shorten(lockId)}
                        </span>
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor()}`}>
                            {getStatusText()}
                        </span>
                    </div>
                    <div className="flex items-center gap-3">
                        <span className="font-mono text-sm text-gray-1">
                            {amount?.toString?.()} LP
                        </span>
                        <span className="text-gray-4 transition-transform duration-200"
                            style={{ transform: expanded ? 'rotate(180deg)' : 'rotate(0deg)' }}>
                            ▼
                        </span>
                    </div>
                </div>
            </div>

            {expanded && (
                <div className="px-4 pb-4 space-y-3 border-t border-[#3a3a3f]">
                    <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                            <span className="text-gray-4">Amount:</span>
                            <div className="font-mono text-gray-1">{amount?.toString?.()} LP</div>
                        </div>
                        <div>
                            <span className="text-gray-4">Status:</span>
                            <div className={`font-medium ${getStatusColor()}`}>{getStatusText()}</div>
                        </div>
                    </div>

                    {isWithdrawalTriggered && lockUpEndTime && Number(lockUpEndTime) > 0 && (
                        <div className="text-sm">
                            <span className="text-gray-4">Unlock Time:</span>
                            <div className="font-mono text-gray-1">
                                {new Date(Number(lockUpEndTime) * 1000).toLocaleString()}
                            </div>
                        </div>
                    )}

                    <div className="pt-2 border-t border-[#3a3a3f]">
                        <button
                            className="text-xs text-salmon hover:text-salmon/80 transition-colors"
                            onClick={(e) => {
                                e.stopPropagation();
                                navigator.clipboard.writeText(lockId);
                            }}
                        >
                            Copy Lock ID
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
};

const AllLocksPanel: React.FC = () => {
    const { allLockIds, owner, feeReceiver, tokenContract } = useLPLocker();

    if (allLockIds.isLoading) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6 animate-pulse">
                <div className="h-6 w-32 bg-[#3a3a3f] rounded mb-6" />
                <div className="space-y-3">
                    <div className="h-16 bg-[#3a3a3f] rounded" />
                    <div className="h-16 bg-[#3a3a3f] rounded" />
                    <div className="h-16 bg-[#3a3a3f] rounded" />
                </div>
            </div>
        );
    }

    if (allLockIds.isError) {
        return (
            <ErrorDisplay
                error={allLockIds.error as Error & { code?: string }}
                title="Error loading locks"
                onRetry={() => window.location.reload()}
            />
        );
    }

    const lockIds = allLockIds.data as string[] | undefined;

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-salmon">All Locks</h2>
                <span className="text-sm text-gray-3 bg-[#23232a] px-3 py-1 rounded-full">
                    {lockIds?.length || 0} active locks
                </span>
            </div>

            {/* Contract Info Summary */}
            <div className="mb-6 p-4 bg-[#23232a] rounded-lg">
                <h3 className="text-sm font-medium text-gray-3 mb-3">Contract Info</h3>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
                    <div>
                        <span className="text-gray-4">Owner:</span>
                        <div className="font-mono text-gray-1">{shorten(owner.data as string || "")}</div>
                    </div>
                    <div>
                        <span className="text-gray-4">Fee Receiver:</span>
                        <div className="font-mono text-gray-1">{shorten(feeReceiver.data as string || "")}</div>
                    </div>
                    <div>
                        <span className="text-gray-4">LP Token:</span>
                        <div className="font-mono text-gray-1">{shorten(tokenContract.data as string || "")}</div>
                    </div>
                </div>
            </div>

            {/* Locks List */}
            <div className="space-y-3">
                {!lockIds || lockIds.length === 0 ? (
                    <div className="text-center py-8 text-gray-4">
                        <div className="text-4xl mb-2">🔓</div>
                        <div className="text-sm">No active locks found</div>
                        <div className="text-xs text-gray-5 mt-1">
                            Use the Deposit Panel to create a new lock
                        </div>
                    </div>
                ) : (
                    <>
                        <div className="text-sm text-gray-4 mb-3">
                            Click on any lock to view details
                        </div>
                        {lockIds.map((lockId) => (
                            <LockCard key={lockId} lockId={lockId} />
                        ))}
                    </>
                )}
            </div>
        </div>
    );
};

export default AllLocksPanel; 