import React, { useState } from "react";
import { formatEther, parseEther } from "viem";
import { useWriteContract, useWaitForTransactionReceipt, useAccount, useReadContract, useChainId, useBlock } from "wagmi";
import { useLPLocker } from "../hooks/useLPLocker";
import { useAppContext } from "../context/AppContext";
import LPLockerABI from "../abi/LPLocker.json";
import { getContractAddress } from "../config";
import toast from "react-hot-toast";
import ErrorDisplay from "./ErrorDisplay";

function shorten(addr: string) {
    return addr ? addr.slice(0, 6) + "..." + addr.slice(-4) : "-";
}

interface LockData {
    lockId: string;
    amount: bigint;
    lockUpEndTime: bigint;
    isLiquidityLocked: boolean;
    isWithdrawalTriggered: boolean;
    isLoading?: boolean;
    error?: any;
}

const LockCard: React.FC<{
    lockData: LockData;
    owner: any;
}> = ({ lockData, owner }) => {
    // ALL HOOKS MUST BE CALLED FIRST - NO EARLY RETURNS BEFORE THIS POINT
    const { address } = useAccount();
    const chainId = useChainId();
    const { refreshLocks, refreshBalances } = useAppContext();
    const [expanded, setExpanded] = useState(false);
    const [withdrawAmount, setWithdrawAmount] = useState("");
    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;
    const { writeContract, data: hash, isPending } = useWriteContract();
    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

    // Get current blockchain timestamp instead of client time
    const { data: currentBlock } = useBlock({
        query: {
            refetchInterval: 5000, // Refetch every 5 seconds
        },
    });

    // Effect hook must also be called consistently
    React.useEffect(() => {
        if (isSuccess) {
            toast.dismiss();
            toast.success("Transaction completed!");
            setWithdrawAmount("");
            // Refresh locks and balances after any lock operation
            refreshLocks();
            refreshBalances();
        }
    }, [isSuccess, refreshLocks, refreshBalances]);

    // NOW we can handle conditional rendering AFTER all hooks are called
    if (lockData.isLoading) {
        return (
            <div className="bg-[#23232a] rounded-lg p-4 animate-pulse">
                <div className="h-4 w-20 bg-[#3a3a3f] rounded mb-2" />
                <div className="h-8 bg-[#3a3a3f] rounded" />
            </div>
        );
    }

    if (lockData.error) {
        return (
            <div className="bg-[#23232a] rounded-lg p-4 border border-red-500/20">
                <div className="text-red-400 text-sm">Error loading lock {shorten(lockData.lockId)}</div>
            </div>
        );
    }

    const { lockId, amount, lockUpEndTime, isLiquidityLocked, isWithdrawalTriggered } = lockData;
    const isOwner = address && owner?.data && address.toLowerCase() === (owner.data as string).toLowerCase();

    // Use blockchain time if available, fallback to client time
    const currentTime = currentBlock?.timestamp ? Number(currentBlock.timestamp) : Math.floor(Date.now() / 1000);
    const unlockTimestamp = Number(lockUpEndTime);
    const canWithdraw = unlockTimestamp > 0 && currentTime >= unlockTimestamp;

    const getStatusColor = () => {
        if (!isLiquidityLocked) return "bg-gray-500/20 text-gray-400";
        if (isWithdrawalTriggered) {
            if (unlockTimestamp > 0 && currentTime >= unlockTimestamp) {
                return "bg-green-500/20 text-green-400";
            }
            return "bg-yellow-500/20 text-yellow-400";
        }
        return "bg-blue-500/20 text-blue-400";
    };

    const getStatusText = () => {
        if (!isLiquidityLocked) return "Unlocked";
        if (isWithdrawalTriggered) {
            if (unlockTimestamp > 0 && currentTime >= unlockTimestamp) {
                return "Withdrawable";
            }
            return "Timelock Active";
        }
        return "Locked";
    };

    const handleTriggerWithdrawal = async () => {
        try {
            toast.loading("Triggering withdrawal...", { id: "trigger" });
            await writeContract({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "triggerWithdrawal",
                args: [lockId],
            });
        } catch (error) {
            console.error("Trigger withdrawal error:", error);
            toast.dismiss("trigger");
            toast.error("Failed to trigger withdrawal");
        }
    };

    const handleCancelWithdrawal = async () => {
        try {
            toast.loading("Cancelling withdrawal...", { id: "cancel" });
            await writeContract({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "cancelWithdrawalTrigger",
                args: [lockId],
            });
        } catch (error) {
            console.error("Cancel withdrawal error:", error);
            toast.dismiss("cancel");
            toast.error("Failed to cancel withdrawal");
        }
    };

    const handleWithdrawLP = async () => {
        if (!withdrawAmount) return;
        try {
            toast.loading("Withdrawing LP tokens...", { id: "withdraw" });
            const withdrawAmountBigInt = parseEther(withdrawAmount);
            await writeContract({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "withdrawLP",
                args: [lockId, withdrawAmountBigInt],
            });
        } catch (error) {
            console.error("Withdraw LP error:", error);
            toast.dismiss("withdraw");
            toast.error("Failed to withdraw LP tokens");
        }
    };

    const handleMaxWithdrawClick = () => {
        setWithdrawAmount(formatEther(amount));
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
                            {formatEther(amount)} LP
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
                            <div className="font-mono text-gray-1">{formatEther(amount)} LP</div>
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
                        <div className="flex items-center justify-between mb-3">
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

                        {/* Withdrawal Management */}
                        {isOwner ? (
                            <div className="space-y-3 pt-3 border-t border-[#3a3a3f]">
                                <div className="text-xs font-medium text-gray-3 mb-2">Withdrawal Management</div>

                                {/* Trigger Withdrawal */}
                                {!isWithdrawalTriggered && (
                                    <button
                                        onClick={(e) => {
                                            e.stopPropagation();
                                            handleTriggerWithdrawal();
                                        }}
                                        disabled={isPending || isConfirming}
                                        className="w-full bg-blue-500/10 hover:bg-blue-500/20 border border-blue-500/20 text-blue-400 text-xs font-medium py-2 px-3 rounded transition-colors disabled:opacity-50"
                                    >
                                        {isPending || isConfirming ? "Processing..." : "🚀 Trigger Withdrawal"}
                                    </button>
                                )}

                                {/* Cancel Withdrawal */}
                                {isWithdrawalTriggered && !canWithdraw && (
                                    <button
                                        onClick={(e) => {
                                            e.stopPropagation();
                                            handleCancelWithdrawal();
                                        }}
                                        disabled={isPending || isConfirming}
                                        className="w-full bg-red-500/10 hover:bg-red-500/20 border border-red-500/20 text-red-400 text-xs font-medium py-2 px-3 rounded transition-colors disabled:opacity-50"
                                    >
                                        {isPending || isConfirming ? "Processing..." : "❌ Cancel Withdrawal"}
                                    </button>
                                )}

                                {/* Withdraw LP Tokens */}
                                {isWithdrawalTriggered && canWithdraw && (
                                    <div className="space-y-2">
                                        <div className="flex gap-2">
                                            <input
                                                type="number"
                                                value={withdrawAmount}
                                                onChange={(e) => setWithdrawAmount(e.target.value)}
                                                placeholder="Amount to withdraw"
                                                className="flex-1 bg-[#1a1a1f] border border-[#3a3a3f] rounded px-2 py-1 text-xs text-gray-1"
                                                onClick={(e) => e.stopPropagation()}
                                            />
                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    handleMaxWithdrawClick();
                                                }}
                                                className="text-xs text-salmon hover:text-salmon/80 px-2 py-1 bg-salmon/10 rounded"
                                            >
                                                MAX
                                            </button>
                                        </div>
                                        <button
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                handleWithdrawLP();
                                            }}
                                            disabled={!withdrawAmount || isPending || isConfirming}
                                            className="w-full bg-green-500/10 hover:bg-green-500/20 border border-green-500/20 text-green-400 text-xs font-medium py-2 px-3 rounded transition-colors disabled:opacity-50"
                                        >
                                            {isPending || isConfirming ? "Processing..." : "💰 Withdraw LP Tokens"}
                                        </button>
                                    </div>
                                )}

                                {/* Status Messages */}
                                {isWithdrawalTriggered && !canWithdraw && unlockTimestamp > 0 && (
                                    <div className="bg-yellow-500/10 border border-yellow-500/20 rounded p-2">
                                        <div className="text-xs text-yellow-400">
                                            ⏰ Withdrawable after {new Date(unlockTimestamp * 1000).toLocaleString()}
                                        </div>
                                    </div>
                                )}
                            </div>
                        ) : null}
                    </div>
                </div>
            )}
        </div>
    );
};

