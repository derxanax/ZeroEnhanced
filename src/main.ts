import readline from 'readline';
import chalk from 'chalk';
import { AIService, DockerService } from './core';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

const askQuestion = (query: string): Promise<string> => {
    return new Promise(resolve => rl.question(query, resolve));
};

async function main() {
    console.log(chalk.cyan('Initializing services...'));
    const aiService = new AIService();
    const dockerService = new DockerService();

    try {
        await dockerService.ensureSandbox();
        await aiService.init();
        console.log(chalk.green('Initialization complete. Zet is ready.'));
        console.log(chalk.gray('Type "exit" or "quit" to end the session.'));
    } catch (error) {
        const message = error instanceof Error ? error.message : 'An unknown error occurred.';
        console.error(chalk.red('Fatal error during initialization:'), message);
        process.exit(1);
    }

    let lastObservation = '';

    while (true) {
        const userInput = await askQuestion(chalk.blue('\n> '));

        if (userInput.toLowerCase() === 'exit' || userInput.toLowerCase() === 'quit') {
            break;
        }

        try {
            console.log(chalk.yellow('Zet is thinking...'));
            const aiResponse = await aiService.getCommand(userInput, lastObservation);

            console.log(chalk.magenta(`Thought: ${aiResponse.thought}`));

            const { tool, parameters } = aiResponse.action;

            if (tool === 'protocol_complete') {
                console.log(chalk.green('Zet: Task complete. Ending session.'));
                break;
            }

            if (tool === 'execute_command' && parameters) {
                if (parameters.confirm) {
                    const confirmPrompt = parameters.prompt || `Execute command "${parameters.command}"? (y/n)`;
                    const confirmation = await askQuestion(chalk.red(`${confirmPrompt} `));
                    if (confirmation.toLowerCase() !== 'y') {
                        console.log(chalk.yellow('Command aborted by user.'));
                        lastObservation = 'User aborted the previous command.';
                        continue;
                    }
                }

                console.log(chalk.yellow(`Executing: ${parameters.command}`));
                const { stdout, stderr } = await dockerService.executeCommand(parameters.command);

                if (stdout) {
                    console.log(chalk.green(stdout));
                    lastObservation = `Command "${parameters.command}" executed and returned:\n${stdout}`;
                }
                if (stderr) {
                    console.error(chalk.red(stderr));
                    lastObservation = `Command "${parameters.command}" failed with error:\n${stderr}`;
                }
                if (!stdout && !stderr) {
                    lastObservation = `Command "${parameters.command}" executed with no output.`;
                }
            }
        } catch (error) {
            const message = error instanceof Error ? error.message : 'An unknown error occurred.';
            console.error(chalk.red('An error occurred:'), message);
            lastObservation = `The last action failed with error: ${message}. I should probably try something else.`;
        }
    }

    rl.close();
    console.log(chalk.cyan('Session terminated.'));
}

main(); 