import React, { useEffect, useRef, useState } from 'react';
import { AIService } from '../../services/AIService';

interface Message {
  id: string;
  type: 'user' | 'ai' | 'system';
  content: string;
  thought?: string;
  displayText?: string;
  action?: any;
  executionResult?: any;
  timestamp: Date;
  streaming?: boolean;
}

interface AIChatProps {
  authToken: string;
}

const AIChat: React.FC<AIChatProps> = ({ authToken }) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isStreaming, setIsStreaming] = useState(false);
  const [aiService] = useState(() => new AIService());
  const [isInitialized, setIsInitialized] = useState(false);
  const [currentStreamId, setCurrentStreamId] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const initializeAI = async () => {
      try {
        await aiService.init(authToken);
        await aiService.ensureSandbox();
        setIsInitialized(true);

        setMessages([{
          id: 'welcome',
          type: 'system',
          content: '🚀 Zet Enhanced готов к работе! Поддержка стриминга активирована. Теперь вы можете видеть ответы ИИ в реальном времени!',
          timestamp: new Date()
        }]);
      } catch (error) {
        console.error('Failed to initialize AI:', error);
        setMessages([{
          id: 'error',
          type: 'system',
          content: '❌ Ошибка инициализации AI Service. Проверьте токен авторизации.',
          timestamp: new Date()
        }]);
      }
    };

    if (authToken) {
      initializeAI();
    }
  }, [authToken, aiService]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const generateId = () => Math.random().toString(36).substr(2, 9);

  const handleSendMessage = async () => {
    if (!inputValue.trim() || isLoading || !isInitialized) return;

    const userMessageId = generateId();
    const aiMessageId = generateId();
    const messageText = inputValue.trim();

    const userMessage: Message = {
      id: userMessageId,
      type: 'user',
      content: messageText,
      timestamp: new Date()
    };

    const initialAiMessage: Message = {
      id: aiMessageId,
      type: 'ai',
      content: '',
      timestamp: new Date(),
      streaming: true
    };

    setMessages(prev => [...prev, userMessage, initialAiMessage]);
    setInputValue('');
    setIsLoading(true);
    setIsStreaming(true);
    setCurrentStreamId(aiMessageId);

    try {
      let streamedContent = '';

      const aiResponse = await aiService.sendMessage(messageText, (chunk: string) => {
        streamedContent += chunk;

        setMessages(prev => prev.map(msg =>
          msg.id === aiMessageId
            ? { ...msg, content: streamedContent }
            : msg
        ));
      });

      setMessages(prev => prev.map(msg =>
        msg.id === aiMessageId
          ? {
            ...msg,
            content: streamedContent,
            thought: aiResponse.thought,
            displayText: aiResponse.displayText,
            action: aiResponse.action,
            executionResult: aiResponse.executionResult,
            streaming: false
          }
          : msg
      ));

      await handleAIAction(aiResponse, aiMessageId);

    } catch (error) {
      console.error('Error sending message:', error);

      setMessages(prev => prev.map(msg =>
        msg.id === aiMessageId
          ? {
            ...msg,
            content: `❌ Ошибка: ${error instanceof Error ? error.message : 'Неизвестная ошибка'}`,
            streaming: false
          }
          : msg
      ));
    } finally {
      setIsLoading(false);
      setIsStreaming(false);
      setCurrentStreamId(null);
      inputRef.current?.focus();
    }
  };

  const handleAIAction = async (aiResponse: any, messageId: string) => {
    const { action } = aiResponse;

    if (!action || action.tool === 'protocol_complete') {
      return;
    }

    const actionMessageId = generateId();

    if (action.tool === 'execute_command') {
      const { command, confirm } = action.parameters;

      if (confirm) {
        const shouldExecute = window.confirm(`Выполнить команду: ${command}?`);
        if (!shouldExecute) {
          setMessages(prev => [...prev, {
            id: actionMessageId,
            type: 'system',
            content: '❌ Выполнение команды отменено пользователем',
            timestamp: new Date()
          }]);
          return;
        }
      }

      setMessages(prev => [...prev, {
        id: actionMessageId,
        type: 'system',
        content: `⚡ Выполняю команду: ${command}`,
        timestamp: new Date()
      }]);

      try {
        const result = await aiService.executeCommand(command);

        const resultContent = result.stdout || result.stderr || 'Команда выполнена без вывода';
        const resultType = result.stderr ? '🔥 Ошибка:' : '📤 Результат:';

        setMessages(prev => [...prev, {
          id: generateId(),
          type: 'system',
          content: `${resultType}\n${resultContent}`,
          timestamp: new Date()
        }]);
      } catch (error) {
        setMessages(prev => [...prev, {
          id: generateId(),
          type: 'system',
          content: `❌ Ошибка выполнения команды: ${error instanceof Error ? error.message : 'Неизвестная ошибка'}`,
          timestamp: new Date()
        }]);
      }
    }

    else if (action.tool === 'update_file') {
      const { file, confirm } = action.parameters;

      if (confirm) {
        const shouldUpdate = window.confirm(`Обновить файл: ${file}?`);
        if (!shouldUpdate) {
          setMessages(prev => [...prev, {
            id: actionMessageId,
            type: 'system',
            content: '❌ Обновление файла отменено пользователем',
            timestamp: new Date()
          }]);
          return;
        }
      }

      setMessages(prev => [...prev, {
        id: actionMessageId,
        type: 'system',
        content: `📝 Обновляю файл: ${file}`,
        timestamp: new Date()
      }]);

      try {
        const result = await aiService.updateFile(action.parameters);

        const resultMessage = result.success
          ? `✅ Файл ${file} успешно обновлен`
          : `❌ Ошибка обновления файла: ${result.error}`;

        setMessages(prev => [...prev, {
          id: generateId(),
          type: 'system',
          content: resultMessage,
          timestamp: new Date()
        }]);
      } catch (error) {
        setMessages(prev => [...prev, {
          id: generateId(),
          type: 'system',
          content: `❌ Ошибка обновления файла: ${error instanceof Error ? error.message : 'Неизвестная ошибка'}`,
          timestamp: new Date()
        }]);
      }
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const formatTimestamp = (date: Date) => {
    return date.toLocaleTimeString('ru-RU', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  const renderMessage = (message: Message) => {
    const isUser = message.type === 'user';
    const isSystem = message.type === 'system';

    return (
      <div
        key={message.id}
        className={`mb-6 ${isUser ? 'flex justify-end' : 'flex justify-start'}`}
      >
        <div
          className={`max-w-[80%] rounded-lg p-4 ${isUser
            ? 'bg-blue-500 text-white'
            : isSystem
              ? 'bg-gray-100 text-gray-800 border-l-4 border-yellow-400'
              : 'bg-gray-50 text-gray-800 border border-gray-200'
            }`}
        >
          <div className="flex items-center justify-between mb-2">
            <span className={`text-sm font-medium ${isUser ? 'text-blue-100' : isSystem ? 'text-gray-600' : 'text-blue-600'
              }`}>
              {isUser ? '👤 Вы' : isSystem ? '🔧 Система' : '🤖 Zet Enhanced'}
              {message.streaming && (
                <span className="ml-2 text-xs animate-pulse">⚡ стриминг...</span>
              )}
            </span>
            <span className={`text-xs ${isUser ? 'text-blue-200' : 'text-gray-500'
              }`}>
              {formatTimestamp(message.timestamp)}
            </span>
          </div>

          {message.thought && (
            <div className="mb-3 p-3 bg-purple-50 border border-purple-200 rounded text-sm">
              <div className="font-medium text-purple-700 mb-1">💭 Размышления ИИ:</div>
              <div className="text-purple-600 whitespace-pre-wrap">{message.thought}</div>
            </div>
          )}

          {message.displayText && (
            <div className="mb-3 p-3 bg-blue-50 border border-blue-200 rounded text-sm">
              <div className="font-medium text-blue-700 mb-1">📝 Действие:</div>
              <div className="text-blue-600">{message.displayText}</div>
            </div>
          )}

          <div className="whitespace-pre-wrap break-words">
            {message.content}
            {message.streaming && message.id === currentStreamId && (
              <span className="inline-block w-2 h-5 bg-current animate-pulse ml-1">|</span>
            )}
          </div>

          {message.action && message.action.tool !== 'protocol_complete' && (
            <div className="mt-3 p-3 bg-gray-50 border border-gray-200 rounded text-sm">
              <div className="font-medium text-gray-700 mb-1">⚙️ Действие:</div>
              <div className="text-gray-600">
                <strong>{message.action.tool}</strong>
                {message.action.parameters && (
                  <pre className="mt-1 text-xs bg-gray-100 p-2 rounded overflow-x-auto">
                    {JSON.stringify(message.action.parameters, null, 2)}
                  </pre>
                )}
              </div>
            </div>
          )}

          {message.executionResult && (
            <div className="mt-3 p-3 bg-green-50 border border-green-200 rounded text-sm">
              <div className="font-medium text-green-700 mb-1">✅ Результат выполнения:</div>
              <pre className="text-green-600 text-xs bg-green-100 p-2 rounded overflow-x-auto whitespace-pre-wrap">
                {JSON.stringify(message.executionResult, null, 2)}
              </pre>
            </div>
          )}
        </div>
      </div>
    );
  };

  if (!isInitialized) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
          <p className="text-gray-600">Инициализация AI Enhanced...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full bg-white">
      <div className="bg-gradient-to-r from-blue-500 to-purple-600 text-white p-4 shadow-lg">
        <h2 className="text-xl font-bold flex items-center">
          🚀 Zet Enhanced Chat
          {isStreaming && (
            <span className="ml-3 text-sm bg-white/20 px-2 py-1 rounded-full animate-pulse">
              ⚡ Стриминг активен
            </span>
          )}
        </h2>
        <p className="text-blue-100 text-sm mt-1">
          Интеллектуальный помощник с поддержкой стриминга в реальном времени
        </p>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map(renderMessage)}
        <div ref={messagesEndRef} />
      </div>

      <div className="border-t bg-gray-50 p-4">
        <div className="flex space-x-3">
          <input
            ref={inputRef}
            type="text"
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder={isLoading ? "ИИ обрабатывает запрос..." : "Введите ваш запрос..."}
            disabled={isLoading}
            className="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-100 disabled:cursor-not-allowed"
          />
          <button
            onClick={handleSendMessage}
            disabled={isLoading || !inputValue.trim()}
            className="bg-blue-500 hover:bg-blue-600 disabled:bg-gray-300 disabled:cursor-not-allowed text-white px-6 py-2 rounded-lg font-medium transition-colors duration-200 flex items-center space-x-2"
          >
            {isLoading ? (
              <>
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                <span>Отправка</span>
              </>
            ) : (
              <>
                <span>Отправить</span>
                <span>🚀</span>
              </>
            )}
          </button>
        </div>

        {isStreaming && (
          <div className="mt-2 text-xs text-gray-500 flex items-center">
            <div className="animate-pulse h-2 w-2 bg-green-500 rounded-full mr-2"></div>
            Получение ответа в реальном времени...
          </div>
        )}
      </div>
    </div>
  );
};

export default AIChat; 