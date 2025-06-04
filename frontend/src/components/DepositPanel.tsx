import React, { useState } from "react";
import { useWriteContract, useWaitForTransactionReceipt, useAccount, useReadContract } from "wagmi";
import { parseEther, formatEther } from "viem";
import { useLPLocker } from "../hooks/useLPLocker";
import { useAppContext } from "../context/AppContext";
import LPLockerABI from "../abi/LPLocker.json";
import ERC20ABI from "../abi/ERC20.json";
import ErrorDisplay from "./ErrorDisplay";
import toast from "react-hot-toast";

const DepositPanel: React.FC = () => {
    const { address, isConnected } = useAccount();
    const { tokenContract, contractAddress } = useLPLocker();
    const { refreshLocks, refreshBalances, balancesRefreshKey } = useAppContext();

    const [depositAmount, setDepositAmount] = useState("");
    const [isApproving, setIsApproving] = useState(false);
    const [isDepositing, setIsDepositing] = useState(false);

    const { writeContract, data: hash, error, isPending } = useWriteContract();

    // Get LP token address from contract
    const lpTokenAddress = tokenContract.data as `0x${string}` | undefined;

    // Check user's LP token balance - add dependency on balancesRefreshKey to force refresh
    const { data: userLPBalance, refetch: refetchBalance } = useReadContract({
        address: lpTokenAddress,
        abi: ERC20ABI,
        functionName: "balanceOf",
        args: [address],
        query: {
            enabled: !!lpTokenAddress && !!address,
        }
    });

    // Check allowance - add dependency on balancesRefreshKey to force refresh
    const { data: allowance, refetch: refetchAllowance } = useReadContract({
        address: lpTokenAddress,
        abi: ERC20ABI,
        functionName: "allowance",
        args: [address, contractAddress],
        query: {
            enabled: !!lpTokenAddress && !!address,
        }
    });

    // Force refresh when balancesRefreshKey changes
    React.useEffect(() => {
        if (balancesRefreshKey > 0) {
            refetchBalance();
            refetchAllowance();
        }
    }, [balancesRefreshKey, refetchBalance, refetchAllowance]);

    // Wait for transaction
    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash,
    });

    const handleApprove = async () => {
        if (!depositAmount || !lpTokenAddress) return;

        try {
            setIsApproving(true);
            const amount = parseEther(depositAmount);
            toast.loading("Approving LP tokens...", { id: "approve" });
            await writeContract({
                address: lpTokenAddress,
                abi: ERC20ABI,
                functionName: "approve",
                args: [contractAddress, amount],
            });
        } catch (error) {
            console.error("Approve error:", error);
            toast.dismiss("approve");
            toast.error("Failed to approve LP tokens");
        } finally {
            setIsApproving(false);
        }
    };

    const handleDeposit = async () => {
        if (!depositAmount) return;

        try {
            setIsDepositing(true);
            const amount = parseEther(depositAmount);
            toast.loading("Locking LP tokens...", { id: "deposit" });
            await writeContract({
                address: contractAddress,
                abi: LPLockerABI,
                functionName: "lockLiquidity",
                args: [amount],
            });
        } catch (error) {
            console.error("Deposit error:", error);
            toast.dismiss("deposit");
            toast.error("Failed to lock LP tokens");
        } finally {
            setIsDepositing(false);
        }
    };

    // Handle transaction success
    React.useEffect(() => {
        if (isSuccess) {
            toast.dismiss();
            if (isApproving) {
                toast.success("LP tokens approved successfully!");
                refetchAllowance();
                refreshBalances(); // Refresh global balance state
            } else {
                toast.success("LP tokens locked successfully!");
                setDepositAmount("");
                // Refresh all relevant data
                refetchAllowance();
                refetchBalance();
                refreshLocks(); // Refresh locks in AllLocksPanel
                refreshBalances(); // Refresh balances everywhere
            }
        }
    }, [isSuccess, isApproving, refetchAllowance, refetchBalance, refreshLocks, refreshBalances]);

    const handleMaxClick = () => {
        if (!userLPBalance || !allowance) return;

        const balance = userLPBalance as bigint;
        const currentAllowance = allowance as bigint;

        // If we have an existing allowance, use the minimum of balance and allowance
        // Otherwise, use the full balance (user will need to approve)
        const maxAmount = currentAllowance > 0n ?
            (balance < currentAllowance ? balance : currentAllowance) :
            balance;

        if (maxAmount > 0n) {
            setDepositAmount(formatEther(maxAmount));
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

    const getMaxButtonText = () => {
        if (!userLPBalance || !allowance) return "MAX";

        const balance = userLPBalance as bigint;
        const currentAllowance = allowance as bigint;

        if (currentAllowance > 0n && currentAllowance < balance) {
            const shortAllowance = formatEther(currentAllowance).slice(0, 8);
            return `MAX (${shortAllowance}...)`;
        }
        return "MAX";
    };

    const formatBalance = (balance: bigint) => {
        return formatEther(balance).slice(0, 10);
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

            {isSuccess && !isApproving && (
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
                            className="w-full px-4 py-3 pr-20 bg-[#23232a] border border-[#3a3a3f] rounded-lg text-gray-1 placeholder-gray-4 focus:outline-none focus:border-salmon transition-colors"
                            disabled={isPending || isConfirming}
                        />
                        <button
                            onClick={handleMaxClick}
                            className="absolute right-3 top-1/2 transform -translate-y-1/2 text-xs text-salmon hover:text-salmon/80 transition-colors px-2 py-1 bg-salmon/10 rounded"
                            disabled={isPending || isConfirming || !userLPBalance}
                            title={needsApproval() && allowance && (allowance as bigint) > 0n ? "Using approved amount" : "Using wallet balance"}
                        >
                            {getMaxButtonText()}
                        </button>
                    </div>
                    {userLPBalance && (
                        <p className="text-xs text-gray-4 mt-1">
                            Wallet Balance: {formatBalance(userLPBalance as bigint)} LP
                            {allowance && (allowance as bigint) > 0n && (
                                <span className="ml-2">
                                    | Approved: {formatBalance(allowance as bigint)} LP
                                </span>
                            )}
                        </p>
                    )}
                </div>

                {/* Approval or Deposit Button */}
                {needsApproval() ? (
                    <button
                        onClick={handleApprove}
                        disabled={!isValidAmount() || isPending || isConfirming}
                        className="w-full py-3 px-4 bg-yellow-500/20 text-yellow-400 border border-yellow-500/30 rounded-lg font-medium hover:bg-yellow-500/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    >
                        {isPending && isApproving ? "Approving..." : isConfirming && isApproving ? "Confirming..." : "Approve LP Tokens"}
                    </button>
                ) : (
                    <button
                        onClick={handleDeposit}
                        disabled={!isValidAmount() || isPending || isConfirming}
                        className="w-full py-3 px-4 bg-salmon text-white rounded-lg font-medium hover:bg-salmon/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    >
                        {isPending && isDepositing ? "Locking..." : isConfirming && isDepositing ? "Confirming..." : "Lock LP Tokens"}
                    </button>
                )}

                {/* Status Information */}
                <div className="text-xs text-gray-4 space-y-1">
                    {depositAmount && isValidAmount() && (
                        <div>
                            Amount to lock: {depositAmount} LP tokens
                        </div>
                    )}
                    {needsApproval() && depositAmount && (
                        <div className="text-yellow-400">
                            ⚠️ Approval required before locking
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default DepositPanel; 