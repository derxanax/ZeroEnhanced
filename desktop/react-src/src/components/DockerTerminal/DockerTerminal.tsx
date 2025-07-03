import React, { useEffect, useRef, useState } from 'react';
import { useApp } from '../../context/AppContext';

interface Command {
  input: string;
  output: string;
  timestamp: Date;
  isError: boolean;
}

export const DockerTerminal: React.FC = () => {
  const { aiService } = useApp();
  const [commands, setCommands] = useState<Command[]>([]);
  const [currentInput, setCurrentInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const terminalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
    ensureSandbox();
  }, []);

  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [commands]);

  const ensureSandbox = async () => {
    if (!aiService.isReady()) return;

    try {
      await aiService.ensureSandbox();
      addCommand({
        input: 'system',
        output: '🐳 Docker sandbox is ready',
        timestamp: new Date(),
        isError: false
      });
    } catch (error) {
      addCommand({
        input: 'system',
        output: `❌ Failed to initialize Docker sandbox: ${error instanceof Error ? error.message : 'Unknown error'}`,
        timestamp: new Date(),
        isError: true
      });
    }
  };

  const addCommand = (command: Command) => {
    setCommands(prev => [...prev, command]);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!currentInput.trim() || isLoading) return;

    const input = currentInput.trim();
    setCurrentInput('');
    setIsLoading(true);

    try {
      const result = await aiService.executeCommand(input);
      const output = result.stdout || result.stderr || 'Command executed';

      addCommand({
        input,
        output,
        timestamp: new Date(),
        isError: !!result.stderr
      });
    } catch (error) {
      addCommand({
        input,
        output: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
        timestamp: new Date(),
        isError: true
      });
    } finally {
      setIsLoading(false);
    }
  };

  const formatTimestamp = (date: Date) => {
    return date.toLocaleTimeString();
  };

  const clearTerminal = () => {
    setCommands([]);
  };

  return (
    <div className="h-full bg-gray-900 text-green-400 font-mono text-sm flex flex-col">
      <div className="bg-gray-800 px-4 py-2 border-b border-gray-700 flex items-center justify-between">
        <h3 className="text-white font-semibold">🐳 Docker Terminal</h3>
        <div className="flex items-center space-x-2">
          <button
            onClick={clearTerminal}
            className="px-2 py-1 text-xs text-gray-400 hover:text-white transition-colors"
          >
            Clear
          </button>
          <button
            onClick={ensureSandbox}
            className="px-2 py-1 text-xs text-gray-400 hover:text-white transition-colors"
          >
            Restart
          </button>
        </div>
      </div>

      <div
        ref={terminalRef}
        className="flex-1 overflow-y-auto p-4 space-y-2"
      >
        {commands.map((command, index) => (
          <div key={index} className="space-y-1">
            {command.input !== 'system' && (
              <div className="flex items-center space-x-2">
                <span className="text-blue-400">$</span>
                <span className="text-white">{command.input}</span>
                <span className="text-gray-500 text-xs">
                  [{formatTimestamp(command.timestamp)}]
                </span>
              </div>
            )}
            {command.output && (
              <div className={`pl-4 whitespace-pre-wrap ${command.isError ? 'text-red-400' :
                command.input === 'system' ? 'text-yellow-400' : 'text-gray-300'
                }`}>
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

        {commands.length === 0 && (
          <div className="text-gray-500">
            <p>🐳 Docker Terminal - Ready for commands</p>
            <p className="text-sm mt-2">Type Docker commands to execute in the sandbox environment</p>
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
            placeholder="Enter Docker command..."
            autoComplete="off"
          />
        </div>
      </form>
    </div>
  );
}; 