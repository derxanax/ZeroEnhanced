import React, { useEffect, useRef, useState } from 'react';
import { useApp } from '../../context/AppContext';

interface Command {
  input: string;
  output: string;
  timestamp: Date;
}

//* компактный терминал для IDE
export const Terminal: React.FC = () => {
  const { aiService } = useApp();
  const [commands, setCommands] = useState<Command[]>([]);
  const [currentInput, setCurrentInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const terminalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [commands]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!currentInput.trim() || isLoading) return;

    const input = currentInput.trim();
    setCurrentInput('');
    setIsLoading(true);

    let output = '';

    try {
      if (input.startsWith('/ai ')) {
        const aiQuery = input.substring(4);
        const response = await aiService.getCommand(aiQuery);
        output = response.ai.displayText || response.ai.thought || 'No response';
      } else {
        const result = await aiService.executeCommand(input);
        output = result.stdout || result.stderr || 'Command executed successfully';
      }
    } catch (error) {
      output = `Error: ${error instanceof Error ? error.message : 'Unknown error'}`;
    }

    const newCommand: Command = {
      input,
      output,
      timestamp: new Date()
    };

    setCommands(prev => [...prev, newCommand]);
    setIsLoading(false);
  };

  const formatTimestamp = (date: Date) => {
    return date.toLocaleTimeString();
  };

  return (
    <div className="h-full bg-black text-green-400 font-mono text-sm flex flex-col">
      <div className="bg-gray-800 px-4 py-2 border-b border-gray-700">
        <h3 className="text-white font-semibold">⚡ Terminal</h3>
      </div>

      <div
        ref={terminalRef}
        className="flex-1 overflow-y-auto p-4 space-y-2"
      >
        {commands.map((command, index) => (
          <div key={index} className="space-y-1">
            <div className="flex items-center space-x-2">
              <span className="text-blue-400">$</span>
              <span className="text-white">{command.input}</span>
              <span className="text-gray-500 text-xs">
                [{formatTimestamp(command.timestamp)}]
              </span>
            </div>
            {command.output && (
              <div className="pl-4 text-gray-300 whitespace-pre-wrap">
                {command.output}
              </div>
            )}
          </div>
        ))}

        {isLoading && (
          <div className="flex items-center space-x-2">
            <span className="text-blue-400">$</span>
            <span className="text-yellow-400">Processing...</span>
            <div className="animate-spin w-4 h-4 border-2 border-yellow-400 border-t-transparent rounded-full"></div>
          </div>
        )}
      </div>

      <form onSubmit={handleSubmit} className="border-t border-gray-700 p-4">
        <div className="flex items-center space-x-2">
          <span className="text-blue-400">$</span>
          <input
            ref={inputRef}
            type="text"
            value={currentInput}
            onChange={(e) => setCurrentInput(e.target.value)}
            disabled={isLoading}
            className="flex-1 bg-transparent text-white outline-none"
            placeholder="Enter command (or /ai <query> for AI assistance)"
            autoComplete="off"
          />
        </div>
      </form>
    </div>
  );
}; 