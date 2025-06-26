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

// --- Функция для чтения конфигурации из Prod.json ---
const loadConfig = (): { prod: boolean } => {
    try {
        const configPath = path.join(__dirname, '..', 'Prod.json');
        const configData = fs.readFileSync(configPath, 'utf-8');
        return JSON.parse(configData);
    } catch (error) {
        console.warn('Failed to load Prod.json, defaulting to development mode:', error);
        return { prod: false };
    }
};

// --- Deployment toggle based on Prod.json ---
const config = loadConfig();
const USE_REMOTE = config.prod;

const API_HOST = USE_REMOTE ? 'https://zetapi.loophole.site/' : 'http://localhost:4000';
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
        const password = await askQuestion(chalk.cyan('Password: ')); // TODO: скрыть пароль

        try {
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
    // для GUI на проде
    if (process.argv.includes('--beta-gui')) {
        const { spawn } = require('child_process');
        const path = require('path');
        const desktopDir = path.join(__dirname, '..', '..', 'desktop');
        const child = spawn('npm', ['run', 'start'], {
            cwd: desktopDir,
            stdio: 'inherit'
        });
        child.on('exit', (code: number) => process.exit(code ?? 0));
        return; 
    }

    console.log(chalk.cyan('Initializing Zet...'));
    
    let authToken = await ensureAuthenticated();

    const aiService = new AIService();
    const dockerService = new DockerService();

    while (true) {
        try {
            await dockerService.ensureSandbox();
            await aiService.init(authToken);
            await fetchRemaining(authToken);
            console.log(chalk.green('Initialization complete. Zet is ready.'));
            console.log(chalk.gray('Type "exit" or "quit" to end the session.'));
            break; 
        } catch (error: any) {
            if (error.status === 401 || error.status === 403 || error.status === 404) {
                console.error(chalk.yellow('Stored token is invalid or user is missing (status ' + error.status + '). Re-authentication required.'));
                deleteToken();
                authToken = await ensureAuthenticated();
                continue;
            }
            const message = error instanceof Error ? error.message : 'An unknown error occurred.';
            console.error(chalk.red('Fatal error during initialization:'), message);
            process.exit(1);
        }
    }

    let lastObservation = '';
    let currentPageId: number | null = null;

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

    while (true) {  
        const countStr = chalk.magenta(`[${remainingRequests ?? '-'}]`);
        const promptStr = `\n${countStr} > `;
        const userInput = await askQuestion(promptStr);

        const lowered = userInput.toLowerCase().trim();

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
                    console.log(chalk.yellow(`Page ${currentPageId} released.`));
                }
                console.log(chalk.green('Zet: Task complete. Ready for new task.'));
                currentPageId = null;
                lastObservation = 'Previous task was completed successfully. Ready for a new task.';
                continue; 
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
                const shouldConfirm = p.confirm === true;
                const promptText = p.prompt || `Update file "${targetFile}"? (y/n)`;

                let shouldProceed = true;
                if (shouldConfirm) {
                const answer = await askQuestion(chalk.yellow(`${promptText} `));
                    shouldProceed = answer.toLowerCase() === 'y';
                }

                if (!shouldProceed) {
                    console.log(chalk.yellow('Update aborted by user.'));
                    lastObservation = 'User aborted file update.';
                } else {
                    try {
                        const absPath = path.isAbsolute(targetFile)
                            ? targetFile
                            : path.join(process.cwd(), 'sandbox', targetFile);
                        
                        fs.mkdirSync(path.dirname(absPath), { recursive: true });

                        let newContent: string;

                        if (p.line_operations) {
                            const fileExists = fs.existsSync(absPath);
                            const fileLines = fileExists ? fs.readFileSync(absPath, 'utf-8').split(/\r?\n/) : [];
                            let workingLines = [...fileLines];

                            console.log(chalk.cyan('Applying line operations:'));
                            
                            const operations = Object.entries(p.line_operations).sort(([a], [b]) => parseInt(b) - parseInt(a));
                            
                            for (const [lineNum, operation] of operations) {
                                const lineIndex = parseInt(lineNum) - 1;
                                const op = operation as { action: 'insert' | 'replace' | 'delete'; content?: string };
                                
                                switch (op.action) {
                                    case 'insert':
                                        workingLines.splice(lineIndex, 0, op.content || '');
                                        console.log(chalk.green(`  ✓ Inserted line ${lineNum}: ${op.content}`));
                                        break;
                                    case 'replace':
                                        if (lineIndex < workingLines.length) {
                                            workingLines[lineIndex] = op.content || '';
                                            console.log(chalk.yellow(`  ✓ Replaced line ${lineNum}: ${op.content}`));
                                        }
                                        break;
                                    case 'delete':
                                        if (lineIndex < workingLines.length) {
                                            workingLines.splice(lineIndex, 1);
                                            console.log(chalk.red(`  ✓ Deleted line ${lineNum}`));
                                        }
                                        break;
                                }
                            }
                            newContent = workingLines.join('\n');
                        }
                        else if (p.code_lines) {
                            newContent = p.code_lines.join('\n');
                        }
                        else if (p.code) {
                            const editMode = p.edit as boolean;
                        if (editMode && typeof p.startLine === 'number' && typeof p.endLine === 'number') {
                            const fileLines = fs.readFileSync(absPath, 'utf-8').split(/\r?\n/);
                            const before = fileLines.slice(0, p.startLine - 1);
                            const after = fileLines.slice(p.endLine);
                                newContent = [...before, ...p.code.split(/\r?\n/), ...after].join('\n');
                            } else {
                                newContent = p.code;
                            }
                        } else {
                            throw new Error('No code content provided (code, code_lines, or line_operations required)');
                        }

                        fs.writeFileSync(absPath, newContent, 'utf-8');
                        console.log(chalk.green(`File ${targetFile} updated successfully.`));
                        lastObservation = `File ${targetFile} updated successfully.`;
                    } catch (err) {
                        console.error(chalk.red(`Failed to update file: ${(err as Error).message}`));
                        lastObservation = `Failed to update file: ${(err as Error).message}`;
                    }
                }
            }

            await fetchRemaining(authToken);

            if (typeof newPageId === 'number') {
                currentPageId = newPageId;
            }
        } catch (error: any) {
            console.error(chalk.red('\n--- Error Details ---'));
            
            if (error.message && error.message.includes('JSON')) {
                console.error(chalk.red('JSON parsing error detected. This may be due to:'));
                console.error(chalk.yellow('1. Server response formatting issues'));
                console.error(chalk.yellow('2. Network corruption'));
                console.error(chalk.yellow('3. API response truncation'));
                console.error(chalk.gray('Full error:'), error.message);
                lastObservation = 'The AI response contained malformed JSON and could not be processed. Please try rephrasing your request.';
            } else if (error.status === 429) {
                console.error(chalk.red('Request limit exceeded. Please upgrade your plan.'));
                lastObservation = 'The previous command failed because the request limit was exceeded.';
            } else if (error.status === 401 || error.status === 403 || error.status === 404) {
                console.error(chalk.red('Authentication error. Your session may have expired.'));
                deleteToken();
                authToken = await ensureAuthenticated();
                lastObservation = 'Authentication failed (status ' + error.status + '). A new login process has been started.';
                if (error.status === 400 || error.status === 404) {
                    currentPageId = null;
                }
            } else {
                const message = error.message || 'An unknown error occurred.';
                console.error(chalk.red('An error occurred:'), message);
                if (error.stack) {
                    console.error(chalk.gray('Stack trace:'), error.stack);
                }
                lastObservation = `The last action failed with error: ${message}. I should probably try something else.`;
            }
            
            console.error(chalk.red('--- End Error Details ---\n'));
        }
    }
    rl.close();
    console.log(chalk.cyan('Session terminated.')); 
}

main(); 
