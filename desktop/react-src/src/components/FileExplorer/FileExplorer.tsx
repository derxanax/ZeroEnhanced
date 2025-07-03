import React, { useEffect, useState } from 'react';
import { useApp } from '../../context/AppContext';

interface FileExplorerProps {
  onFileSelect?: (filePath: string) => void;
}

export const FileExplorer: React.FC<FileExplorerProps> = ({ onFileSelect }) => {
  const { aiService } = useApp();
  const [files, setFiles] = useState<string[]>([]);
  const [directories, setDirectories] = useState<string[]>([]);
  const [currentPath, setCurrentPath] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    loadFiles();
  }, [currentPath]);

  const loadFiles = async () => {
    if (!aiService.isReady()) return;

    setIsLoading(true);
    try {
      const result = await aiService.listFiles(currentPath);
      setFiles(result.files);
      setDirectories(result.directories);
    } catch (error) {
      console.error('Failed to load files:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleDirectoryClick = (dirName: string) => {
    const newPath = currentPath ? `${currentPath}/${dirName}` : dirName;
    setCurrentPath(newPath);
  };

  const handleFileClick = (fileName: string) => {
    const fullPath = currentPath ? `${currentPath}/${fileName}` : fileName;
    if (onFileSelect) {
      onFileSelect(fullPath);
    }
  };

  const goBack = () => {
    const pathParts = currentPath.split('/');
    pathParts.pop();
    setCurrentPath(pathParts.join('/'));
  };

  return (
    <div className="h-full bg-white border-r border-gray-200 flex flex-col">
      <div className="bg-gray-50 px-4 py-3 border-b border-gray-200">
        <h3 className="font-semibold text-gray-800">📁 File Explorer</h3>
        {currentPath && (
          <div className="mt-2 flex items-center space-x-2">
            <button
              onClick={goBack}
              className="text-blue-600 hover:text-blue-800 text-sm"
            >
              ← Back
            </button>
            <span className="text-sm text-gray-600">/{currentPath}</span>
          </div>
        )}
      </div>

      <div className="flex-1 overflow-y-auto p-2">
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <div className="animate-spin w-6 h-6 border-2 border-blue-600 border-t-transparent rounded-full"></div>
          </div>
        ) : (
          <div className="space-y-1">
            {directories.map((dir) => (
              <button
                key={dir}
                onClick={() => handleDirectoryClick(dir)}
                className="w-full text-left px-3 py-2 rounded-md hover:bg-gray-100 flex items-center space-x-2"
              >
                <span>📁</span>
                <span className="text-gray-800">{dir}</span>
              </button>
            ))}

            {files.map((file) => (
              <button
                key={file}
                onClick={() => handleFileClick(file)}
                className="w-full text-left px-3 py-2 rounded-md hover:bg-gray-100 flex items-center space-x-2"
              >
                <span>📄</span>
                <span className="text-gray-800">{file}</span>
              </button>
            ))}

            {directories.length === 0 && files.length === 0 && (
              <div className="text-center text-gray-500 py-8">
                <span>Empty directory</span>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}; 