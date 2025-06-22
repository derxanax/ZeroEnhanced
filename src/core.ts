import axios from 'axios';
import Docker from 'dockerode';
import { Writable } from 'stream';

const API_BASE_URL = 'http://localhost:3700'; //! чутка хардкода брооо 
const DOCKER_IMAGE_NAME = 'zet-sandbox-image';
const SANDBOX_CONTAINER_NAME = 'zet-sandbox';

export interface AIAction { //* деркс бля какой аиа дай уже норм имена хотть чему то 
    tool: 'execute_command' | 'protocol_complete';
    parameters: {
        command: string;
        confirm: boolean;
        prompt?: string;
    } | null;
}

export interface AIResponse {
    thought: string;
    displayText?: string;
    action: AIAction;
}

const systemPrompt = `
You are an AI-powered terminal assistant named Zet. Your purpose is to help the user by executing commands inside a sandboxed Docker environment.
You MUST follow these rules:
1.  You MUST ALWAYS respond in a single JSON object format. No exceptions.
2.  Your JSON object must validate against this schema: { "thought": "string", "displayText": "string" | null, "action": { ... } }.
3.  The 'thought' field is your detailed internal monologue in Russian. Explain your reasoning, assumptions, and plan. Be verbose.
4.  The 'displayText' field is a brief, user-facing message in Russian that provides context or a summary. It will be shown to the user before the command output. It can be null.
5.  The 'action.tool' field determines the function to be called. It can be one of two values:
    - 'execute_command': When you need to run a shell command in the sandbox.
    - 'protocol_complete': When you believe the user's task is fully completed.
6.  For 'execute_command', the 'parameters' object must contain:
    - 'command': The exact shell command to execute.
    - 'confirm': A boolean. If true, the system will ask the user for confirmation before running a potentially destructive command.
    - 'prompt' (optional): The text for the confirmation prompt.

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
`; //! смоти чо написал
//* рял не хуета 

export class AIService {
    private isInitialized = false;

    async init(): Promise<void> {
        try {
            await axios.post(`${API_BASE_URL}/api/new-chat`);
            this.isInitialized = true;
        } catch (error) {
            if (error instanceof Error) {
                throw new Error(`Failed to initialize new chat session: ${error.message}`);
            }
            throw new Error(`An unknown error occurred during chat session initialization.`);
        }
    }

    async getCommand(userInput: string, observation: string = ""): Promise<AIResponse> {
        if (!this.isInitialized) {
            throw new Error("AI Service is not initialized. Call init() first.");
        }

        const fullPrompt = `${systemPrompt}\n[OBSERVATION]\n${observation || "You are at the beginning of the session."}\n[USER_REQUEST]\n${userInput}`;

        try {
            const response = await axios.post(`${API_BASE_URL}/api/send`, { message: fullPrompt });
            const aiRawResponse = response.data.response;
            return JSON.parse(aiRawResponse);
        } catch (error) {
            console.error("Error parsing AI response:", error);
            if (error instanceof Error) {
                throw new Error(`Failed to get command from AI: ${error.message}`);
            }
            throw new Error(`An unknown error occurred while getting command from AI.`);
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
        const containerInfo = containers.find(c => c.Names.includes(`/${SANDBOX_CONTAINER_NAME}`));
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
        container = await this.docker.createContainer({ //! никакой винды у нас тут!

          //* ахуя? 

          //! потому что винда говно бля
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
                write(chunk, encoding, callback) {
                    stdout += chunk.toString();
                    callback();
                }
            });

            const stderrStream = new Writable({
                write(chunk, encoding, callback) {
                    stderr += chunk.toString();
                    callback();
                }
            });
            
            this.docker.modem.demuxStream(stream, stdoutStream, stderrStream);
            
            stream.on('end', () => resolve({ stdout, stderr })); //!  я не еьббу чр тут ? поясни ка  
            //* када поток данных из ексек завершился ну ета (stream 'end')  мы резолвим промис возвращая накопленные стдоут и стедерр

            //! вау а чо такое резолвим 
            //* резолвим это значит что мы разрешаем промис 

            //! а чэ такое промисили  там написано пенис
            //* промис это объект который представляет собой результат асинхронной операции 

            //! а чо такое асинхронная пипирация
            //* асинхронная операция это операция которая не завершается сразу  уебан 
            //! повелся на тролинг сука ХАХАХААХ
        
        });

    }
} 