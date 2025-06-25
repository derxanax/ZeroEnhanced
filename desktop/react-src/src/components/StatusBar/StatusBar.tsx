import React from 'react';
import { useApp } from '../../context/AppContext';

//* статус бар с индикатором подключения
export const StatusBar: React.FC = () => {
  const { isAuthenticated, isInitialized, error } = useApp();
  
  const getConnectionStatus = () => {
    if (!isAuthenticated) return { status: 'disconnected', color: 'bg-red-500', text: 'Not Connected' };
    if (!isInitialized) return { status: 'connecting', color: 'bg-yellow-500', text: 'Connecting...' };
    if (error) return { status: 'error', color: 'bg-red-500', text: 'Connection Error' };
    return { status: 'connected', color: 'bg-green-500', text: 'Connected' };
  };

  const { status, color, text } = getConnectionStatus();

  return (
    <div className="bg-dark-800 border-b border-dark-500 px-4 py-2 flex items-center justify-between">
      <div className="flex items-center space-x-4">
        <h1 className="text-lg font-bold text-accent">ZetGui</h1>
        <div className="flex items-center space-x-2">
          <div className={`w-3 h-3 rounded-full ${color}`}></div>
          <span className="text-sm text-dark-200">{text}</span>
        </div>
      </div>
      
      <div className="flex items-center space-x-4 text-sm text-dark-400">
        <span>AI Terminal IDE</span>
      </div>
    </div>
  );
}; 