const LockCardWithData: React.FC<{
    lockId: string;
    owner: any;
}> = ({ lockId, owner }) => {
    const chainId = useChainId();
    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;

    // Always call useReadContract - never call it conditionally
    const lockInfoResult = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getLockInfo",
        args: [lockId],
        query: {
            refetchInterval: 2000, // Refetch every 2 seconds to keep data fresh
            enabled: !!lockId && !!lpLockerAddress, // Only enable when we have required data
        },
    });

    // Create base lock data structure
    const baseLockData: LockData = {
        lockId,
        amount: BigInt(0),
        lockUpEndTime: BigInt(0),
        isLiquidityLocked: false,
        isWithdrawalTriggered: false,
    };

    // Handle loading state
    if (lockInfoResult.isLoading) {
        return <LockCard lockData={{ ...baseLockData, isLoading: true }} owner={owner} />;
    }

    // Handle error state
    if (lockInfoResult.isError) {
        return <LockCard lockData={{ ...baseLockData, error: lockInfoResult.error }} owner={owner} />;
    }

    // Handle success state
    try {
        const lockInfoData = lockInfoResult.data as any[];
        if (!lockInfoData || lockInfoData.length < 7) {
            return <LockCard lockData={{ ...baseLockData, error: new Error("Invalid lock data") }} owner={owner} />;
        }

        const [, , , amount, lockUpEndTime, isLiquidityLocked, isWithdrawalTriggered] = lockInfoData;

        const realLockData: LockData = {
            lockId,
            amount: amount as bigint,
            lockUpEndTime: lockUpEndTime as bigint,
            isLiquidityLocked: isLiquidityLocked as boolean,
            isWithdrawalTriggered: isWithdrawalTriggered as boolean,
        };

        return <LockCard lockData={realLockData} owner={owner} />;
    } catch (error) {
        console.error('Error parsing lock data:', error);
        return <LockCard lockData={{ ...baseLockData, error: error as Error }} owner={owner} />;
    }
};

const AllLocksPanel: React.FC = () => {
    const { allLockIds, owner, feeReceiver, tokenContract } = useLPLocker();
    const { locksRefreshKey } = useAppContext();

    // Force refresh when locksRefreshKey changes
    React.useEffect(() => {
        if (locksRefreshKey > 0) {
            allLockIds.refetch?.();
        }
    }, [locksRefreshKey, allLockIds]);

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

    const lockIds = (allLockIds.data as string[]) || [];

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-salmon">All Locks</h2>
                <span className="text-sm text-gray-3 bg-[#23232a] px-3 py-1 rounded-full">
                    {lockIds.length || 0} active locks
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
                            Click on any lock to view details and manage withdrawals
                        </div>
                        {lockIds.map((lockId, index) => {
                            return (
                                <LockCardWithData
                                    key={`${lockId}-${locksRefreshKey}`}
                                    lockId={lockId}
                                    owner={owner}
                                />
                            );
                        })}
                    </>
                )}
            </div>
        </div>
    );
};

export default AllLocksPanel; 