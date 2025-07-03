// шок деркс еблан и сунул инфу о том как он круто мержил что поломал билдтнг

import axios from 'axios';
import cors from 'cors';
import Docker from 'dockerode';
import express, { Request, Response } from 'express';
import fs from 'fs';
import { createServer } from 'http';
import os from 'os';
import path from 'path';
import { Writable } from 'stream';
import { WebSocketServer } from 'ws';

// --- Функция для чтения конфигурации из Prod.json ---
const loadConfig = (): { prod: boolean; domain?: string } => {
  try {
    const configPath = path.join(__dirname, '..', '..', 'Prod.json');
    const configData = fs.readFileSync(configPath, 'utf-8');
    return JSON.parse(configData);
  } catch (error) {
    console.warn('Failed to load Prod.json, defaulting to development mode:', error);
    return { prod: false };
  }
};

// --- Load configuration ---
const config = loadConfig();
const IS_PRODUCTION = config.prod;
const FRONTEND_DOMAIN = config.domain;

console.log(`Server running in ${IS_PRODUCTION ? 'PRODUCTION' : 'DEVELOPMENT'} mode`);
if (IS_PRODUCTION && FRONTEND_DOMAIN) {
  console.log(`Frontend domain: ${FRONTEND_DOMAIN}`);
}

const app = express();
const PORT = process.env.PORT || 3003;
const WS_PORT = 8080;

const USE_REMOTE = IS_PRODUCTION;
const API_HOST = USE_REMOTE ? (FRONTEND_DOMAIN || 'https://zetapi.loophole.site/') : 'http://localhost:4000';
const API_STREAM_URL = `${API_HOST}/api/stream`;
const API_PROXY_URL = `${API_HOST}/api/proxy`;

const DOCKER_IMAGE_NAME = 'zet-sandbox-image';
const SANDBOX_CONTAINER_NAME = 'zet-sandbox';

const docker = new Docker();

// --- CORS configuration based on environment ---
const allowedOrigins = IS_PRODUCTION && FRONTEND_DOMAIN
  ? [FRONTEND_DOMAIN, 'http://localhost:3000', 'http://127.0.0.1:3000', 'http://localhost:8080']
  : ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://localhost:8080'];

app.use(cors({
  origin: allowedOrigins,
  credentials: true
}));
app.use(express.json());

// Enhanced error handling function like in main.ts
const handleAPIError = (error: any, res: Response) => {
  if (axios.isAxiosError(error) && error.response) {
    const status = error.response.status;

    switch (status) {
      case 401:
      case 403:
      case 404:
        res.status(status).json({
          error: 'Authentication error',
          code: status,
          message: 'Token invalid or user missing'
        });
        break;

      case 429:
        res.status(status).json({
          error: 'Rate limit exceeded',
          code: status,
          message: 'Request limit exceeded'
        });
        break;

      default:
        res.status(status).json(error.response.data);
    }
  } else {
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
};

// Helper functions for file operations
const updateFile = async (parameters: any): Promise<any> => {
  const { file, code, edit, startLine, endLine } = parameters;

  try {
    const sandboxPath = path.join(process.cwd(), 'sandbox');
    if (!fs.existsSync(sandboxPath)) {
      fs.mkdirSync(sandboxPath, { recursive: true });
    }

    const absPath = path.isAbsolute(file)
      ? file
      : path.join(sandboxPath, file);

    // Create directory if it doesn't exist
    fs.mkdirSync(path.dirname(absPath), { recursive: true });

    let newContent: string;
    if (edit && typeof startLine === 'number' && typeof endLine === 'number') {
      const fileLines = fs.readFileSync(absPath, 'utf-8').split(/\r?\n/);
      const before = fileLines.slice(0, startLine - 1);
      const after = fileLines.slice(endLine);
      newContent = [...before, ...code.split(/\r?\n/), ...after].join('\n');
    } else {
      newContent = code;
    }

    fs.writeFileSync(absPath, newContent, 'utf-8');
    return { success: true, message: `File ${file} updated successfully` };
  } catch (err) {
    return { success: false, error: (err as Error).message };
  }
};

// Execute command helper
const executeCommand = async (command: string): Promise<{ stdout: string; stderr: string }> => {
  const container = await findContainer();
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

    docker.modem.demuxStream(stream, stdoutStream, stderrStream);
    stream.on('end', () => resolve({ stdout, stderr }));
  });
};

