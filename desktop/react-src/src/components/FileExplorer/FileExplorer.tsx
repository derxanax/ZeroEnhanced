import React, { useState, useEffect } from 'react';

interface FileItem {
  name: string;
  path: string;
  type: 'file' | 'directory';
  children?: FileItem[];
}

interface FileExplorerProps {
  onFileSelect: (filePath: string) => void;
  selectedFile?: string;
}

//* файловый браузер
export const FileExplorer: React.FC<FileExplorerProps> = ({ onFileSelect, selectedFile }) => {
  const [files, setFiles] = useState<FileItem[]>([]);
  const [expandedDirs, setExpandedDirs] = useState<Set<string>>(new Set());

  useEffect(() => {
    loadFiles();
  }, []);

  const loadFiles = async () => {
    try {
      // Используем Neutralino API для получения файлов
      const result = await (window as any).Neutralino.os.execCommand('find . -type f -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.json" -o -name "*.md" | head -20');
      const fileList = result.stdOut.split('\n').filter((f: string) => f.trim());
      
      const fileItems: FileItem[] = fileList.map((path: string) => ({
        name: path.split('/').pop() || path,
        path: path.replace('./', ''),
        type: 'file' as const
      }));
      
      setFiles(fileItems);
    } catch (error) {
      console.error('Error loading files:', error);
      // Fallback с примерами файлов
      setFiles([
        { name: 'App.tsx', path: 'src/App.tsx', type: 'file' },
        { name: 'main.ts', path: 'src/main.ts', type: 'file' },
        { name: 'core.ts', path: 'src/core.ts', type: 'file' },
        { name: 'package.json', path: 'package.json', type: 'file' },
        { name: 'README.md', path: 'README.md', type: 'file' }
      ]);
    }
  };

  const getFileIcon = (fileName: string) => {
    const ext = fileName.split('.').pop()?.toLowerCase();
    switch (ext) {
      case 'ts':
      case 'tsx':
        return '🔷';
      case 'js':
      case 'jsx':
        return '🟨';
      case 'json':
        return '📋';
      case 'md':
        return '📝';
      default:
        return '📄';
    }
  };

  return (
    <div className="bg-dark-800 border-r border-dark-500 w-64 flex flex-col">
      <div className="p-3 border-b border-dark-500">
        <h3 className="text-sm font-semibold text-dark-200 flex items-center">
          📁 Files
        </h3>
      </div>
      
      <div className="flex-1 overflow-y-auto p-2">
        {files.map((file, index) => (
          <div
            key={index}
            className={`flex items-center p-2 text-sm cursor-pointer rounded-md hover:bg-dark-700 transition-colors ${
              selectedFile === file.path ? 'bg-accent/20 text-accent' : 'text-dark-300'
            }`}
            onClick={() => onFileSelect(file.path)}
          >
            <span className="mr-2">{getFileIcon(file.name)}</span>
            <span className="truncate">{file.name}</span>
          </div>
        ))}
      </div>
      
      <div className="p-2 border-t border-dark-500">
        <button
          onClick={loadFiles}
          className="w-full text-xs text-dark-400 hover:text-dark-200 transition-colors"
        >
          🔄 Refresh
        </button>
      </div>
    </div>
  );
}; 