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

const ClaimableFeesPanel: React.FC = () => {
    const { address, isConnected } = useAccount();
    const chainId = useChainId();
    const { claimableFees, lockInfo } = useLPLocker();

    const [isClaiming, setIsClaiming] = useState(false);
    const [claimHash, setClaimHash] = useState<`0x${string}` | undefined>();

    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;

    // Write contract hook
    const { writeContract: claimFees } = useWriteContract();

    // Wait for claim transaction
    const { isLoading: isClaimLoading, isSuccess: isClaimSuccess } = useWaitForTransactionReceipt({
        hash: claimHash,
    });

    // Check if user is owner
    const lockData = Array.isArray(lockInfo.data) ? lockInfo.data : [];
    const [owner] = lockData;
    const isOwner = address && owner && address.toLowerCase() === owner.toLowerCase();

    const handleClaimFees = async () => {
        if (!isOwner) {
            toast.error("Only the owner can claim fees");
            return;
        }

        try {
            setIsClaiming(true);
            toast.loading("Claiming fees...", { id: "claim-fees" });

            claimFees({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "claimFees",
                args: [],
            }, {
                onSuccess: (hash) => {
                    setClaimHash(hash);
                    toast.dismiss("claim-fees");
                    toast.success("Claim transaction submitted!");
                },
                onError: (error) => {
                    console.error("Claim fees error:", error);
                    setIsClaiming(false);
                    toast.dismiss("claim-fees");
                    toast.error("Failed to claim fees");
                }
            });
        } catch (error) {
            console.error("Claim fees error:", error);
            setIsClaiming(false);
            toast.dismiss("claim-fees");
            toast.error("Failed to claim fees");
        }
    };

    // Handle transaction success
    React.useEffect(() => {
        if (isClaimSuccess) {
            setIsClaiming(false);
            toast.success("Fees claimed successfully!");
        }
    }, [isClaimSuccess]);

    if (claimableFees.isLoading) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6 animate-pulse">
                <div className="h-6 w-32 bg-[#3a3a3f] rounded mb-4" />
                <div className="space-y-3">
                    {[...Array(2)].map((_, i) => (
                        <div key={i} className="h-4 w-full bg-[#3a3a3f] rounded" />
                    ))}
                </div>
            </div>
        );
    }

    if (claimableFees.isError) {
        return (
            <ErrorDisplay
                error={claimableFees.error as Error & { code?: string }}
                title="Error loading claimable fees"
                onRetry={() => window.location.reload()}
            />
        );
    }

    const data = Array.isArray(claimableFees.data) ? claimableFees.data : [];
    const [token0, amount0, token1, amount1] = data;

    const hasToken0 = token0 && amount0 && amount0.toString() !== "0";
    const hasToken1 = token1 && amount1 && amount1.toString() !== "0";
    const hasAnyFees = hasToken0 || hasToken1;

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <h2 className="text-xl font-semibold mb-6 text-salmon">Claimable Fees</h2>

            {!hasAnyFees ? (
                <div className="flex items-center justify-center py-8 text-gray-3">
                    <div className="text-center">
                        <div className="text-2xl mb-2">💸</div>
                        <div className="font-medium">No fees available</div>
                        <div className="text-sm">Fees will appear here when earned</div>
                    </div>
                </div>
            ) : (
                <div className="space-y-4">
                    {/* Token 0 */}
                    <div className="bg-[#23232a] rounded-lg p-4 border border-[#3a3a3f]">
                        <div className="flex justify-between items-center mb-2">
                            <span className="text-sm font-medium text-gray-3">Token 0</span>
                            <span className={`px-2 py-1 rounded text-xs font-medium ${hasToken0 ? "bg-green/10 text-green" : "bg-gray-4/10 text-gray-3"
                                }`}>
                                {hasToken0 ? "Available" : "None"}
                            </span>
                        </div>
                        <div className="flex justify-between items-center">
                            <span className="text-gray-1 font-mono text-sm" title={token0}>
                                {shorten(token0 || "")}
                            </span>
                            <span className="text-gray-1 font-mono font-bold">
                                {amount0?.toString?.() ?? "0"}
                            </span>
                        </div>
                    </div>

                    {/* Token 1 */}
                    <div className="bg-[#23232a] rounded-lg p-4 border border-[#3a3a3f]">
                        <div className="flex justify-between items-center mb-2">
                            <span className="text-sm font-medium text-gray-3">Token 1</span>
                            <span className={`px-2 py-1 rounded text-xs font-medium ${hasToken1 ? "bg-green/10 text-green" : "bg-gray-4/10 text-gray-3"
                                }`}>
                                {hasToken1 ? "Available" : "None"}
                            </span>
                        </div>
                        <div className="flex justify-between items-center">
                            <span className="text-gray-1 font-mono text-sm" title={token1}>
                                {shorten(token1 || "")}
                            </span>
                            <span className="text-gray-1 font-mono font-bold">
                                {amount1?.toString?.() ?? "0"}
                            </span>
                        </div>
                    </div>

                    {/* Claim Button */}
                    {isConnected && isOwner && (
                        <button
                            onClick={handleClaimFees}
                            disabled={isClaiming || isClaimLoading}
                            className="w-full bg-green/10 hover:bg-green/20 border border-green/20 text-green font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {isClaiming || isClaimLoading ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="w-4 h-4 border-2 border-green/30 border-t-green rounded-full animate-spin" />
                                    Claiming Fees...
                                </span>
                            ) : (
                                "💰 Claim Fees"
                            )}
                        </button>
                    )}

                    {/* Access message for non-owners */}
                    {isConnected && !isOwner && (
                        <div className="bg-blue/10 border border-blue/20 rounded-lg p-3">
                            <div className="text-sm text-blue">
                                🔒 Only the contract owner can claim fees
                            </div>
                        </div>
                    )}
                </div>
            )}
        </div>
    );
};

export default ClaimableFeesPanel; 