import express, { Request, Response } from 'express';
import cors from 'cors';
import axios from 'axios';
import Docker from 'dockerode';
import { Writable } from 'stream';
import { WebSocketServer } from 'ws';
import fs from 'fs';
import path from 'path';
import { createServer } from 'http';

const app = express();
const PORT = process.env.PORT || 3003;
const WS_PORT = 8080;

const USE_REMOTE = false;
const API_HOST = USE_REMOTE ? 'https://api.derx.space' : 'http://localhost:4000';
const API_BASE_URL = `${API_HOST}/api/proxy`;

const DOCKER_IMAGE_NAME = 'zet-sandbox-image';
const SANDBOX_CONTAINER_NAME = 'zet-sandbox';

const docker = new Docker();

app.use(cors());
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
    const response = await axios.post(`${API_HOST}/api/auth/login`, req.body);
    res.json(response.data);
  } catch (error) {
    handleAPIError(error, res);
  }
});

app.post('/api/auth/register', async (req, res) => {
  try {
    const response = await axios.post(`${API_HOST}/api/auth/register`, req.body);
    res.json(response.data);
  } catch (error) {
    handleAPIError(error, res);
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

// Enhanced AI proxy endpoint with action processing
app.post('/api/proxy/send', async (req, res) => {
  try {
    const response = await axios.post(`${API_BASE_URL}/send`, req.body, {
      headers: { 'Authorization': req.headers.authorization }
    });
    
    const aiResponse = JSON.parse(response.data.response);
    
    // Process different AI action types
    switch (aiResponse.action.tool) {
      case 'execute_command':
        // Auto-execute command if confirm: false
        if (!aiResponse.action.parameters.confirm) {
          try {
            const cmdResult = await executeCommand(aiResponse.action.parameters.command);
            aiResponse.executionResult = cmdResult;
          } catch (error) {
            aiResponse.executionResult = { 
              success: false, 
              error: error instanceof Error ? error.message : 'Command execution failed' 
            };
          }
        }
        break;
        
      case 'update_file':
        // Auto-update file if confirm: false
        if (!aiResponse.action.parameters.confirm) {
          const fileResult = await updateFile(aiResponse.action.parameters);
          aiResponse.executionResult = fileResult;
        }
        break;
        
      case 'protocol_complete':
        // Auto-end session
        if (response.data.pageId) {
          try {
            await axios.post(`${API_HOST}/api/exit`, 
              { pageId: response.data.pageId },
              { headers: { 'Authorization': req.headers.authorization } }
            );
          } catch (error) {
            console.error('Failed to auto-end session:', error);
          }
        }
        break;
    }
    
    res.json({
      ...response.data,
      processedResponse: aiResponse
    });
  } catch (error) {
    handleAPIError(error, res);
  }
});

app.get('/api/user/me', async (req, res) => {
  try {
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

<<<<<<< HEAD
console.log(`WebSocket server running on ws://localhost:${WS_PORT}`); 
=======
console.log(`WebSocket server running on ws://localhost:${WS_PORT}`); 
>>>>>>> 7019bc8 (Обновление проекта ZetGui:)
