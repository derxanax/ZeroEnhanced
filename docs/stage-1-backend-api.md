# 🔧 Этап 1: Backend API расширение

## 📝 Цель
Расширить `/backend/src/server.ts` для поддержки всех функций CLI версии

## 🔍 Анализ текущего состояния

### ✅ Уже есть:
- `/api/auth/login` - авторизация
- `/api/auth/register` - регистрация  
- `/api/proxy/send` - отправка запросов к ИИ
- `/api/user/me` - информация о пользователе
- `/api/docker/ensure-sandbox` - создание контейнера
- `/api/docker/execute` - выполнение команд

### ❌ Отсутствует:
- `/api/exit` - завершение сессии (освобождение pageId)
- WebSocket для real-time терминала
- Управление файлами в sandbox
- Proper error handling как в main.ts

## 🚀 Новые эндпоинты

### 1. `/api/exit` - Завершение сессии
```typescript
app.post('/api/exit', async (req: Request, res: Response) => {
  try {
    const { pageId } = req.body;
    
    if (pageId) {
      // Отправляем запрос на освобождение pageId
      await axios.post(`${API_HOST}/api/exit`, 
        { pageId }, 
        { headers: { 'Authorization': req.headers.authorization } }
      );
    }
    
    res.json({ success: true, message: 'Session ended successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to end session' });
  }
});
```

### 2. `/api/files/*` - Управление файлами в sandbox
```typescript
// Создание/обновление файла
app.post('/api/files/update', async (req: Request, res: Response) => {
  const { file, code, edit, startLine, endLine } = req.body;
  // Логика как в main.ts для update_file
});

// Чтение файла из sandbox
app.get('/api/files/read', async (req: Request, res: Response) => {
  const { path } = req.query;
  // Чтение файла из sandbox
});

// Список файлов в sandbox
app.get('/api/files/list', async (req: Request, res: Response) => {
  // Список файлов и папок
});
```

### 3. WebSocket для терминала
```typescript
import { WebSocketServer } from 'ws';

const wss = new WebSocketServer({ port: 8080 });

wss.on('connection', (ws) => {
  ws.on('message', async (message) => {
    const { command, sessionId } = JSON.parse(message.toString());
    
    // Выполнение команды в Docker
    const result = await executeCommand(command);
    
    // Отправка результата обратно
    ws.send(JSON.stringify({
      type: 'command_result',
      sessionId,
      stdout: result.stdout,
      stderr: result.stderr
    }));
  });
});
```

## 🔄 Улучшения существующих эндпоинтов

### `/api/proxy/send` - Добавить обработку всех действий ИИ
```typescript
app.post('/api/proxy/send', async (req, res) => {
  try {
    const response = await axios.post(`${API_BASE_URL}/send`, req.body, {
      headers: { 'Authorization': req.headers.authorization }
    });
    
    const aiResponse = JSON.parse(response.data.response);
    
    // Обработка разных типов действий ИИ
    switch (aiResponse.action.tool) {
      case 'execute_command':
        // Автоматическое выполнение команды если confirm: false
        if (!aiResponse.action.parameters.confirm) {
          const cmdResult = await executeCommand(aiResponse.action.parameters.command);
          aiResponse.executionResult = cmdResult;
        }
        break;
        
      case 'update_file':
        // Автоматическое обновление файла если confirm: false
        if (!aiResponse.action.parameters.confirm) {
          const fileResult = await updateFile(aiResponse.action.parameters);
          aiResponse.executionResult = fileResult;
        }
        break;
        
      case 'protocol_complete':
        // Автоматическое завершение сессии
        if (response.data.pageId) {
          await axios.post(`${API_HOST}/api/exit`, 
            { pageId: response.data.pageId },
            { headers: { 'Authorization': req.headers.authorization } }
          );
        }
        break;
    }
    
    res.json({
      ...response.data,
      processedResponse: aiResponse
    });
  } catch (error) {
    // Improved error handling like in main.ts
    handleAPIError(error, res);
  }
});
```

## 🛡️ Error Handling как в main.ts

### Функция для обработки ошибок API
```typescript
function handleAPIError(error: any, res: Response) {
  if (axios.isAxiosError(error) && error.response) {
    const status = error.response.status;
    
    switch (status) {
      case 401:
      case 403:
      case 404:
        res.status(status).json({
          error: 'Authentication error',
          code: status,
          message: 'Token invalid or user missing'
        });
        break;
      
      case 429:
        res.status(status).json({
          error: 'Rate limit exceeded',
          code: status,
          message: 'Request limit exceeded'
        });
        break;
        
      default:
        res.status(status).json(error.response.data);
    }
  } else {
    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message || 'Unknown error'
    });
  }
}
```

## 📦 Новые зависимости
```json
{
  "dependencies": {
    // ... existing
    "ws": "^8.18.0"
  },
  "devDependencies": {
    // ... existing  
    "@types/ws": "^8.5.13"
  }
}
```

## ✅ Результат этапа 1
После завершения backend будет поддерживать:
- ✅ Завершение сессий с освобождением pageId
- ✅ Управление файлами в sandbox
- ✅ WebSocket терминал для real-time команд
- ✅ Полную интеграцию с ИИ API как в CLI
- ✅ Proper error handling

---
**Следующий этап:** Frontend Layout переработка 