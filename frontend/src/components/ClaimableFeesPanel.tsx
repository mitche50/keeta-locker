import React, { useState } from "react";
import { formatEther } from "viem";
import { useAccount, useChainId, useWriteContract, useWaitForTransactionReceipt, useReadContract } from "wagmi";
import { useLPLocker } from "../hooks/useLPLocker";
import { useAppContext } from "../context/AppContext";
import LPLockerABI from "../abi/LPLocker.json";
import { getContractAddress } from "../config";
import toast from "react-hot-toast";
import ErrorDisplay from "./ErrorDisplay";

function shorten(addr: string) {
    return addr ? addr.slice(0, 6) + "..." + addr.slice(-4) : "-";
}

const ClaimableFeesPanel: React.FC = () => {
    const { address, isConnected } = useAccount();
    const chainId = useChainId();
    const { allLockIds, owner } = useLPLocker();
    const { refreshFees, feesRefreshKey, refreshBalances } = useAppContext();
    const [selectedLockId, setSelectedLockId] = useState<string>("");
    const [isUpdating, setIsUpdating] = useState(false);
    const [isClaiming, setIsClaiming] = useState(false);

    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;
    const {
        writeContract,
        data: hash,
        error,
        isPending,
    } = useWriteContract();

    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

    const lockIds = (allLockIds.data as string[]) || [];
    const firstLockId = lockIds[0] || "";
    const isOwner = address && owner?.data && address.toLowerCase() === (owner.data as string).toLowerCase();

    // Auto-select first lock if none selected
    React.useEffect(() => {
        if (lockIds.length > 0 && !selectedLockId) {
            setSelectedLockId(lockIds[0]);
        }
    }, [lockIds, selectedLockId]);

    // Get claimable fees for selected lock - refresh based on feesRefreshKey
    const { data: claimableFeesData, refetch: refetchClaimableFees, isLoading: claimableFeesLoading, isError: claimableFeesError, error: claimableFeesErrorMsg } = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getClaimableFees",
        args: [selectedLockId],
        query: {
            enabled: !!selectedLockId && !!lpLockerAddress,
            refetchInterval: 3000,
        }
    });

    // Get total accumulated fees for selected lock - refresh based on feesRefreshKey
    const { data: totalFeesData, refetch: refetchTotalFees, isLoading: totalFeesLoading, isError: totalFeesError, error: totalFeesErrorMsg } = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getTotalAccumulatedFees",
        args: [selectedLockId],
        query: {
            enabled: !!selectedLockId && !!lpLockerAddress,
            refetchInterval: 3000,
        }
    });

    // Force refresh when feesRefreshKey changes
    React.useEffect(() => {
        if (feesRefreshKey > 0 && selectedLockId) {
            refetchClaimableFees();
            refetchTotalFees();
        }
    }, [feesRefreshKey, selectedLockId, refetchClaimableFees, refetchTotalFees]);

    // Handle transaction success
    React.useEffect(() => {
        if (isSuccess) {
            toast.dismiss();
            if (isUpdating) {
                toast.success("Fees updated successfully!");
            } else if (isClaiming) {
                toast.success("Fees claimed successfully!");
                refreshBalances(); // Refresh balances when fees are claimed
            }
            // Always refresh fees after any operation
            refreshFees();
            setIsUpdating(false);
            setIsClaiming(false);
        }
    }, [isSuccess, isUpdating, isClaiming, refreshFees, refreshBalances]);

    const handleUpdateFees = async () => {
        if (!selectedLockId) return;
        try {
            setIsUpdating(true);
            toast.loading("Updating fees...", { id: "update" });
            await writeContract({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "updateClaimableFees",
                args: [selectedLockId],
            });
        } catch (error) {
            console.error("Update fees error:", error);
            toast.dismiss("update");
            toast.error("Failed to update fees");
            setIsUpdating(false);
        }
    };

    const handleClaimFees = async () => {
        if (!selectedLockId) return;
        try {
            setIsClaiming(true);
            toast.loading("Claiming fees...", { id: "claim" });
            await writeContract({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "claimLPFees",
                args: [selectedLockId],
            });
        } catch (error) {
            console.error("Claim fees error:", error);
            toast.dismiss("claim");
            toast.error("Failed to claim fees");
            setIsClaiming(false);
        }
    };

    const handleRefreshFees = () => {
        if (selectedLockId) {
            refetchClaimableFees();
            refetchTotalFees();
            toast.success("Refreshed fee data!");
        }
    };

    if (allLockIds.isLoading || claimableFeesLoading || totalFeesLoading) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6 animate-pulse">
                <div className="h-6 w-32 bg-[#3a3a3f] rounded mb-4" />
                <div className="space-y-3">
                    <div className="h-4 w-full bg-[#3a3a3f] rounded" />
                    <div className="h-4 w-3/4 bg-[#3a3a3f] rounded" />
                </div>
            </div>
        );
    }

    if (allLockIds.isError) {
        return (
            <ErrorDisplay
                error={allLockIds.error as Error & { code?: string }}
                title="Error loading locks"
                onRetry={() => allLockIds.refetch()}
            />
        );
    }

    const feesData = claimableFeesData as [string, bigint, string, bigint] | undefined;
    const [token0, amount0, token1, amount1] = feesData || ["", BigInt(0), "", BigInt(0)];
    const hasClaimableFees = amount0 > 0 || amount1 > 0;

    const totalFees = totalFeesData as [string, bigint, string, bigint] | undefined;
    const [totalToken0, totalAmount0, totalToken1, totalAmount1] = totalFees || ["", BigInt(0), "", BigInt(0)];
    const hasTotalFees = totalAmount0 > 0 || totalAmount1 > 0;

    const totalLocks = lockIds.length;

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-salmon">Claimable Fees</h2>
                <div className="flex gap-2">
                    <button
                        onClick={handleRefreshFees}
                        className="text-xs text-gray-3 hover:text-salmon transition-colors px-2 py-1 bg-[#23232a] rounded"
                    >
                        🔄 Refresh
                    </button>
                </div>
            </div>

            {totalLocks === 0 ? (
                <div className="text-center py-8 text-gray-4">
                    <div className="text-4xl mb-2">💰</div>
                    <div className="text-sm">No locks available</div>
                    <div className="text-xs text-gray-5 mt-1">
                        Create a lock to start earning fees
                    </div>
                </div>
            ) : (
                <div className="space-y-4">
                    {/* Lock Selection */}
                    {totalLocks > 1 && (
                        <div>
                            <label className="block text-xs text-gray-3 mb-2">Select Lock to View Fees</label>
                            <select
                                value={selectedLockId}
                                onChange={(e) => setSelectedLockId(e.target.value)}
                                className="w-full bg-[#23232a] border border-[#3a3a3f] rounded px-3 py-2 text-sm text-gray-1"
                            >
                                {lockIds.map((lockId, index) => (
                                    <option key={lockId} value={lockId}>
                                        Lock #{index + 1} - {shorten(lockId)}
                                    </option>
                                ))}
                            </select>
                        </div>
                    )}

                    {/* Current Lock Info */}
                    <div className="bg-[#23232a] rounded-lg p-4">
                        <div className="text-xs text-gray-4 mb-2">
                            {totalLocks === 1 ? "Lock ID" : "Selected Lock"}
                        </div>
                        <div className="font-mono text-sm text-gray-1 mb-3">
                            {shorten(selectedLockId)}
                        </div>

                        {/* Fee Details */}
                        {claimableFeesError ? (
                            <div className="text-red-400 text-sm">
                                Error loading fees: {claimableFeesErrorMsg?.message || "Unknown error"}
                            </div>
                        ) : (
                            <div className="space-y-4">
                                {/* Claimable Fees */}
                                <div>
                                    <div className="text-xs text-gray-4 mb-2">💰 Claimable Now</div>
                                    <div className="grid grid-cols-2 gap-3">
                                        <div className="bg-[#1a1a1f] rounded p-3">
                                            <div className="text-xs text-gray-4 mb-1">Token 0</div>
                                            <div className="font-mono text-xs text-gray-3 mb-2">
                                                {token0 ? shorten(token0) : "Loading..."}
                                            </div>
                                            <div className={`font-mono text-sm ${amount0 > 0 ? 'text-green-400' : 'text-gray-4'}`}>
                                                {amount0 > 0 ? formatEther(amount0) : "0.0"}
                                            </div>
                                        </div>
                                        <div className="bg-[#1a1a1f] rounded p-3">
                                            <div className="text-xs text-gray-4 mb-1">Token 1</div>
                                            <div className="font-mono text-xs text-gray-3 mb-2">
                                                {token1 ? shorten(token1) : "Loading..."}
                                            </div>
                                            <div className={`font-mono text-sm ${amount1 > 0 ? 'text-green-400' : 'text-gray-4'}`}>
                                                {amount1 > 0 ? formatEther(amount1) : "0.0"}
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                {/* Total Accumulated Fees */}
                                <div>
                                    <div className="text-xs text-gray-4 mb-2">📊 Total Accumulated (Index-based)</div>
                                    {totalFeesError ? (
                                        <div className="text-red-400 text-sm">
                                            Error loading total fees: {totalFeesErrorMsg?.message || "Unknown error"}
                                        </div>
                                    ) : (
                                        <div className="grid grid-cols-2 gap-3">
                                            <div className="bg-[#1a1a1f] rounded p-3 border border-blue-500/20">
                                                <div className="text-xs text-gray-4 mb-1">Token 0</div>
                                                <div className="font-mono text-xs text-gray-3 mb-2">
                                                    {totalToken0 ? shorten(totalToken0) : "Loading..."}
                                                </div>
                                                <div className={`font-mono text-sm ${totalAmount0 > 0 ? 'text-blue-400' : 'text-gray-4'}`}>
                                                    {totalAmount0 > 0 ? formatEther(totalAmount0) : "0.0"}
                                                </div>
                                            </div>
                                            <div className="bg-[#1a1a1f] rounded p-3 border border-blue-500/20">
                                                <div className="text-xs text-gray-4 mb-1">Token 1</div>
                                                <div className="font-mono text-xs text-gray-3 mb-2">
                                                    {totalToken1 ? shorten(totalToken1) : "Loading..."}
                                                </div>
                                                <div className={`font-mono text-sm ${totalAmount1 > 0 ? 'text-blue-400' : 'text-gray-4'}`}>
                                                    {totalAmount1 > 0 ? formatEther(totalAmount1) : "0.0"}
                                                </div>
                                            </div>
                                        </div>
                                    )}
                                </div>

                                {/* Action Buttons */}
                                {isOwner ? (
                                    <div className="space-y-2">
                                        <button
                                            onClick={handleUpdateFees}
                                            disabled={isPending || isConfirming}
                                            className={`w-full py-2 px-4 rounded text-sm font-medium transition-colors ${!isPending && !isConfirming
                                                ? "bg-blue-500/10 hover:bg-blue-500/20 border border-blue-500/20 text-blue-400"
                                                : "bg-gray-500/10 border border-gray-500/20 text-gray-500 cursor-not-allowed"
                                                }`}
                                        >
                                            {isPending || isConfirming
                                                ? "Processing..."
                                                : "🔄 Update Claimable Fees"}
                                        </button>
                                        <button
                                            onClick={handleClaimFees}
                                            disabled={!hasClaimableFees || isPending || isConfirming}
                                            className={`w-full py-2 px-4 rounded text-sm font-medium transition-colors ${hasClaimableFees && !isPending && !isConfirming
                                                ? "bg-green-500/10 hover:bg-green-500/20 border border-green-500/20 text-green-400"
                                                : "bg-gray-500/10 border border-gray-500/20 text-gray-500 cursor-not-allowed"
                                                }`}
                                        >
                                            {isPending || isConfirming
                                                ? "Processing..."
                                                : hasClaimableFees
                                                    ? "💰 Claim Fees"
                                                    : "No Fees Available"}
                                        </button>
                                    </div>
                                ) : (
                                    <div className="text-center py-2 text-gray-4 text-sm">
                                        Only the contract owner can claim fees
                                    </div>
                                )}

                                {/* Info */}
                                <div className="bg-blue-500/10 border border-blue-500/20 rounded p-3">
                                    <div className="text-xs text-blue-400 mb-1">ℹ️ About LP Fees</div>
                                    <div className="text-xs text-blue-300">
                                        Aerodrome LP tokens earn trading fees from the pool. Fees accumulate over time and can be claimed by the contract owner.
                                        {totalLocks > 1 && " Use the dropdown above to view fees for different locks."}
                                        <br /><br />
                                        <strong>🔄 Update Claimable Fees:</strong> Syncs your fee tracking with the pool to show the latest claimable amounts.
                                        <br />
                                        <strong>💰 Claimable Now:</strong> Fees that can be claimed immediately from the pool.
                                        <br />
                                        <strong>📊 Total Accumulated:</strong> Index-based calculation showing total fees accumulated since last update (including claimable).
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
};

export default ClaimableFeesPanel; 