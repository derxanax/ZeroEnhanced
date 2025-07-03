import React, { createContext, ReactNode, useContext, useEffect, useState } from 'react';
import { AIService } from '../services/AIService';

interface AppContextType {
  aiService: AIService;
  isAuthenticated: boolean;
  isInitialized: boolean;
  isLoading: boolean;
  error: string | null;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  initialize: (token?: string) => Promise<void>;
  setError: (error: string | null) => void;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export const useApp = () => {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
};

interface AppProviderProps {
  children: ReactNode;
}

export const AppProvider: React.FC<AppProviderProps> = ({ children }) => {
  const [aiService] = useState(() => new AIService());
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('auth_token');
    if (token) {
      setIsAuthenticated(true);
      initialize(token);
    }
  }, []);

  const initialize = async (token?: string) => {
    setIsLoading(true);
    setError(null);

    try {
      await aiService.init(token);
      setIsInitialized(true);
      console.log('[APP CONTEXT] AI Service initialized successfully');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Initialization failed';
      setError(errorMessage);
      console.error('[APP CONTEXT] Initialization failed:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (email: string, password: string) => {
    setIsLoading(true);
    setError(null);

    try {
      const token = await aiService.login(email, password);
      localStorage.setItem('auth_token', token);
      setIsAuthenticated(true);
      setIsInitialized(true);
      console.log('[APP CONTEXT] Login successful');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Login failed';
      setError(errorMessage);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const register = async (email: string, password: string) => {
    setIsLoading(true);
    setError(null);

    try {
      const token = await aiService.register(email, password);
      localStorage.setItem('auth_token', token);
      setIsAuthenticated(true);
      setIsInitialized(true);
      console.log('[APP CONTEXT] Registration successful');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Registration failed';
      setError(errorMessage);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = async () => {
    setIsLoading(true);

    try {
      await aiService.logout();
      localStorage.removeItem('auth_token');
      setIsAuthenticated(false);
      setIsInitialized(false);
      setError(null);
      console.log('[APP CONTEXT] Logout successful');
    } catch (error) {
      console.error('[APP CONTEXT] Logout error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const value: AppContextType = {
    aiService,
    isAuthenticated,
    isInitialized,
    isLoading,
    error,
    login,
    register,
    logout,
    initialize,
    setError
  };

  return (
    <AppContext.Provider value={value}>
      {children}
    </AppContext.Provider>
  );
}; 