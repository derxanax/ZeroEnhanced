import React, { useState, useEffect } from 'react';
import Editor from '@monaco-editor/react';

interface CodeEditorProps {
  filePath?: string;
  onSave?: (content: string) => void;
}

//* редактор кода с monaco
export const CodeEditor: React.FC<CodeEditorProps> = ({ filePath, onSave }) => {
  const [content, setContent] = useState<string>('');
  const [language, setLanguage] = useState<string>('typescript');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (filePath) {
      loadFile(filePath);
    }
  }, [filePath]);

  const loadFile = async (path: string) => {
    setIsLoading(true);
    try {
      // Определяем язык по расширению
      const ext = path.split('.').pop()?.toLowerCase();
      const langMap: { [key: string]: string } = {
        'ts': 'typescript',
        'tsx': 'typescript',
        'js': 'javascript',
        'jsx': 'javascript',
        'json': 'json',
        'md': 'markdown',
        'html': 'html',
        'css': 'css'
      };
      setLanguage(langMap[ext || ''] || 'plaintext');

      // Загружаем содержимое файла через Neutralino API
      try {
        const result = await (window as any).Neutralino.filesystem.readFile(path);
        setContent(result);
      } catch (error) {
        // Если файл не существует, показываем пример содержимого
        console.warn('Could not load file:', error);
        setContent(getExampleContent(path));
      }
    } catch (error) {
      console.error('Error loading file:', error);
      setContent(`// Error loading file: ${path}\n// ${error}`);
    } finally {
      setIsLoading(false);
    }
  };

  const getExampleContent = (path: string): string => {
    if (path.includes('App.tsx')) {
      return `import React from 'react';

const App: React.FC = () => {
  return (
    <div className="app">
      <h1>Hello ZetGui!</h1>
    </div>
  );
};

export default App;`;
    }
    
    if (path.includes('.ts') || path.includes('.tsx')) {
      return `// TypeScript file: ${path}
export interface Example {
  id: number;
  name: string;
}

export const exampleFunction = (): Example => {
  return {
    id: 1,
    name: 'Example'
  };
};`;
    }
    
    if (path.includes('.json')) {
      return `{
  "name": "example",
  "version": "1.0.0",
  "description": "Example JSON file"
}`;
    }
    
    return `// File: ${path}
// This is an example file content
// Select a file from the file explorer to edit it`;
  };

  const handleEditorChange = (value: string | undefined) => {
    setContent(value || '');
  };

  const handleSave = () => {
    if (onSave) {
      onSave(content);
    }
    // TODO: Сохранение файла через Neutralino API
    console.log('Saving file:', filePath, content);
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
      e.preventDefault();
      handleSave();
    }
  };

  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [content, filePath]);

  return (
    <div className="flex flex-col h-full bg-dark-900">
      <div className="bg-dark-800 border-b border-dark-500 px-4 py-2 flex items-center justify-between">
        <div className="flex items-center space-x-2">
          <span className="text-sm text-dark-200">
            {filePath ? `📝 ${filePath}` : '📝 No file selected'}
          </span>
          {filePath && (
            <span className="text-xs text-dark-400 bg-dark-700 px-2 py-1 rounded">
              {language}
            </span>
          )}
        </div>
        
        {filePath && (
          <button
            onClick={handleSave}
            className="text-xs bg-accent hover:bg-accent-dark text-dark-900 px-3 py-1 rounded transition-colors"
          >
            💾 Save (Ctrl+S)
          </button>
        )}
      </div>
      
      <div className="flex-1">
        {isLoading ? (
          <div className="flex items-center justify-center h-full">
            <div className="text-dark-400">Loading...</div>
          </div>
        ) : (
          <Editor
            height="100%"
            language={language}
            value={content}
            onChange={handleEditorChange}
            theme="vs-dark"
            options={{
              fontSize: 14,
              fontFamily: 'JetBrains Mono, Consolas, Monaco, monospace',
              minimap: { enabled: false },
              scrollBeyondLastLine: false,
              wordWrap: 'on',
              automaticLayout: true,
              tabSize: 2,
              insertSpaces: true,
              renderWhitespace: 'selection',
              bracketPairColorization: { enabled: true },
              guides: {
                indentation: true,
                bracketPairs: true
              }
            }}
          />
        )}
      </div>
    </div>
  );
}; 