# 🎨 Этап 2: Frontend Layout переработка

## 📝 Цель
Полностью переработать layout для правильного размещения компонентов

## 🔍 Текущие проблемы layout

### ❌ Что не так сейчас:
- ИИ панель внизу экрана (должна быть справа)
- Терминал отсутствует (должен быть слева)
- Нет интеграции с Docker для выполнения команд
- FileExplorer занимает много места
- StatusBar не информативный

### ✅ Целевой layout:
```
┌─────────────────────────────────────────────────────────┐
│ Header: [Logo] [Status] [User] [Settings]              │
├─────────────────┬───────────────────┬───────────────────┤
│ FileExplorer    │ Terminal          │ AI Chat Panel     │
│ (200px width)   │ (flex-1)          │ (400px width)     │
│                 │                   │                   │
│ 📁 src/         │ $ docker exec...  │ 🤖 Zet: Привет!  │
│ 📁 docs/        │ output here       │ 👤 You: команда  │
│ 📄 README.md    │                   │ 🤖 Zet: Думаю... │
│                 │ [command input]   │                   │
│                 │                   │ [message input]   │
├─────────────────┴───────────────────┴───────────────────┤
│ Footer: [Docker Status] [Requests Left] [Version]      │
└─────────────────────────────────────────────────────────┘
```

## 🔄 Структура новых компонентов

### 1. `App.tsx` - Новый главный layout
```typescript
const App: React.FC = () => {
  const [selectedFile, setSelectedFile] = useState<string>('');
  const [aiSession, setAiSession] = useState<AISession | null>(null);
  const [terminalSession, setTerminalSession] = useState<string>('');

  return (
    <div className="h-screen flex flex-col bg-gray-900">
      {/* Header */}
      <Header />
      
      {/* Main Content */}
      <div className="flex-1 flex overflow-hidden">
        {/* File Explorer - Left */}
        <FileExplorer 
          width={200}
          onFileSelect={setSelectedFile}
        />
        
        {/* Terminal - Center */}  
        <DockerTerminal 
          className="flex-1"
          sessionId={terminalSession}
        />
        
        {/* AI Chat - Right */}
        <AIChat 
          width={400}
          session={aiSession}
          onSessionChange={setAiSession}
        />
      </div>
      
      {/* Footer */}
      <Footer />
    </div>
  );
};
```

### 2. `DockerTerminal.tsx` - Новый терминал компонент
```typescript
interface DockerTerminalProps {
  className?: string;
  sessionId: string;
}

export const DockerTerminal: React.FC<DockerTerminalProps> = ({ 
  className, 
  sessionId 
}) => {
  const [history, setHistory] = useState<TerminalEntry[]>([]);
  const [currentCommand, setCurrentCommand] = useState('');
  const [isExecuting, setIsExecuting] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);

  // WebSocket connection для real-time команд
  useEffect(() => {
    const ws = new WebSocket('ws://localhost:8080');
    wsRef.current = ws;

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === 'command_result') {
        setHistory(prev => [...prev, {
          type: 'output',
          content: data.stdout || data.stderr,
          timestamp: new Date(),
          isError: !!data.stderr
        }]);
        setIsExecuting(false);
      }
    };

    return () => ws.close();
  }, []);

  const executeCommand = (command: string) => {
    setIsExecuting(true);
    setHistory(prev => [...prev, {
      type: 'input',
      content: `$ ${command}`,
      timestamp: new Date()
    }]);

    wsRef.current?.send(JSON.stringify({
      command,
      sessionId
    }));
  };

  return (
    <div className={`flex flex-col bg-black text-green-400 ${className}`}>
      {/* Terminal Header */}
      <div className="flex items-center px-4 py-2 bg-gray-800 border-b border-gray-700">
        <TerminalIcon className="w-5 h-5 mr-2" />
        <span className="font-mono text-sm">Docker Terminal</span>
        <div className="ml-auto flex items-center space-x-2">
          <DockerStatus />
          <ClearButton onClick={clearTerminal} />
        </div>
      </div>

      {/* Terminal Content */}
      <div className="flex-1 overflow-y-auto p-4 font-mono text-sm">
        {history.map((entry, index) => (
          <TerminalLine key={index} entry={entry} />
        ))}
        {isExecuting && <LoadingSpinner />}
      </div>

      {/* Command Input */}
      <div className="p-4 border-t border-gray-700">
        <div className="flex items-center">
          <span className="text-green-400 mr-2">$</span>
          <input
            type="text"
            value={currentCommand}
            onChange={(e) => setCurrentCommand(e.target.value)}
            onKeyPress={(e) => {
              if (e.key === 'Enter' && currentCommand.trim()) {
                executeCommand(currentCommand);
                setCurrentCommand('');
              }
            }}
            className="flex-1 bg-transparent text-green-400 outline-none"
            placeholder="Введите команду..."
            disabled={isExecuting}
          />
        </div>
      </div>
    </div>
  );
};
```

