import React, { useState } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useLPLocker } from "../hooks/useLPLocker";
import LPLockerABI from "../abi/LPLocker.json";
import ErrorDisplay from "./ErrorDisplay";

const EmergencyRecoveryPanel: React.FC = () => {
    const { address } = useAccount();
    const { contractAddress, owner } = useLPLocker();
    const [tokenAddress, setTokenAddress] = useState("");
    const [amount, setAmount] = useState("");
    const [isRecovering, setIsRecovering] = useState(false);

    const { writeContract, data: hash, error, isPending } = useWriteContract();

    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash,
    });

    const isOwner = address && owner.data &&
        address.toLowerCase() === (owner.data as string).toLowerCase();

    const handleRecover = async () => {
        if (!tokenAddress || !amount || !isOwner) return;

        try {
            setIsRecovering(true);
            await writeContract({
                address: contractAddress,
                abi: LPLockerABI,
                functionName: "recoverToken",
                args: [tokenAddress as `0x${string}`, BigInt(amount)],
            });
        } catch (err) {
            console.error("Recovery failed:", err);
        } finally {
            setIsRecovering(false);
        }
    };

    const reset = () => {
        setTokenAddress("");
        setAmount("");
    };

    if (!isOwner) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
                <h2 className="text-xl font-semibold mb-4 text-salmon">Emergency Recovery</h2>
                <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4">
                    <div className="flex items-center gap-2 text-yellow-400">
                        <span>⚠️</span>
                        <span className="font-medium">Access Restricted</span>
                    </div>
                    <p className="text-sm text-gray-3 mt-2">
                        Only the contract owner can use emergency recovery features.
                    </p>
                </div>
            </div>
        );
    }

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <div className="flex items-center gap-2 mb-4">
                <h2 className="text-xl font-semibold text-salmon">Emergency Recovery</h2>
                <span className="text-xs bg-red-500/20 text-red-400 px-2 py-1 rounded">
                    DANGER ZONE
                </span>
            </div>

            <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4 mb-6">
                <div className="flex items-start gap-2">
                    <span className="text-red-400 text-lg">⚠️</span>
                    <div>
                        <div className="font-medium text-red-400 mb-1">Use with extreme caution</div>
                        <div className="text-sm text-gray-3">
                            This function recovers accidentally sent tokens. It CANNOT recover the main LP token.
                            Double-check the token address before proceeding.
                        </div>
                    </div>
                </div>
            </div>

            {error && (
                <div className="mb-4">
                    <ErrorDisplay
                        error={error as Error & { code?: string }}
                        title="Recovery failed"
                        onRetry={() => { }}
                    />
                </div>
            )}

            {isSuccess && (
                <div className="mb-4 bg-green-500/10 border border-green-500/20 rounded-lg p-4">
                    <div className="flex items-center gap-2 text-green-400">
                        <span>✅</span>
                        <span className="font-medium">Recovery successful</span>
                    </div>
                    <p className="text-sm text-gray-3 mt-1">
                        Tokens have been recovered to the owner address.
                    </p>
                </div>
            )}

            <div className="space-y-4">
                <div>
                    <label className="block text-sm font-medium text-gray-3 mb-2">
                        Token Address to Recover
                    </label>
                    <input
                        type="text"
                        value={tokenAddress}
                        onChange={(e) => setTokenAddress(e.target.value)}
                        placeholder="0x..."
                        className="w-full px-4 py-3 bg-[#23232a] border border-[#3a3a3f] rounded-lg text-gray-1 placeholder-gray-4 focus:outline-none focus:border-salmon transition-colors font-mono"
                        disabled={isPending || isConfirming}
                    />
                    <p className="text-xs text-gray-4 mt-1">
                        Enter the contract address of the token you want to recover
                    </p>
                </div>

                <div>
                    <label className="block text-sm font-medium text-gray-3 mb-2">
                        Amount (in smallest token unit)
                    </label>
                    <input
                        type="text"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        placeholder="1000000000000000000"
                        className="w-full px-4 py-3 bg-[#23232a] border border-[#3a3a3f] rounded-lg text-gray-1 placeholder-gray-4 focus:outline-none focus:border-salmon transition-colors font-mono"
                        disabled={isPending || isConfirming}
                    />
                    <p className="text-xs text-gray-4 mt-1">
                        For tokens with 18 decimals, 1 token = 1000000000000000000 units
                    </p>
                </div>

                <div className="flex gap-3">
                    <button
                        onClick={handleRecover}
                        disabled={!tokenAddress || !amount || isPending || isConfirming || isRecovering}
                        className="flex-1 bg-red-600 hover:bg-red-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-medium py-3 px-4 rounded-lg transition-colors flex items-center justify-center gap-2"
                    >
                        {(isPending || isConfirming || isRecovering) ? (
                            <>
                                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                {isPending || isRecovering ? "Confirming..." : "Processing..."}
                            </>
                        ) : (
                            <>
                                <span>🚨</span>
                                Recover Tokens
                            </>
                        )}
                    </button>

                    <button
                        onClick={reset}
                        disabled={isPending || isConfirming}
                        className="px-4 py-3 bg-[#3a3a3f] hover:bg-[#4a4a4f] disabled:opacity-50 text-gray-3 rounded-lg transition-colors"
                    >
                        Clear
                    </button>
                </div>

                <div className="text-xs text-gray-4 space-y-1">
                    <div>• This function is for emergency recovery only</div>
                    <div>• Cannot recover the main LP token that is supposed to be locked</div>
                    <div>• Recovered tokens will be sent to the contract owner</div>
                    <div>• Transaction must be confirmed by the owner wallet</div>
                </div>
            </div>
        </div>
    );
};

export default EmergencyRecoveryPanel; 