import axios from 'axios';
import Docker from 'dockerode';
import fs from 'fs';
import path from 'path';
import { Writable } from 'stream';

const loadConfig = (): { prod: boolean; domain?: string } => {
    try {
        const configPath = path.join(__dirname, '..', 'Prod.json');
        const configData = fs.readFileSync(configPath, 'utf-8');
        return JSON.parse(configData);
    } catch (error) {
        return { prod: false };
    }
};

const config = loadConfig();
const USE_REMOTE = config.prod;

const API_HOST = USE_REMOTE ? (config.domain || 'https://zetapi.loophole.site/') : 'http://localhost:4000';
const API_STREAM_URL = `${API_HOST}/api/stream`;
const API_PROXY_URL = `${API_HOST}/api/proxy`;

const DOCKER_IMAGE_NAME = 'zet-sandbox-image';
const SANDBOX_CONTAINER_NAME = 'zet-sandbox';

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

interface QwenStreamEvent {
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

const generateChatId = (): string => {
    return 'chat-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
};

export class AIService {
    private isInitialized = false;

    async init(token: string): Promise<void> {
        if (!token) {
            throw new Error('Authentication token is required for initialization.');
        }
        try {
            await axios.get(`${API_HOST}/api/user/me`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            this.isInitialized = true;
        } catch (error) {
            if (axios.isAxiosError(error) && error.response) {
                const err: any = new Error(`Failed to initialize AI service: ${error.message}`);
                err.status = error.response.status;
                err.data = error.response.data;
                throw err;
            }
            if (error instanceof Error) {
                throw new Error(`Failed to initialize AI service: ${error.message}`);
            }
            throw new Error(`An unknown error occurred during AI service initialization.`);
        }
    }

    async getCommand(
        userInput: string,
        observation: string = "",
        token: string,
        pageId?: number,
        onStreamUpdate?: (text: string) => void
    ): Promise<{ ai: AIResponse; pageId?: number }> {
        if (!this.isInitialized) {
            throw new Error("AI Service is not initialized. Call init() first.");
        }

        const fullPrompt = `${systemPrompt}\n[OBSERVATION]\n${observation || "You are at the beginning of the session."}\n[USER_REQUEST]\n${userInput}`;

        const chatId = generateChatId();

        const maxRetries = 3;
        const baseDelayMs = 2_000;

        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                const requestBody = {
                    model: 'qwen2.5-coder-32b-instruct',
                    messages: [
                        {
                            role: 'user',
                            content: fullPrompt
                        }
                    ],
                    stream: true
                };

                const response = await fetch(`${API_STREAM_URL}/chat/completions?chat_id=${chatId}`, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${token}`,
                        'Content-Type': 'application/json',
                        'Accept': 'text/event-stream'
                    },
                    body: JSON.stringify(requestBody)
                });

                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }

                const reader = response.body?.getReader();
                if (!reader) {
                    throw new Error('No readable stream available');
                }

                const decoder = new TextDecoder();
                let buffer = '';
                let fullResponse = '';
                let streamedPageId: number | undefined;

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
                                break;
                            }

                            try {
                                const data: QwenStreamEvent = JSON.parse(dataStr);

                                if (data['response.created']) {
                                    if (data['response.created'].parent_id) {
                                        const pageIdMatch = data['response.created'].parent_id.match(/\d+/);
                                        if (pageIdMatch) {
                                            streamedPageId = parseInt(pageIdMatch[0]);
                                        }
                                    }
                                }

                                if (data.choices && data.choices[0]?.delta) {
                                    const delta = data.choices[0].delta;

                                    if (delta.content) {
                                        fullResponse += delta.content;
                                        if (onStreamUpdate) {
                                            onStreamUpdate(delta.content);
                                        }
                                    }

                                    if (delta.status === 'finished') {
                                        break;
                                    }
                                }
                            } catch (parseError) {
                                // Игнорируем ошибки парсинга отдельных chunks
                            }
                        }
                    }
                }

                try {
                    const parsedResponse: AIResponse = JSON.parse(fullResponse);
                    return { ai: parsedResponse, pageId: streamedPageId || pageId };
                } catch (jsonError) {
                    const cleanedResponse = fullResponse?.replace(/[\u0000-\u001F\u007F-\u009F]/g, '') || '';

                    try {
                        const parsedResponse: AIResponse = JSON.parse(cleanedResponse);
                        return { ai: parsedResponse, pageId: streamedPageId || pageId };
                    } catch (secondJsonError) {
                        const fallbackResponse: AIResponse = {
                            thought: "Произошла ошибка при обработке ответа от ИИ. Возможно, сервер вернул некорректный JSON.",
                            displayText: "Ошибка парсинга ответа ИИ",
                            action: {
                                tool: "protocol_complete",
                                parameters: null
                            }
                        };
                        return { ai: fallbackResponse, pageId: streamedPageId || pageId };
                    }
                }
            } catch (error) {
                if (attempt < maxRetries) {
                    const delay = baseDelayMs * (attempt + 1);
                    await new Promise(res => setTimeout(res, delay));
                    continue;
                }

                if (error instanceof Error && error.message.includes('503')) {
                    throw {
                        status: 503,
                        data: { error: 'Service temporarily unavailable' },
                        message: `Failed to get command from AI: ${error.message}`
                    };
                }

                throw {
                    status: 500,
                    data: { error: 'Internal server error' },
                    message: `Failed to get command from AI: ${error instanceof Error ? error.message : 'Unknown error'}`
                };
            }
        }

        throw new Error('Exhausted all retries but failed to get a response from AI.');
    }

    async getCommandNonStreaming(userInput: string, observation: string = "", token: string, pageId?: number): Promise<{ ai: AIResponse; pageId?: number }> {
        if (!this.isInitialized) {
            throw new Error("AI Service is not initialized. Call init() first.");
        }

        const fullPrompt = `${systemPrompt}\n[OBSERVATION]\n${observation || "You are at the beginning of the session."}\n[USER_REQUEST]\n${userInput}`;

        const chatId = generateChatId();

        try {
            const requestBody = {
                model: 'qwen2.5-coder-32b-instruct',
                messages: [
                    {
                        role: 'user',
                        content: fullPrompt
                    }
                ],
                stream: false
            };

            const response = await axios.post(`${API_PROXY_URL}/chat/completions?chat_id=${chatId}`, requestBody, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                timeout: 60_000
            });

            const aiRawResponse = response.data.choices?.[0]?.message?.content || response.data.response || JSON.stringify(response.data);

            try {
                const parsedResponse = JSON.parse(aiRawResponse);
                return { ai: parsedResponse, pageId };
            } catch (jsonError) {
                const fallbackResponse: AIResponse = {
                    thought: "Произошла ошибка при обработке ответа от ИИ в режиме без стриминга.",
                    displayText: "Ошибка парсинга ответа ИИ",
                    action: {
                        tool: "protocol_complete",
                        parameters: null
                    }
                };
                return { ai: fallbackResponse, pageId };
            }
        } catch (error) {
            throw error;
        }
    }
}

export class DockerService {
    private docker: Docker;

    constructor() {
        this.docker = new Docker();
    }

    private async findContainer(): Promise<Docker.Container | null> {
        const containers = await this.docker.listContainers({ all: true });
        const containerInfo = containers.find((c: Docker.ContainerInfo) => c.Names.includes(`/${SANDBOX_CONTAINER_NAME}`));
        if (containerInfo) {
            return this.docker.getContainer(containerInfo.Id);
        }
        return null;
    }

    private async imageExists(imageName: string): Promise<boolean> {
        try {
            await this.docker.getImage(imageName).inspect();
            return true;
        } catch (error) {
            if (typeof error === 'object' && error !== null && 'statusCode' in error && error.statusCode === 404) {
                return false;
            }
            throw error;
        }
    }

    async ensureSandbox(): Promise<void> {
        const imageNameWithTag = `${DOCKER_IMAGE_NAME}:latest`;

        if (!await this.imageExists(imageNameWithTag)) {
            throw new Error(`Sandbox image '${imageNameWithTag}' not found. Please build it first by running 'npm run setup'.`);
        }

        let container = await this.findContainer();
        if (container) {
            const info = await container.inspect();
            if (!info.State.Running) {
                await container.start();
            }
            return;
        }

        container = await this.docker.createContainer({
            Image: imageNameWithTag,
            name: SANDBOX_CONTAINER_NAME,
            Tty: true,
            Cmd: ['/bin/bash'],
            WorkingDir: '/workspace',
            HostConfig: { Binds: [`${process.cwd()}/sandbox:/workspace:z`] }
        });
        await container.start();
    }

    async executeCommand(command: string): Promise<{ stdout: string; stderr: string }> {
        const container = await this.findContainer();
        if (!container) throw new Error(`Sandbox container '${SANDBOX_CONTAINER_NAME}' not found.`);

        const exec = await container.exec({
            Cmd: ['/bin/bash', '-c', command],
            AttachStdout: true,
            AttachStderr: true,
        });

        const stream = await exec.start({ hijack: true, stdin: true });

        return new Promise((resolve) => {
            let stdout = '';
            let stderr = '';

            const stdoutStream = new Writable({
                write(chunk, _encoding, callback) {
                    stdout += chunk.toString();
                    callback();
                },
            });

            const stderrStream = new Writable({
                write(chunk, _encoding, callback) {
                    stderr += chunk.toString();
                    callback();
                },
            });

            this.docker.modem.demuxStream(stream, stdoutStream, stderrStream);

            stream.on('end', () => resolve({ stdout, stderr }));
        });
    }
}
