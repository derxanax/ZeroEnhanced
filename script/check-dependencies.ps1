# PowerShell версия для Windows  
# ZetGui Dependencies Checker

# Функции для красивого вывода
function Write-LogInfo { param([string]$Message) Write-Host "ℹ  $Message" -ForegroundColor Cyan }
function Write-LogSuccess { param([string]$Message) Write-Host "✓  $Message" -ForegroundColor Green }
function Write-LogWarning { param([string]$Message) Write-Host "⚠  $Message" -ForegroundColor Yellow }
function Write-LogError { param([string]$Message) Write-Host "✗  $Message" -ForegroundColor Red }
function Write-LogStep { param([string]$Message) Write-Host "*  $Message" -ForegroundColor Magenta }

# Красивый логотип
function Show-Logo {
    Write-Host @"
██████╗ ███████╗████████╗     ██████╗ ██╗   ██╗██╗
╚════██╗██╔════╝╚══██╔══╝    ██╔════╝ ██║   ██║██║
 █████╔╝█████╗     ██║       ██║  ███╗██║   ██║██║
██╔═══╝ ██╔══╝     ██║       ██║   ██║██║   ██║██║
███████╗███████╗   ██║       ╚██████╔╝╚██████╔╝██║
╚══════╝╚══════╝   ╚═╝        ╚═════╝  ╚═════╝ ╚═╝
"@ -ForegroundColor Cyan
    Write-Host "ZetGui Dependencies Checker" -ForegroundColor Blue
    Write-Host "══════════════════════════════════════════════════=" -ForegroundColor Blue
}

# Функции для проверки установленных пакетов
function Test-Installed {
    param([string]$Command, [string]$Name = $Command)
    
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

function Get-NodeVersion {
    try {
        $version = node --version 2>$null
        return $version
    } catch {
        return $null
    }
}

function Test-DockerRunning {
    try {
        $null = docker ps 2>$null
        return $true
    } catch {
        return $false
    }
}

# Проверка системных зависимостей
function Test-SystemDependencies {
    Write-LogStep "Проверка системных зависимостей"
    
    $allGood = $true
    
    # Node.js
    if (Test-Installed "node") {
        $nodeVersion = Get-NodeVersion
        $majorVersion = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
        
        if ($majorVersion -ge 18) {
            Write-LogSuccess "Node.js: $nodeVersion"
        } else {
            Write-LogWarning "Node.js: $nodeVersion (рекомендуется v18+)"
            $allGood = $false
        }
    } else {
        Write-LogError "Node.js не установлен"
        $allGood = $false
    }
    
    # npm
    if (Test-Installed "npm") {
        $npmVersion = npm --version 2>$null
        Write-LogSuccess "npm: v$npmVersion"
    } else {
        Write-LogError "npm не установлен"
        $allGood = $false
    }
    
    # TypeScript
    if (Test-Installed "tsc") {
        $tscVersion = tsc --version 2>$null
        Write-LogSuccess "TypeScript: $tscVersion"
    } else {
        Write-LogWarning "TypeScript не установлен глобально"
        Write-LogInfo "Установите: npm install -g typescript"
    }
    
    # Docker
    if (Test-Installed "docker") {
        $dockerVersion = docker --version 2>$null
        Write-LogSuccess "Docker: $dockerVersion"
        
        # Проверка Docker daemon
        if (Test-DockerRunning) {
            Write-LogSuccess "Docker daemon работает"
        } else {
            Write-LogError "Docker daemon не запущен"
            Write-LogInfo "Запустите Docker Desktop"
            $allGood = $false
        }
    } else {
        Write-LogError "Docker не установлен"
        $allGood = $false
    }
    
    # Git
    if (Test-Installed "git") {
        $gitVersion = git --version 2>$null
        Write-LogSuccess "Git: $gitVersion"
    } else {
        Write-LogWarning "Git не установлен"
    }
    
    return $allGood
}

# Проверка Docker окружения
function Test-DockerEnvironment {
    Write-LogStep "Проверка Docker окружения"
    
    $allGood = $true
    $imageName = "zet-sandbox-image:latest"
    $containerName = "zet-sandbox"
    
    # Проверка образа
    try {
        $null = docker image inspect $imageName 2>$null
        Write-LogSuccess "Docker образ $imageName существует"
    } catch {
        Write-LogWarning "Docker образ $imageName не найден"
        Write-LogInfo "Создайте образ: .\script\setup-docker.ps1"
        $allGood = $false
    }
    
    # Проверка контейнера
    try {
        $null = docker container inspect $containerName 2>$null
        try {
            $status = docker inspect -f '{{.State.Running}}' $containerName 2>$null
            if ($status -eq "true") {
                Write-LogSuccess "Docker контейнер $containerName запущен"
            } else {
                Write-LogWarning "Docker контейнер $containerName остановлен"
                Write-LogInfo "Запустите: docker start $containerName"
            }
        } catch {
            Write-LogWarning "Не удалось получить статус контейнера"
        }
    } catch {
        Write-LogWarning "Docker контейнер $containerName не создан"
        Write-LogInfo "Создайте контейнер: .\script\setup-docker.ps1"
        $allGood = $false
    }
    
    # Проверка sandbox директории
    if (Test-Path ".\sandbox") {
        Write-LogSuccess "Sandbox директория существует"
    } else {
        Write-LogWarning "Sandbox директория не найдена"
        Write-LogInfo "Создайте директорию: .\script\setup-docker.ps1"
        $allGood = $false
    }
    
    return $allGood
}

# Основная функция
function Main {
    param([string]$Command = "check")
    
    switch ($Command) {
        "check" {
            Show-Logo
            Write-Host ""
            
            $systemOk = Test-SystemDependencies
            Write-Host ""
            $dockerOk = Test-DockerEnvironment
            
            Write-Host ""
            Write-Host "══════════════════════════════════════════════════=" -ForegroundColor Blue
            
            if ($systemOk -and $dockerOk) {
                Write-LogSuccess "Все зависимости в порядке! ZetGui готов к запуску"
            } else {
                Write-LogError "Обнаружены проблемы с зависимостями"
            }
        }
        "--system" {
            Show-Logo
            Write-Host ""
            Test-SystemDependencies
        }
        "--docker" {
            Show-Logo
            Write-Host ""
            Test-DockerEnvironment  
        }
        "--help" {
            Show-Logo
            Write-Host ""
            Write-Host "Использование: .\script\check-dependencies.ps1 [команда]"
            Write-Host ""
            Write-Host "Команды:"
            Write-Host "  check    - Полная проверка зависимостей (по умолчанию)"
            Write-Host "  --system - Проверка только системных зависимостей"
            Write-Host "  --docker - Проверка только Docker окружения"
            Write-Host "  --help   - Показать эту справку"
        }
        default {
            Write-LogError "Неизвестная команда: $Command"
            Write-Host "Используйте --help для справки" -ForegroundColor Yellow
        }
    }
}

# Запуск
Main @args 