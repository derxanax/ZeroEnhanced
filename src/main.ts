import readline from 'readline';
import chalk from 'chalk';
import { AIService, DockerService } from './core';
import fs from 'fs';
import path from 'path';
import os from 'os';
import axios from 'axios';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// --- Deployment toggle: 1 = production (api.derx.space), 0 = localhost ---
const USE_REMOTE = process.env.ZET_USE_REMOTE === '1';

const API_HOST = USE_REMOTE ? 'https://api.derx.space' : 'http://localhost:4000';
const AUTH_API_URL = `${API_HOST}/api/auth`;
const CONFIG_DIR = path.join(os.homedir(), '.config', 'zet');
const TOKEN_PATH = path.join(CONFIG_DIR, 'token');

type UserInfo = { email: string; request_count: number };

const askQuestion = (query: string): Promise<string> => new Promise(resolve => rl.question(query, resolve));

let remainingRequests: number | null = null;

const fetchRemaining = async (token: string): Promise<void> => {
    try {
        const resp = await axios.get<UserInfo>(`${API_HOST}/api/user/me`, {
            headers: { Authorization: `Bearer ${token}` }
        });
        remainingRequests = resp.data.request_count;
    } catch {
        remainingRequests = null;
    }
};

// --- Token Management ---
const saveToken = (token: string): void => {
    if (!fs.existsSync(CONFIG_DIR)) {
        fs.mkdirSync(CONFIG_DIR, { recursive: true });
    }
    fs.writeFileSync(TOKEN_PATH, token, 'utf-8');
};

const readToken = (): string | null => {
    if (fs.existsSync(TOKEN_PATH)) {
        return fs.readFileSync(TOKEN_PATH, 'utf-8');
    }
    return null;
};

const deleteToken = (): void => {
    if (fs.existsSync(TOKEN_PATH)) {
        fs.unlinkSync(TOKEN_PATH);
    }
};

// --- Authentication Flow (CLI) ---
const ensureAuthenticated = async (): Promise<string> => {
    const existingToken = readToken();
    if (existingToken) return existingToken;

    console.log(chalk.yellow('Authentication required.'));    

    while (true) {
        const email = await askQuestion(chalk.cyan('Email: '));
        const password = await askQuestion(chalk.cyan('Password: ')); // пароль виден; можно заменить на скрытый ввод при желании

        try {
            // Пытаемся войти
            const loginResp = await axios.post(`${AUTH_API_URL}/login`, { email, password });
            const token: string = loginResp.data.token;
            saveToken(token);
            await fetchRemaining(token);
            console.log(chalk.green(`Login successful. Requests left: ${remainingRequests ?? 'N/A'}`));
            return token;
        } catch (err: any) {
            if (axios.isAxiosError(err) && err.response?.status === 404) {
                // Пользователь не найден – предложим зарегистрироваться
                const answer = await askQuestion(chalk.yellow('User not found. Register new account? (y/n) '));
                if (answer.toLowerCase() !== 'y') {
                    continue;
                }
                try {
                    const regResp = await axios.post(`${AUTH_API_URL}/register`, { email, password });
                    const token: string = regResp.data.token;
                    saveToken(token);
                    await fetchRemaining(token);
                    console.log(chalk.green(`Registration successful. Requests left: ${remainingRequests ?? 'N/A'}`));
                    return token;
                } catch (regErr: any) {
                    console.error(chalk.red(regErr.response?.data?.error || 'Registration failed.'));
                    continue;
                }
            } else if (axios.isAxiosError(err) && err.response?.status === 401) {
                console.error(chalk.red('Invalid password.'));
                continue;
            } else {
                console.error(chalk.red('Login failed:'), err.message);
                continue;
            }
        }
    }
};