// Authentication endpoints
app.post('/api/auth/login', async (req, res) => {
  try {
    // ответ от внешнего api: { token: string }
    const response = await axios.post(`${API_HOST}/api/auth/login`, req.body);
    res.json(response.data);
  } catch (error) {
    handleAPIError(error, res);
  }
});

app.post('/api/auth/register', async (req, res) => {
  try {
    // ответ от внешнего api: { token: string }
    const response = await axios.post(`${API_HOST}/api/auth/register`, req.body);
    res.json(response.data);
  } catch (error) {
    handleAPIError(error, res);
  }
});

// Token synchronization endpoints
app.get('/api/auth/token', async (req: Request, res: Response) => {
  try {
    const tokenPath = path.join(os.homedir(), '.config', 'zet', 'token');

    if (fs.existsSync(tokenPath)) {
      const token = fs.readFileSync(tokenPath, 'utf-8').trim();
      res.json({ token });
    } else {
      res.status(404).json({ error: 'Token not found' });
    }
  } catch (error) {
    res.status(500).json({
      error: 'Failed to read token',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

app.post('/api/auth/token', async (req: Request, res: Response) => {
  try {
    const { token } = req.body;

    if (!token) {
      res.status(400).json({ error: 'Token is required' });
      return;
    }

    const configDir = path.join(os.homedir(), '.config', 'zet');
    const tokenPath = path.join(configDir, 'token');

    // Create directory if it doesn't exist
    if (!fs.existsSync(configDir)) {
      fs.mkdirSync(configDir, { recursive: true });
    }

    fs.writeFileSync(tokenPath, token, 'utf-8');
    res.json({ success: true, message: 'Token saved successfully' });
  } catch (error) {
    res.status(500).json({
      error: 'Failed to save token',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

app.delete('/api/auth/token', async (req: Request, res: Response) => {
  try {
    const tokenPath = path.join(os.homedir(), '.config', 'zet', 'token');

    if (fs.existsSync(tokenPath)) {
      fs.unlinkSync(tokenPath);
      res.json({ success: true, message: 'Token deleted successfully' });
    } else {
      res.json({ success: true, message: 'Token already not exists' });
    }
  } catch (error) {
    res.status(500).json({
      error: 'Failed to delete token',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// NEW: Session management endpoint
app.post('/api/exit', async (req: Request, res: Response) => {
  try {
    const { pageId } = req.body;

    if (pageId) {
      // Send request to release pageId
      await axios.post(`${API_HOST}/api/exit`,
        { pageId },
        { headers: { 'Authorization': req.headers.authorization } }
      );
    }

    res.json({ success: true, message: 'Session ended successfully' });
  } catch (error) {
    console.error('Failed to end session:', error);
    handleAPIError(error, res);
  }
});

// NEW: Enhanced AI proxy endpoint for new Qwen API
app.post('/api/proxy/chat/completions', async (req: Request, res: Response) => {
  try {
    const { message, model = 'qwen2.5-coder-32b-instruct', stream = false } = req.body;

    const generateChatId = (): string => {
      return 'chat-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    };

    const chatId = generateChatId();

    const requestBody = {
      model,
      messages: [
        {
          role: 'user',
          content: message
        }
      ],
      stream
    };

    console.log(`[BACKEND] Making request to: ${API_PROXY_URL}/chat/completions?chat_id=${chatId}`);

    const response = await axios.post(`${API_PROXY_URL}/chat/completions?chat_id=${chatId}`, requestBody, {
      headers: {
        'Authorization': req.headers.authorization,
        'Content-Type': 'application/json'
      }
    });

    const aiResponse = response.data.choices?.[0]?.message?.content || response.data.response;

    if (aiResponse) {
      try {
        const parsedResponse = JSON.parse(aiResponse);

        // Process different AI action types
        switch (parsedResponse.action?.tool) {
          case 'execute_command':
            // Auto-execute command if confirm: false
            if (!parsedResponse.action.parameters.confirm) {
              try {
                const cmdResult = await executeCommand(parsedResponse.action.parameters.command);
                parsedResponse.executionResult = cmdResult;
              } catch (error) {
                parsedResponse.executionResult = {
                  success: false,
                  error: error instanceof Error ? error.message : 'Command execution failed'
                };
              }
            }
            break;

          case 'update_file':
            // Auto-update file if confirm: false
            if (!parsedResponse.action.parameters.confirm) {
              const fileResult = await updateFile(parsedResponse.action.parameters);
              parsedResponse.executionResult = fileResult;
            }
            break;

          case 'protocol_complete':
            // Auto-end session
            break;
        }

        res.json({
          response: JSON.stringify(parsedResponse),
          processedResponse: parsedResponse,
          chat_id: chatId
        });
      } catch (jsonError) {
        console.warn('[BACKEND] Failed to parse AI response as JSON:', jsonError);
        res.json({
          response: aiResponse,
          raw: true,
          chat_id: chatId
        });
      }
    } else {
      res.json(response.data);
    }
  } catch (error) {
    console.error('[BACKEND] Proxy error:', error);
    handleAPIError(error, res);
  }
});

// NEW: Streaming AI endpoint for new Qwen API
app.post('/api/stream/chat/completions', async (req: Request, res: Response) => {
  try {
    const { message, model = 'qwen2.5-coder-32b-instruct', stream = true } = req.body;

    const generateChatId = (): string => {
      return 'chat-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    };

    const chatId = generateChatId();

    const requestBody = {
      model,
      messages: [
        {
          role: 'user',
          content: message
        }
      ],
      stream
    };

    console.log(`[BACKEND] Making streaming request to: ${API_STREAM_URL}/chat/completions?chat_id=${chatId}`);

    if (stream) {
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Headers', 'Cache-Control');

      const response = await fetch(`${API_STREAM_URL}/chat/completions?chat_id=${chatId}`, {
        method: 'POST',
        headers: {
          'Authorization': req.headers.authorization as string,
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
              res.write('data: [DONE]\n\n');
              break;
            }

            res.write(`data: ${dataStr}\n\n`);
          }
        }
      }

      res.end();
    } else {
      // Fallback to non-streaming
      const response = await axios.post(`${API_PROXY_URL}/chat/completions?chat_id=${chatId}`, requestBody, {
        headers: {
          'Authorization': req.headers.authorization,
          'Content-Type': 'application/json'
        }
      });

      res.json({
        ...response.data,
        chat_id: chatId
      });
    }
  } catch (error) {
    console.error('[BACKEND] Streaming error:', error);
    handleAPIError(error, res);
  }
});

app.get('/api/user/me', async (req, res) => {
  try {
    // ответ от внешнего api: { email: string, request_count: number }
    const response = await axios.get(`${API_HOST}/api/user/me`, {
      headers: { 'Authorization': req.headers.authorization }
    });
    res.json(response.data);
  } catch (error) {
    handleAPIError(error, res);
  }
});

// NEW: File management endpoints
app.post('/api/files/update', async (req: Request, res: Response) => {
  try {
    const { file, code, edit, startLine, endLine, confirm } = req.body;

    if (!file || !code) {
      res.status(400).json({ error: 'File path and code are required' });
      return;
    }

    const result = await updateFile({ file, code, edit, startLine, endLine });
    res.json(result);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to update file',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

app.get('/api/files/read', async (req: Request, res: Response) => {
  try {
    const { path: filePath } = req.query;

    if (!filePath || typeof filePath !== 'string') {
      res.status(400).json({ error: 'File path is required' });
      return;
    }

    const sandboxPath = path.join(process.cwd(), 'sandbox');
    const absPath = path.isAbsolute(filePath) ? filePath : path.join(sandboxPath, filePath);

    if (!fs.existsSync(absPath)) {
      res.status(404).json({ error: 'File not found' });
      return;
    }

    const content = fs.readFileSync(absPath, 'utf-8');
    res.json({ content, path: filePath });
  } catch (error) {
    res.status(500).json({
      error: 'Failed to read file',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

app.get('/api/files/list', async (req: Request, res: Response) => {
  try {
    const { path: dirPath = '' } = req.query;
    const sandboxPath = path.join(process.cwd(), 'sandbox');
    const targetPath = path.join(sandboxPath, dirPath as string);

    if (!fs.existsSync(targetPath)) {
      res.json({ files: [], directories: [] });
      return;
    }

    const items = fs.readdirSync(targetPath);
    const files: string[] = [];
    const directories: string[] = [];

    items.forEach(item => {
      const itemPath = path.join(targetPath, item);
      const stats = fs.statSync(itemPath);

      if (stats.isDirectory()) {
        directories.push(item);
      } else {
        files.push(item);
      }
    });

    res.json({ files, directories });
  } catch (error) {
    res.status(500).json({
      error: 'Failed to list files',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Docker helper functions
const findContainer = async (): Promise<Docker.Container | null> => {
  const containers = await docker.listContainers({ all: true });
  const containerInfo = containers.find((c: any) => c.Names.includes(`/${SANDBOX_CONTAINER_NAME}`));
  if (containerInfo) {
    return docker.getContainer(containerInfo.Id);
  }
  return null;
};

const imageExists = async (imageName: string): Promise<boolean> => {
  try {
    await docker.getImage(imageName).inspect();
    return true;
  } catch (error: any) {
    if (error.statusCode === 404) {
      return false;
    }
    throw error;
  }
};

// Docker endpoints
app.post('/api/docker/ensure-sandbox', async (req: Request, res: Response) => {
  try {
    const imageNameWithTag = `${DOCKER_IMAGE_NAME}:latest`;

    if (!await imageExists(imageNameWithTag)) {
      res.status(400).json({
        error: `Sandbox image '${imageNameWithTag}' not found. Please build it first by running 'npm run setup'.`
      });
      return;
    }

    let container = await findContainer();
    if (container) {
      const info = await container.inspect();
      if (!info.State.Running) {
        try {
          await container.start();
        } catch (error: any) {
          if (error.statusCode === 304) {
            console.log('Container already running');
          } else {
            throw error;
          }
        }
      }
      res.json({ message: 'Sandbox is ready' });
      return;
    }

    console.log(`Creating new sandbox container '${SANDBOX_CONTAINER_NAME}'...`);
    container = await docker.createContainer({
      Image: imageNameWithTag,
      name: SANDBOX_CONTAINER_NAME,
      Tty: true,
      Cmd: ['/bin/bash'],
      WorkingDir: '/workspace',
      HostConfig: { Binds: [`${process.cwd()}/sandbox:/workspace:z`] }
    });

    try {
      await container.start();
      console.log('Sandbox container created and started.');
    } catch (error: any) {
      if (error.statusCode === 304) {
        console.log('Container already running');
      } else {
        throw error;
      }
    }

    res.json({ message: 'Sandbox created and started' });
  } catch (error) {
    console.error('Docker error:', error);
    res.status(500).json({ error: `Failed to ensure sandbox: ${error instanceof Error ? error.message : 'Unknown error'}` });
  }
});

app.post('/api/docker/execute', async (req: Request, res: Response) => {
  try {
    const { command } = req.body;

    if (!command) {
      res.status(400).json({ error: 'Command is required' });
      return;
    }

    const result = await executeCommand(command);
    res.json(result);
  } catch (error) {
    console.error('Execute error:', error);
    res.status(500).json({ error: `Failed to execute command: ${error instanceof Error ? error.message : 'Unknown error'}` });
  }
});

// Start HTTP server
const server = createServer(app);
server.listen(PORT, () => {
  console.log(`Backend server running on http://localhost:${PORT}`);
});

// WebSocket server for real-time terminal
const wss = new WebSocketServer({ port: WS_PORT });

wss.on('connection', (ws) => {
  console.log('WebSocket client connected');

  ws.on('message', async (message) => {
    try {
      const { command, sessionId, type } = JSON.parse(message.toString());

      if (type === 'execute_command') {
        console.log(`Executing command via WebSocket: ${command}`);

        // Execute command in Docker
        const result = await executeCommand(command);

        // Send result back
        ws.send(JSON.stringify({
          type: 'command_result',
          sessionId,
          stdout: result.stdout,
          stderr: result.stderr,
          success: true
        }));
      }
    } catch (error) {
      console.error('WebSocket command execution error:', error);
      ws.send(JSON.stringify({
        type: 'command_result',
        sessionId: 'unknown',
        error: error instanceof Error ? error.message : 'Unknown error',
        success: false
      }));
    }
  });

  ws.on('close', () => {
    console.log('WebSocket client disconnected');
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

console.log(`WebSocket server running on ws://localhost:${WS_PORT}`); 
