# ZetGui System Dependencies Installer
# Установка системных зависимостей для Windows

$ErrorActionPreference = "Stop"

# Функции логирования с символами  
function log_info { param([string]$msg) Write-Host "ℹ  $msg" -ForegroundColor Cyan }
function log_success { param([string]$msg) Write-Host "✓  $msg" -ForegroundColor Green }
function log_warning { param([string]$msg) Write-Host "⚠  $msg" -ForegroundColor Yellow }
function log_error { param([string]$msg) Write-Host "✗  $msg" -ForegroundColor Red }
function log_step { param([string]$msg) Write-Host "*  $msg" -ForegroundColor Purple }

# Анимация загрузки
function Show-Loading {
    param([string]$message, [int]$duration = 2)
    $chars = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
    
    for ($i = 0; $i -lt ($duration * 10); $i++) {
        $char = $chars[$i % $chars.Length]
        Write-Host "`r$char  $message" -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r✓  $message" -ForegroundColor Green
}

# Красивый логотип
function Show-Logo {
    Clear-Host
    Write-Host "██████╗ ███████╗████████╗     ██████╗ ██╗   ██╗██╗" -ForegroundColor Cyan
    Write-Host "╚════██╗██╔════╝╚══██╔══╝    ██╔════╝ ██║   ██║██║" -ForegroundColor Cyan  
    Write-Host " █████╔╝█████╗     ██║       ██║  ███╗██║   ██║██║" -ForegroundColor Cyan
    Write-Host "██╔═══╝ ██╔══╝     ██║       ██║   ██║██║   ██║██║" -ForegroundColor Cyan
    Write-Host "███████╗███████╗   ██║       ╚██████╔╝╚██████╔╝██║" -ForegroundColor Cyan
    Write-Host "╚══════╝╚══════╝   ╚═╝        ╚═════╝  ╚═════╝ ╚═╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "System Dependencies Installer" -ForegroundColor Blue
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
}

Show-Logo
log_step "ZetGui System Dependencies Installation для Windows"

# Функции для проверки установленных пакетов
function Check-Installed {
    param([string]$Command, [string]$VersionCmd)
    
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            $version = Invoke-Expression $VersionCmd 2>$null
            Write-Host "✅ $Command установлен: $version" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ $Command не установлен" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "⚠️ $Command не установлен" -ForegroundColor Yellow
        return $false
    }
}

