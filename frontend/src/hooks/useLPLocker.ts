import { useReadContract, useChainId } from "wagmi";
import LPLockerABI from "../abi/LPLocker.json";
import { getContractAddress } from "../config";

export function useLPLocker() {
    const chainId = useChainId();
    const lpLockerAddress = getContractAddress(chainId, 'lpLocker') as `0x${string}`;

    // getLockInfo
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

    return {
        lockInfo,
        lpBalance,
        claimableFees,
        contractAddress: lpLockerAddress,
    };
} 