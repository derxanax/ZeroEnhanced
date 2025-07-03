import React from 'react';

export const Footer: React.FC = () => {
  return (
    <footer className="bg-gray-800 text-white py-2 px-4">
      <div className="flex items-center justify-between text-sm">
        <div className="flex items-center space-x-4">
          <span>🚀 ZeroEnhanced v1.0.0</span>
          <span className="text-gray-400">AI-Powered Development</span>
        </div>

        <div className="flex items-center space-x-4">
          <span className="text-gray-400">
            Connected to server
          </span>
          <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
        </div>
      </div>
    </footer>
  );
}; 