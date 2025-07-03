# PowerShell версия для Windows
# ZetGui Smart Build System

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
    Write-Host "ZetGui Smart Build System" -ForegroundColor Blue
    Write-Host "══════════════════════════════════════════════════=" -ForegroundColor Blue
}

# Переходим в корневую директорию проекта
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $scriptPath "..")

# Build Backend
function Build-Backend {
    Write-LogStep "Сборка backend"
Set-Location backend
try {
        if (Get-Content package.json | Select-String "build") {
            Write-LogInfo "Запускаю npm run build"
    npm run build --silent
            Write-LogSuccess "Backend собран успешно"
        } else {
            Write-LogWarning "Backend build script не настроен, пропускаю"
        }
} catch {
        Write-LogError "Ошибка сборки backend"
}
Set-Location ..
}

# Build Desktop React App
function Build-ReactApp {
    Write-LogStep "Сборка React приложения"
Set-Location desktop/react-src
    
    Write-LogInfo "Запускаю npm run build"
npm run build --silent
    Write-LogSuccess "React приложение собрано"

    Set-Location ..
    Write-LogInfo "Копирую сборку в desktop/www"
if (!(Test-Path "www")) { New-Item -ItemType Directory -Name "www" }
try {
    Copy-Item -Path "react-src/build/*" -Destination "www/" -Recurse -Force
        Write-LogSuccess "Файлы скопированы в desktop/www/"
} catch {
        Write-LogWarning "Не удалось скопировать build файлы"
}
Set-Location ..
}

# Build CLI
function Build-CLI {
    Write-LogStep "Сборка CLI компонентов"
Set-Location src
try {
        Write-LogInfo "Компилирую TypeScript"
    npx tsc
        Write-LogSuccess "CLI компоненты собраны"
} catch {
        Write-LogWarning "CLI TypeScript сборка не настроена"
}
Set-Location ..
}

# Показать результаты
function Show-BuildResults {
    Write-LogStep "Результаты сборки"
    
    Write-Host "Готовые файлы:" -ForegroundColor Cyan
    Write-Host "  * Desktop GUI: desktop/www/" -ForegroundColor Blue
    Write-Host "  * Backend: backend/dist/ (если настроено)" -ForegroundColor Blue
    Write-Host "  * CLI: src/ (скомпилированные .js файлы)" -ForegroundColor Blue
    
    Write-Host "Команды для запуска:" -ForegroundColor Cyan
    Write-Host "  * CLI версия:    .\script\start-all-cli.ps1" -ForegroundColor Blue
    Write-Host "  * Desktop GUI:   .\script\start-all-gui.ps1" -ForegroundColor Blue
    Write-Host "  * Web версия:    .\script\start-all-web.ps1" -ForegroundColor Blue
}

# Основная функция
function Main {
    Clear-Host
    Show-Logo
    Write-Host ""
    
    Build-Backend
    Build-ReactApp
    Build-CLI
    
Write-Host ""
    Write-Host "══════════════════════════════════════════════════=" -ForegroundColor Blue
    Write-LogSuccess "Сборка завершена успешно"
    Show-BuildResults
Write-Host "" 
}

# Запуск
Main 