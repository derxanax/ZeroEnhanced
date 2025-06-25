import React, { useState } from 'react';
import { AppProvider } from './context/AppContext';
import { DockerTerminal } from './components/DockerTerminal/DockerTerminal';
import { AIChat } from './components/AIChat/AIChat';
import { LoginForm } from './components/Auth/LoginForm';
import { FileExplorer } from './components/FileExplorer/FileExplorer';
import { Header } from './components/Header/Header';
import { Footer } from './components/Footer/Footer';
import { useApp } from './context/AppContext';

// Main application content with new layout
const AppContent: React.FC = () => {
  const { isAuthenticated, isInitialized, error, initialize } = useApp();
  const [selectedFile, setSelectedFile] = useState<string | undefined>();
  const [terminalSessionId] = useState(() => `session-${Date.now()}`);

  // Show login form if not authenticated
  if (!isAuthenticated) {
    return <LoginForm />;
  }

  // Show initialization screen if authenticated but not initialized
  if (isAuthenticated && !isInitialized) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-900">
        <div className="bg-gray-800 p-8 rounded-lg border border-gray-700 shadow-lg w-full max-w-md text-center">
          <div className="flex items-center justify-center mb-4">
            <svg className="w-12 h-12 text-blue-500 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
          <h2 className="text-xl font-bold text-white mb-4">Initializing ZetGui...</h2>
          <p className="text-gray-400 mb-6">Setting up Docker environment and AI services</p>
          
          {error && (
            <div className="bg-red-900/20 border border-red-800 text-red-200 px-4 py-3 rounded mb-4">
              <div className="flex items-center">
                <svg className="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                </svg>
                {error}
              </div>
            </div>
          )}
          
          <button
            onClick={initialize}
            className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors"
          >
            Retry Initialization
          </button>
        </div>
      </div>
    );
  }

  const handleFileSelect = (filePath: string) => {
    setSelectedFile(filePath);
  };

  // New three-panel layout: FileExplorer | DockerTerminal | AIChat
  return (
    <div className="h-screen flex flex-col bg-gray-900 text-white">
      {/* Header */}
      <Header />
      
      {/* Main Content Area */}
      <div className="flex-1 flex overflow-hidden">
        {/* File Explorer - Left Panel (200px width) */}
        <div className="w-[250px] border-r border-gray-700">
          <FileExplorer 
            onFileSelect={handleFileSelect}
            selectedFile={selectedFile}
          />
        </div>
        
        {/* Docker Terminal - Center Panel (flexible width) */}
        <div className="flex-1 min-w-0">
          <DockerTerminal 
            className="h-full"
            sessionId={terminalSessionId}
          />
        </div>
        
        {/* AI Chat - Right Panel (400px width) */}
        <div className="w-[400px] border-l border-gray-700">
          <AIChat 
            width={400}
            className="h-full"
          />
        </div>
      </div>
      
      {/* Footer */}
      <Footer />
    </div>
  );
};

// App component with provider wrapper
const App: React.FC = () => {
  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
};

export default App; 