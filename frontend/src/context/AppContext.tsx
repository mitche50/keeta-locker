import React, { createContext, useContext, useState, useCallback } from 'react';
import type { ReactNode } from 'react';

interface AppContextType {
    // Refresh triggers
    refreshLocks: () => void;
    refreshBalances: () => void;
    refreshFees: () => void;
    refreshAll: () => void;

    // Global state
    lastTransactionHash: string | null;
    setLastTransactionHash: (hash: string | null) => void;

    // Refresh counters to force re-renders
    locksRefreshKey: number;
    balancesRefreshKey: number;
    feesRefreshKey: number;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export const useAppContext = () => {
    const context = useContext(AppContext);
    if (!context) {
        throw new Error('useAppContext must be used within an AppProvider');
    }
    return context;
};

interface AppProviderProps {
    children: ReactNode;
}

export const AppProvider: React.FC<AppProviderProps> = ({ children }) => {
    const [locksRefreshKey, setLocksRefreshKey] = useState(0);
    const [balancesRefreshKey, setBalancesRefreshKey] = useState(0);
    const [feesRefreshKey, setFeesRefreshKey] = useState(0);
    const [lastTransactionHash, setLastTransactionHash] = useState<string | null>(null);

    const refreshLocks = useCallback(() => {
        setLocksRefreshKey(prev => prev + 1);
    }, []);

    const refreshBalances = useCallback(() => {
        setBalancesRefreshKey(prev => prev + 1);
    }, []);

    const refreshFees = useCallback(() => {
        setFeesRefreshKey(prev => prev + 1);
    }, []);

    const refreshAll = useCallback(() => {
        setLocksRefreshKey(prev => prev + 1);
        setBalancesRefreshKey(prev => prev + 1);
        setFeesRefreshKey(prev => prev + 1);
    }, []);

    const contextValue: AppContextType = {
        refreshLocks,
        refreshBalances,
        refreshFees,
        refreshAll,
        lastTransactionHash,
        setLastTransactionHash,
        locksRefreshKey,
        balancesRefreshKey,
        feesRefreshKey,
    };

    return (
        <AppContext.Provider value={contextValue}>
            {children}
        </AppContext.Provider>
    );
}; 