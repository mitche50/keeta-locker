import { useReadContract, useChainId } from "wagmi";
import LPLockerABI from "../abi/LPLocker.json";
import { getContractAddress } from "../config";

export function useLPLocker() {
    const chainId = useChainId();
    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;

    // Example: getLockInfo
    const lockInfo = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getLockInfo",
    });

    // getLPBalance
    const lpBalance = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getLPBalance",
    });

    // getClaimableFees
    const claimableFees = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getClaimableFees",
    });

    // getAllClaimableRewards
    const allClaimableRewards = useReadContract({
        address: lpLockerAddress,
        abi: LPLockerABI,
        functionName: "getAllClaimableRewards",
    });

    // Add more reads/writes as needed

    return {
        lockInfo,
        lpBalance,
        claimableFees,
        allClaimableRewards,
        contractAddress: lpLockerAddress,
        // ...other hooks
    };
} 