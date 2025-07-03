# PowerShell версия для Windows
# ZetGui Dependencies Installer

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
    Write-Host "Dependencies Installer" -ForegroundColor Blue
    Write-Host "══════════════════════════════════════════════════=" -ForegroundColor Blue
    Write-Host ""
}

# Проверка Node.js
function Test-NodeJS {
    Write-LogStep "Проверка Node.js"
    
    try {
        $version = node --version 2>$null
        if ($version) {
            Write-LogSuccess "Node.js найден: $version"
            return $true
        } else {
            Write-LogError "Node.js не найден"
            return $false
        }
    } catch {
        Write-LogError "Node.js не найден"
        return $false
    }
}

# Проверка npm
function Test-Npm {
    Write-LogStep "Проверка npm"
    
    try {
        $version = npm --version 2>$null
        if ($version) {
            Write-LogSuccess "npm найден: v$version"
            return $true
        } else {
            Write-LogError "npm не найден"
            return $false
        }
    } catch {
        Write-LogError "npm не найден"
        return $false
    }
}

# Установка зависимостей для основного проекта
function Install-MainDependencies {
    Write-LogStep "Установка зависимостей основного проекта"
    
    if (-not (Test-Path "package.json")) {
        Write-LogError "package.json не найден в корневой директории"
        return $false
    }
    
    Show-Loading "Загрузка npm зависимостей" 3
    
    try {
        npm install | Out-Null
        Write-LogSuccess "Зависимости основного проекта установлены"
        return $true
    } catch {
        Write-LogError "Ошибка установки зависимостей основного проекта"
        return $false
    }
}

# Установка зависимостей для backend
function Install-BackendDependencies {
    Write-LogStep "Установка зависимостей backend"
    
    if ((Test-Path "backend") -and (Test-Path "backend/package.json")) {
        Push-Location "backend"
        
        Show-Loading "Установка backend зависимостей" 2
        
        try {
            npm install | Out-Null
            Write-LogSuccess "Backend зависимости установлены"
            Pop-Location
            return $true
        } catch {
            Write-LogError "Ошибка установки backend зависимостей"
            Pop-Location
            return $false
        }
    } else {
        Write-LogWarning "Backend директория или package.json не найдены - пропускаю"
        return $true
    }
}

# Установка зависимостей для desktop
function Install-DesktopDependencies {
    Write-LogStep "Установка зависимостей desktop"
    
    if ((Test-Path "desktop/react-src") -and (Test-Path "desktop/react-src/package.json")) {
        Push-Location "desktop/react-src"
        
        Show-Loading "Установка desktop зависимостей" 2
        
        try {
            npm install | Out-Null
            Write-LogSuccess "Desktop зависимости установлены"
            Pop-Location
            return $true
        } catch {
            Write-LogError "Ошибка установки desktop зависимостей"
            Pop-Location
            return $false
        }
    } else {
        Write-LogWarning "Desktop директория или package.json не найдены - пропускаю"
        return $true
    }
}

# Глобальная установка TypeScript
function Install-TypeScript {
    Write-LogStep "Проверка TypeScript"
    
    try {
        $version = tsc --version 2>$null
        if ($version) {
            Write-LogSuccess "TypeScript уже установлен: $version"
            return $true
        }
    } catch {
        # TypeScript не найден
    }
    
    Write-LogInfo "Устанавливаю TypeScript глобально"
    Show-Loading "Установка TypeScript" 2
    
    try {
        npm install -g typescript | Out-Null
        Write-LogSuccess "TypeScript установлен"
        return $true
    } catch {
        Write-LogError "Ошибка установки TypeScript"
        return $false
    }
}

# Проверка и установка зависимостей
function Start-Installation {
    Show-Logo
    
    Write-LogInfo "Начинаю установку всех зависимостей проекта"
    Write-Host ""
    
    # Проверка основных требований
    if (-not (Test-NodeJS) -or -not (Test-Npm)) {
        Write-LogError "Необходимо установить Node.js и npm"
        Write-LogInfo "Скачайте с https://nodejs.org/"
        exit 1
    }
    
    Write-Host ""
    
    # Установка TypeScript
    if (-not (Install-TypeScript)) {
        exit 1
    }
    Write-Host ""
    
    # Установка зависимостей
    if (-not (Install-MainDependencies)) {
        exit 1
    }
    Write-Host ""
    
    if (-not (Install-BackendDependencies)) {
        exit 1
    }
    Write-Host ""
    
    if (-not (Install-DesktopDependencies)) {
        exit 1
    }
    Write-Host ""
    
    Write-LogSuccess "Установка зависимостей завершена"
    
    # Проверка финального состояния
    Write-LogStep "Финальная проверка"
    Write-Host ""
    
    if (Test-Path "node_modules") {
        Write-LogSuccess "Основные зависимости: ОК"
    } else {
        Write-LogWarning "Основные зависимости: Не найдены"
    }
    
    if (Test-Path "backend/node_modules") {
        Write-LogSuccess "Backend зависимости: ОК"
    } else {
        Write-LogWarning "Backend зависимости: Не найдены"
    }
    
    if (Test-Path "desktop/react-src/node_modules") {
        Write-LogSuccess "Desktop зависимости: ОК"
    } else {
        Write-LogWarning "Desktop зависимости: Не найдены"
    }
    
    Write-Host ""
    Write-LogInfo "Готово! Можно переходить к сборке проекта"
}

# Проверка что скрипт запущен из правильной директории
function Test-Directory {
    if (-not (Test-Path "package.json") -or -not (Test-Path "script")) {
        Write-LogError "Скрипт должен запускаться из корневой директории ZetGui"
        Write-LogInfo "Перейдите в директорию с package.json и script/"
        exit 1
    }
}

# Главная функция
function Main {
    Test-Directory
    Start-Installation
}

# Обработка Ctrl+C
try {
    Main
} catch {
    Write-Host ""
    Write-LogInfo "Прерывание установки"
    exit 0
} 