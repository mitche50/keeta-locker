import { useReadContract, useChainId } from "wagmi";
import LPLockerABI from "../abi/LPLocker.json";
import { getContractAddress } from "../config";

export function useLPLocker(lockId?: `0x${string}`) {
    const chainId = useChainId();
    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;

    // getAllLockIds - Get all lock IDs
    const allLockIds = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getAllLockIds",
    });

    // getLockInfo - for a specific lock ID if provided
    const lockInfo = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getLockInfo",
        args: lockId ? [lockId] : undefined,
        query: {
            enabled: !!lockId,
        },
    });

    // getLPBalance - total LP balance in contract
    const lpBalance = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getLPBalance",
    });

    // getClaimableFees - for a specific lock ID if provided
    const claimableFees = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getClaimableFees",
        args: lockId ? [lockId] : undefined,
        query: {
            enabled: !!lockId,
        },
    });

    // lockExists - check if a specific lock exists
    const lockExists = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "lockExists",
        args: lockId ? [lockId] : undefined,
        query: {
            enabled: !!lockId,
        },
    });

    // getUnlockTime - for a specific lock ID if provided
    const unlockTime = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getUnlockTime",
        args: lockId ? [lockId] : undefined,
        query: {
            enabled: !!lockId,
        },
    });

    // Basic contract info
    const owner = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "owner",
    });

    const feeReceiver = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "feeReceiver",
    });

    const tokenContract = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "tokenContract",
    });

    return {
        // Multi-lock functionality
        allLockIds,

        // Single lock functionality (requires lockId)
        lockInfo,
        claimableFees,
        lockExists,
        unlockTime,

        // Contract-wide info
        lpBalance,
        owner,
        feeReceiver,
        tokenContract,

        // Contract address
        contractAddress: lpLockerAddress,
    };
} 