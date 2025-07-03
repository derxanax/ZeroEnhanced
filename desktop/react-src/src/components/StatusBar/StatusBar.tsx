import React from 'react';

export const StatusBar: React.FC = () => {
  return (
    <div className="bg-blue-600 text-white py-1 px-4 text-sm">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <span>⚡ Ready</span>
          <span className="text-blue-200">AI Service Active</span>
        </div>

        <div className="flex items-center space-x-4">
          <span className="text-blue-200">Docker: Online</span>
          <span>{new Date().toLocaleTimeString()}</span>
        </div>
      </div>
    </div>
  );
}; 