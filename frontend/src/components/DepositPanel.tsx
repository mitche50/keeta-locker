import React, { useState } from "react";
import { useWriteContract, useWaitForTransactionReceipt, useAccount, useReadContract } from "wagmi";
import { parseEther, formatEther } from "viem";
import { useLPLocker } from "../hooks/useLPLocker";
import LPLockerABI from "../abi/LPLocker.json";
import ERC20ABI from "../abi/ERC20.json";
import ErrorDisplay from "./ErrorDisplay";

const DepositPanel: React.FC = () => {
    const { address, isConnected } = useAccount();
    const { tokenContract, contractAddress } = useLPLocker();

    const [depositAmount, setDepositAmount] = useState("");
    const [isApproving, setIsApproving] = useState(false);
    const [isDepositing, setIsDepositing] = useState(false);

    const { writeContract, data: hash, error, isPending } = useWriteContract();

    // Get LP token address from contract
    const lpTokenAddress = tokenContract.data as `0x${string}` | undefined;

    // Check user's LP token balance
    const { data: userLPBalance } = useReadContract({
        address: lpTokenAddress,
        abi: ERC20ABI,
        functionName: "balanceOf",
        args: [address],
        query: {
            enabled: !!lpTokenAddress && !!address,
        }
    });

    // Check allowance
    const { data: allowance, refetch: refetchAllowance } = useReadContract({
        address: lpTokenAddress,
        abi: ERC20ABI,
        functionName: "allowance",
        args: [address, contractAddress],
        query: {
            enabled: !!lpTokenAddress && !!address,
        }
    });

    // Wait for transaction
    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash,
    });

    const handleApprove = async () => {
        if (!depositAmount || !lpTokenAddress) return;

        try {
            setIsApproving(true);
            const amount = parseEther(depositAmount);
            await writeContract({
                address: lpTokenAddress,
                abi: ERC20ABI,
                functionName: "approve",
                args: [contractAddress, amount],
            });
        } catch (error) {
            console.error("Approve error:", error);
        } finally {
            setIsApproving(false);
        }
    };

    const handleDeposit = async () => {
        if (!depositAmount) return;

        try {
            setIsDepositing(true);
            const amount = parseEther(depositAmount);
            await writeContract({
                address: contractAddress,
                abi: LPLockerABI,
                functionName: "lockLiquidity",
                args: [amount],
            });
        } catch (error) {
            console.error("Deposit error:", error);
        } finally {
            setIsDepositing(false);
        }
    };

    // Handle transaction success
    React.useEffect(() => {
        if (isSuccess && !isApproving) {
            refetchAllowance();
            setDepositAmount("");
        }
    }, [isSuccess, isApproving, refetchAllowance]);

    const handleMaxClick = () => {
        if (userLPBalance) {
            setDepositAmount(formatEther(userLPBalance as bigint));
        }
    };

    const isValidAmount = () => {
        if (!depositAmount || !userLPBalance) return false;
        try {
            const amount = parseEther(depositAmount);
            return amount > 0n && amount <= (userLPBalance as bigint);
        } catch {
            return false;
        }
    };

    const needsApproval = () => {
        if (!depositAmount || !allowance) return true;
        try {
            const amount = parseEther(depositAmount);
            return amount > (allowance as bigint);
        } catch {
            return true;
        }
    };

    if (!isConnected) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
                <h2 className="text-xl font-semibold mb-6 text-salmon">Lock LP Tokens</h2>
                <div className="flex items-center justify-center py-8 text-gray-3">
                    <div className="text-center">
                        <div className="text-2xl mb-2">🔌</div>
                        <div className="font-medium">Connect your wallet</div>
                        <div className="text-sm">Connect your wallet to lock LP tokens</div>
                    </div>
                </div>
            </div>
        );
    }

    if (tokenContract.isLoading) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6 animate-pulse">
                <div className="h-6 w-40 bg-[#3a3a3f] rounded mb-6" />
                <div className="space-y-4">
                    <div className="h-12 bg-[#3a3a3f] rounded" />
                    <div className="h-10 bg-[#3a3a3f] rounded" />
                </div>
            </div>
        );
    }

    if (tokenContract.isError) {
        return (
            <ErrorDisplay
                error={tokenContract.error as Error & { code?: string }}
                title="Error loading contract info"
                onRetry={() => window.location.reload()}
            />
        );
    }

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <h2 className="text-xl font-semibold mb-6 text-salmon">Lock LP Tokens</h2>

            {error && (
                <div className="mb-4">
                    <ErrorDisplay
                        error={error as Error & { code?: string }}
                        title="Transaction failed"
                        onRetry={() => { }}
                    />
                </div>
            )}

            {isSuccess && (
                <div className="mb-4 bg-green-500/10 border border-green-500/20 rounded-lg p-4">
                    <div className="flex items-center gap-2 text-green-400">
                        <span>✅</span>
                        <span className="font-medium">LP tokens locked successfully!</span>
                    </div>
                    <p className="text-sm text-gray-3 mt-1">
                        A new lock has been created. Check the All Locks panel to view it.
                    </p>
                </div>
            )}

            <div className="space-y-4">
                <div>
                    <label className="block text-sm font-medium text-gray-3 mb-2">
                        Amount to Lock
                    </label>
                    <div className="relative">
                        <input
                            type="text"
                            value={depositAmount}
                            onChange={(e) => setDepositAmount(e.target.value)}
                            placeholder="0.0"
                            className="w-full px-4 py-3 pr-16 bg-[#23232a] border border-[#3a3a3f] rounded-lg text-gray-1 placeholder-gray-4 focus:outline-none focus:border-salmon transition-colors"
                            disabled={isPending || isConfirming}
                        />
                        <button
                            onClick={handleMaxClick}
                            className="absolute right-3 top-1/2 transform -translate-y-1/2 text-xs text-salmon hover:text-salmon/80 transition-colors px-2 py-1 bg-salmon/10 rounded"
                            disabled={isPending || isConfirming}
                        >
                            MAX
                        </button>
                    </div>
                    <div className="flex justify-between text-xs text-gray-4 mt-1">
                        <span>Balance: {userLPBalance ? formatEther(userLPBalance as bigint) : "0"}</span>
                    </div>
                </div>

                <div className="space-y-3">
                    {needsApproval() ? (
                        <button
                            onClick={handleApprove}
                            disabled={!isValidAmount() || isPending || isConfirming || isApproving}
                            className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-medium py-3 px-4 rounded-lg transition-colors flex items-center justify-center gap-2"
                        >
                            {(isPending || isApproving) ? (
                                <>
                                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                    Approving...
                                </>
                            ) : (
                                <>
                                    <span>✓</span>
                                    Approve LP Tokens
                                </>
                            )}
                        </button>
                    ) : (
                        <button
                            onClick={handleDeposit}
                            disabled={!isValidAmount() || isPending || isConfirming || isDepositing}
                            className="w-full bg-salmon hover:bg-salmon/90 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-medium py-3 px-4 rounded-lg transition-colors flex items-center justify-center gap-2"
                        >
                            {(isPending || isConfirming || isDepositing) ? (
                                <>
                                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                    {isPending || isDepositing ? "Locking..." : "Processing..."}
                                </>
                            ) : (
                                <>
                                    <span>🔒</span>
                                    Lock LP Tokens
                                </>
                            )}
                        </button>
                    )}
                </div>

                <div className="text-xs text-gray-4 space-y-1">
                    <div>• Creates a new lock with the specified amount</div>
                    <div>• 30-day withdrawal timelock applies after triggering withdrawal</div>
                    <div>• You can create multiple locks with different amounts</div>
                    <div>• Each lock gets a unique ID for management</div>
                </div>
            </div>
        </div>
    );
};

export default DepositPanel; 