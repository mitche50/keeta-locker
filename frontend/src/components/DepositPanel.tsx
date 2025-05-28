import React, { useState } from "react";
import { useWriteContract, useWaitForTransactionReceipt, useAccount, useReadContract } from "wagmi";
import { parseEther, formatEther } from "viem";
import { useLPLocker } from "../hooks/useLPLocker";
import LPLockerABI from "../abi/LPLocker.json";
import ERC20ABI from "../abi/ERC20.json";
import { getContractAddress } from "../config";
import { useChainId } from "wagmi";
import toast from "react-hot-toast";
import ErrorDisplay from "./ErrorDisplay";

const DepositPanel: React.FC = () => {
    const { address, isConnected } = useAccount();
    const chainId = useChainId();
    const { lockInfo } = useLPLocker();

    const [depositAmount, setDepositAmount] = useState("");
    const [isApproving, setIsApproving] = useState(false);
    const [isDepositing, setIsDepositing] = useState(false);
    const [approveHash, setApproveHash] = useState<`0x${string}` | undefined>();
    const [depositHash, setDepositHash] = useState<`0x${string}` | undefined>();

    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;

    // Get LP token address from lock info
    const lpTokenAddress = (Array.isArray(lockInfo.data) ? lockInfo.data[2] : undefined) as `0x${string}` | undefined;

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
        args: [address, lpLockerAddress],
        query: {
            enabled: !!lpTokenAddress && !!address,
        }
    });

    // Write contract hooks
    const { writeContract: approve } = useWriteContract();
    const { writeContract: deposit } = useWriteContract();

    // Wait for approve transaction
    const { isLoading: isApproveLoading, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({
        hash: approveHash,
    });

    // Wait for deposit transaction
    const { isLoading: isDepositLoading, isSuccess: isDepositSuccess } = useWaitForTransactionReceipt({
        hash: depositHash,
    });

    const handleApprove = async () => {
        if (!depositAmount || !lpTokenAddress) return;

        try {
            setIsApproving(true);
            toast.loading("Approving LP tokens...", { id: "approve" });

            const amount = parseEther(depositAmount);
            approve({
                address: lpTokenAddress,
                abi: ERC20ABI,
                functionName: "approve",
                args: [lpLockerAddress, amount],
            }, {
                onSuccess: (hash) => {
                    setApproveHash(hash);
                    toast.dismiss("approve");
                    toast.success("Approval transaction submitted!");
                },
                onError: (error) => {
                    console.error("Approve error:", error);
                    setIsApproving(false);
                    toast.dismiss("approve");
                    toast.error("Failed to approve LP tokens");
                }
            });
        } catch (error) {
            console.error("Approve error:", error);
            setIsApproving(false);
            toast.dismiss("approve");
            toast.error("Failed to approve LP tokens");
        }
    };

    const handleDeposit = async () => {
        if (!depositAmount) return;

        try {
            setIsDepositing(true);
            toast.loading("Depositing LP tokens...", { id: "deposit" });

            const amount = parseEther(depositAmount);
            deposit({
                address: lpLockerAddress,
                abi: LPLockerABI,
                functionName: "depositLPTokens",
                args: [amount],
            }, {
                onSuccess: (hash) => {
                    setDepositHash(hash);
                    toast.dismiss("deposit");
                    toast.success("Deposit transaction submitted!");
                },
                onError: (error) => {
                    console.error("Deposit error:", error);
                    setIsDepositing(false);
                    toast.dismiss("deposit");
                    toast.error("Failed to deposit LP tokens");
                }
            });
        } catch (error) {
            console.error("Deposit error:", error);
            setIsDepositing(false);
            toast.dismiss("deposit");
            toast.error("Failed to deposit LP tokens");
        }
    };

    // Handle transaction success
    React.useEffect(() => {
        if (isApproveSuccess) {
            setIsApproving(false);
            refetchAllowance();
            toast.success("LP tokens approved successfully!");
        }
    }, [isApproveSuccess, refetchAllowance]);

    React.useEffect(() => {
        if (isDepositSuccess) {
            setIsDepositing(false);
            setDepositAmount("");
            toast.success("LP tokens deposited successfully!");
        }
    }, [isDepositSuccess]);

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
                <h2 className="text-xl font-semibold mb-6 text-salmon">Deposit LP Tokens</h2>
                <div className="flex items-center justify-center py-8 text-gray-3">
                    <div className="text-center">
                        <div className="text-2xl mb-2">🔌</div>
                        <div className="font-medium">Connect your wallet</div>
                        <div className="text-sm">Connect your wallet to deposit LP tokens</div>
                    </div>
                </div>
            </div>
        );
    }

    if (lockInfo.isLoading) {
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

    if (lockInfo.isError) {
        return (
            <ErrorDisplay
                error={lockInfo.error as Error & { code?: string }}
                title="Error loading lock info for deposits"
                onRetry={() => window.location.reload()}
            />
        );
    }

    return (
        <div className="bg-[#2a2a2f] rounded-xl border border-[#3a3a3f] p-6">
            <h2 className="text-xl font-semibold mb-6 text-salmon">Deposit LP Tokens</h2>

            <div className="space-y-6">
                {/* Balance Info */}
                <div className="bg-[#23232a] rounded-lg p-4 border border-[#3a3a3f]">
                    <div className="flex justify-between items-center mb-2">
                        <span className="text-sm text-gray-3">Your LP Token Balance</span>
                        <button
                            onClick={handleMaxClick}
                            className="text-xs text-salmon hover:text-salmon/80 transition-colors px-2 py-1 rounded bg-salmon/10 hover:bg-salmon/20"
                        >
                            Max
                        </button>
                    </div>
                    <div className="text-lg font-mono font-bold text-gray-1">
                        {userLPBalance ? formatEther(userLPBalance as bigint) : "0"} LP
                    </div>
                </div>

                {/* Deposit Form */}
                <div className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-3 mb-2">
                            Deposit Amount
                        </label>
                        <input
                            type="number"
                            value={depositAmount}
                            onChange={(e) => setDepositAmount(e.target.value)}
                            placeholder="0.0"
                            className="w-full bg-[#23232a] border border-[#3a3a3f] rounded-lg px-4 py-3 text-gray-1 font-mono focus:border-salmon focus:outline-none transition-colors"
                        />
                    </div>

                    {/* Action Buttons */}
                    <div className="space-y-3">
                        {needsApproval() && isValidAmount() && (
                            <button
                                onClick={handleApprove}
                                disabled={isApproving || isApproveLoading}
                                className="w-full bg-blue/10 hover:bg-blue/20 border border-blue/20 text-blue font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                                {isApproving || isApproveLoading ? (
                                    <span className="flex items-center justify-center gap-2">
                                        <div className="w-4 h-4 border-2 border-blue/30 border-t-blue rounded-full animate-spin" />
                                        Approving...
                                    </span>
                                ) : (
                                    "1. Approve LP Tokens"
                                )}
                            </button>
                        )}

                        <button
                            onClick={handleDeposit}
                            disabled={
                                !isValidAmount() ||
                                needsApproval() ||
                                isDepositing ||
                                isDepositLoading ||
                                isApproving ||
                                isApproveLoading
                            }
                            className="w-full bg-salmon/10 hover:bg-salmon/20 border border-salmon/20 text-salmon font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {isDepositing || isDepositLoading ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="w-4 h-4 border-2 border-salmon/30 border-t-salmon rounded-full animate-spin" />
                                    Depositing...
                                </span>
                            ) : needsApproval() ? (
                                "2. Deposit LP Tokens"
                            ) : (
                                "Deposit LP Tokens"
                            )}
                        </button>
                    </div>

                    {/* Validation Messages */}
                    {depositAmount && !isValidAmount() && (
                        <div className="bg-error/10 border border-error/20 rounded-lg p-3">
                            <div className="text-sm text-error">
                                ⚠️ Invalid amount. Please enter a valid amount within your balance.
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default DepositPanel; 