async function main() {
    // Early GUI flag detection
    if (process.argv.includes('--beta-gui')) {
        const { spawn } = require('child_process');
        const path = require('path');
        const desktopDir = path.join(__dirname, '..', '..', 'desktop');
        const child = spawn('npm', ['run', 'start'], {
            cwd: desktopDir,
            stdio: 'inherit'
        });
        child.on('exit', (code: number) => process.exit(code ?? 0));
        return; // do not continue CLI flow
    }

    console.log(chalk.cyan('Initializing Zet...')); //! ыы я тупой пиндо ббббе пишу на английском блять
    
    let authToken = await ensureAuthenticated();

    const aiService = new AIService();
    const dockerService = new DockerService();

    // --- Инициализация с возможной повторной авторизацией ---
    while (true) {
        try {
            await dockerService.ensureSandbox();
            await aiService.init(authToken);
            await fetchRemaining(authToken);
            console.log(chalk.green('Initialization complete. Zet is ready.'));
            console.log(chalk.gray('Type "exit" or "quit" to end the session.'));
            break; // успех — выходим из цикла
        } catch (error: any) {
            if (error.status === 401 || error.status === 403 || error.status === 404) {
                console.error(chalk.yellow('Stored token is invalid or user is missing (status ' + error.status + '). Re-authentication required.'));
                deleteToken();
                authToken = await ensureAuthenticated();
                // повторим цикл
                continue;
            }
            const message = error instanceof Error ? error.message : 'An unknown error occurred.';
            console.error(chalk.red('Fatal error during initialization:'), message);
            process.exit(1);
        }
    }

    let lastObservation = '';
    let currentPageId: number | null = null;

    // Release page on Ctrl+C
    process.on('SIGINT', async () => {
        try {
            if (currentPageId !== null) {
                await axios.post(`${API_HOST}/api/exit`, { pageId: currentPageId }).catch(() => {});
                console.log(chalk.yellow(`\nPage ${currentPageId} released.`));
            }
        } finally {
            rl.close();
            process.exit(0);
        }
    });

    while (true) { //* адская дрочильня 
        const countStr = chalk.magenta(`[${remainingRequests ?? '-'}]`);
        const promptStr = `\n${countStr} > `;
        const userInput = await askQuestion(promptStr);

        const lowered = userInput.toLowerCase().trim();

        // --- Local utility commands ---
        if (lowered === '/deluser' || lowered === '/logout') {
            console.log(chalk.yellow('Deleting local session...'));
            deleteToken();
            console.log(chalk.cyan('Session deleted. Please authenticate again.'));
            authToken = await ensureAuthenticated();
            lastObservation = 'User explicitly deleted the session and re-authenticated.';
            continue;
        }

        if (lowered === 'exit' || lowered === 'quit') {
            break;
        }

        try {
            console.log(chalk.yellow('Zet is thinking...'));
            const { ai: aiResponse, pageId: newPageId } = await aiService.getCommand(userInput, lastObservation, authToken, currentPageId === null ? undefined : currentPageId);

            console.log(chalk.magenta(`Thought: ${aiResponse.thought}`));

            if (aiResponse.displayText) {
                console.log(chalk.cyan(`\n${aiResponse.displayText}`));
            }

            const { tool, parameters } = aiResponse.action;

            if (tool === 'protocol_complete') {
                if (currentPageId !== null) {
                    await axios.post(`${API_HOST}/api/exit`, { pageId: currentPageId }).catch(()=>{});
                }
                console.log(chalk.green('Zet: Task complete. Ending session.'));
                break;
            }

            if (tool === 'execute_command' && parameters && 'command' in parameters) {
                const cmdParams = parameters as { command: string; confirm: boolean; prompt?: string };

                if (cmdParams.confirm) {
                    const confirmPrompt = cmdParams.prompt || `Execute command "${cmdParams.command}"? (y/n)`;
                    const confirmation = await askQuestion(chalk.red(`${confirmPrompt} `));
                    if (confirmation.toLowerCase() !== 'y') {
                        console.log(chalk.yellow('Command aborted by user.'));
                        lastObservation = 'User aborted the previous command.';
                        continue;
                    }
                }

                console.log(chalk.yellow(`Executing: ${cmdParams.command}`));
                const { stdout, stderr } = await dockerService.executeCommand(cmdParams.command);

                if (stdout) {
                    console.log(chalk.green(stdout));
                    lastObservation = `Command "${cmdParams.command}" executed and returned:\n${stdout}`;
                }
                if (stderr) {
                    console.error(chalk.red(stderr));
                    lastObservation = `Command "${cmdParams.command}" failed with error:\n${stderr}`;
                }
                if (!stdout && !stderr) {
                    lastObservation = `Command "${cmdParams.command}" executed with no output.`;
                }
            }

            else if (tool === 'update_file' && parameters) {
                const p: any = parameters;
                const targetFile = p.file;
                const code = p.code as string;
                const editMode = p.edit as boolean;
                const promptText = p.prompt || `Update file "${targetFile}"? (y/n)`;

                const answer = await askQuestion(chalk.yellow(`${promptText} `));
                if (answer.toLowerCase() !== 'y') {
                    console.log(chalk.yellow('Update aborted by user.'));
                    lastObservation = 'User aborted file update.';
                } else {
                    try {
                        const absPath = path.isAbsolute(targetFile)
                            ? targetFile
                            : path.join(process.cwd(), 'sandbox', targetFile);
                        // ensure directory exists
                        fs.mkdirSync(path.dirname(absPath), { recursive: true });

                        let newContent: string;
                        if (editMode && typeof p.startLine === 'number' && typeof p.endLine === 'number') {
                            const fileLines = fs.readFileSync(absPath, 'utf-8').split(/\r?\n/);
                            const before = fileLines.slice(0, p.startLine - 1);
                            const after = fileLines.slice(p.endLine);
                            newContent = [...before, ...code.split(/\r?\n/), ...after].join('\n');
                        } else {
                            newContent = code;
                        }
                        fs.writeFileSync(absPath, newContent, 'utf-8');
                        console.log(chalk.green(`File ${targetFile} updated.`));
                        lastObservation = `File ${targetFile} updated successfully.`;
                    } catch (err) {
                        console.error(chalk.red(`Failed to update file: ${(err as Error).message}`));
                        lastObservation = `Failed to update file: ${(err as Error).message}`;
                    }
                }
            }

            // запрос к AI тоже списывает лимит — обновим
            await fetchRemaining(authToken);

            if (typeof newPageId === 'number') {
                currentPageId = newPageId;
            }
        } catch (error: any) {
            if (error.status === 429) {
                console.error(chalk.red('Request limit exceeded. Please upgrade your plan.'));
                lastObservation = 'The previous command failed because the request limit was exceeded.';
            } else if (error.status === 401 || error.status === 403 || error.status === 404) {
                console.error(chalk.red('Authentication error. Your session may have expired.'));
                deleteToken();
                authToken = await ensureAuthenticated();
                lastObservation = 'Authentication failed (status ' + error.status + '). A new login process has been started.';
                if (error.status === 400 || error.status === 404) {
                    currentPageId = null; // invalidate page
                }
            } else {
                const message = error.message || 'An unknown error occurred.';
                console.error(chalk.red('An error occurred:'), message);
                lastObservation = `The last action failed with error: ${message}. I should probably try something else.`;
            }
        }
    }
    rl.close(); //! зараза мне кажется лучше как то ппо дургому прогу стопать
    console.log(chalk.cyan('Session terminated.')); 
}
main(); 