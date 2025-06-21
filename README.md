# ZeroEnhanced Terminal (Zet)

Zet is an experimental AI-powered terminal that uses a Large Language Model (Qwen) to translate natural language into shell commands, which are then executed in an isolated Docker sandbox.

## Architecture

The application consists of two main components:

1.  `src/core.ts`: The brain of the application. It contains all the core logic:
    *   **Configuration**: API endpoints, Docker image names.
    *   **TypeScript Types**: Defines the strict JSON contract for AI responses.
    *   **System Prompt**: A detailed instruction set that tells the AI how to behave and what format to respond in.
    *   **AIService**: A class responsible for communicating with the Qwen API (creating new chat sessions, sending prompts).
    *   **DockerService**: A class for managing the lifecycle of a sandboxed Docker container (`ubuntu:latest`). It ensures the container exists, is running, and executes commands within it.

2.  `src/main.ts`: The orchestrator. This file is responsible for:
    *   Initializing the services.
    *   Running the main application loop (Read-Eval-Print Loop).
    *   Handling user input and output formatting (with `chalk`).
    *   Managing the conversation flow, including asking for user confirmation for potentially destructive commands.

The `sandbox` directory in the project root is mounted into the Docker container at `/workspace`, allowing the AI to interact with files.

## How to Run

### Prerequisites

*   Node.js (v16 or higher)
*   Docker installed and running.
*   The Kiala API (the wrapper for Qwen) running on `http://localhost:3700`.

### Setup

1.  **Install dependencies:**
    ```bash
    npm install
    ```

2.  **Compile TypeScript:**
    ```bash
    npx tsc
    ```

3.  **Create the sandbox directory:**
    This directory will be shared with the Docker container.
    ```bash
    mkdir sandbox
    ```

### Execution

Run the compiled application:

```bash
node dist/main.js
``` 