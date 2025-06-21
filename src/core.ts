import axios from 'axios';
import Docker from 'dockerode';
import { Writable } from 'stream';

const API_BASE_URL = 'http://localhost:3700';
const DOCKER_IMAGE_NAME = 'zet-sandbox-image';
const SANDBOX_CONTAINER_NAME = 'zet-sandbox';

export interface AIAction {
    tool: 'execute_command' | 'protocol_complete';
    parameters: {
        command: string;
        confirm: boolean;
        prompt?: string;
    } | null;
}

export interface AIResponse {
    thought: string;
    action: AIAction;
}

const systemPrompt = `
You are an AI-powered terminal assistant named Zet. Your purpose is to help the user by executing commands inside a sandboxed Docker environment.
You MUST follow these rules:
1.  You MUST ALWAYS respond in a JSON format. No exceptions. Do not ever write any text outside of the JSON structure.
2.  Your entire response must be a single JSON object that validates against this schema: { "thought": "string", "action": { "tool": "string", "parameters": { "command": "string", "confirm": "boolean", "prompt": "string" | null } | null } }.
3.  The 'thought' field is for your internal monologue. Briefly explain your reasoning for the chosen action.
4.  The 'action.tool' field determines the function to be called. It can be one of two values:
    - 'execute_command': When you need to run a shell command in the sandbox.
    - 'protocol_complete': When you believe the user's task is fully completed. Use this to end the session.
5.  For 'execute_command', the 'parameters' object must contain:
    - 'command': The exact shell command to execute.
    - 'confirm': A boolean. If true, the system will ask the user for confirmation before running a potentially destructive command (e.g., rm, dd, mkfs).
    - 'prompt' (optional): The text to show the user for confirmation if 'confirm' is true.
6.  The user will provide you with context from previous command executions prefixed with [OBSERVATION]. Use this information to inform your next action.

Example user request: "List all files in the current directory"
Your JSON response:
{
    "thought": "The user wants to see the files. The 'ls -F' command is appropriate for this.",
    "action": {
        "tool": "execute_command",
        "parameters": {
            "command": "ls -F",
            "confirm": false
        }
    }
}
`;

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

    private async imageExists(): Promise<boolean> {
        const images = await this.docker.listImages();
        return images.some(image => image.RepoTags && image.RepoTags.includes(`${DOCKER_IMAGE_NAME}:latest`));
    }

    async ensureSandbox(): Promise<void> {
        if (!await this.imageExists()) {
            console.log(`Custom sandbox image '${DOCKER_IMAGE_NAME}' not found. Building...`);
            const uid = process.getuid ? process.getuid() : 1000;
            const gid = process.getgid ? process.getgid() : 1000;

            const stream = await this.docker.buildImage({
                context: `${process.cwd()}/docker-sandbox`,
                src: ['Dockerfile']
            }, {
                t: DOCKER_IMAGE_NAME,
                buildargs: {
                    USER_ID: uid.toString(),
                    GROUP_ID: gid.toString()
                }
            });

            await new Promise((resolve, reject) => {
                this.docker.modem.followProgress(stream, (err, res) => err ? reject(err) : resolve(res));
            });
            console.log('Sandbox image built successfully.');
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
            Image: DOCKER_IMAGE_NAME,
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
            
            stream.on('end', () => resolve({ stdout, stderr }));
        });
    }
} 