import React, { useState, useEffect } from 'react';

export const Footer: React.FC = () => {
  const [dockerStatus, setDockerStatus] = useState<'connected' | 'disconnected' | 'checking'>('checking');
  const [remainingRequests, setRemainingRequests] = useState<number | null>(null);

  useEffect(() => {
    checkDockerStatus();
    fetchRemainingRequests();
    
    // Check status every 30 seconds
    const interval = setInterval(() => {
      checkDockerStatus();
      fetchRemainingRequests();
    }, 30000);

    return () => clearInterval(interval);
  }, []);

  const checkDockerStatus = async () => {
    try {
      const response = await fetch('/api/docker/ensure-sandbox', {
        method: 'POST'
      });
      
      if (response.ok) {
        setDockerStatus('connected');
      } else {
        setDockerStatus('disconnected');
      }
    } catch (error) {
      setDockerStatus('disconnected');
    }
  };

  const fetchRemainingRequests = async () => {
    try {
      const token = localStorage.getItem('auth_token');
      if (!token) return;

      const response = await fetch('/api/user/me', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (response.ok) {
        const data = await response.json();
        setRemainingRequests(data.request_count);
      }
    } catch (error) {
      console.error('Failed to fetch remaining requests:', error);
    }
  };

  return (
    <footer className="flex items-center justify-between px-6 py-2 bg-gray-800 border-t border-gray-700 text-sm">
      {/* Left side - Docker status */}
      <div className="flex items-center space-x-4">
        <div className="flex items-center">
          <svg className="w-4 h-4 mr-2 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
            <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zm0 4a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1V8zm8 0a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 01-1 1h-2a1 1 0 01-1-1V8z" />
          </svg>
          <span className="text-gray-300 mr-2">Docker:</span>
          <div className="flex items-center">
            <div className={`w-2 h-2 rounded-full mr-2 ${
              dockerStatus === 'connected' 
                ? 'bg-green-400' 
                : dockerStatus === 'disconnected' 
                  ? 'bg-red-400' 
                  : 'bg-yellow-400'
            }`} />
            <span className={`text-xs ${
              dockerStatus === 'connected' 
                ? 'text-green-400' 
                : dockerStatus === 'disconnected' 
                  ? 'text-red-400' 
                  : 'text-yellow-400'
            }`}>
              {dockerStatus === 'connected' 
                ? 'Connected' 
                : dockerStatus === 'disconnected' 
                  ? 'Disconnected' 
                  : 'Checking...'}
            </span>
          </div>
        </div>

        {/* WebSocket Status */}
        <div className="flex items-center">
          <svg className="w-4 h-4 mr-2 text-green-400" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clipRule="evenodd" />
          </svg>
          <span className="text-gray-300 mr-2">WebSocket:</span>
          <div className="flex items-center">
            <div className="w-2 h-2 bg-green-400 rounded-full mr-2" />
            <span className="text-xs text-green-400">Active</span>
          </div>
        </div>
      </div>

      {/* Center - Version info */}
      <div className="flex items-center space-x-4">
        <span className="text-gray-400">ZetGui v1.0.0</span>
        <span className="text-gray-500">•</span>
        <span className="text-gray-400">qZET AI Assistant</span>
      </div>

      {/* Right side - Request count and other info */}
      <div className="flex items-center space-x-4">
        {remainingRequests !== null && (
          <div className="flex items-center">
            <svg className="w-4 h-4 mr-2 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
            </svg>
            <span className="text-gray-300 mr-2">Requests:</span>
            <span className={`text-xs font-medium ${
              remainingRequests > 10 
                ? 'text-green-400' 
                : remainingRequests > 5 
                  ? 'text-yellow-400' 
                  : 'text-red-400'
            }`}>
              {remainingRequests} left
            </span>
          </div>
        )}

        <div className="flex items-center">
          <svg className="w-4 h-4 mr-2 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clipRule="evenodd" />
          </svg>
          <span className="text-gray-400 text-xs">
            {new Date().toLocaleTimeString()}
          </span>
        </div>
      </div>
    </footer>
  );
}; 