#!/usr/bin/env pwsh

# ZetGui Web Application Starter
# Запуск веб-версии с автоматической настройкой зависимостей

param(
    [switch]$NoDocker,
    [switch]$Debug,
    [switch]$Help,
    [int]$Port = 3000
)

if ($Help) {
    Write-Host "ZetGui Web Application Starter" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Использование:" -ForegroundColor Yellow
    Write-Host "  .\start-all-web.ps1          # Стандартный запуск с Docker"
    Write-Host "  .\start-all-web.ps1 -NoDocker   # Запуск без Docker"
    Write-Host "  .\start-all-web.ps1 -Port 8080  # Задать порт веб-сервера"
    Write-Host "  .\start-all-web.ps1 -Debug      # Debug режим"
    Write-Host "  .\start-all-web.ps1 -Help       # Показать справку"
    exit 0
}

$ErrorActionPreference = "Stop"
$OriginalLocation = Get-Location

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
    Write-Host "Web Application Starter" -ForegroundColor Blue
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
}

function Test-WebDependencies {
    log_step "Проверяю Web зависимости..."
    
    $dependencies = @{
        "node" = { node --version 2>$null }
        "npm" = { npm --version 2>$null }
    }
    
    if (-not $NoDocker) {
        $dependencies["docker"] = { docker --version 2>$null }
    }
    
    $missing = @()
    foreach ($dep in $dependencies.Keys) {
        try {
            $result = & $dependencies[$dep]
            if ($LASTEXITCODE -eq 0) {
                log_success "$dep найден: $($result -split "`n" | Select-Object -First 1)"
            } else {
                $missing += $dep
            }
        } catch {
            $missing += $dep
        }
    }
    
    if ($missing.Count -gt 0) {
        log_error "Не удалось установить следующие зависимости: $($missing -join ', ')"
        exit 1
    }
    
    log_success "Все Web зависимости проверены"
}

function Test-DockerEnvironment {
    if ($NoDocker) {
        log_warning "Docker отключен по параметру --no-docker"
        return
    }
    
    log_step "Настраиваю Docker окружение для Web..."
    
    try {
        $dockerInfo = docker info 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker не запущен или недоступен"
        }
        log_success "Docker запущен и доступен"
    } catch {
        log_warning "Docker недоступен, пытаюсь настроить..."
        & ".\setup-docker.ps1"
        if ($LASTEXITCODE -ne 0) {
            throw "Ошибка настройки Docker"
        }
    }
    
    $imageName = "zet-sandbox-image:latest"
    try {
        $images = docker images --format "table {{.Repository}}:{{.Tag}}" | Select-String $imageName
        if (-not $images) {
            log_warning "Docker образ $imageName не найден, собираю..."
            & ".\setup-docker.ps1" "--rebuild"
            if ($LASTEXITCODE -ne 0) {
                throw "Ошибка сборки Docker образа"
            }
        } else {
            log_success "Docker образ $imageName найден"
        }
    } catch {
        log_error "Ошибка проверки Docker образа: $_"
        throw
    }
    
    try {
        $containers = docker ps -a --filter "name=zet-sandbox" --format "{{.Names}}"
        if (-not $containers) {
            log_warning "Контейнер zet-sandbox не найден, создаю..."
            & ".\setup-docker.ps1"
            if ($LASTEXITCODE -ne 0) {
                throw "Ошибка создания контейнера"
            }
        } else {
            $status = docker ps --filter "name=zet-sandbox" --format "{{.Status}}"
            if (-not $status) {
                log_step "Запускаю остановленный контейнер..."
                docker start zet-sandbox | Out-Null
                Start-Sleep -Seconds 2
            }
            log_success "Docker контейнер готов"
        }
    } catch {
        log_error "Ошибка работы с контейнером: $_"
        throw
    }
    
    log_success "Docker окружение готово для Web"
}

function Install-NodeModules {
    param([string]$Path, [string]$Name)
    
    log_step "Проверяю npm модули в $Name..."
    
    if (-not (Test-Path "$Path/package.json")) {
        log_warning "package.json не найден в $Path"
        return
    }
    
    Set-Location $Path
    
    if (-not (Test-Path "node_modules") -or -not (Test-Path "package-lock.json")) {
        log_step "Устанавливаю зависимости для $Name..."
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "Ошибка установки npm модулей в $Name"
        }
        log_success "Зависимости $Name установлены"
    } else {
        log_success "Зависимости $Name уже установлены"
    }
    
    Set-Location $OriginalLocation
}

function Build-TypeScriptProjects {
    log_step "Собираю TypeScript проекты..."
    
    $projects = @(
        @{ Path = "."; Name = "Core" }
        @{ Path = "backend"; Name = "Backend" }
    )
    
    foreach ($project in $projects) {
        if (Test-Path "$($project.Path)/tsconfig.json") {
            Set-Location $project.Path
            log_step "Компилирую TypeScript в $($project.Name)..."
            npx tsc
            if ($LASTEXITCODE -ne 0) {
                throw "Ошибка компиляции TypeScript в $($project.Name)"
            }
            log_success "$($project.Name) скомпилирован"
            Set-Location $OriginalLocation
        }
    }
}

function Test-PortAvailable {
    param([int]$Port)
    
    try {
        $listener = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
        $activeConnections = $listener.GetActiveTcpListeners()
        $portInUse = $activeConnections | Where-Object { $_.Port -eq $Port }
        return (-not $portInUse)
    } catch {
        return $true
    }
}

function Find-AvailablePort {
    param([int]$StartPort)
    
    $port = $StartPort
    $maxAttempts = 100
    $attempts = 0
    
    while (-not (Test-PortAvailable -Port $port) -and $attempts -lt $maxAttempts) {
        log_warning "Порт $port занят, пробую следующий..."
        $port++
        $attempts++
    }
    
    if ($attempts -eq $maxAttempts) {
        throw "Не удалось найти свободный порт в диапазоне $StartPort-$($StartPort + $maxAttempts)"
    }
    
    return $port
}

function Start-Backend {
    log_step "Запускаю backend сервер..."
    
    Set-Location "backend"
    
    if (-not (Test-Path "src/server.ts")) {
        throw "Не найден исходный файл backend: src/server.ts"
    }

    log_success "Backend сервер запускается на порту 3001 через ts-node..."
    $Global:BackendProcess = Start-Process -FilePath "npx" -ArgumentList "ts-node src/server.ts" -PassThru -NoNewWindow
    
    Set-Location $OriginalLocation
    
    Start-Sleep -Seconds 3
    
    if ($Global:BackendProcess.HasExited) {
        throw "Backend сервер не запустился"
    }
    
    log_success "Backend сервер запущен на http://localhost:3001 (PID: $($Global:BackendProcess.Id))"
    
    return 3001
}

function Get-ReactAppPath {
    log_step "Подготавливаю React приложение для web..."
    
    $reactPaths = @("desktop/react-src", "react-src", "web-src")
    
    foreach ($path in $reactPaths) {
        if (Test-Path $path) {
            log_success "Найдено React приложение в $path"
            return $path
        }
    }
    
    log_warning "React приложение не найдено, создаю базовую структуру..."
    
    $webSrcPath = "web-src"
    New-Item -ItemType Directory -Path $webSrcPath -Force | Out-Null
    Set-Location $webSrcPath
    
    if (-not (Test-Path "package.json")) {
        log_step "Создаю базовое React приложение..."
        npx create-react-app . --template typescript --use-npm
        if ($LASTEXITCODE -ne 0) {
            throw "Ошибка создания React приложения"
        }
        log_success "Базовое React приложение создано"
    }
    
    Set-Location $OriginalLocation
    
    return $webSrcPath
}

function Start-ReactDevServer {
    param([string]$ReactPath)
    
    log_step "Запускаю React development сервер..."
    
    Set-Location $ReactPath
    
    $frontendPort = Find-AvailablePort -StartPort $Port
    
    if ($frontendPort -ne $Port) {
        log_warning "Порт $Port занят, использую порт $frontendPort"
    }
    
    log_success "React dev сервер запускается на порту $frontendPort..."
    
    $env:PORT = $frontendPort
    $env:BROWSER = "none"
    
    $Global:FrontendProcess = Start-Process -FilePath "npm" -ArgumentList "start" -PassThru -NoNewWindow
    
    Set-Location $OriginalLocation
    
    Start-Sleep -Seconds 8
    
    if ($Global:FrontendProcess.HasExited) {
        throw "React dev сервер не запустился"
    }
    
    log_success "React dev сервер запущен на http://localhost:$frontendPort (PID: $($Global:FrontendProcess.Id))"
    
    return $frontendPort
}

function Open-Browser {
    param([string]$Url)
    
    log_step "Открываю браузер..."
    
    Start-Sleep -Seconds 3
    
    try {
        Start-Process $Url
        log_success "Браузер открыт с URL: $Url"
    } catch {
        log_warning "Не удалось открыть браузер автоматически. Откройте URL вручную: $Url"
    }
}

function Cleanup {
    log_step "Выполняю cleanup..."
    
    try {
        if ($Global:BackendProcess -and -not $Global:BackendProcess.HasExited) {
            log_info "Останавливаю backend сервер (PID: $($Global:BackendProcess.Id))..."
            $Global:BackendProcess.Kill()
            $Global:BackendProcess.WaitForExit(5000)
        }
        
        if ($Global:FrontendProcess -and -not $Global:FrontendProcess.HasExited) {
            log_info "Останавливаю frontend сервер (PID: $($Global:FrontendProcess.Id))..."
            $Global:FrontendProcess.Kill()
            $Global:FrontendProcess.WaitForExit(5000)
        }
        
        Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { 
            $_.CommandLine -like "*react-scripts*" -or $_.CommandLine -like "*webpack-dev-server*" -or $_.CommandLine -like "*server.js*"
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        
        log_success "Background процессы остановлены"
    } catch {
        log_warning "Ошибка остановки процессов: $_"
    }
    
    Set-Location $OriginalLocation
    log_success "🏁 Web сессия завершена"
}

# Главная функция
function Main {
    Show-Logo
    log_info "Запуск ZeroEnhanced Web..."
    log_info "====================================="
    
    Set-Location (Split-Path $MyInvocation.MyCommand.Path)
    Set-Location ".."
    
    Test-WebDependencies
    Install-NodeModules -Path "." -Name "Core"
    Install-NodeModules -Path "backend" -Name "Backend"
    Install-NodeModules -Path "desktop/react-src" -Name "Frontend"
    
    Start-Backend
    Start-FrontendDevServer
    
    log_info "Веб-сервер и backend запущены."
    log_info "Нажмите Ctrl+C для завершения."
    
    Open-Browser -Url "http://localhost:$frontendPort"
    
    while (-not $Global:FrontendProcess.HasExited) {
        Start-Sleep -Seconds 1
    }
}

Main

try {
    # ... (остальной код без изменений) ...
} catch {
    log_error "Критическая ошибка: $_"
    log_info "Для диагностики запустите с флагом -Debug"
    exit 1
} finally {
    Cleanup
} 