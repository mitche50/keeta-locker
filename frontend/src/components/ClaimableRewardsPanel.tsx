import React, { useState } from "react";
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { useLPLocker } from "../hooks/useLPLocker";
import LPLockerABI from "../abi/LPLocker.json";
import { getContractAddress } from "../config";
import { useChainId } from "wagmi";
import toast from "react-hot-toast";
import ErrorDisplay from "./ErrorDisplay";

function shorten(addr: string) {
    return addr ? addr.slice(0, 6) + "..." + addr.slice(-4) : "-";
}

const ClaimableRewardsPanel: React.FC = () => {
    const { address, isConnected } = useAccount();
    const chainId = useChainId();
    const { allClaimableRewards, lockInfo } = useLPLocker();

    const [isClaiming, setIsClaiming] = useState(false);
    const [claimHash, setClaimHash] = useState<`0x${string}` | undefined>();

    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;

    // Write contract hook
    const { writeContract: claimRewards } = useWriteContract();

    // Wait for claim transaction
    const { isLoading: isClaimLoading, isSuccess: isClaimSuccess } = useWaitForTransactionReceipt({
        hash: claimHash,
    });

    // Check if user is owner
    const lockData = Array.isArray(lockInfo.data) ? lockInfo.data : [];
    const [owner] = lockData;
    const isOwner = address && owner && address.toLowerCase() === owner.toLowerCase();

    const handleClaimRewards = async () => {
        if (!isOwner) {
            toast.error("Only the owner can claim rewards");
            return;
        }

        try {
            setIsClaiming(true);
            toast.loading("Claiming rewards...", { id: "claim-rewards" });

            claimRewards({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "claimAllRewards",
                args: [],
            }, {
                onSuccess: (hash) => {
                    setClaimHash(hash);
                    toast.dismiss("claim-rewards");
                    toast.success("Claim transaction submitted!");
                },
                onError: (error) => {
                    console.error("Claim rewards error:", error);
                    setIsClaiming(false);
                    toast.dismiss("claim-rewards");
                    toast.error("Failed to claim rewards");
                }
            });
        } catch (error) {
            console.error("Claim rewards error:", error);
            setIsClaiming(false);
            toast.dismiss("claim-rewards");
            toast.error("Failed to claim rewards");
        }
    };

    // Handle transaction success
    React.useEffect(() => {
        if (isClaimSuccess) {
            setIsClaiming(false);
            toast.success("Rewards claimed successfully!");
        }
    }, [isClaimSuccess]);

    if (allClaimableRewards.isLoading) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6 animate-pulse">
                <div className="h-6 w-40 bg-[#3a3a3f] rounded mb-4" />
                <div className="space-y-3">
                    {[...Array(2)].map((_, i) => (
                        <div key={i} className="h-4 w-full bg-[#3a3a3f] rounded" />
                    ))}
                </div>
            </div>
        );
    }

    if (allClaimableRewards.isError) {
        return (
            <ErrorDisplay
                error={allClaimableRewards.error as Error & { code?: string }}
                title="Error loading claimable rewards"
                onRetry={() => window.location.reload()}
            />
        );
    }

    const data = Array.isArray(allClaimableRewards.data) ? allClaimableRewards.data : [[], [], []];
    const [sources = [], tokens = [], amounts = []] = data;

    // Check if there are any claimable rewards
    const hasAnyRewards = sources.some((_: string, i: number) => {
        const sourceAmounts = amounts[i] || [];
        return sourceAmounts.some((amount: bigint | string | number) =>
            amount && amount.toString() !== "0"
        );
    });

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <h2 className="text-xl font-semibold mb-6 text-salmon">Claimable Rewards</h2>

            {sources.length === 0 ? (
                <div className="flex items-center justify-center py-8 text-gray-3">
                    <div className="text-center">
                        <div className="text-2xl mb-2">🎁</div>
                        <div className="font-medium">No reward sources</div>
                        <div className="text-sm">Reward sources will appear here when registered</div>
                    </div>
                </div>
            ) : (
                <div className="space-y-4">
                    {sources.map((src: string, i: number) => {
                        const sourceTokens = tokens[i] || [];
                        const sourceAmounts = amounts[i] || [];
                        const hasRewards = sourceAmounts.some((amount: bigint | string | number) =>
                            amount && amount.toString() !== "0"
                        );

                        return (
                            <div key={src} className="bg-[#23232a] rounded-lg border border-[#3a3a3f] p-4">
                                <div className="flex justify-between items-center mb-3">
                                    <div className="flex flex-col">
                                        <span className="text-sm font-medium text-gray-3">Reward Source</span>
                                        <span className="text-gray-1 font-mono text-sm" title={src}>
                                            {shorten(src)}
                                        </span>
                                    </div>
                                    <span className={`px-2 py-1 rounded text-xs font-medium ${hasRewards ? "bg-blue/10 text-blue" : "bg-gray-4/10 text-gray-3"
                                        }`}>
                                        {hasRewards ? "Has Rewards" : "No Rewards"}
                                    </span>
                                </div>

                                {sourceTokens.length === 0 ? (
                                    <div className="text-gray-3 text-sm italic">No tokens configured</div>
                                ) : (
                                    <div className="space-y-2">
                                        {sourceTokens.map((token: string, j: number) => {
                                            const amount = sourceAmounts[j];
                                            const hasAmount = amount && amount.toString() !== "0";

                                            return (
                                                <div key={token} className="flex justify-between items-center py-2 px-3 bg-[#1a1a1f] rounded border border-[#2a2a2f]">
                                                    <span className="text-gray-1 font-mono text-sm" title={token}>
                                                        {shorten(token)}
                                                    </span>
                                                    <div className="flex items-center gap-2">
                                                        <span className={`font-mono text-sm ${hasAmount ? "text-gray-1" : "text-gray-3"}`}>
                                                            {amount?.toString?.() ?? "0"}
                                                        </span>
                                                        {hasAmount && (
                                                            <span className="w-2 h-2 bg-green rounded-full"></span>
                                                        )}
                                                    </div>
                                                </div>
                                            );
                                        })}
                                    </div>
                                )}
                            </div>
                        );
                    })}

                    {/* Claim Button */}
                    {isConnected && isOwner && hasAnyRewards && (
                        <button
                            onClick={handleClaimRewards}
                            disabled={isClaiming || isClaimLoading}
                            className="w-full bg-green/10 hover:bg-green/20 border border-green/20 text-green font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {isClaiming || isClaimLoading ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="w-4 h-4 border-2 border-green/30 border-t-green rounded-full animate-spin" />
                                    Claiming Rewards...
                                </span>
                            ) : (
                                "🎁 Claim All Rewards"
                            )}
                        </button>
                    )}

                    {/* Access message for non-owners */}
                    {isConnected && !isOwner && hasAnyRewards && (
                        <div className="bg-blue/10 border border-blue/20 rounded-lg p-3">
                            <div className="text-sm text-blue">
                                🔒 Only the contract owner can claim rewards
                            </div>
                        </div>
                    )}

                    {/* No rewards message */}
                    {isConnected && isOwner && !hasAnyRewards && sources.length > 0 && (
                        <div className="bg-gray-4/10 border border-gray-4/20 rounded-lg p-3">
                            <div className="text-sm text-gray-3">
                                💤 No rewards available to claim at this time
                            </div>
                        </div>
                    )}
                </div>
            )}
        </div>
    );
};

export default ClaimableRewardsPanel; 