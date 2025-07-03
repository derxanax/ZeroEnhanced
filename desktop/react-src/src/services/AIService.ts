const loadConfig = async (): Promise<{ prod: boolean; domain?: string }> => {
  if (isNeutralinoEnvironment()) {
    try {
      const configData = await (window as any).Neutralino.filesystem.readFile('Prod.json');
      return JSON.parse(configData);
    } catch (error) {
      console.warn('Failed to load Prod.json via Neutralino, defaulting to development mode:', error);
      return { prod: false };
    }
  } else {
    try {
      const response = await fetch('/Prod.json');
      const configData = await response.json();
      return configData;
    } catch (error) {
      console.warn('Failed to load Prod.json via fetch, defaulting to development mode:', error);
      return { prod: false };
    }
  }
};

let configCache: { prod: boolean; domain?: string } | null = null;

const getConfig = (): Promise<{ prod: boolean; domain?: string }> => {
  if (configCache) {
    return Promise.resolve(configCache);
  }
  return loadConfig().then(config => {
    configCache = config;
    return config;
  });
};

const getApiUrl = async (): Promise<string> => {
  const config = await getConfig();
  return config.prod ? (config.domain || 'https://zetapi.loophole.site/') + '/api/proxy' : 'http://localhost:4000/api/proxy';
};

const getAuthUrl = async (): Promise<string> => {
  const config = await getConfig();
  return config.prod ? (config.domain || 'https://zetapi.loophole.site/') + '/api/auth' : 'http://localhost:4000/api/auth';
};

const getUserUrl = async (): Promise<string> => {
  const config = await getConfig();
  return config.prod ? (config.domain || 'https://zetapi.loophole.site/') + '/api/user/me' : 'http://localhost:4000/api/user/me';
};

const isNeutralinoEnvironment = (): boolean => {
  try {
    return typeof window !== 'undefined' && 'Neutralino' in window;
  } catch {
    return false;
  }
};

const universalStorage = {
  async getData(key: string): Promise<string | null> {
    if (isNeutralinoEnvironment()) {
      try {
        if (key === 'auth_token') {
          const { os } = await import('@neutralinojs/lib');
          const homePath = await os.getPath('home' as any);
          const tokenPath = `${homePath}/.config/zet/token`;

          try {
            const { filesystem } = await import('@neutralinojs/lib');
            const tokenContent = await filesystem.readFile(tokenPath);
            return tokenContent.trim();
          } catch (error) {
            console.warn('Failed to read token from file system, trying Neutralino storage:', error);
            const { storage } = await import('@neutralinojs/lib');
            return await storage.getData(key);
          }
        }

        const { storage } = await import('@neutralinojs/lib');
        return await storage.getData(key);
      } catch {
        return localStorage.getItem(key);
      }
    } else {
      if (key === 'auth_token') {
        try {
          const response = await fetch('/api/auth/token');
          if (response.ok) {
            const data = await response.json();
            return data.token;
          }
        } catch (error) {
          console.warn('Failed to get token from backend, using localStorage:', error);
        }
      }
      return localStorage.getItem(key);
    }
  },

  async setData(key: string, value: string): Promise<void> {
    if (isNeutralinoEnvironment()) {
      try {
        if (key === 'auth_token') {
          const { os, filesystem } = await import('@neutralinojs/lib');
          const homePath = await os.getPath('home' as any);
          const configDir = `${homePath}/.config/zet`;
          const tokenPath = `${configDir}/token`;

          try {
            try {
              await filesystem.createDirectory(configDir);
            } catch (dirError) {

            }

            await filesystem.writeFile(tokenPath, value);
            console.log('Token saved to file system');
            return;
          } catch (error) {
            console.warn('Failed to save token to file system, using Neutralino storage:', error);
            const { storage } = await import('@neutralinojs/lib');
            await storage.setData(key, value);
            return;
          }
        }

        const { storage } = await import('@neutralinojs/lib');
        await storage.setData(key, value);
        return;
      } catch {
        localStorage.setItem(key, value);
      }
    } else {
      if (key === 'auth_token') {
        try {
          await fetch('/api/auth/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ token: value })
          });
        } catch (error) {
          console.warn('Failed to save token to backend:', error);
        }
      }
      localStorage.setItem(key, value);
    }
  }
};

