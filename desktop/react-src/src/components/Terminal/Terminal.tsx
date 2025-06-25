import React, { useState, useRef, useEffect } from 'react';
import { useApp } from '../../context/AppContext';

//* компактный терминал для IDE
export const Terminal: React.FC = () => {
  const { aiService, dockerService, isInitialized } = useApp();
  const [input, setInput] = useState('');
  const [history, setHistory] = useState<Array<{ type: 'input' | 'output' | 'thinking' | 'error', content: string }>>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [currentPageId, setCurrentPageId] = useState<number | null>(null);
  const [isExpanded, setIsExpanded] = useState(true);
  
  const terminalRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Прокрутка терминала вниз при добавлении новых сообщений
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [history]);

  // Фокус на поле ввода при клике на терминал
  const handleTerminalClick = () => {
    if (inputRef.current) {
      inputRef.current.focus();
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!input.trim()) return;
    
    const userInput = input;
    setInput('');
    setHistory(prev => [...prev, { type: 'input', content: `> ${userInput}` }]);
    
    // Проверяем инициализацию
    if (!isInitialized) {
      setHistory(prev => [...prev, { 
        type: 'error', 
        content: 'System is not initialized. Please wait for initialization to complete.' 
      }]);
      return;
    }
    
    setIsProcessing(true);

    try {
      setHistory(prev => [...prev, { type: 'thinking', content: 'Zet is thinking...' }]);
      
      // Получаем последнее наблюдение для контекста
      const lastObservation = history
        .filter(item => item.type === 'output' || item.type === 'error')
        .map(item => item.content)
        .slice(-3)
        .join('\n');
      
      // Получаем ответ от AI
      const { ai: aiResponse, pageId } = await aiService.getCommand(
        userInput, 
        lastObservation, 
        currentPageId || undefined
      );
      
      if (pageId) {
        setCurrentPageId(pageId);
      }
      
      // Отображаем мысли AI
      setHistory(prev => [...prev.filter(item => item.type !== 'thinking'), 
        { type: 'output', content: `💭 ${aiResponse.thought}` }
      ]);
      
      // Отображаем сообщение для пользователя, если есть
      if (aiResponse.displayText) {
        setHistory(prev => [...prev, { type: 'output', content: aiResponse.displayText || '' }]);
      }
      
      // Обрабатываем действие AI
      const { tool, parameters } = aiResponse.action;
      
      if (tool === 'protocol_complete') {
        setHistory(prev => [...prev, { type: 'output', content: '✅ Task complete. Ending session.' }]);
        return;
      }
      
      if (tool === 'execute_command' && parameters && 'command' in parameters) {
        const cmdParams = parameters as { command: string; confirm: boolean; prompt?: string };
        
        setHistory(prev => [...prev, { type: 'output', content: `⚡ Executing: ${cmdParams.command}` }]);
        
        try {
          const { stdout, stderr } = await dockerService.executeCommand(cmdParams.command);
          
          if (stdout) {
            setHistory(prev => [...prev, { type: 'output', content: stdout }]);
          }
          
          if (stderr) {
            setHistory(prev => [...prev, { type: 'error', content: stderr }]);
          }
          
          if (!stdout && !stderr) {
            setHistory(prev => [...prev, { type: 'output', content: 'Command executed with no output.' }]);
          }
        } catch (error) {
          setHistory(prev => [...prev, { 
            type: 'error', 
            content: `❌ Command execution failed: ${error instanceof Error ? error.message : 'Unknown error'}` 
          }]);
        }
      }
      
    } catch (error) {
      setHistory(prev => [...prev.filter(item => item.type !== 'thinking'), { 
        type: 'error', 
        content: `❌ Error: ${error instanceof Error ? error.message : 'Unknown error'}` 
      }]);
    } finally {
      setIsProcessing(false);
    }
  };

  const clearTerminal = () => {
    setHistory([]);
  };

  return (
    <div className="bg-dark-800 border-t border-dark-500 flex flex-col">
      {/* Заголовок терминала */}
      <div className="flex items-center justify-between px-4 py-2 border-b border-dark-500">
        <div className="flex items-center space-x-2">
          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className="text-dark-400 hover:text-dark-200 transition-colors"
          >
            {isExpanded ? '🔽' : '🔼'}
          </button>
          <span className="text-sm font-semibold text-dark-200">Terminal</span>
          <div className="flex items-center space-x-1">
            <div className={`w-2 h-2 rounded-full ${isInitialized ? 'bg-green-500' : 'bg-yellow-500'}`}></div>
            <span className="text-xs text-dark-400">
              {isInitialized ? 'Ready' : 'Initializing...'}
            </span>
          </div>
        </div>
        
        <div className="flex items-center space-x-2">
          <button
            onClick={clearTerminal}
            className="text-xs text-dark-400 hover:text-dark-200 transition-colors"
          >
            🗑️ Clear
          </button>
        </div>
      </div>

      {isExpanded && (
        <>
          {/* Вывод терминала */}
          <div 
            className="flex-1 p-4 overflow-y-auto font-mono text-sm max-h-64 min-h-32"
            ref={terminalRef}
            onClick={handleTerminalClick}
          >
            {history.length === 0 && (
              <div className="text-dark-500 text-xs">
                Welcome to ZetGui Terminal! Type your commands here...
              </div>
            )}
            
            {history.map((entry, index) => (
              <div key={index} className={`mb-1 ${
                entry.type === 'input' ? 'text-accent' :
                entry.type === 'error' ? 'text-red-400' :
                entry.type === 'thinking' ? 'text-yellow-400 italic' :
                'text-dark-200'
              }`}>
                {entry.content}
              </div>
            ))}
            
            {isProcessing && (
              <div className="text-yellow-400 animate-pulse">Processing...</div>
            )}
          </div>
          
          {/* Поле ввода */}
          <form onSubmit={handleSubmit} className="flex items-center p-4 border-t border-dark-500">
            <span className="text-accent mr-2 font-mono">&gt;</span>
            <input
              ref={inputRef}
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              disabled={isProcessing || !isInitialized}
              className="flex-1 bg-transparent text-dark-200 font-mono text-sm focus:outline-none placeholder-dark-500"
              placeholder={isInitialized ? "Type your command..." : "Initializing..."}
            />
            {isProcessing && (
              <div className="ml-2 text-yellow-400 text-xs">⏳</div>
            )}
          </form>
        </>
      )}
    </div>
  );
}; 