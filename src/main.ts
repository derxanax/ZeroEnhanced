import axios from 'axios';
import chalk from 'chalk';
import cors from 'cors';
import express from 'express';
import fs from 'fs';
import os from 'os';
import path from 'path';
import readline from 'readline';
import { AIService, DockerService } from './core';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// --- Функция для чтения конфигурации из Prod.json ---
const loadConfig = (): { prod: boolean; domain?: string } => {
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

const API_HOST = USE_REMOTE ? (config.domain || 'https://zetapi.loophole.site/') : 'http://localhost:4000';
const AUTH_API_URL = `${API_HOST}/api/auth`;
const CONFIG_DIR = path.join(os.homedir(), '.config', 'zet');
const TOKEN_PATH = path.join(CONFIG_DIR, 'token');

type UserInfo = { email: string; request_count: number };

const askQuestion = (query: string): Promise<string> => new Promise(resolve => rl.question(query, resolve));

let remainingRequests: number | null = null;

const fetchRemaining = async (token: string): Promise<void> => {
    try {
        // ответ: { email: string, request_count: number }
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

    console.log(chalk.yellow('Требуется авторизация.'));

    while (true) {
        const email = await askQuestion(chalk.cyan('Email: '));
        const password = await askQuestion(chalk.cyan('Пароль: '));

        try {
            // ответ: { token: string }
            const loginResp = await axios.post(`${AUTH_API_URL}/login`, { email, password });
            const token: string = loginResp.data.token;
            saveToken(token);
            await fetchRemaining(token);
            console.log(chalk.green(`Вход выполнен. Запросов осталось: ${remainingRequests ?? 'N/A'}`));
            return token;
        } catch (err: any) {
            if (axios.isAxiosError(err) && err.response?.status === 404) {
                // Пользователь не найден – предложим зарегистрироваться
                const answer = await askQuestion(chalk.yellow('Пользователь не найден. Создать аккаунт? (y/n) '));
                if (answer.toLowerCase() !== 'y') {
                    continue;
                }
                try {
                    // ответ: { token: string }
                    const regResp = await axios.post(`${AUTH_API_URL}/register`, { email, password });
                    const token: string = regResp.data.token;
                    saveToken(token);
                    await fetchRemaining(token);
                    console.log(chalk.green(`Регистрация прошла успешно. Запросов осталось: ${remainingRequests ?? 'N/A'}`));
                    return token;
                } catch (regErr: any) {
                    console.error(chalk.red(regErr.response?.data?.error || 'Ошибка регистрации.'));
                    continue;
                }
            } else if (axios.isAxiosError(err) && err.response?.status === 401) {
                console.error(chalk.red('Неверный пароль.'));
                continue;
            } else {
                console.error(chalk.red('Ошибка входа:'), err.message);
                continue;
            }
        }
    }
};

// Спиннер для анимации загрузки
class Spinner {
    private frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    private interval: NodeJS.Timeout | null = null;
    private frameIndex = 0;
    private message = '';

    start(message: string): void {
        this.message = message;
        this.interval = setInterval(() => {
            process.stdout.write(`\r${chalk.cyan(this.frames[this.frameIndex])} ${chalk.yellow(this.message)}`);
            this.frameIndex = (this.frameIndex + 1) % this.frames.length;
        }, 100);
    }

    stop(): void {
        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
            process.stdout.write('\r' + ' '.repeat(50) + '\r');
        }
    }
}

async function main() {
    // для GUI на проде
    if (process.argv.includes('--beta-gui')) {
        const { spawn } = require('child_process');
        const path = require('path');
        const desktopDir = path.join(__dirname, '..', '..', 'desktop');

        console.log(chalk.cyan('🚀 Запуск GUI-драйвера...'));

        const dockerService = new DockerService();
        try {
            await dockerService.ensureSandbox();
            console.log(chalk.green('✅ Docker Sandbox готов.'));
        } catch (error) {
            console.error(chalk.red('💥 Критическая ошибка Docker:'), error);
            process.exit(1);
        }

        const app = express();
        const GUI_DRIVER_PORT = 4001;
        app.use(cors());
        app.use(express.json());

        app.post('/api/execute', async (req: express.Request, res: express.Response) => {
            const { command } = req.body;
            if (!command) {
                return res.status(400).json({ error: 'Команда не предоставлена' });
            }
            try {
                console.log(chalk.yellow(`⚡ GUI | Выполняется: ${command}`));
                const result = await dockerService.executeCommand(command);
                res.json(result);
            } catch (error) {
                const message = error instanceof Error ? error.message : 'Неизвестная ошибка Docker';
                console.error(chalk.red('🐳 GUI | Ошибка Docker:'), message);
                res.status(500).json({ error: message });
            }
        });

        app.post('/api/update-file', async (req: express.Request, res: express.Response) => {
            const p = req.body;
            try {
                if (!p.file) throw new Error('Имя файла не предоставлено');

                let newContent: string;
                if (p.code_lines) newContent = p.code_lines.join('\\n');
                else if (p.code) newContent = p.code;
                else throw new Error('Содержимое файла не предоставлено (code или code_lines)');

                const base64Content = Buffer.from(newContent).toString('base64');
                const command = `mkdir -p $(dirname '${p.file}') && echo '${base64Content}' | base64 -d > '${p.file}'`;

                console.log(chalk.yellow(`⚡ GUI | Запись в файл: ${p.file}`));
                const result = await dockerService.executeCommand(command);
                if (result.stderr) throw new Error(result.stderr);

                res.json({ success: true, ...result });
            } catch (error) {
                const message = error instanceof Error ? error.message : 'Неизвестная ошибка обновления файла';
                console.error(chalk.red('📝 GUI | Ошибка обновления файла:'), message);
                res.status(500).json({ error: message });
            }
        });

        app.post('/api/files', async (req: express.Request, res: express.Response) => {
            const { path = '.' } = req.body;
            try {
                console.log(chalk.yellow(`⚡ GUI | Листинг файлов в: ${path}`));
                // Безопасная обработка пути
                const safePath = path.replace(/'/g, "'\\''");
                const result = await dockerService.executeCommand(`ls -F '${safePath}'`);
                if (result.stderr) throw new Error(result.stderr);
                res.json({ files: result.stdout.split('\\n').filter(Boolean) });
            } catch (error) {
                const message = error instanceof Error ? error.message : 'Неизвестная ошибка листинга файлов';
                console.error(chalk.red('📂 GUI | Ошибка листинга файлов:'), message);
                res.status(500).json({ error: message });
            }
        });

        app.post('/api/file/read', async (req: express.Request, res: express.Response) => {
            const { file } = req.body;
            if (!file) {
                return res.status(400).json({ error: 'Имя файла не предоставлено' });
            }
            try {
                console.log(chalk.yellow(`⚡ GUI | Чтение файла: ${file}`));
                const safeFile = file.replace(/'/g, "'\\''");
                const result = await dockerService.executeCommand(`cat '${safeFile}'`);
                // stderr может содержать сообщения, которые не являются ошибками, но cat в случае успеха не должен ничего туда писать
                if (result.stderr) throw new Error(result.stderr);
                res.json({ content: result.stdout });
            } catch (error) {
                const message = error instanceof Error ? error.message : 'Неизвестная ошибка чтения файла';
                console.error(chalk.red('📖 GUI | Ошибка чтения файла:'), message);
                res.status(500).json({ error: message });
            }
        });

        app.listen(GUI_DRIVER_PORT, () => {
            console.log(chalk.green(`✅ GUI-драйвер слушает на порту ${GUI_DRIVER_PORT}`));
        });

        const child = spawn('npm', ['run', 'start'], {
            cwd: desktopDir,
            stdio: 'inherit'
        });
        child.on('exit', (code: number) => process.exit(code ?? 0));
        return;
    }

    console.log(chalk.cyan('🚀 Zet Enhanced запускается...'));

    let authToken = await ensureAuthenticated();

    const aiService = new AIService();
    const dockerService = new DockerService();
    const spinner = new Spinner();

    while (true) {
        try {
            await dockerService.ensureSandbox();
            await aiService.init(authToken);
            await fetchRemaining(authToken);
            console.log(chalk.green('✅ Готов к работе!'));
            console.log(chalk.gray('Введите "exit" или "quit" для выхода.'));
            break;
        } catch (error: any) {
            if (error.status === 401 || error.status === 403 || error.status === 404) {
                console.error(chalk.yellow(`🔄 Токен недействителен (статус ${error.status}). Требуется повторная авторизация.`));
                deleteToken();
                authToken = await ensureAuthenticated();
                continue;
            }
            const message = error instanceof Error ? error.message : 'Неизвестная ошибка.';
            console.error(chalk.red('💥 Критическая ошибка инициализации:'), message);
            process.exit(1);
        }
    }

    let lastObservation = '';
    let currentPageId: number | null = null;

    process.on('SIGINT', async () => {
        try {
            if (currentPageId !== null) {
                await axios.post(`${API_HOST}/api/exit`, { pageId: currentPageId }).catch(() => { });
                console.log(chalk.yellow(`\n📄 Страница ${currentPageId} освобождена.`));
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
            console.log(chalk.yellow('🗑️ Удаление локальной сессии...'));
            deleteToken();
            console.log(chalk.cyan('🔄 Сессия удалена. Войдите снова.'));
            authToken = await ensureAuthenticated();
            lastObservation = 'Пользователь явно удалил сессию и прошел повторную аутентификацию.';
            continue;
        }

        if (lowered === 'exit' || lowered === 'quit') {
            break;
        }

        try {
            spinner.start('Zet думает...');

            let streamBuffer = '';
            let isThinking = true;
            let lastThoughtLength = 0;

            const { ai: aiResponse, pageId: newPageId } = await aiService.getCommand(
                userInput,
                lastObservation,
                authToken,
                currentPageId === null ? undefined : currentPageId,
                (chunk: string) => {
                    spinner.stop();
                    streamBuffer += chunk;

                    try {
                        const thoughtMatch = streamBuffer.match(/"thought":\s*"([^"]*(?:\\.[^"]*)*)/);
                        if (thoughtMatch) {
                            const thoughtText = thoughtMatch[1]
                                .replace(/\\n/g, '\n')
                                .replace(/\\"/g, '"')
                                .replace(/\\\\/g, '\\');

                            if (thoughtText.length > lastThoughtLength) {
                                if (isThinking) {
                                    process.stdout.write(chalk.gray('💭 '));
                                    isThinking = false;
                                }

                                const newText = thoughtText.slice(lastThoughtLength);
                                process.stdout.write(chalk.gray(newText));
                                lastThoughtLength = thoughtText.length;
                            }
                        }
                    } catch (e) {

                    }
                }
            );

            spinner.stop();

            if (lastThoughtLength === 0) {
                console.log(chalk.gray(`💭 ${aiResponse.thought}`));
            } else {
                console.log('');
            }

            if (aiResponse.displayText) {
                console.log(chalk.cyan(`\n📝 ${aiResponse.displayText}`));
            }

            const { tool, parameters } = aiResponse.action;

            if (tool === 'protocol_complete') {
                if (currentPageId !== null) {
                    await axios.post(`${API_HOST}/api/exit`, { pageId: currentPageId }).catch(() => { });
                    console.log(chalk.yellow(`📄 Страница ${currentPageId} освобождена.`));
                }
                console.log(chalk.green('✅ Задача завершена. Готов к новой задаче.'));
                currentPageId = null;
                lastObservation = 'Предыдущая задача была успешно завершена. Готов к новой задаче.';
                continue;
            }

            if (tool === 'execute_command' && parameters && 'command' in parameters) {
                const cmdParams = parameters as { command: string; confirm: boolean; prompt?: string };

                if (cmdParams.confirm) {
                    const confirmPrompt = cmdParams.prompt || `Выполнить команду "${cmdParams.command}"? (y/n)`;
                    const confirmation = await askQuestion(chalk.red(`⚠️ ${confirmPrompt} `));
                    if (confirmation.toLowerCase() !== 'y') {
                        console.log(chalk.yellow('❌ Команда отменена пользователем.'));
                        lastObservation = 'Пользователь отменил выполнение предыдущей команды.';
                        continue;
                    }
                }

                console.log(chalk.yellow(`⚡ Выполняется: ${cmdParams.command}`));

                try {
                    const { stdout, stderr } = await dockerService.executeCommand(cmdParams.command);

                    if (stdout) {
                        console.log(chalk.green('📤 Результат:'));
                        console.log(stdout);
                        lastObservation = `Команда "${cmdParams.command}" выполнена и вернула:\n${stdout}`;
                    }

                    if (stderr) {
                        console.error(chalk.red('🔥 Ошибка:'));
                        console.error(stderr);
                        lastObservation = `Команда "${cmdParams.command}" завершилась с ошибкой:\n${stderr}`;
                    }

                    if (!stdout && !stderr) {
                        console.log(chalk.gray('✅ Команда выполнена без вывода.'));
                        lastObservation = `Команда "${cmdParams.command}" выполнена без вывода.`;
                    }
                } catch (dockerError) {
                    console.error(chalk.red('🐳 Ошибка Docker:'), dockerError);
                    lastObservation = `Команда "${cmdParams.command}" не смогла выполниться: ${dockerError instanceof Error ? dockerError.message : 'Неизвестная ошибка Docker'}`;
                }
            }

            else if (tool === 'update_file' && parameters) {
                const p: any = parameters;
                const targetFile = p.file;
                const shouldConfirm = p.confirm === true;
                const promptText = p.prompt || `Обновить файл "${targetFile}"? (y/n)`;

                let shouldProceed = true;
                if (shouldConfirm) {
                    const answer = await askQuestion(chalk.yellow(`📝 ${promptText} `));
                    shouldProceed = answer.toLowerCase() === 'y';
                }

                if (!shouldProceed) {
                    console.log(chalk.yellow('❌ Обновление отменено пользователем.'));
                    lastObservation = 'Пользователь отменил обновление файла.';
                } else {
                    try {
                        let newContent: string;

                        if (p.file.includes('..')) {
                            throw new Error('Недопустимый путь к файлу: путь не может содержать ".."');
                        }

                        if (p.line_operations) {
                            console.log(chalk.red('❌ Обновление по строкам пока не поддерживается через Docker. Используйте полную замену файла.'));
                            lastObservation = 'Обновление по строкам не удалось.';
                            continue;
                        }
                        else if (p.code_lines) {
                            newContent = p.code_lines.join('\n');
                            console.log(chalk.cyan(`📝 Подготовка к записи ${p.code_lines.length} строк в файл ${targetFile}`));
                        }
                        else if (p.code) {
                            newContent = p.code;
                            console.log(chalk.cyan(`📝 Подготовка к записи в файл ${targetFile}`));
                        }
                        else {
                            throw new Error('Не предоставлен контент для кода (требуется code, code_lines или line_operations)');
                        }

                        const base64Content = Buffer.from(newContent).toString('base64');
                        const command = `mkdir -p $(dirname '${targetFile}') && echo '${base64Content}' | base64 -d > '${targetFile}'`;

                        console.log(chalk.yellow(`⚡ Выполняется запись в файл через Docker...`));
                        const { stdout, stderr } = await dockerService.executeCommand(command);

                        if (stderr) {
                            throw new Error(stderr);
                        }

                        console.log(chalk.green(`✅ Файл ${targetFile} успешно обновлен в контейнере.`));
                        lastObservation = `Файл ${targetFile} успешно обновлен.`;
                        if (stdout) {
                            console.log(chalk.gray(stdout));
                        }

                    } catch (err) {
                        console.error(chalk.red(`💥 Ошибка обновления файла: ${(err as Error).message}`));
                        lastObservation = `Ошибка обновления файла: ${(err as Error).message}`;
                    }
                }
            }

            await fetchRemaining(authToken);

            if (typeof newPageId === 'number') {
                currentPageId = newPageId;
            }
        } catch (error: any) {
            spinner.stop();
            console.error(chalk.red('\n🚨 Ошибка:'));

            if (error.message && error.message.includes('JSON')) {
                console.error(chalk.red('📝 Ошибка парсинга JSON. Возможные причины:'));
                console.error(chalk.yellow('• Проблемы с форматированием ответа сервера'));
                console.error(chalk.yellow('• Повреждение данных при передаче'));
                lastObservation = 'Ответ ИИ содержал некорректный JSON и не мог быть обработан. Попробуйте переформулировать запрос.';
            } else if (error.status === 429) {
                console.error(chalk.red('🚫 Превышен лимит запросов.'));
                lastObservation = 'Предыдущая команда не выполнилась из-за превышения лимита запросов.';
            } else if (error.status === 401 || error.status === 403 || error.status === 404) {
                console.error(chalk.red('🔑 Ошибка аутентификации. Возможно, сессия истекла.'));
                deleteToken();
                authToken = await ensureAuthenticated();
                lastObservation = `Ошибка аутентификации (статус ${error.status}). Начат новый процесс входа.`;
                if (error.status === 400 || error.status === 404) {
                    currentPageId = null;
                }
            } else if (error.message && error.message.includes('fetch')) {
                console.error(chalk.red('🌐 Ошибка сети: Не удалось подключиться к API стриминга'));
                lastObservation = 'Ошибка сетевого подключения. API стриминга может быть временно недоступен.';
            } else {
                const message = error.message || 'Произошла неизвестная ошибка.';
                console.error(chalk.red('💥 Произошла ошибка:'), message);
                lastObservation = `Последнее действие завершилось с ошибкой: ${message}. Попробую что-то другое.`;
            }

            if (error.status === 503 || (error.message && error.message.includes('503'))) {
                console.log(chalk.yellow('🔄 Сервис временно недоступен. Повтор через 5 секунд...'));
                await new Promise(resolve => setTimeout(resolve, 5000));
            }
        }
    }
    rl.close();
    console.log(chalk.cyan('👋 Сессия завершена. Спасибо за использование Zet Enhanced!'));
}

main(); 