export interface AIAction {
  tool: 'execute_command' | 'protocol_complete' | 'update_file';
  parameters: any;
}

export interface AIResponse {
  thought: string;
  displayText?: string;
  action: AIAction;
  executionResult?: any;
}

interface StreamEvent {
  'response.created'?: {
    chat_id: string;
    parent_id: string;
    response_id: string;
  };
  choices?: Array<{
    delta: {
      role: string;
      content: string;
      phase: string;
      status: string;
    };
  }>;
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

export class AIService {
  private baseUrl: string;
  private isInitialized = false;
  private authToken: string | null = null;

  constructor() {
    this.baseUrl = 'http://localhost:4000';
  }

  async init(token?: string): Promise<void> {
    try {
      if (token) {
        this.authToken = token;
      }

      if (!this.authToken) {
        throw new Error('Authentication token is required');
      }

      const response = await fetch(`${this.baseUrl}/api/user/me`, {
        headers: {
          'Authorization': `Bearer ${this.authToken}`,
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.message || `HTTP ${response.status}`);
      }

      this.isInitialized = true;
      console.log('[AI SERVICE] Initialized successfully');
    } catch (error) {
      console.error('[AI SERVICE] Initialization failed:', error);
      throw error;
    }
  }

  async login(email: string, password: string): Promise<string> {
    try {
      const response = await fetch(`${this.baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ email, password })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `HTTP ${response.status}`);
      }

      const data = await response.json();
      this.authToken = data.token;
      this.isInitialized = true;

      console.log('[AI SERVICE] Login successful');
      return data.token;
    } catch (error) {
      console.error('[AI SERVICE] Login failed:', error);
      throw error;
    }
  }

  async register(email: string, password: string): Promise<string> {
    try {
      const response = await fetch(`${this.baseUrl}/api/auth/register`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ email, password })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `HTTP ${response.status}`);
      }

      const data = await response.json();
      this.authToken = data.token;
      this.isInitialized = true;

      console.log('[AI SERVICE] Registration successful');
      return data.token;
    } catch (error) {
      console.error('[AI SERVICE] Registration failed:', error);
      throw error;
    }
  }

  async logout(): Promise<void> {
    try {
      if (this.authToken) {
        await fetch(`${this.baseUrl}/api/auth/token`, {
          method: 'DELETE',
          headers: {
            'Authorization': `Bearer ${this.authToken}`
          }
        });
      }

      this.authToken = null;
      this.isInitialized = false;
      console.log('[AI SERVICE] Logout successful');
    } catch (error) {
      console.error('[AI SERVICE] Logout error:', error);
      this.authToken = null;
      this.isInitialized = false;
    }
  }

  async sendMessage(message: string, onChunk?: (chunk: string) => void): Promise<AIResponse> {
    if (!this.isInitialized || !this.authToken) {
      throw new Error('AI Service not initialized. Call init() first.');
    }

    try {
      console.log('[AI SERVICE] Sending streaming message:', message);

      const response = await fetch(`${this.baseUrl}/api/stream/chat/completions`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.authToken}`,
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream'
        },
        body: JSON.stringify({
          message,
          model: 'qwen2.5-coder-32b-instruct',
          stream: true
        })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      const reader = response.body?.getReader();
      if (!reader) {
        throw new Error('No readable stream available');
      }

      const decoder = new TextDecoder();
      let buffer = '';
      let fullResponse = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (line.trim() === '') continue;

          if (line.startsWith('data: ')) {
            const dataStr = line.substring(6);

            if (dataStr.trim() === '[DONE]') {
              console.log('[AI SERVICE] Stream completed');
              break;
            }

            try {
              const event: StreamEvent = JSON.parse(dataStr);

              if (event['response.created']) {
                console.log(`[AI SERVICE] Chat created: ${event['response.created'].chat_id}`);
              }

              if (event.choices && event.choices[0]?.delta) {
                const delta = event.choices[0].delta;

                if (delta.content) {
                  fullResponse += delta.content;
                  if (onChunk) {
                    onChunk(delta.content);
                  }
                }

                if (delta.status === 'finished') {
                  console.log('[AI SERVICE] Stream finished');
                  break;
                }
              }
            } catch (parseError) {
              console.warn('[AI SERVICE] Parse error:', parseError);
            }
          }
        }
      }

      try {
        const parsedResponse: AIResponse = JSON.parse(fullResponse);
        console.log('[AI SERVICE] Successfully parsed response');
        return parsedResponse;
      } catch (jsonError) {
        console.error('[AI SERVICE] Failed to parse final response:', jsonError);
        throw new Error('Failed to parse AI response');
      }
    } catch (error) {
      console.error('[AI SERVICE] Send message error:', error);
      throw error;
    }
  }

