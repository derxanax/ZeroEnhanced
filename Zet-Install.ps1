# PowerShell версия для Windows
# ZetGui Installation Manager

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
    Write-Host "ZetGui Installation Manager" -ForegroundColor Blue
    Write-Host "══════════════════════════════════════════════════=" -ForegroundColor Blue
    Write-Host ""
}

# Анимация приветствия
function Show-Welcome {
    Show-Loading "Загрузка системы" 2
    Show-Loading "Проверка окружения" 1
    Show-Loading "Подготовка интерфейса" 1
    Write-Host ""
    Write-LogSuccess "Система готова к работе"
    Write-Host ""
}

# Показать главное меню
function Show-Menu {
    Write-Host "Выберите действие:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1  " -NoNewline -ForegroundColor Blue
    Write-Host "Проверить системные зависимости"
    Write-Host "  2  " -NoNewline -ForegroundColor Blue
    Write-Host "Установить все зависимости проекта (npm, TypeScript)"
    Write-Host "  3  " -NoNewline -ForegroundColor Blue
    Write-Host "Настроить Docker контейнер (отдельно)"
    Write-Host "  4  " -NoNewline -ForegroundColor Blue
    Write-Host "Собрать все компоненты"
    Write-Host ""
    Write-Host "  5  " -NoNewline -ForegroundColor Yellow
    Write-Host "Запустить CLI версию"
    Write-Host "  6  " -NoNewline -ForegroundColor Yellow
    Write-Host "Запустить Desktop GUI"
    Write-Host "  7  " -NoNewline -ForegroundColor Yellow
    Write-Host "Запустить Web версию"
    Write-Host ""
    Write-Host "  8  " -NoNewline -ForegroundColor Magenta
    Write-Host "Создать AppImage (Linux)"
    Write-Host "  9  " -NoNewline -ForegroundColor Magenta
    Write-Host "Показать информацию о системе"
    Write-Host ""
    Write-Host "  0  " -NoNewline -ForegroundColor Red
    Write-Host "Выход"
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════=" -ForegroundColor Blue
}

# Выполнить действие
function Invoke-Action {
    param([string]$Choice)
    
    switch ($Choice) {
        "1" {
            Write-LogStep "Проверка системных зависимостей"
            & ".\script\check-dependencies.ps1" "--system"
        }
        "2" {
            Write-LogStep "Установка зависимостей проекта"
            Write-LogInfo "Устанавливаю системные пакеты"
            & ".\script\install-system-packages.ps1"
            Write-Host ""
            Write-LogInfo "Устанавливаю npm зависимости"
            & ".\script\install-all-Dependencies.ps1"
        }
        "3" {
            Write-LogStep "Настройка Docker контейнера"
            & ".\script\setup-docker.ps1"
        }
        "4" {
            Write-LogStep "Сборка всех компонентов"
            & ".\script\build-all.ps1"
        }
        "5" {
            Write-LogStep "Запуск CLI версии"
            & ".\script\start-all-cli.ps1"
        }
        "6" {
            Write-LogStep "Запуск Desktop GUI"
            & ".\script\start-all-gui.ps1"
        }
        "7" {
            Write-LogStep "Запуск Web версии"
            & ".\script\start-all-web.ps1"
        }
        "8" {
            Write-LogStep "Создание AppImage"
            Write-LogWarning "AppImage доступен только в Linux"
        }
        "9" {
            Write-LogStep "Информация о системе"
            & ".\script\check-dependencies.ps1" "--info"
        }
        "0" {
            Write-Host ""
            Write-LogSuccess "До свидания!"
            exit 0
        }
        default {
            Write-LogError "Неверный выбор: $Choice"
        }
    }
}

# Основной цикл
function Start-MainLoop {
    while ($true) {
        Show-Logo
        Show-Menu
        
        Write-Host -NoNewline "Ваш выбор: " -ForegroundColor Cyan
        $choice = Read-Host
        
        Write-Host ""
        Invoke-Action $choice
        
        Write-Host ""
        Write-Host "Нажмите Enter для продолжения..." -ForegroundColor Blue
        Read-Host | Out-Null
    }
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
    Show-Logo
    Show-Welcome
    Start-MainLoop
}

# Обработка Ctrl+C
try {
    Main
} catch {
    Write-Host ""
    Write-LogInfo "Прерывание работы"
    exit 0
} 
