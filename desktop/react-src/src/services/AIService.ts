import axios from 'axios';

// --- Функция для чтения конфигурации из Prod.json ---
const loadConfig = async (): Promise<{ prod: boolean }> => {
    try {
        // В браузере используем fetch для чтения из public
        if (typeof window !== 'undefined') {
            try {
                const response = await fetch('/Prod.json');
                if (response.ok) {
                    const config = await response.json();
                    return config;
                }
            } catch (fetchError) {
                console.warn('Failed to fetch Prod.json from public directory:', fetchError);
            }
        } else {
            // В Node.js окружении (Neutralino или SSR)
            const possiblePaths = [
                '../../Prod.json', // относительно src/services/
                '../../../Prod.json', // относительно react-src/src/services/
                '../../../../Prod.json', // относительно desktop/react-src/src/services/
            ];
            
            for (const configPath of possiblePaths) {
                try {
                    // Используем динамический require чтобы избежать предупреждений webpack
                    const fs = eval('require')('fs');
                    const path = eval('require')('path');
                    const fullPath = path.resolve(__dirname, configPath);
                    
                    if (fs.existsSync(fullPath)) {
                        const configData = fs.readFileSync(fullPath, 'utf-8');
                        return JSON.parse(configData);
                    }
                } catch (pathError) {
                    continue;
                }
            }
        }
        
        throw new Error('Prod.json not found');
    } catch (error) {
        console.warn('Failed to load Prod.json, defaulting to development mode:', error);
        return { prod: false };
    }
};

// --- Инициализация конфигурации ---
let configPromise: Promise<{ prod: boolean }> | null = null;
const getConfig = (): Promise<{ prod: boolean }> => {
    if (!configPromise) {
        configPromise = loadConfig();
    }
    return configPromise;
};

// --- Функция для получения API URL на основе конфигурации ---
const getApiUrl = async (): Promise<string> => {
    const config = await getConfig();
    const USE_REMOTE = config.prod;
    const BACKEND_HOST = USE_REMOTE ? 'https://zetapi.loophole.site/' : 'http://localhost:4000';
    return `${BACKEND_HOST}/api/proxy`;
};

const getAuthUrl = async (): Promise<string> => {
    const config = await getConfig();
    const USE_REMOTE = config.prod;
    const BACKEND_HOST = USE_REMOTE ? 'https://zetapi.loophole.site/' : 'http://localhost:4000';
    return `${BACKEND_HOST}/api/auth`;
};

const getUserUrl = async (): Promise<string> => {
    const config = await getConfig();
    const USE_REMOTE = config.prod;
    const BACKEND_HOST = USE_REMOTE ? 'https://zetapi.loophole.site/' : 'http://localhost:4000';
    return `${BACKEND_HOST}/api/user/me`;
};

//! проверяем среду выполнения
const isNeutralinoEnvironment = (): boolean => {
  try {
    return typeof window !== 'undefined' && 'Neutralino' in window;
  } catch {
    return false;
  }
};

//! универсальное хранилище для браузера и Neutralino
const universalStorage = {
  async getData(key: string): Promise<string | null> {
    if (isNeutralinoEnvironment()) {
      try {
        const { storage } = await import('@neutralinojs/lib');
        return await storage.getData(key);
      } catch {
        return localStorage.getItem(key);
      }
    } else {
      return localStorage.getItem(key);
    }
  },
  
  async setData(key: string, value: string): Promise<void> {
    if (isNeutralinoEnvironment()) {
      try {
        const { storage } = await import('@neutralinojs/lib');
        await storage.setData(key, value);
        return;
      } catch {
        localStorage.setItem(key, value);
      }
    } else {
      localStorage.setItem(key, value);
    }
  }
};

