import axios from 'axios';

//! контейнер для GUI - используем backend
const BACKEND_HOST = 'http://localhost:3003';

//* обертка для команд через backend
export class DockerService {
  async ensureSandbox(): Promise<void> {
    try {
      const response = await axios.post(`${BACKEND_HOST}/api/docker/ensure-sandbox`);
      console.log('Sandbox ready:', response.data.message);
    } catch (error) {
      if (axios.isAxiosError(error) && error.response) {
        throw new Error(error.response.data.error || 'Failed to ensure sandbox');
      }
      throw new Error(`Failed to ensure sandbox: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  async executeCommand(command: string): Promise<{ stdout: string; stderr: string }> {
    try {
      const response = await axios.post(`${BACKEND_HOST}/api/docker/execute`, { command });
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error) && error.response) {
        throw new Error(error.response.data.error || 'Failed to execute command');
      }
      throw new Error(`Failed to execute command: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }
} 