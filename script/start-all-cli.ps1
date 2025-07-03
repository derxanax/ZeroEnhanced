#!/usr/bin/env pwsh

param(
    [switch]$NoDocker,
    [switch]$Debug,
    [switch]$Help
)

if ($Help) {
    Write-Host "🚀 ZeroEnhanced CLI Starter" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Использование:" -ForegroundColor Yellow
    Write-Host "  .\start-all-cli.ps1         # Стандартный запуск с Docker"
    Write-Host "  .\start-all-cli.ps1 -NoDocker  # Запуск без Docker"
    Write-Host "  .\start-all-cli.ps1 -Debug     # Debug режим"
    Write-Host "  .\start-all-cli.ps1 -Help      # Показать справку"
    exit 0
}

$ErrorActionPreference = "Stop"
$OriginalLocation = Get-Location

# Функции для красивого вывода
function Write-LogInfo { param([string]$Message) Write-Host "ℹ  $Message" -ForegroundColor Cyan }
function Write-LogSuccess { param([string]$Message) Write-Host "✓  $Message" -ForegroundColor Green }
function Write-LogWarning { param([string]$Message) Write-Host "⚠  $Message" -ForegroundColor Yellow }
function Write-LogError { param([string]$Message) Write-Host "✗  $Message" -ForegroundColor Red }
function Write-LogStep { param([string]$Message) Write-Host "*  $Message" -ForegroundColor Magenta }

# Анимация загрузки
function Show-Loading {
    param([string]$Message, [int]$Duration = 3)
    
    $chars = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
    
    for ($i = 0; $i -lt ($Duration * 10); $i++) {
        $char = $chars[$i % 10]
        Write-Host -NoNewline "`r$char  $Message" -ForegroundColor Cyan
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r✓  $Message" -ForegroundColor Green
}

# Красивый логотип
function Show-Logo {
    Clear-Host
    Write-Host @"
██████╗ ███████╗████████╗     ██████╗ ██╗   ██╗██╗
╚════██╗██╔════╝╚══██╔══╝    ██╔════╝ ██║   ██║██║
 █████╔╝█████╗     ██║       ██║  ███╗██║   ██║██║
██╔═══╝ ██╔══╝     ██║       ██║   ██║██║   ██║██║
███████╗███████╗   ██║       ╚██████╔╝╚██████╔╝██║
╚══════╝╚══════╝   ╚═╝        ╚═════╝  ╚═════╝ ╚═╝
"@ -ForegroundColor Cyan
    Write-Host "CLI Terminal Launcher" -ForegroundColor Blue
    Write-Host "══════════════════════════════════════════════════=" -ForegroundColor Blue
    Write-Host ""
                }

# Проверка зависимостей
function Test-Dependencies {
    Write-LogStep "Проверка зависимостей"
    
    # Проверка Node.js
    try {
        $nodeVersion = node --version 2>$null
        if (-not $nodeVersion) {
            Write-LogError "Node.js не найден"
            Write-LogInfo "Установите Node.js: https://nodejs.org/"
            return $false
        }
    } catch {
        Write-LogError "Node.js не найден"
        return $false
    }
    
    # Проверка npm
    try {
        $npmVersion = npm --version 2>$null
        if (-not $npmVersion) {
            Write-LogError "npm не найден"
            return $false
        }
    } catch {
        Write-LogError "npm не найден"
        return $false
    }
    
    # Проверка TypeScript
    try {
        $tscVersion = tsc --version 2>$null
        if (-not $tscVersion) {
            Write-LogWarning "TypeScript не найден глобально"
            Write-LogInfo "Попробую установить: npm install -g typescript"
            try {
                npm install -g typescript | Out-Null
            } catch {
                Write-LogError "Не удалось установить TypeScript"
                return $false
            }
        }
    } catch {
        Write-LogWarning "TypeScript не найден глобально"
        Write-LogInfo "Попробую установить: npm install -g typescript"
        try {
            npm install -g typescript | Out-Null
        } catch {
            Write-LogError "Не удалось установить TypeScript"
            return $false
        }
    }
    
    # Проверка зависимостей проекта
    if (-not (Test-Path "node_modules")) {
        Write-LogWarning "Зависимости проекта не установлены"
        Write-LogInfo "Запускаю установку: npm install"
        try {
            npm install | Out-Null
        } catch {
            Write-LogError "Не удалось установить зависимости"
            return $false
        }
    }
    
    Write-LogSuccess "Все зависимости в порядке"
    return $true
}

# Запуск CLI приложения
function Start-CliApp {
    Write-LogStep "Запуск CLI терминала"
    npx ts-node src/main.ts
}

# Проверка окружения
function Test-Environment {
    Write-LogStep "Проверка окружения"
    
    # Проверка конфигурации
    if (Test-Path "Prod.json") {
        try {
            $config = Get-Content "Prod.json" | ConvertFrom-Json
            
            if ($config.prod -eq $true) {
                Write-LogInfo "Режим: Production"
            } else {
                Write-LogInfo "Режим: Development"
    }
    
            if ($config.domain) {
                Write-LogInfo "API сервер: $($config.domain)"
}
        } catch {
            Write-LogWarning "Ошибка чтения конфигурации Prod.json"
        }
    } else {
        Write-LogWarning "Конфигурация Prod.json не найдена"
    }
    
    Write-LogSuccess "Окружение проверено"
}

# Главная функция
function Start-Main {
    Show-Logo
    
    Write-LogInfo "Инициализация CLI терминала"
    Write-Host ""
    
    # Проверки
    if (-not (Test-Dependencies)) {
        Write-LogError "Не удалось проверить зависимости"
        exit 1
    }
    Write-Host ""
    
    Test-Environment
    Write-Host ""
    
    # Запуск
    Write-LogInfo "Все проверки пройдены, запускаю CLI"
    Write-Host "══════════════════════════════════════════════════=" -ForegroundColor Blue
    Write-Host ""
    
    Start-CliApp
}

# Проверка директории
function Test-Directory {
    if (-not (Test-Path "package.json") -and -not (Test-Path "src")) {
        Write-LogError "Скрипт должен запускаться из корневой директории проекта"
        Write-LogInfo "Перейдите в директорию с package.json и src/"
        exit 1
    }
}

# Обработка прерывания
function Stop-Cleanup {
    Write-Host ""
    Write-LogInfo "Завершение работы CLI"
    exit 0
}

# Запуск
try {
    Test-Directory
    Start-Main
} catch {
    Stop-Cleanup
} 