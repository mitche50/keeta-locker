import React, { useState } from "react";
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { parseEther, formatEther } from "viem";
import { useLPLocker } from "../hooks/useLPLocker";
import LPLockerABI from "../abi/LPLocker.json";
import { getContractAddress } from "../config";
import { useChainId } from "wagmi";
import toast from "react-hot-toast";
import ErrorDisplay from "./ErrorDisplay";

const WithdrawalPanel: React.FC = () => {
    const { address, isConnected } = useAccount();
    const chainId = useChainId();
    const { lockInfo } = useLPLocker();

    const [withdrawAmount, setWithdrawAmount] = useState("");
    const [isTriggeringWithdrawal, setIsTriggeringWithdrawal] = useState(false);
    const [isCancellingWithdrawal, setIsCancellingWithdrawal] = useState(false);
    const [isWithdrawing, setIsWithdrawing] = useState(false);
    const [triggerHash, setTriggerHash] = useState<`0x${string}` | undefined>();
    const [cancelHash, setCancelHash] = useState<`0x${string}` | undefined>();
    const [withdrawHash, setWithdrawHash] = useState<`0x${string}` | undefined>();

    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;

    // Write contract hooks
    const { writeContract: triggerWithdrawal } = useWriteContract();
    const { writeContract: cancelWithdrawal } = useWriteContract();
    const { writeContract: withdrawLP } = useWriteContract();

    // Wait for transactions
    const { isLoading: isTriggerLoading, isSuccess: isTriggerSuccess } = useWaitForTransactionReceipt({
        hash: triggerHash,
    });

    const { isLoading: isCancelLoading, isSuccess: isCancelSuccess } = useWaitForTransactionReceipt({
        hash: cancelHash,
    });

    const { isLoading: isWithdrawLoading, isSuccess: isWithdrawSuccess } = useWaitForTransactionReceipt({
        hash: withdrawHash,
    });

    // Extract lock info data
    const lockData = Array.isArray(lockInfo.data) ? lockInfo.data : [];
    const [owner, , , lockedAmount, lockUpEndTime, isLiquidityLocked, isWithdrawalTriggered] = lockData;

    const isOwner = address && owner && address.toLowerCase() === owner.toLowerCase();
    const currentTime = Math.floor(Date.now() / 1000);
    const unlockTime = lockUpEndTime ? Number(lockUpEndTime) : 0;
    const canWithdraw = unlockTime > 0 && currentTime >= unlockTime;

    const handleTriggerWithdrawal = async () => {
        if (!isOwner) {
            toast.error("Only the owner can trigger withdrawal");
            return;
        }

        try {
            setIsTriggeringWithdrawal(true);
            toast.loading("Triggering withdrawal...", { id: "trigger" });

            triggerWithdrawal({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "triggerWithdrawal",
                args: [],
            }, {
                onSuccess: (hash) => {
                    setTriggerHash(hash);
                    toast.dismiss("trigger");
                    toast.success("Withdrawal triggered successfully!");
                },
                onError: (error) => {
                    console.error("Trigger withdrawal error:", error);
                    setIsTriggeringWithdrawal(false);
                    toast.dismiss("trigger");
                    toast.error("Failed to trigger withdrawal");
                }
            });
        } catch (error) {
            console.error("Trigger withdrawal error:", error);
            setIsTriggeringWithdrawal(false);
            toast.dismiss("trigger");
            toast.error("Failed to trigger withdrawal");
        }
    };

    const handleCancelWithdrawal = async () => {
        if (!isOwner) {
            toast.error("Only the owner can cancel withdrawal");
            return;
        }

        try {
            setIsCancellingWithdrawal(true);
            toast.loading("Cancelling withdrawal...", { id: "cancel" });

            cancelWithdrawal({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "cancelWithdrawal",
                args: [],
            }, {
                onSuccess: (hash) => {
                    setCancelHash(hash);
                    toast.dismiss("cancel");
                    toast.success("Withdrawal cancelled successfully!");
                },
                onError: (error) => {
                    console.error("Cancel withdrawal error:", error);
                    setIsCancellingWithdrawal(false);
                    toast.dismiss("cancel");
                    toast.error("Failed to cancel withdrawal");
                }
            });
        } catch (error) {
            console.error("Cancel withdrawal error:", error);
            setIsCancellingWithdrawal(false);
            toast.dismiss("cancel");
            toast.error("Failed to cancel withdrawal");
        }
    };

    const handleWithdrawLP = async () => {
        if (!withdrawAmount || !isOwner) {
            toast.error("Please enter a valid amount");
            return;
        }

        try {
            setIsWithdrawing(true);
            toast.loading("Withdrawing LP tokens...", { id: "withdraw" });

            const amount = parseEther(withdrawAmount);
            withdrawLP({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "withdrawLP",
                args: [amount],
            }, {
                onSuccess: (hash) => {
                    setWithdrawHash(hash);
                    toast.dismiss("withdraw");
                    toast.success("LP tokens withdrawn successfully!");
                    setWithdrawAmount("");
                },
                onError: (error) => {
                    console.error("Withdraw LP error:", error);
                    setIsWithdrawing(false);
                    toast.dismiss("withdraw");
                    toast.error("Failed to withdraw LP tokens");
                }
            });
        } catch (error) {
            console.error("Withdraw LP error:", error);
            setIsWithdrawing(false);
            toast.dismiss("withdraw");
            toast.error("Failed to withdraw LP tokens");
        }
    };

    const handleMaxClick = () => {
        if (lockedAmount) {
            setWithdrawAmount(formatEther(lockedAmount as bigint));
        }
    };

    const isValidAmount = () => {
        if (!withdrawAmount || !lockedAmount) return false;
        try {
            const amount = parseEther(withdrawAmount);
            return amount > 0n && amount <= (lockedAmount as bigint);
        } catch {
            return false;
        }
    };

    // Handle transaction success
    React.useEffect(() => {
        if (isTriggerSuccess) {
            setIsTriggeringWithdrawal(false);
        }
    }, [isTriggerSuccess]);

    React.useEffect(() => {
        if (isCancelSuccess) {
            setIsCancellingWithdrawal(false);
        }
    }, [isCancelSuccess]);

    React.useEffect(() => {
        if (isWithdrawSuccess) {
            setIsWithdrawing(false);
        }
    }, [isWithdrawSuccess]);

    if (!isConnected) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
                <h2 className="text-xl font-semibold mb-6 text-salmon">Withdrawal Management</h2>
                <div className="flex items-center justify-center py-8 text-gray-3">
                    <div className="text-center">
                        <div className="text-2xl mb-2">🔌</div>
                        <div className="font-medium">Connect your wallet</div>
                        <div className="text-sm">Connect your wallet to manage withdrawals</div>
                    </div>
                </div>
            </div>
        );
    }

    if (lockInfo.isLoading) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6 animate-pulse">
                <div className="h-6 w-48 bg-[#3a3a3f] rounded mb-6" />
                <div className="space-y-4">
                    <div className="h-16 bg-[#3a3a3f] rounded" />
                    <div className="h-12 bg-[#3a3a3f] rounded" />
                    <div className="h-10 bg-[#3a3a3f] rounded" />
                </div>
            </div>
        );
    }

    if (lockInfo.isError) {
        return (
            <ErrorDisplay
                error={lockInfo.error as Error & { code?: string }}
                title="Error loading lock info for withdrawals"
                onRetry={() => window.location.reload()}
            />
        );
    }

    if (!isOwner) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
                <h2 className="text-xl font-semibold mb-6 text-salmon">Withdrawal Management</h2>
                <div className="flex items-center justify-center py-8 text-gray-3">
                    <div className="text-center">
                        <div className="text-2xl mb-2">🔒</div>
                        <div className="font-medium">Access Restricted</div>
                        <div className="text-sm">Only the contract owner can manage withdrawals</div>
                    </div>
                </div>
            </div>
        );
    }

    if (!isLiquidityLocked) {
        return (
            <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
                <h2 className="text-xl font-semibold mb-6 text-salmon">Withdrawal Management</h2>
                <div className="flex items-center justify-center py-8 text-gray-3">
                    <div className="text-center">
                        <div className="text-2xl mb-2">📭</div>
                        <div className="font-medium">No liquidity locked</div>
                        <div className="text-sm">Lock some LP tokens first to enable withdrawals</div>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <h2 className="text-xl font-semibold mb-6 text-salmon">Withdrawal Management</h2>

            <div className="space-y-6">
                {/* Status Info */}
                <div className="bg-[#23232a] rounded-lg p-4 border border-[#3a3a3f]">
                    <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                            <span className="text-gray-3">Locked Amount:</span>
                            <div className="text-gray-1 font-mono font-bold">
                                {lockedAmount ? formatEther(lockedAmount as bigint) : "0"} LP
                            </div>
                        </div>
                        <div>
                            <span className="text-gray-3">Withdrawal Status:</span>
                            <div className={`font-medium ${isWithdrawalTriggered ? "text-blue" : "text-gray-3"}`}>
                                {isWithdrawalTriggered ? "🟡 Triggered" : "⚪ Not Triggered"}
                            </div>
                        </div>
                        {unlockTime > 0 && (
                            <>
                                <div>
                                    <span className="text-gray-3">Unlock Time:</span>
                                    <div className="text-gray-1 text-xs">
                                        {new Date(unlockTime * 1000).toLocaleString()}
                                    </div>
                                </div>
                                <div>
                                    <span className="text-gray-3">Can Withdraw:</span>
                                    <div className={`font-medium ${canWithdraw ? "text-green" : "text-error"}`}>
                                        {canWithdraw ? "✅ Yes" : "❌ Not Yet"}
                                    </div>
                                </div>
                            </>
                        )}
                    </div>
                </div>

                {/* Action Buttons */}
                <div className="space-y-4">
                    {/* Trigger Withdrawal */}
                    {!isWithdrawalTriggered && (
                        <button
                            onClick={handleTriggerWithdrawal}
                            disabled={isTriggeringWithdrawal || isTriggerLoading}
                            className="w-full bg-blue/10 hover:bg-blue/20 border border-blue/20 text-blue font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {isTriggeringWithdrawal || isTriggerLoading ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="w-4 h-4 border-2 border-blue/30 border-t-blue rounded-full animate-spin" />
                                    Triggering Withdrawal...
                                </span>
                            ) : (
                                "🚀 Trigger Withdrawal"
                            )}
                        </button>
                    )}

                    {/* Cancel Withdrawal */}
                    {isWithdrawalTriggered && !canWithdraw && (
                        <button
                            onClick={handleCancelWithdrawal}
                            disabled={isCancellingWithdrawal || isCancelLoading}
                            className="w-full bg-error/10 hover:bg-error/20 border border-error/20 text-error font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {isCancellingWithdrawal || isCancelLoading ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="w-4 h-4 border-2 border-error/30 border-t-error rounded-full animate-spin" />
                                    Cancelling...
                                </span>
                            ) : (
                                "❌ Cancel Withdrawal"
                            )}
                        </button>
                    )}

                    {/* Withdraw LP Tokens */}
                    {isWithdrawalTriggered && canWithdraw && (
                        <div className="space-y-3">
                            <div>
                                <label className="block text-sm font-medium text-gray-3 mb-2">
                                    Withdrawal Amount
                                </label>
                                <div className="flex gap-2">
                                    <input
                                        type="number"
                                        value={withdrawAmount}
                                        onChange={(e) => setWithdrawAmount(e.target.value)}
                                        placeholder="0.0"
                                        className="flex-1 bg-[#23232a] border border-[#3a3a3f] rounded-lg px-4 py-3 text-gray-1 font-mono focus:border-salmon focus:outline-none transition-colors"
                                    />
                                    <button
                                        onClick={handleMaxClick}
                                        className="text-xs text-salmon hover:text-salmon/80 transition-colors px-3 py-2 rounded bg-salmon/10 hover:bg-salmon/20"
                                    >
                                        Max
                                    </button>
                                </div>
                            </div>

                            <button
                                onClick={handleWithdrawLP}
                                disabled={!isValidAmount() || isWithdrawing || isWithdrawLoading}
                                className="w-full bg-green/10 hover:bg-green/20 border border-green/20 text-green font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                                {isWithdrawing || isWithdrawLoading ? (
                                    <span className="flex items-center justify-center gap-2">
                                        <div className="w-4 h-4 border-2 border-green/30 border-t-green rounded-full animate-spin" />
                                        Withdrawing...
                                    </span>
                                ) : (
                                    "💰 Withdraw LP Tokens"
                                )}
                            </button>

                            {withdrawAmount && !isValidAmount() && (
                                <div className="bg-error/10 border border-error/20 rounded-lg p-3">
                                    <div className="text-sm text-error">
                                        ⚠️ Invalid amount. Please enter a valid amount within your locked balance.
                                    </div>
                                </div>
                            )}
                        </div>
                    )}
                </div>

                {/* Info Messages */}
                {isWithdrawalTriggered && !canWithdraw && (
                    <div className="bg-blue/10 border border-blue/20 rounded-lg p-3">
                        <div className="text-sm text-blue">
                            ⏰ Withdrawal triggered! You can withdraw after {new Date(unlockTime * 1000).toLocaleString()}
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};

export default WithdrawalPanel; 