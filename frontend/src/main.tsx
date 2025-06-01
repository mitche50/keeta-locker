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
    appName: "LPLocker Admin",
    projectId: "lp-locker-admin",
    chains: [BASE_MAINNET, ANVIL_LOCAL],
    transports: {
        [BASE_MAINNET.id]: http(),
        [ANVIL_LOCAL.id]: http(),
    },
});

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById("root")!).render(
    <React.StrictMode>
        <QueryClientProvider client={queryClient}>
            <WagmiProvider config={config}>
                <RainbowKitProvider>
                    <App />
                    <Toaster
                        position="top-right"
                        toastOptions={{
                            duration: 4000,
                            style: {
                                background: '#2a2a2f',
                                color: '#f8f9fa',
                                border: '1px solid #3a3a3f',
                            },
                            success: {
                                iconTheme: {
                                    primary: '#00d4aa',
                                    secondary: '#2a2a2f',
                                },
                            },
                            error: {
                                iconTheme: {
                                    primary: '#ff4757',
                                    secondary: '#2a2a2f',
                                },
                            },
                        }}
                    />
                </RainbowKitProvider>
            </WagmiProvider>
        </QueryClientProvider>
    </React.StrictMode>
); 