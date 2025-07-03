import React, { useState } from 'react';
import { useApp } from '../../context/AppContext';

export const CodeEditor: React.FC = () => {
  const { aiService } = useApp();
  const [content, setContent] = useState('');
  const [filePath, setFilePath] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  const loadFile = async (path: string) => {
    if (!aiService.isReady() || !path) return;

    setIsLoading(true);
    try {
      const result = await aiService.readFile(path);
      setContent(result.content);
      setFilePath(result.path);
    } catch (error) {
      console.error('Failed to load file:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const saveFile = async () => {
    if (!aiService.isReady() || !filePath) return;

    setIsSaving(true);
    try {
      await aiService.updateFile({
        file: filePath,
        code: content
      });
      console.log('File saved successfully');
    } catch (error) {
      console.error('Failed to save file:', error);
    } finally {
      setIsSaving(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.ctrlKey && e.key === 's') {
      e.preventDefault();
      saveFile();
    }
  };

  return (
    <div className="h-full bg-white flex flex-col">
      <div className="bg-gray-50 px-4 py-3 border-b border-gray-200 flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <h3 className="font-semibold text-gray-800">💻 Code Editor</h3>
          {filePath && (
            <span className="text-sm text-gray-600">{filePath}</span>
          )}
        </div>

        <div className="flex items-center space-x-2">
          <input
            type="text"
            placeholder="Enter file path..."
            className="px-3 py-1 border border-gray-300 rounded-md text-sm"
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                loadFile((e.target as HTMLInputElement).value);
              }
            }}
          />
          <button
            onClick={saveFile}
            disabled={!filePath || isSaving}
            className="px-3 py-1 bg-blue-600 text-white rounded-md text-sm hover:bg-blue-700 disabled:opacity-50"
          >
            {isSaving ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>

      <div className="flex-1 relative">
        {isLoading ? (
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="animate-spin w-8 h-8 border-2 border-blue-600 border-t-transparent rounded-full"></div>
          </div>
        ) : (
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            onKeyDown={handleKeyDown}
            className="w-full h-full p-4 font-mono text-sm border-none outline-none resize-none"
            placeholder={filePath ? 'File content will appear here...' : 'Enter a file path to load content...'}
            spellCheck={false}
          />
        )}
      </div>

      <div className="bg-gray-50 px-4 py-2 border-t border-gray-200 text-sm text-gray-600">
        <div className="flex items-center justify-between">
          <span>
            {content.split('\n').length} lines • {content.length} characters
          </span>
          <span>
            Ctrl+S to save
          </span>
        </div>
      </div>
    </div>
  );
}; 