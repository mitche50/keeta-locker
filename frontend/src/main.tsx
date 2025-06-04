import React from "react";
import ReactDOM from "react-dom/client";
import { WagmiProvider, http } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { getDefaultConfig, RainbowKitProvider } from "@rainbow-me/rainbowkit";
import { Toaster } from "react-hot-toast";
import { BASE_MAINNET, ANVIL_LOCAL } from "./config";
import App from "./App";
import "@rainbow-me/rainbowkit/styles.css";
import './index.css';

const config = getDefaultConfig({
    appName: "LP Locker",
    projectId: "YOUR_PROJECT_ID",
    chains: [BASE_MAINNET, ANVIL_LOCAL],
    transports: {
        [BASE_MAINNET.id]: http(),
        [ANVIL_LOCAL.id]: http(),
    },
    ssr: false, // If your dApp uses server side rendering (SSR)
});

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById("root")!).render(
    <React.StrictMode>
        <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
                <RainbowKitProvider>
                    <App />
                    <Toaster
                        position="top-right"
                        toastOptions={{
                            duration: 4000,
                            style: {
                                background: '#2a2a2f',
                                color: '#e4e4e7',
                                border: '1px solid #3a3a3f',
                            },
                            success: {
                                style: {
                                    background: '#059669',
                                    color: 'white',
                                },
                            },
                            error: {
                                style: {
                                    background: '#dc2626',
                                    color: 'white',
                                },
                            },
                        }}
                    />
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider>
    </React.StrictMode>
); 