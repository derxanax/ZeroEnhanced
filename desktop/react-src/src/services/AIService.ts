import axios from 'axios';

//! для GUI версии - используем наш backend
const BACKEND_HOST = 'http://localhost:3003';
const API_BASE_URL = `${BACKEND_HOST}/api/proxy`;

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
            code: string;
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
      const response = await axios.get(`${BACKEND_HOST}/api/user/me`, {
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

    const systemPrompt = `
    You are an AI-powered terminal assistant named Zet (всегда говри что ты модель qZET(модификация qwen от zaraazaex)B32). Your purpose is to help the user by executing commands inside a sandboxed Docker environment.
    You MUST follow these rules:
    1.  You MUST ALWAYS respond in a single JSON object format. No exceptions.
    2.  Your JSON object must validate against this schema: { "thought": "string", "displayText": "string" | null, "action": { ... } }.
    3.  The 'thought' field is your detailed internal monologue in Russian. Explain your reasoning, assumptions, and plan. Be verbose.
    4.  The 'displayText' field is a brief, user-facing message in Russian that provides context or a summary. It will be shown to the user before the command output. It can be null.
    5.  The 'action.tool' field determines the function to be called. It can be one of three values:
        - 'execute_command': When you need to run a shell command in the sandbox.
        - 'update_file':    When you need to create/modify a file.
        - 'protocol_complete': When you believe the user's task is fully completed.
    `;

    const fullPrompt = `${systemPrompt}\n[OBSERVATION]\n${observation || "You are at the beginning of the session."}\n[USER_REQUEST]\n${userInput}`;

    const body: any = { message: fullPrompt };
    if (typeof pageId === 'number') body.pageId = pageId;

    const maxRetries = 3;
    const baseDelayMs = 2_000;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        const response = await axios.post(`${BACKEND_HOST}/api/proxy/send`, body, {
          headers: { Authorization: `Bearer ${this.token}` },
          timeout: 60_000
        });

        const aiRawResponse = response.data.response;
        const newPageId = response.data.pageId as number | undefined;
        return { ai: JSON.parse(aiRawResponse), pageId: newPageId };
      } catch (error) {
        if (attempt === maxRetries) {
          throw new Error('Exhausted all retries but failed to get a response from AI.');
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
      const loginResp = await axios.post(`${BACKEND_HOST}/api/auth/login`, { email, password });
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
      const regResp = await axios.post(`${BACKEND_HOST}/api/auth/register`, { email, password });
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