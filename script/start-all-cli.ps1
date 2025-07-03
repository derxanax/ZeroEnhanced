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

# Сборка проекта
function Build-Project {
    Write-LogStep "Сборка проекта"
    
    Show-Loading "Компиляция TypeScript" 2
    
    if (Test-Path "tsconfig.json") {
        try {
            tsc | Out-Null
            Write-LogSuccess "Проект собран успешно"
            return $true
        } catch {
            Write-LogError "Ошибка сборки проекта"
            return $false
        }
    } else {
        Write-LogWarning "tsconfig.json не найден - пропускаю сборку"
        return $true
    }
}

# Запуск CLI приложения
function Start-CliApp {
    Write-LogStep "Запуск CLI терминала"
    
    # Проверяем наличие скомпилированных файлов
    if (Test-Path "dist/main.js") {
        Write-LogInfo "Запускаю скомпилированную версию"
        Show-Loading "Инициализация терминала" 1
        Write-Host ""
        Write-LogSuccess "Zet CLI готов к работе!"
        Write-Host ""
        node "dist/main.js"
    } elseif (Test-Path "src/main.ts") {
        Write-LogInfo "Запускаю через ts-node"
        
        # Проверяем ts-node
        try {
            $tsNodeVersion = ts-node --version 2>$null
            if (-not $tsNodeVersion) {
                Write-LogWarning "ts-node не найден, устанавливаю"
                npm install -g ts-node | Out-Null
            }
        } catch {
            Write-LogWarning "ts-node не найден, устанавливаю"
            try {
                npm install -g ts-node | Out-Null
            } catch {
                Write-LogError "Не удалось установить ts-node"
                return $false
            }
        }
        
        Show-Loading "Инициализация терминала" 1
        Write-Host ""
        Write-LogSuccess "Zet CLI готов к работе!"
        Write-Host ""
        ts-node "src/main.ts"
    } else {
        Write-LogError "Не найден main.js или main.ts файл"
        Write-LogInfo "Проверьте структуру проекта"
        return $false
    }
    
    return $true
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
    
    if (-not (Build-Project)) {
        Write-LogError "Не удалось собрать проект"
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