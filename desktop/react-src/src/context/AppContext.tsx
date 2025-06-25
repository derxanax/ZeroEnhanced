import React, { createContext, useState, useContext, useEffect } from 'react';
import { AIService } from '../services/AIService';
import { DockerService } from '../services/DockerService';

interface AppContextType {
  aiService: AIService;
  dockerService: DockerService;
  isAuthenticated: boolean;
  isInitialized: boolean;
  error: string | null;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  initialize: () => Promise<void>;
}

//! контекст для GUI
const AppContext = createContext<AppContextType | undefined>(undefined);

//* провайдер состояния
export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // Создаем сервисы один раз и переиспользуем
  const [aiService] = useState(() => new AIService());
  const [dockerService] = useState(() => new DockerService());

  const initialize = async () => {
    try {
      setError(null);
      console.log('Starting initialization...');
      
      // Сначала инициализируем Docker
      console.log('Initializing Docker sandbox...');
      await dockerService.ensureSandbox();
      console.log('Docker sandbox ready');
      
      // Затем инициализируем AI Service с токеном
      const token = localStorage.getItem('auth_token');
      if (token) {
        console.log('Initializing AI Service...');
        await aiService.init();
        console.log('AI Service initialized successfully');
      } else {
        throw new Error('No authentication token found');
      }
      
      setIsInitialized(true);
      console.log('Full initialization complete');
    } catch (error) {
      console.error('Initialization error:', error);
      setError(`Initialization error: ${error instanceof Error ? error.message : 'Unknown error'}`);
      setIsInitialized(false);
    }
  };

  const login = async (email: string, password: string) => {
    try {
      setError(null);
      await aiService.login(email, password);
      setIsAuthenticated(true);
      await initialize();
    } catch (error) {
      setError(error instanceof Error ? error.message : 'Unknown error');
      setIsAuthenticated(false);
    }
  };

  const register = async (email: string, password: string) => {
    try {
      setError(null);
      await aiService.register(email, password);
      setIsAuthenticated(true);
      await initialize();
    } catch (error) {
      setError(error instanceof Error ? error.message : 'Unknown error');
      setIsAuthenticated(false);
    }
  };

  const logout = async () => {
    try {
      await aiService.logout();
      setIsAuthenticated(false);
      setIsInitialized(false);
    } catch (error) {
      setError(`Logout error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  useEffect(() => {
    // Проверяем наличие токена при загрузке
    const checkAuth = async () => {
      try {
        const token = localStorage.getItem('auth_token');
        if (token) {
          // Проверяем валидность токена через /api/user/me
          const response = await fetch('http://localhost:3003/api/user/me', {
            headers: {
              'Authorization': `Bearer ${token}`
            }
          });
          
          if (response.ok) {
            // Токен валидный, устанавливаем аутентификацию и инициализируем
            setIsAuthenticated(true);
            await initialize();
          } else {
            // Токен невалидный, очищаем его
            localStorage.removeItem('auth_token');
            setIsAuthenticated(false);
            setIsInitialized(false);
          }
        }
      } catch (error) {
        console.error('Auth check failed:', error);
        // Если ошибка сети или другая проблема, очищаем токен
        localStorage.removeItem('auth_token');
        setIsAuthenticated(false);
        setIsInitialized(false);
      }
    };
    
    checkAuth();
  }, []);

  return (
    <AppContext.Provider value={{
      aiService,
      dockerService,
      isAuthenticated,
      isInitialized,
      error,
      login,
      register,
      logout,
      initialize
    }}>
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
}; 