  async getCommand(userInput: string, observation: string = "", pageId?: number): Promise<{ ai: AIResponse; pageId?: number }> {
    const response = await this.sendMessage(`[OBSERVATION]\n${observation || "You are at the beginning of the session."}\n[USER_REQUEST]\n${userInput}`);
    return { ai: response, pageId };
  }

  async sendMessageNonStreaming(message: string): Promise<AIResponse> {
    if (!this.isInitialized || !this.authToken) {
      throw new Error('AI Service not initialized. Call init() first.');
    }

    try {
      console.log('[AI SERVICE] Sending non-streaming message:', message);

      const response = await fetch(`${this.baseUrl}/api/proxy/chat/completions`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.authToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message,
          model: 'qwen2.5-coder-32b-instruct',
          stream: false
        })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      const data = await response.json();

      if (data.processedResponse) {
        return data.processedResponse;
      } else if (data.response) {
        try {
          return JSON.parse(data.response);
        } catch (jsonError) {
          throw new Error('Failed to parse AI response');
        }
      } else {
        throw new Error('No valid response received');
      }
    } catch (error) {
      console.error('[AI SERVICE] Non-streaming error:', error);
      throw error;
    }
  }

  async executeCommand(command: string): Promise<{ stdout: string; stderr: string }> {
    if (!this.authToken) {
      throw new Error('Not authenticated');
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/docker/execute`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.authToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ command })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('[AI SERVICE] Execute command error:', error);
      throw error;
    }
  }

  async updateFile(fileParams: {
    file: string;
    code?: string;
    code_lines?: string[];
    line_operations?: any;
    edit?: boolean;
    startLine?: number;
    endLine?: number;
  }): Promise<{ success: boolean; message?: string; error?: string }> {
    if (!this.authToken) {
      throw new Error('Not authenticated');
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/files/update`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.authToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(fileParams)
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('[AI SERVICE] Update file error:', error);
      throw error;
    }
  }

  async readFile(filePath: string): Promise<{ content: string; path: string }> {
    if (!this.authToken) {
      throw new Error('Not authenticated');
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/files/read?path=${encodeURIComponent(filePath)}`, {
        headers: {
          'Authorization': `Bearer ${this.authToken}`
        }
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('[AI SERVICE] Read file error:', error);
      throw error;
    }
  }

  async listFiles(dirPath: string = ''): Promise<{ files: string[]; directories: string[] }> {
    if (!this.authToken) {
      throw new Error('Not authenticated');
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/files/list?path=${encodeURIComponent(dirPath)}`, {
        headers: {
          'Authorization': `Bearer ${this.authToken}`
        }
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('[AI SERVICE] List files error:', error);
      throw error;
    }
  }

  async ensureSandbox(): Promise<void> {
    if (!this.authToken) {
      throw new Error('Not authenticated');
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/docker/ensure-sandbox`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.authToken}`,
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      console.log('[AI SERVICE] Sandbox ensured');
    } catch (error) {
      console.error('[AI SERVICE] Ensure sandbox error:', error);
      throw error;
    }
  }

  isReady(): boolean {
    return this.isInitialized && this.authToken !== null;
  }

  getAuthToken(): string | null {
    return this.authToken;
  }
}

export default AIService; 