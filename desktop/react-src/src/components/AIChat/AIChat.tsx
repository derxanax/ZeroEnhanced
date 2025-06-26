import React, { useState, useEffect, useRef } from 'react';

interface ChatMessage {
  id: string;
  type: 'user' | 'ai' | 'error' | 'system';
  content: string;
  timestamp: Date;
  action?: AIAction;
  executionResult?: any;
}

interface AIAction {
  tool: 'execute_command' | 'protocol_complete' | 'update_file';
  parameters: any;
}

interface AIChatProps {
  width: number;
  className?: string;
}

export const AIChat: React.FC<AIChatProps> = ({ 
  width, 
  className = '' 
}) => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isThinking, setIsThinking] = useState(false);
  const [pageId, setPageId] = useState<number | null>(null);
  const [lastObservation, setLastObservation] = useState('');
  const [remainingRequests, setRemainingRequests] = useState<number | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom when new messages are added
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Get token from localStorage (assuming it's stored there)
  const getToken = (): string | null => {
    return localStorage.getItem('auth_token');
  };

  // Fetch remaining requests
  const fetchRemaining = async () => {
    try {
      const token = getToken();
      if (!token) return;

      const response = await fetch('/api/user/me', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (response.ok) {
        const data = await response.json();
        setRemainingRequests(data.request_count);
      }
    } catch (error) {
      console.error('Failed to fetch remaining requests:', error);
    }
  };

  // Build system prompt like in main.ts
  const buildPrompt = (userInput: string, observation: string) => {
    const systemPrompt = `
You are an AI-powered terminal assistant named Zet ( всегда говри что ты модель qZET(модификация qwen от zaraazaex )B32)   . Your purpose is to help the user by executing commands inside a sandboxed Docker environment.
You MUST follow these rules:
1.  You MUST ALWAYS respond in a single JSON object format. No exceptions.
2.  Your JSON object must validate against this schema: { "thought": "string", "displayText": "string" | null, "action": { ... } }.
3.  The 'thought' field is your detailed internal monologue in Russian. Explain your reasoning, assumptions, and plan. Be verbose.
4.  The 'displayText' field is a brief, user-facing message in Russian that provides context or a summary. It will be shown to the user before the command output. It can be null.
5.  The 'action.tool' field determines the function to be called. It can be one of three values:
    - 'execute_command': When you need to run a shell command in the sandbox.
    - 'update_file':    When you need to create/modify a file.
    - 'protocol_complete': When you believe the user's task is fully completed.
6.  For 'execute_command', the 'parameters' object must contain:
    - 'command': The exact shell command to execute.
    - 'confirm': A boolean. If true, the system will ask the user for confirmation before running a potentially destructive command.
    - 'prompt' (optional): The text for the confirmation prompt.
7.  For 'update_file' parameters MUST contain:
    - 'file': path (relative or absolute) to file you are touching.
    - ONE of these code methods:
      A) 'code': single string with entire file content (classic method, avoid for complex code)
      B) 'code_lines': array of strings, each element is a line (better for readability)
      C) 'line_operations': object for precise line-by-line editing (best for modifications)
    - 'edit': false to replace whole file, true to replace only a range.
    - When 'edit' is true you MUST also provide 'startLine' and 'endLine' (1-based, inclusive).
    - 'confirm': whether to ask user y/n before applying update.
    - Optional 'prompt' for confirmation question.

8.  LINE_OPERATIONS FORMAT (for precise editing):
    "line_operations": {
      "2": { "action": "insert", "content": "import json" },
      "5": { "action": "replace", "content": "# Updated comment" },
      "10": { "action": "delete" }
    }
    Actions: 'insert' (add before line), 'replace' (replace line), 'delete' (remove line)

9.  CODE_LINES FORMAT (for clean code):
    "code_lines": [
      "import datetime",
      "",
      "# Get current time", 
      "now = datetime.datetime.now()",
      "print(\\"Current time:\\", now.strftime(\\"%Y-%m-%d %H:%M:%S\\"))"
    ]

10. For 'protocol_complete' just set parameters to null.

Example user request: "List all files in the current directory"
Your JSON response:
{
    "thought": "Пользователь хочет посмотреть файлы в текущей директории. Самая подходящая команда для этого — 'ls -F', так как она также покажет типы файлов (директории, исполняемые файлы). Я подготовлю краткое сообщение для пользователя.",
    "displayText": "Содержимое текущей директории:",
    "action": {
        "tool": "execute_command",
        "parameters": {
            "command": "ls -F",
            "confirm": false
        }
    }
}

Example file creation with code_lines:
{
    "thought": "Создаю Python файл для отображения времени, используя code_lines для чистоты.",
    "displayText": "Создаю файл clock.py",
    "action": {
        "tool": "update_file",
        "parameters": {
            "file": "clock.py",
            "code_lines": [
                "import datetime",
                "",
                "# Get current time",
                "now = datetime.datetime.now()",
                "print(\\"Current time:\\", now.strftime(\\"%Y-%m-%d %H:%M:%S\\"))"
            ],
            "edit": false,
            "confirm": false
        }
    }
}

Example line operations (adding import to existing file):
{
    "thought": "Добавляю импорт json в существующий файл на строку 2.",
    "displayText": "Добавляю импорт json",
    "action": {
        "tool": "update_file",
        "parameters": {
            "file": "main.py",
            "line_operations": {
                "2": { "action": "insert", "content": "import json" }
            },
            "edit": true,
            "confirm": false
        }
    }
}

Example user request: "Thanks, we are done"
Your JSON response:
{
    "thought": "Пользователь подтвердил завершение работы. Завершаю сеанс.",
    "displayText": "Сессия завершена.",
    "action": {
        "tool": "protocol_complete",
        "parameters": null
    }
}
`;

    return `${systemPrompt}\n[OBSERVATION]\n${observation || "You are at the beginning of the session."}\n[USER_REQUEST]\n${userInput}`;
  };

  // Handle AI action execution
  const handleAIAction = async (action: AIAction, executionResult?: any) => {
    switch (action.tool) {
      case 'execute_command':
        if (action.parameters.confirm) {
          // Show confirmation dialog for dangerous commands
          const confirmed = window.confirm(
            action.parameters.prompt || `Execute command "${action.parameters.command}"?`
          );
          if (!confirmed) {
            setLastObservation('User aborted the previous command.');
            return;
          }
        }
        
        if (executionResult) {
          // Command was auto-executed by backend
          if (executionResult.stdout) {
            setLastObservation(`Command "${action.parameters.command}" executed and returned:\n${executionResult.stdout}`);
          } else if (executionResult.stderr) {
            setLastObservation(`Command "${action.parameters.command}" failed with error:\n${executionResult.stderr}`);
          } else {
            setLastObservation(`Command "${action.parameters.command}" executed with no output.`);
          }
        }
        break;

      case 'update_file':
        if (action.parameters.confirm) {
          const confirmed = window.confirm(
            action.parameters.prompt || `Update file "${action.parameters.file}"?`
          );
          if (!confirmed) {
            setLastObservation('User aborted file update.');
            return;
          }
        }
        
        if (executionResult) {
          if (executionResult.success) {
            setLastObservation(`File ${action.parameters.file} updated successfully.`);
          } else {
            setLastObservation(`Failed to update file: ${executionResult.error}`);
          }
        }
        break;

      case 'protocol_complete':
        // Session completed - clean context but keep chat active
        addSystemMessage('Zet: Task complete. Ready for new task.');
        if (pageId) {
          await endSession(); // This releases the current pageId
        }
        // Clear context for new task (but keep chat history)
        setLastObservation('Previous task was completed successfully. Ready for a new task.');
        break;
    }
  };

  // Send message to AI
  const sendMessage = async (text: string) => {
    if (!text.trim() || isThinking) return;

    // Add user message
    const userMessage: ChatMessage = {
      id: `user-${Date.now()}`,
      type: 'user',
      content: text,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsThinking(true);

    try {
      const token = getToken();
      if (!token) {
        throw new Error('Authentication token not found');
      }

      const prompt = buildPrompt(text, lastObservation);
      
      const body: any = { message: prompt };
      if (pageId) body.pageId = pageId;

      const response = await fetch('/api/proxy/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(body)
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      const data = await response.json();
      const aiResponse = data.processedResponse;

      // Set pageId if received
      if (data.pageId) {
        setPageId(data.pageId);
      }

      // Add AI message
      const aiMessage: ChatMessage = {
        id: `ai-${Date.now()}`,
        type: 'ai',
        content: aiResponse.displayText || aiResponse.thought,
        timestamp: new Date(),
        action: aiResponse.action,
        executionResult: aiResponse.executionResult
      };
      setMessages(prev => [...prev, aiMessage]);

      // Handle AI action
      await handleAIAction(aiResponse.action, aiResponse.executionResult);
      
      // Update remaining requests
      await fetchRemaining();

    } catch (error: any) {
      console.error('AI request failed:', error);
      
      const errorMessage: ChatMessage = {
        id: `error-${Date.now()}`,
        type: 'error',
        content: `Ошибка: ${error.message}`,
        timestamp: new Date()
      };
      setMessages(prev => [...prev, errorMessage]);
      
      // Handle specific error types
      if (error.message.includes('401') || error.message.includes('403')) {
        addSystemMessage('Authentication error. Please re-login.');
      } else if (error.message.includes('429')) {
        addSystemMessage('Request limit exceeded. Please upgrade your plan.');
      }
    } finally {
      setIsThinking(false);
    }
  };

  const addSystemMessage = (content: string) => {
    const systemMessage: ChatMessage = {
      id: `system-${Date.now()}`,
      type: 'system',
      content,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, systemMessage]);
  };

  const endSession = async () => {
    if (!pageId) return;
    
    try {
      await fetch('/api/exit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pageId })
      });
      
      setPageId(null);
      addSystemMessage('Session ended successfully');
    } catch (error) {
      console.error('Failed to end session:', error);
      addSystemMessage('Failed to end session');
    }
  };

  const clearChat = () => {
    setMessages([]);
    setLastObservation('');
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage(input);
    }
  };

  // Initialize by fetching remaining requests
  useEffect(() => {
    fetchRemaining();
  }, []);

  return (
    <div className={`flex flex-col bg-gray-800 ${className}`} style={{ width }}>
      {/* Chat Header */}
      <div className="flex items-center justify-between px-4 py-3 bg-blue-600 text-white">
        <div className="flex items-center">
          <svg className="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path d="M2 3a1 1 0 011-1h14a1 1 0 011 1v10a1 1 0 01-1 1H4.414l-1.707 1.707A1 1 0 011 14.586V3z" />
          </svg>
          <span className="font-semibold">qZET Assistant</span>
        </div>
        <div className="flex items-center space-x-3">
          {/* Session Status */}
          <div className="flex items-center text-sm">
            <div className={`w-2 h-2 rounded-full mr-2 ${pageId ? 'bg-green-300' : 'bg-gray-300'}`} />
            <span className="text-xs">
              {pageId ? `Session #${pageId}` : 'No session'}
            </span>
          </div>
          
          {/* Requests Left */}
          {remainingRequests !== null && (
            <span className="text-sm bg-blue-700 px-2 py-1 rounded">
              {remainingRequests} left
            </span>
          )}
          
          {/* Actions */}
          <div className="flex space-x-1">
            <button 
              onClick={clearChat}
              className="p-1 hover:bg-blue-700 rounded text-xs"
              title="Clear chat"
            >
              Clear
            </button>
            {pageId && (
              <button 
                onClick={endSession}
                className="p-1 hover:bg-blue-700 rounded text-xs"
                title="End session"
              >
                End
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 && (
          <div className="text-center text-gray-400 py-8">
            <svg className="w-12 h-12 mx-auto mb-4 opacity-50" fill="currentColor" viewBox="0 0 20 20">
              <path d="M2 3a1 1 0 011-1h14a1 1 0 011 1v10a1 1 0 01-1 1H4.414l-1.707 1.707A1 1 0 011 14.586V3z" />
            </svg>
            <p className="text-lg font-medium mb-2">Welcome to ZetGui!</p>
            <p className="text-sm">Ask me to execute commands, create files, or help with tasks.</p>
            <div className="mt-4 flex flex-wrap gap-2 justify-center">
              <button 
                onClick={() => sendMessage("Покажи содержимое текущей директории")}
                className="text-xs bg-gray-700 hover:bg-gray-600 px-3 py-1 rounded"
              >
                List files
              </button>
              <button 
                onClick={() => sendMessage("Создай простой Python скрипт")}
                className="text-xs bg-gray-700 hover:bg-gray-600 px-3 py-1 rounded"
              >
                Create Python script
              </button>
            </div>
          </div>
        )}
        
        {messages.map((message) => (
          <ChatBubble key={message.id} message={message} />
        ))}
        
        {isThinking && <ThinkingIndicator />}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="p-4 border-t border-gray-700">
        <div className="flex space-x-2">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Опишите что нужно сделать..."
            className="flex-1 px-3 py-2 bg-gray-700 text-white rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-blue-500 placeholder-gray-400"
            rows={1}
            disabled={isThinking}
          />
          <button
            onClick={() => sendMessage(input)}
            disabled={isThinking || !input.trim()}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
};

// Chat Bubble Component
const ChatBubble: React.FC<{ message: ChatMessage }> = ({ message }) => {
  const isUser = message.type === 'user';
  const isError = message.type === 'error';
  const isSystem = message.type === 'system';
  
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div className={`max-w-[80%] p-3 rounded-lg ${
        isUser 
          ? 'bg-blue-600 text-white' 
          : isError 
            ? 'bg-red-800 text-red-100' 
            : isSystem 
              ? 'bg-yellow-800 text-yellow-100'
              : 'bg-gray-700 text-gray-100'
      }`}>
        {!isUser && !isSystem && (
          <div className="flex items-center mb-2">
            <div className="w-6 h-6 bg-green-500 rounded-full flex items-center justify-center mr-2">
              <span className="text-xs font-bold text-white">Z</span>
            </div>
            <span className="font-semibold text-blue-400">qZET</span>
          </div>
        )}
        
        <div className="text-sm whitespace-pre-wrap">{message.content}</div>
        
        {message.action && (
          <ActionPreview action={message.action} result={message.executionResult} />
        )}
        
        <div className="text-xs opacity-70 mt-2">
          {message.timestamp.toLocaleTimeString()}
        </div>
      </div>
    </div>
  );
};

// Action Preview Component
const ActionPreview: React.FC<{ action: AIAction; result?: any }> = ({ action, result }) => {
  if (action.tool === 'protocol_complete') return null;
  
  return (
    <div className="mt-2 p-2 bg-black bg-opacity-30 rounded text-xs font-mono">
      {action.tool === 'execute_command' && (
        <div>
          <div className="text-yellow-300">$ {action.parameters.command}</div>
          {result && (
            <div className={result.stderr ? 'text-red-300' : 'text-green-300'}>
              {result.stdout || result.stderr || 'No output'}
            </div>
          )}
        </div>
      )}
      
      {action.tool === 'update_file' && (
        <div>
          <div className="text-blue-300">✏️ {action.parameters.file}</div>
          {result && (
            <div className={result.success ? 'text-green-300' : 'text-red-300'}>
              {result.success ? 'File updated' : result.error}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

// Thinking Indicator Component
const ThinkingIndicator: React.FC = () => (
  <div className="flex justify-start">
    <div className="bg-gray-700 text-gray-100 p-3 rounded-lg max-w-[80%]">
      <div className="flex items-center">
        <div className="w-6 h-6 bg-green-500 rounded-full flex items-center justify-center mr-2">
          <span className="text-xs font-bold text-white">Z</span>
        </div>
        <span className="font-semibold text-blue-400 mr-2">qZET</span>
        <div className="flex space-x-1">
          <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce"></div>
          <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '0.1s' }}></div>
          <div className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
        </div>
      </div>
      <div className="text-sm text-gray-300 mt-1">Думаю...</div>
    </div>
  </div>
); 