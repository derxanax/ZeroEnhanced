import React, { useState } from 'react';
import AIChat from './components/AIChat/AIChat';
import { LoginForm } from './components/Auth/LoginForm';
import { CodeEditor } from './components/CodeEditor/CodeEditor';
import { DockerTerminal } from './components/DockerTerminal/DockerTerminal';
import { FileExplorer } from './components/FileExplorer/FileExplorer';
import { Footer } from './components/Footer/Footer';
import { Header } from './components/Header/Header';
import { StatusBar } from './components/StatusBar/StatusBar';
import { Terminal } from './components/Terminal/Terminal';
import { AppProvider } from './context/AppContext';

const App: React.FC = () => {
  const [authToken, setAuthToken] = useState<string | null>(localStorage.getItem('auth_token'));
  const [activeTab, setActiveTab] = useState<'chat' | 'files' | 'code' | 'terminal' | 'docker'>('chat');

  const handleLogin = (token: string) => {
    setAuthToken(token);
    localStorage.setItem('auth_token', token);
  };

  const handleLogout = () => {
    setAuthToken(null);
    localStorage.removeItem('auth_token');
  };

  if (!authToken) {
    return (
      <AppProvider>
        <div className="min-h-screen bg-gray-100 flex items-center justify-center">
          <LoginForm onLogin={handleLogin} />
        </div>
      </AppProvider>
    );
  }

  return (
    <AppProvider>
      <div className="flex flex-col h-screen bg-gray-100">
        <Header onLogout={handleLogout} />

        <div className="flex-1 flex">
          <nav className="w-64 bg-white shadow-lg">
            <div className="p-4">
              <h2 className="text-lg font-semibold text-gray-800 mb-4">🚀 ZeroEnhanced</h2>
              <ul className="space-y-2">
                <li>
                  <button
                    onClick={() => setActiveTab('chat')}
                    className={`w-full text-left p-3 rounded-lg transition-colors ${activeTab === 'chat' ? 'bg-blue-500 text-white' : 'text-gray-700 hover:bg-gray-100'
                      }`}
                  >
                    🤖 AI Chat
                  </button>
                </li>
                <li>
                  <button
                    onClick={() => setActiveTab('files')}
                    className={`w-full text-left p-3 rounded-lg transition-colors ${activeTab === 'files' ? 'bg-blue-500 text-white' : 'text-gray-700 hover:bg-gray-100'
                      }`}
                  >
                    📁 Files
                  </button>
                </li>
                <li>
                  <button
                    onClick={() => setActiveTab('code')}
                    className={`w-full text-left p-3 rounded-lg transition-colors ${activeTab === 'code' ? 'bg-blue-500 text-white' : 'text-gray-700 hover:bg-gray-100'
                      }`}
                  >
                    💻 Code Editor
                  </button>
                </li>
                <li>
                  <button
                    onClick={() => setActiveTab('terminal')}
                    className={`w-full text-left p-3 rounded-lg transition-colors ${activeTab === 'terminal' ? 'bg-blue-500 text-white' : 'text-gray-700 hover:bg-gray-100'
                      }`}
                  >
                    ⚡ Terminal
                  </button>
                </li>
                <li>
                  <button
                    onClick={() => setActiveTab('docker')}
                    className={`w-full text-left p-3 rounded-lg transition-colors ${activeTab === 'docker' ? 'bg-blue-500 text-white' : 'text-gray-700 hover:bg-gray-100'
                      }`}
                  >
                    🐳 Docker
                  </button>
                </li>
              </ul>
            </div>
          </nav>

          <main className="flex-1 overflow-hidden">
            {activeTab === 'chat' && <AIChat authToken={authToken} />}
            {activeTab === 'files' && <FileExplorer />}
            {activeTab === 'code' && <CodeEditor />}
            {activeTab === 'terminal' && <Terminal />}
            {activeTab === 'docker' && <DockerTerminal />}
          </main>
        </div>

        <StatusBar />
        <Footer />
      </div>
    </AppProvider>
  );
};

export default App; 