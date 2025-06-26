import axios from 'axios';
import Docker from 'dockerode';
import { Writable } from 'stream';

// --- Deployment toggle ---
// 1 = production (remote api.derx.space), 0 = local development (localhost:4000)
const USE_REMOTE = false;

const API_HOST = USE_REMOTE ? 'https://api.derx.space' : 'http://localhost:4000';
const API_BASE_URL = `${API_HOST}/api/proxy`;

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
    private isInitialized = false;

    async init(token: string): Promise<void> {
        if (!token) {
            throw new Error('Authentication token is required for initialization.');
        }
        try {
            // Используем /api/user/me для проверки, что токен валиден и сервер доступен
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

    async getCommand(userInput: string, observation: string = "", token: string, pageId?: number): Promise<{ ai: AIResponse; pageId?: number }> {
        if (!this.isInitialized) {
            throw new Error("AI Service is not initialized. Call init() first.");
        }

        const fullPrompt = `${systemPrompt}\n[OBSERVATION]\n${observation || "You are at the beginning of the session."}\n[USER_REQUEST]\n${userInput}`;

        const body: any = { message: fullPrompt };
        if (typeof pageId === 'number') body.pageId = pageId;

        const maxRetries = 3;
        const baseDelayMs = 2_000; 

        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                const response = await axios.post(`${API_BASE_URL}/send`, body, {
                    headers: { Authorization: `Bearer ${token}` },
                    timeout: 60_000
                });

                const aiRawResponse = response.data.response;
                const newPageId = response.data.pageId as number | undefined;
                
                // Добавляем логирование и лучшую обработку ошибок JSON
                try {
                    const parsedResponse = JSON.parse(aiRawResponse);
                    return { ai: parsedResponse, pageId: newPageId };
                } catch (jsonError) {
                    console.error('JSON parse error details:');
                    console.error('Raw response:', aiRawResponse);
                    console.error('Response length:', aiRawResponse?.length || 'undefined');
                    console.error('JSON error:', jsonError instanceof Error ? jsonError.message : jsonError);
                    
                    // Попытка "починить" JSON
                    let cleanedResponse = aiRawResponse?.replace(/[\u0000-\u001F\u007F-\u009F]/g, '') || '';
                    
                    // Попытка исправить неэкранированные кавычки в строках кода
                    // Ищем паттерн "code": "...print("...")..." и экранируем внутренние кавычки
                    cleanedResponse = cleanedResponse.replace(
                        /"code":\s*"([^"]*(?:\\.[^"]*)*?)"/g,
                        (match: string, codeContent: string) => {
                            // Экранируем неэкранированные кавычки внутри строки кода
                            const escapedCode = codeContent.replace(/(?<!\\)"/g, '\\"');
                            return `"code": "${escapedCode}"`;
                        }
                    );
                    
                    try {
                        const parsedResponse = JSON.parse(cleanedResponse);
                        console.log('Successfully parsed cleaned JSON');
                        return { ai: parsedResponse, pageId: newPageId };
                    } catch (secondJsonError) {
                        // Если всё равно не удаётся распарсить, возвращаем заглушку
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
        }

        throw new Error('Exhausted all retries but failed to get a response from AI.');
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

        console.log(`Creating new sandbox container '${SANDBOX_CONTAINER_NAME}'...`);
        container = await this.docker.createContainer({
            Image: imageNameWithTag,
            name: SANDBOX_CONTAINER_NAME,
            Tty: true,
            Cmd: ['/bin/bash'],
            WorkingDir: '/workspace',
            HostConfig: { Binds: [`${process.cwd()}/sandbox:/workspace:z`] }
        });
        await container.start();
        console.log('Sandbox container created and started.');
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
