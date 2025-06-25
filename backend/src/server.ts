import express from 'express';
import cors from 'cors';
import axios from 'axios';
import Docker from 'dockerode';
import { Writable } from 'stream';

const app = express();
const PORT = process.env.PORT || 3003;

//! настройки API
const USE_REMOTE = false;
const API_HOST = USE_REMOTE ? 'https://api.derx.space' : 'http://localhost:4000';
const API_BASE_URL = `${API_HOST}/api/proxy`;

//! Docker настройки
const DOCKER_IMAGE_NAME = 'zet-sandbox-image';
const SANDBOX_CONTAINER_NAME = 'zet-sandbox';

const docker = new Docker();

app.use(cors());
app.use(express.json());

//! проксируем аутентификацию
app.post('/api/auth/login', async (req, res) => {
  try {
    const response = await axios.post(`${API_HOST}/api/auth/login`, req.body);
    res.json(response.data);
  } catch (error) {
    if (axios.isAxiosError(error) && error.response) {
      res.status(error.response.status).json(error.response.data);
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

app.post('/api/auth/register', async (req, res) => {
  try {
    const response = await axios.post(`${API_HOST}/api/auth/register`, req.body);
    res.json(response.data);
  } catch (error) {
    if (axios.isAxiosError(error) && error.response) {
      res.status(error.response.status).json(error.response.data);
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

//! проксируем AI запросы
app.post('/api/proxy/send', async (req, res) => {
  try {
    const response = await axios.post(`${API_BASE_URL}/send`, req.body, {
      headers: {
        'Authorization': req.headers.authorization
      }
    });
    res.json(response.data);
  } catch (error) {
    if (axios.isAxiosError(error) && error.response) {
      res.status(error.response.status).json(error.response.data);
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

app.get('/api/user/me', async (req, res) => {
  try {
    const response = await axios.get(`${API_HOST}/api/user/me`, {
      headers: {
        'Authorization': req.headers.authorization
      }
    });
    res.json(response.data);
  } catch (error) {
    if (axios.isAxiosError(error) && error.response) {
      res.status(error.response.status).json(error.response.data);
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

//! Docker API
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

app.post('/api/docker/ensure-sandbox', async (req, res) => {
  try {
    const imageNameWithTag = `${DOCKER_IMAGE_NAME}:latest`;

    if (!await imageExists(imageNameWithTag)) {
      return res.status(400).json({ 
        error: `Sandbox image '${imageNameWithTag}' not found. Please build it first by running 'npm run setup'.` 
      });
    }

    let container = await findContainer();
    if (container) {
      const info = await container.inspect();
      if (!info.State.Running) {
        try {
          await container.start();
        } catch (error: any) {
          // 304 означает что контейнер уже запущен - это нормально
          if (error.statusCode === 304) {
            console.log('Container already running');
          } else {
            throw error;
          }
        }
      }
      return res.json({ message: 'Sandbox is ready' });
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
      // 304 означает что контейнер уже запущен - это нормально
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

app.post('/api/docker/execute', async (req, res) => {
  try {
    const { command } = req.body;
    
    if (!command) {
      return res.status(400).json({ error: 'Command is required' });
    }

    const container = await findContainer();
    if (!container) {
      return res.status(400).json({ error: `Sandbox container '${SANDBOX_CONTAINER_NAME}' not found.` });
    }

    const exec = await container.exec({
      Cmd: ['/bin/bash', '-c', command],
      AttachStdout: true,
      AttachStderr: true,
    });

    const stream = await exec.start({ hijack: true, stdin: true });

    const result = await new Promise<{ stdout: string; stderr: string }>((resolve) => {
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

    res.json(result);
  } catch (error) {
    console.error('Execute error:', error);
    res.status(500).json({ error: `Failed to execute command: ${error instanceof Error ? error.message : 'Unknown error'}` });
  }
});

app.listen(PORT, () => {
  console.log(`Backend server running on http://localhost:${PORT}`);
}); 