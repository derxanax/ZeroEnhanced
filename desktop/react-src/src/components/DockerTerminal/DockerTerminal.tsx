import React, { useState, useEffect, useRef } from 'react';

interface TerminalEntry {
  id: string;
  type: 'input' | 'output' | 'error';
  content: string;
  timestamp: Date;
}

interface DockerTerminalProps {
  className?: string;
  sessionId?: string;
}

export const DockerTerminal: React.FC<DockerTerminalProps> = ({ 
  className = '', 
  sessionId = 'default' 
}) => {
  const [history, setHistory] = useState<TerminalEntry[]>([]);
  const [currentCommand, setCurrentCommand] = useState('');
  const [isExecuting, setIsExecuting] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);
  const terminalRef = useRef<HTMLDivElement>(null);

  // WebSocket connection для real-time команд
  useEffect(() => {
    const connectWebSocket = () => {
      const ws = new WebSocket('ws://localhost:8080');
      wsRef.current = ws;

      ws.onopen = () => {
        setIsConnected(true);
        addSystemMessage('Connected to Docker terminal');
      };

      ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.type === 'command_result') {
          const outputContent = data.stdout || data.stderr || 'Command completed with no output';
          const isError = !!data.stderr || !data.success;
          
          setHistory(prev => [...prev, {
            id: `output-${Date.now()}`,
            type: isError ? 'error' : 'output',
            content: outputContent,
            timestamp: new Date()
          }]);
          
          setIsExecuting(false);
        }
      };

      ws.onclose = () => {
        setIsConnected(false);
        addSystemMessage('Disconnected from Docker terminal');
        
        // Попытка переподключения через 3 секунды
        setTimeout(connectWebSocket, 3000);
      };

      ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        addSystemMessage('WebSocket connection error');
      };
    };

    connectWebSocket();

    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, []);

  // Auto-scroll to bottom when new entries are added
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [history]);

  const addSystemMessage = (message: string) => {
    setHistory(prev => [...prev, {
      id: `system-${Date.now()}`,
      type: 'output',
      content: `[SYSTEM] ${message}`,
      timestamp: new Date()
    }]);
  };

  const executeCommand = (command: string) => {
    if (!command.trim() || isExecuting || !isConnected) return;
    
    setIsExecuting(true);
    
    // Add command to history
    setHistory(prev => [...prev, {
      id: `input-${Date.now()}`,
      type: 'input',
      content: `$ ${command}`,
      timestamp: new Date()
    }]);

    // Send command via WebSocket
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({
        type: 'execute_command',
        command,
        sessionId
      }));
    } else {
      setIsExecuting(false);
      addSystemMessage('WebSocket not connected');
    }
  };

  const clearTerminal = () => {
    setHistory([]);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && currentCommand.trim()) {
      executeCommand(currentCommand);
      setCurrentCommand('');
    }
  };

  return (
    <div className={`flex flex-col bg-black text-green-400 ${className}`}>
      {/* Terminal Header */}
      <div className="flex items-center px-4 py-2 bg-gray-800 border-b border-gray-700">
        <div className="flex items-center">
          <svg className="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M2 3a1 1 0 00-1 1v12a1 1 0 001 1h16a1 1 0 001-1V4a1 1 0 00-1-1H2zm13.5 6a.5.5 0 01-.5.5h-4a.5.5 0 010-1h4a.5.5 0 01.5.5zM3.5 6.5a.5.5 0 01.707-.707L6.5 8.086 8.793 5.793a.5.5 0 11.707.707L7.207 8.793 9.5 11.086a.5.5 0 01-.707.707L6.5 9.5 4.207 11.793a.5.5 0 01-.707-.707L5.793 8.793 3.5 6.5z" clipRule="evenodd" />
          </svg>
          <span className="font-mono text-sm text-white">Docker Terminal</span>
        </div>
        
        <div className="ml-auto flex items-center space-x-3">
          {/* Connection Status */}
          <div className="flex items-center">
            <div className={`w-2 h-2 rounded-full mr-2 ${isConnected ? 'bg-green-400' : 'bg-red-400'}`} />
            <span className="text-xs text-gray-400">
              {isConnected ? 'Connected' : 'Disconnected'}
            </span>
          </div>
          
          {/* Clear Button */}
          <button
            onClick={clearTerminal}
            className="text-gray-400 hover:text-white text-xs px-2 py-1 bg-gray-700 rounded"
            title="Clear terminal"
          >
            Clear
          </button>
        </div>
      </div>

      {/* Terminal Content */}
      <div 
        ref={terminalRef}
        className="flex-1 overflow-y-auto p-4 font-mono text-sm"
      >
        {history.length === 0 && (
          <div className="text-gray-500 mb-2">
            Welcome to ZetGui Docker Terminal. Type commands to execute them in the sandbox.
          </div>
        )}
        
        {history.map((entry) => (
          <div key={entry.id} className="mb-1">
            <div className={`${
              entry.type === 'input' 
                ? 'text-white' 
                : entry.type === 'error' 
                  ? 'text-red-400' 
                  : 'text-green-400'
              }`}>
              {entry.content}
            </div>
          </div>
        ))}
        
        {isExecuting && (
          <div className="flex items-center text-yellow-400">
            <svg className="animate-spin -ml-1 mr-2 h-4 w-4" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Executing...
          </div>
        )}
      </div>

      {/* Command Input */}
      <div className="p-4 border-t border-gray-700">
        <div className="flex items-center">
          <span className="text-green-400 mr-2">$</span>
          <input
            type="text"
            value={currentCommand}
            onChange={(e) => setCurrentCommand(e.target.value)}
            onKeyPress={handleKeyPress}
            className="flex-1 bg-transparent text-green-400 outline-none placeholder-gray-500"
            placeholder={isConnected ? "Введите команду..." : "Waiting for connection..."}
            disabled={isExecuting || !isConnected}
          />
        </div>
      </div>
    </div>
  );
}; 