# Проверка наличия winget
function Test-Winget {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Проверка наличия chocolatey
function Test-Chocolatey {
    try {
        $null = Get-Command choco -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Установка chocolatey
function Install-Chocolatey {
    Write-Host "🍫 Устанавливаю Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Обновляем PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    
    if (Test-Chocolatey) {
        Write-Host "✅ Chocolatey установлен успешно" -ForegroundColor Green
    } else {
        Write-Host "❌ Ошибка установки Chocolatey" -ForegroundColor Red
        exit 1
    }
}

# Установка через winget
function Install-WithWinget {
    Write-Host "📦 Установка через winget..." -ForegroundColor Purple
    
    # Node.js
    if (-not (Check-Installed "node" "node --version")) {
        Write-Host "📦 Устанавливаю Node.js..." -ForegroundColor Yellow
        winget install OpenJS.NodeJS --accept-package-agreements --accept-source-agreements
    }
    
    # Git
    if (-not (Check-Installed "git" "git --version")) {
        Write-Host "📦 Устанавливаю Git..." -ForegroundColor Yellow
        winget install Git.Git --accept-package-agreements --accept-source-agreements
    }
    
    # Docker Desktop
    if (-not (Check-Installed "docker" "docker --version")) {
        Write-Host "📦 Устанавливаю Docker Desktop..." -ForegroundColor Yellow
        winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
        Write-Host "⚠️ После установки Docker Desktop требуется перезагрузка!" -ForegroundColor Yellow
    }
    
    # Python (опционально)
    if (-not (Check-Installed "python" "python --version")) {
        Write-Host "📦 Устанавливаю Python..." -ForegroundColor Yellow
        winget install Python.Python.3.11 --accept-package-agreements --accept-source-agreements
    }
}

# Установка через chocolatey
function Install-WithChocolatey {
    Write-Host "🍫 Установка через Chocolatey..." -ForegroundColor Purple
    
    # Node.js
    if (-not (Check-Installed "node" "node --version")) {
        Write-Host "📦 Устанавливаю Node.js..." -ForegroundColor Yellow
        choco install nodejs -y
    }
    
    # Git
    if (-not (Check-Installed "git" "git --version")) {
        Write-Host "📦 Устанавливаю Git..." -ForegroundColor Yellow
        choco install git -y
    }
    
    # Docker Desktop
    if (-not (Check-Installed "docker" "docker --version")) {
        Write-Host "📦 Устанавливаю Docker Desktop..." -ForegroundColor Yellow
        choco install docker-desktop -y
        Write-Host "⚠️ После установки Docker Desktop требуется перезагрузка!" -ForegroundColor Yellow
    }
    
    # Python (опционально)
    if (-not (Check-Installed "python" "python --version")) {
        Write-Host "📦 Устанавливаю Python..." -ForegroundColor Yellow
        choco install python -y
    }
}

# Установка TypeScript глобально
function Install-TypeScript {
    if (-not (Check-Installed "tsc" "tsc --version")) {
        Write-Host "📦 Устанавливаю TypeScript глобально..." -ForegroundColor Yellow
        npm install -g typescript ts-node
    }
}

# Обновление PATH
function Update-Path {
    Write-Host "🔄 Обновляю переменные окружения..." -ForegroundColor Yellow
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
}

# Проверка Docker Desktop
function Test-DockerDesktop {
    try {
        $dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
        if ($dockerProcess) {
            Write-Host "✅ Docker Desktop запущен" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ Docker Desktop не запущен" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "⚠️ Docker Desktop не найден" -ForegroundColor Yellow
        return $false
    }
}

# Проверка всех установок
function Verify-Installation {
    Write-Host "🔍 Проверка установленных пакетов..." -ForegroundColor Purple
    
    Update-Path
    
    $allGood = $true
    
    if (-not (Check-Installed "node" "node --version")) { $allGood = $false }
    if (-not (Check-Installed "npm" "npm --version")) { $allGood = $false }
    if (-not (Check-Installed "tsc" "tsc --version")) { $allGood = $false }
    if (-not (Check-Installed "docker" "docker --version")) { $allGood = $false }
    if (-not (Check-Installed "git" "git --version")) { $allGood = $false }
    
    # Проверка Docker
    if (Test-DockerDesktop) {
        Write-Host "✅ Docker Desktop работает" -ForegroundColor Green
    } else {
        Write-Host "❌ Docker Desktop не работает или не установлен" -ForegroundColor Red
        $allGood = $false
    }
    
    if ($allGood) {
        Write-Host "✅ Все системные зависимости установлены и работают!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Некоторые зависимости установлены неправильно" -ForegroundColor Red
        return $false
    }
}

# Основная функция
function Main {
    Write-Host ""
    Write-Host "🎯 Начинаю установку системных зависимостей..." -ForegroundColor Purple
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    # Проверка прав администратора
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "❌ Требуются права администратора!" -ForegroundColor Red
        Write-Host "   Запустите PowerShell от имени администратора" -ForegroundColor Yellow
        exit 1
    }
    
    # Проверка текущих установок
    Write-Host "🔍 Проверка текущих установок..." -ForegroundColor Purple
    Check-Installed "node" "node --version"
    Check-Installed "npm" "npm --version"
    Check-Installed "tsc" "tsc --version"
    Check-Installed "docker" "docker --version"
    Check-Installed "git" "git --version"
    
    # Выбор метода установки
    if (Test-Winget) {
        Write-Host "✅ Используем winget для установки" -ForegroundColor Green
        Install-WithWinget
    } elseif (Test-Chocolatey) {
        Write-Host "✅ Используем Chocolatey для установки" -ForegroundColor Green
        Install-WithChocolatey
    } else {
        Write-Host "⚠️ winget и Chocolatey не найдены. Устанавливаю Chocolatey..." -ForegroundColor Yellow
        Install-Chocolatey
        Install-WithChocolatey
    }
    
    # Обновляем PATH после установки
    Update-Path
    
    # Установка TypeScript
    Install-TypeScript
    
    # Финальная проверка
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    if (Verify-Installation) {
        Write-Host "🎉 Установка системных зависимостей завершена!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 Следующие шаги:" -ForegroundColor Cyan
        Write-Host "   1. Запустите Docker Desktop если он не запущен" -ForegroundColor White
        Write-Host "   2. Перезапустите PowerShell (для обновления PATH)" -ForegroundColor White
        Write-Host "   3. Запустите: .\script\install-all-Dependencies.ps1" -ForegroundColor White
        Write-Host "   4. Запустите: .\Zet-Install.ps1" -ForegroundColor White
    } else {
        Write-Host "❌ Установка завершилась с ошибками" -ForegroundColor Red
        Write-Host "💡 Попробуйте:" -ForegroundColor Yellow
        Write-Host "   - Перезапустить PowerShell от имени администратора" -ForegroundColor White
        Write-Host "   - Запустить Docker Desktop вручную" -ForegroundColor White
        Write-Host "   - Перезагрузить систему" -ForegroundColor White
        exit 1
    }
    Write-Host ""
}

# Запуск
Main 