### 3. `AIChat.tsx` - Новый чат компонент для ИИ
```typescript
interface AIChatProps {
  width: number;
  session: AISession | null;
  onSessionChange: (session: AISession | null) => void;
}

export const AIChat: React.FC<AIChatProps> = ({ 
  width, 
  session, 
  onSessionChange 
}) => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isThinking, setIsThinking] = useState(false);
  const [pageId, setPageId] = useState<number | null>(null);

  const sendMessage = async (text: string) => {
    if (!text.trim()) return;

    // Добавляем сообщение пользователя
    const userMessage: ChatMessage = {
      id: Date.now(),
      type: 'user',
      content: text,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsThinking(true);

    try {
      // Отправляем запрос к ИИ через backend
      const response = await fetch('/api/proxy/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${getToken()}`
        },
        body: JSON.stringify({
          message: buildPrompt(text, getLastObservation()),
          pageId: pageId || undefined
        })
      });

      const data = await response.json();
      const aiResponse = data.processedResponse;

      // Устанавливаем pageId если получили новый
      if (data.pageId) {
        setPageId(data.pageId);
      }

      // Добавляем ответ ИИ
      const aiMessage: ChatMessage = {
        id: Date.now() + 1,
        type: 'ai',
        content: aiResponse.displayText || aiResponse.thought,
        timestamp: new Date(),
        action: aiResponse.action,
        executionResult: aiResponse.executionResult
      };
      setMessages(prev => [...prev, aiMessage]);

      // Обрабатываем действие ИИ
      await handleAIAction(aiResponse.action, aiResponse.executionResult);

    } catch (error) {
      console.error('AI request failed:', error);
      // Показываем ошибку в чате
      const errorMessage: ChatMessage = {
        id: Date.now() + 1,
        type: 'error',
        content: `Ошибка: ${error.message}`,
        timestamp: new Date()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsThinking(false);
    }
  };

  const endSession = async () => {
    if (pageId) {
      try {
        await fetch('/api/exit', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ pageId })
        });
        setPageId(null);
        setMessages([]);
      } catch (error) {
        console.error('Failed to end session:', error);
      }
    }
  };

  return (
    <div className="flex flex-col bg-gray-800" style={{ width }}>
      {/* Chat Header */}
      <div className="flex items-center justify-between px-4 py-3 bg-blue-600 text-white">
        <div className="flex items-center">
          <AIIcon className="w-5 h-5 mr-2" />
          <span className="font-semibold">qZET Assistant</span>
        </div>
        <div className="flex items-center space-x-2">
          <SessionStatus pageId={pageId} />
          <button 
            onClick={endSession}
            className="p-1 hover:bg-blue-700 rounded"
            title="Завершить сессию"
          >
            <XIcon className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 && (
          <WelcomeMessage onQuickStart={sendMessage} />
        )}
        
        {messages.map((message) => (
          <ChatBubble key={message.id} message={message} />
        ))}
        
        {isThinking && <ThinkingIndicator />}
      </div>

      {/* Input */}
      <div className="p-4 border-t border-gray-700">
        <div className="flex space-x-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && sendMessage(input)}
            placeholder="Опишите что нужно сделать..."
            className="flex-1 px-3 py-2 bg-gray-700 text-white rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={isThinking}
          />
          <button
            onClick={() => sendMessage(input)}
            disabled={isThinking || !input.trim()}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            <SendIcon className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
};
```

## 🔧 Вспомогательные компоненты

### Header, Footer, ChatBubble, etc.
```typescript
// Header.tsx
export const Header: React.FC = () => (
  <div className="flex items-center justify-between px-6 py-3 bg-gray-800 border-b border-gray-700">
    <div className="flex items-center space-x-4">
      <ZetLogo className="w-8 h-8" />
      <span className="text-xl font-bold text-white">ZetGui</span>
    </div>
    <div className="flex items-center space-x-4">
      <ConnectionStatus />
      <UserProfile />
      <SettingsButton />
    </div>
  </div>
);

// ChatBubble.tsx - Красивые сообщения вместо TUI
export const ChatBubble: React.FC<{ message: ChatMessage }> = ({ message }) => {
  const isUser = message.type === 'user';
  
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div className={`max-w-[80%] p-3 rounded-lg ${
        isUser 
          ? 'bg-blue-600 text-white' 
          : 'bg-gray-700 text-gray-100'
      }`}>
        {!isUser && (
          <div className="flex items-center mb-2">
            <ZetAvatar className="w-6 h-6 mr-2" />
            <span className="font-semibold text-blue-400">qZET</span>
          </div>
        )}
        
        <p className="text-sm">{message.content}</p>
        
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
```

## 📱 Responsive Design
```css
/* Адаптивность для разных размеров экрана */
@media (max-width: 1024px) {
  .file-explorer {
    width: 150px;
  }
  .ai-chat {
    width: 300px;
  }
}

@media (max-width: 768px) {
  .main-layout {
    flex-direction: column;
  }
  .file-explorer,
  .ai-chat {
    width: 100%;
    height: 200px;
  }
}
```

## ✅ Результат этапа 2
После переработки layout:
- ✅ Терминал в центре для выполнения команд
- ✅ ИИ чат справа с красивым GUI
- ✅ FileExplorer слева (компактный)
- ✅ Proper header/footer
- ✅ Responsive design
- ✅ Real-time WebSocket терминал

---
**Следующий этап:** ИИ интеграция 