import React, { useState } from 'react';
import { AppProvider } from './context/AppContext';
import { Terminal } from './components/Terminal/Terminal';
import { LoginForm } from './components/Auth/LoginForm';
import { StatusBar } from './components/StatusBar/StatusBar';
import { FileExplorer } from './components/FileExplorer/FileExplorer';
import { CodeEditor } from './components/CodeEditor/CodeEditor';
import { useApp } from './context/AppContext';

//! главный компонент IDE
const AppContent: React.FC = () => {
  const { isAuthenticated, isInitialized, error, initialize } = useApp();
  const [selectedFile, setSelectedFile] = useState<string | undefined>();

  if (!isAuthenticated) {
    return <LoginForm />;
  }

  // Если аутентифицирован но не инициализирован, показываем загрузку или ошибку
  if (isAuthenticated && !isInitialized) {
    return (
      <div className="flex items-center justify-center h-screen bg-dark-900">
        <div className="bg-dark-800 p-8 rounded-lg border border-dark-500 shadow-lg w-full max-w-md text-center">
          <h2 className="text-xl font-bold text-dark-200 mb-4">Initializing ZetGui...</h2>
          
          {error && (
            <div className="bg-red-900/20 border border-red-800 text-red-200 px-4 py-3 rounded mb-4">
              {error}
            </div>
          )}
          
          <button
            onClick={initialize}
            className="bg-accent hover:bg-accent-dark text-dark-200 font-bold py-2 px-4 rounded-sm focus:outline-none focus:ring-2 focus:ring-accent transition-colors"
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

  const handleFileSave = (content: string) => {
    console.log('Saving file content:', content);
    // TODO: Implement file saving
  };

  return (
    <div className="flex flex-col h-screen bg-dark-900 text-dark-200">
      {/* Статус бар */}
      <StatusBar />
      
      {/* Основная область */}
      <div className="flex flex-1 overflow-hidden">
        {/* Файловый браузер */}
        <FileExplorer 
          onFileSelect={handleFileSelect}
          selectedFile={selectedFile}
        />
        
        {/* Редактор кода */}
        <div className="flex-1 flex flex-col">
          <CodeEditor 
            filePath={selectedFile}
            onSave={handleFileSave}
          />
        </div>
      </div>
      
      {/* Терминал */}
      <Terminal />
    </div>
  );
};

//* обертка с провайдером
const App: React.FC = () => {
  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
};

export default App; 