export interface AIAction {
    tool: 'execute_command' | 'protocol_complete' | 'update_file';
    parameters: (
      | {
            command: string;
            confirm: boolean;
            prompt?: string;
        }
      | {
            file: string;
            code?: string;
            code_lines?: string[];
            line_operations?: {
                [lineNumber: string]: {
                    action: 'insert' | 'replace' | 'delete';
                    content?: string;
                };
            };
            edit: boolean; 
            startLine?: number;
            endLine?: number;
            confirm: boolean;
            prompt?: string;
        }
    ) | null;
}

export interface AIResponse {
    thought: string;
    displayText?: string;
    action: AIAction;
}

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

//* универсальный адаптер для браузера и нейтралино
export class AIService {
  private isInitialized = false;
  private token: string | null = null;

  async init(): Promise<void> {
    try {
      // Получаем токен из универсального хранилища
      this.token = await universalStorage.getData('auth_token');
      
      if (!this.token) {
        throw new Error('Authentication token not found.');
      }
      
      // Проверяем валидность токена через backend
      const userUrl = await getUserUrl();
      const response = await axios.get(userUrl, {
        headers: { Authorization: `Bearer ${this.token}` }
      });
      
      if (response.status === 200) {
        this.isInitialized = true;
      } else {
        throw new Error('Token validation failed');
      }
    } catch (error) {
      if (axios.isAxiosError(error) && error.response) {
        const status = error.response.status;
        const errorData = error.response.data;
        
        if (status === 401 || status === 403) {
          throw new Error('Токен недействителен. Необходимо войти заново.');
        } else if (status === 404) {
          throw new Error('Пользователь не найден. Необходимо войти заново.');
        } else if (status >= 500) {
          throw new Error('Ошибка сервера. Попробуйте позже.');
        } else {
          throw new Error(errorData?.error || `Ошибка инициализации (${status})`);
        }
      } else if (error instanceof Error) {
        if (error.message.includes('ECONNREFUSED') || error.message.includes('Network Error')) {
          throw new Error('Не удается подключиться к серверу. Проверьте что сервер запущен на localhost:4000');
        }
        throw new Error(`Ошибка инициализации: ${error.message}`);
      }
      throw new Error('Неизвестная ошибка инициализации');
    }
  }

