import React from "react";

interface ErrorDisplayProps {
    error: Error & { code?: string };
    title: string;
    onRetry?: () => void;
}

const ErrorDisplay: React.FC<ErrorDisplayProps> = ({ error, title, onRetry }) => {
    const errorMessage = error?.message || "Unknown error";
    const errorCode = error?.code;

    // Try to extract more specific error information
    let specificError = title;
    let suggestion = "Check your wallet connection and try again.";

    if (errorMessage.includes("execution reverted")) {
        specificError = "Contract call reverted";
        suggestion = "The contract may not be properly initialized or the function is not available.";
    } else if (errorMessage.includes("network")) {
        specificError = "Network connection error";
        suggestion = "Check your network connection and ensure you're on the correct chain.";
    } else if (errorMessage.includes("insufficient funds")) {
        specificError = "Insufficient funds for gas";
        suggestion = "Add more ETH to your wallet to cover gas fees.";
    } else if (errorMessage.includes("user rejected")) {
        specificError = "Transaction rejected";
        suggestion = "You rejected the transaction in your wallet.";
    } else if (errorCode === "CALL_EXCEPTION") {
        specificError = "Contract call failed";
        suggestion = "The contract function may not exist or the contract is not deployed on this network.";
    } else if (errorMessage.includes("timeout")) {
        specificError = "Request timeout";
        suggestion = "The request took too long. Try again or check your connection.";
    } else if (errorMessage.includes("rate limit")) {
        specificError = "Rate limit exceeded";
        suggestion = "Too many requests. Please wait a moment and try again.";
    } else if (errorMessage.includes("unauthorized")) {
        specificError = "Unauthorized access";
        suggestion = "You may not have permission to perform this action.";
    } else if (errorMessage.includes("not found")) {
        specificError = "Resource not found";
        suggestion = "The requested resource could not be found. Check the contract address.";
    }

    return (
        <div className="bg-[#2a2a2f] border border-error/20 rounded-xl p-6">
            <div className="space-y-4">
                <div className="flex items-center gap-2">
                    <span className="text-error text-lg">⚠️</span>
                    <span className="font-medium text-error">{specificError}</span>
                </div>

                <div className="bg-[#23232a] rounded-lg p-4 border border-error/10">
                    <div className="text-sm text-gray-3 mb-2">Error Details:</div>
                    <div className="text-xs font-mono text-gray-1 bg-[#1a1a1f] p-2 rounded border border-[#3a3a3f] break-all">
                        {errorMessage}
                    </div>
                    {errorCode && (
                        <div className="text-xs text-gray-4 mt-2">
                            Code: {errorCode}
                        </div>
                    )}
                </div>

                <div className="bg-blue/10 border border-blue/20 rounded-lg p-3">
                    <div className="text-sm text-blue font-medium mb-1">💡 Suggestion:</div>
                    <div className="text-xs text-gray-2">{suggestion}</div>
                </div>

                <button
                    onClick={onRetry || (() => window.location.reload())}
                    className="w-full bg-salmon/10 hover:bg-salmon/20 border border-salmon/20 text-salmon text-sm font-medium py-2 px-4 rounded-lg transition-colors"
                >
                    🔄 Retry
                </button>
            </div>
        </div>
    );
};

export default ErrorDisplay; 