  async getCommand(userInput: string, observation: string = "", pageId?: number): Promise<{ ai: AIResponse; pageId?: number }> {
    if (!this.isInitialized || !this.token) {
      throw new Error("AI Service is not initialized. Call init() first.");
    }

    const fullPrompt = `${systemPrompt}\n[OBSERVATION]\n${observation || "You are at the beginning of the session."}\n[USER_REQUEST]\n${userInput}`;

    const body: any = { message: fullPrompt };
    if (typeof pageId === 'number') body.pageId = pageId;

    const maxRetries = 3;
    const baseDelayMs = 2_000;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        const apiUrl = await getApiUrl();
        const response = await axios.post(`${apiUrl}/send`, body, {
          headers: { Authorization: `Bearer ${this.token}` },
          timeout: 60_000
        });

        const aiRawResponse = response.data.response;
        const newPageId = response.data.pageId as number | undefined;
        
        try {
          const parsedResponse = JSON.parse(aiRawResponse);
          return { ai: parsedResponse, pageId: newPageId };
        } catch (jsonError) {
          console.error('JSON parse error details:');
          console.error('Raw response:', aiRawResponse);
          console.error('Response length:', aiRawResponse?.length || 'undefined');
          console.error('JSON error:', jsonError instanceof Error ? jsonError.message : jsonError);
          
          const cleanedResponse = aiRawResponse?.replace(/[\u0000-\u001F\u007F-\u009F]/g, '') || '';
          
          try {
            const parsedResponse = JSON.parse(cleanedResponse);
            console.log('Successfully parsed cleaned JSON');
            return { ai: parsedResponse, pageId: newPageId };
          } catch (secondJsonError) {
            console.error('Failed to parse even cleaned JSON:', secondJsonError);
            const fallbackResponse: AIResponse = {
              thought: "Произошла ошибка при обработке ответа от ИИ. Возможно, сервер вернул некорректный JSON.",
              displayText: "Ошибка парсинга ответа ИИ",
              action: {
                tool: "protocol_complete",
                parameters: null
              }
            };
            return { ai: fallbackResponse, pageId: newPageId };
          }
        }
      } catch (error) {
        if (axios.isAxiosError(error) && error.response?.status === 503) {
          if (attempt < maxRetries) {
            const delay = baseDelayMs * (attempt + 1);
            await new Promise(res => setTimeout(res, delay));
            continue;
          }
        }

        if (attempt === maxRetries) {
          if (axios.isAxiosError(error) && error.response) {
            throw {
              status: error.response.status,
              data: error.response.data,
              message: `Failed to get command from AI: ${error.message}`
            };
          }
          if (error instanceof Error) {
            throw new Error(`Failed to get command from AI: ${error.message}`);
          }
          throw new Error(`An unknown error occurred while getting command from AI.`);
        }
        
        // Ждем перед следующей попыткой
        const delay = baseDelayMs * (attempt + 1);
        await new Promise(res => setTimeout(res, delay));
      }
    }

    throw new Error('Exhausted all retries but failed to get a response from AI.');
  }
  
  async login(email: string, password: string): Promise<void> {
    try {
      const authUrl = await getAuthUrl();
      const loginResp = await axios.post(`${authUrl}/login`, { email, password });
      const token: string = loginResp.data.token;
      await universalStorage.setData('auth_token', token);
      this.token = token;
      this.isInitialized = true;
    } catch (error) {
      if (axios.isAxiosError(error) && error.response) {
        const status = error.response.status;
        const errorData = error.response.data;
        
        if (status === 404) {
          throw new Error('Пользователь не найден. Проверьте email или зарегистрируйтесь.');
        } else if (status === 401) {
          const errorMsg = errorData?.error || 'Неверный пароль';
          throw new Error(errorMsg);
        } else if (status === 429) {
          throw new Error('Слишком много попыток входа. Попробуйте позже.');
        } else if (status >= 500) {
          throw new Error('Ошибка сервера. Попробуйте позже.');
        } else {
          throw new Error(errorData?.error || `Ошибка входа (${status})`);
        }
      } else if (error instanceof Error) {
        if (error.message.includes('ECONNREFUSED') || error.message.includes('Network Error')) {
          throw new Error('Не удается подключиться к серверу. Проверьте что сервер запущен на localhost:4000');
        }
        throw new Error(`Ошибка сети: ${error.message}`);
      }
      throw new Error('Неизвестная ошибка при входе');
    }
  }

  async register(email: string, password: string): Promise<void> {
    try {
      const authUrl = await getAuthUrl();
      const regResp = await axios.post(`${authUrl}/register`, { email, password });
      const token: string = regResp.data.token;
      await universalStorage.setData('auth_token', token);
      this.token = token;
      this.isInitialized = true;
    } catch (error) {
      if (axios.isAxiosError(error) && error.response) {
        const status = error.response.status;
        const errorData = error.response.data;
        
        if (status === 400) {
          throw new Error(errorData?.error || 'Некорректные данные для регистрации');
        } else if (status === 409) {
          throw new Error('Пользователь с таким email уже существует');
        } else if (status >= 500) {
          throw new Error('Ошибка сервера при регистрации. Попробуйте позже.');
        } else {
          throw new Error(errorData?.error || `Ошибка регистрации (${status})`);
        }
      } else if (error instanceof Error) {
        if (error.message.includes('ECONNREFUSED') || error.message.includes('Network Error')) {
          throw new Error('Не удается подключиться к серверу. Проверьте что сервер запущен на localhost:4000');
        }
        throw new Error(`Ошибка сети: ${error.message}`);
      }
      throw new Error('Неизвестная ошибка при регистрации');
    }
  }
  
  async logout(): Promise<void> {
    await universalStorage.setData('auth_token', '');
    this.token = null;
    this.isInitialized = false;
  }
} 