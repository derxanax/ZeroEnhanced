#!/usr/bin/env pwsh

# ZetGui Desktop GUI Starter  
# Запуск десктопного приложения на базе Neutralino

param(
    [switch]$NoDocker,
    [switch]$Debug,
    [switch]$Help
)

if ($Help) {
    Write-Host "ZetGui Desktop GUI Starter" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Использование:" -ForegroundColor Yellow
    Write-Host "  .\start-all-gui.ps1         # Стандартный запуск с Docker"
    Write-Host "  .\start-all-gui.ps1 -NoDocker  # Запуск без Docker"
    Write-Host "  .\start-all-gui.ps1 -Debug     # Debug режим"
    Write-Host "  .\start-all-gui.ps1 -Help      # Показать справку"
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
    Write-Host "Desktop GUI Application Starter" -ForegroundColor Blue
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
}

function Test-GUISystemDependencies {
    log_step "Проверяю GUI зависимости..."
    
    $dependencies = @{
        "node" = { node --version 2>$null }
        "npm" = { npm --version 2>$null }
        "neu" = { neu --version 2>$null }
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
    
    if ($missing -contains "neu") {
        log_warning "Neutralino CLI не найден, устанавливаю..."
        try {
            npm install -g @neutralinojs/neu
            $result = neu --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                log_success "Neutralino CLI установлен: $result"
                $missing = $missing | Where-Object { $_ -ne "neu" }
            }
        } catch {
            log_error "Ошибка установки Neutralino CLI"
        }
    }
    
    if ($missing.Count -gt 0) {
        log_warning "Отсутствующие зависимости: $($missing -join ', ')"
        log_step "Запускаю автоматическую установку..."
        
        & ".\install-all-Dependencies.ps1"
        if ($LASTEXITCODE -ne 0) {
            throw "Ошибка установки зависимостей"
        }
        
        log_step "Зависимости установлены, повторная проверка..."
        foreach ($dep in $missing) {
            try {
                $result = & $dependencies[$dep]
                if ($LASTEXITCODE -eq 0) {
                    log_success "$dep теперь доступен"
                } else {
                    throw "Dependency $dep все еще недоступен"
                }
            } catch {
                throw "Критическая ошибка: $dep не найден после установки"
            }
        }
    }
    
    log_success "Все GUI зависимости проверены"
}

function Test-DockerEnvironment {
    if ($NoDocker) {
        log_warning "Docker отключен по параметру --no-docker"
        return
    }
    
    log_step "Настраиваю Docker окружение для GUI..."
    
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
    
    log_success "Docker окружение готово для GUI"
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
        @{ Path = "desktop/react-src"; Name = "Desktop React" }
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

function Build-ReactApp {
    log_step "Собираю React приложение..."
    
    Set-Location "desktop/react-src"
    
    if (-not (Test-Path "build") -or -not (Test-Path "build/index.html")) {
        log_step "Собираю React build..."
        npm run build
        if ($LASTEXITCODE -ne 0) {
            throw "Ошибка сборки React приложения"
        }
        log_success "React приложение собрано"
    } else {
        log_success "React build уже существует"
    }
    
    Set-Location $OriginalLocation
}

function Initialize-Neutralino {
    log_step "Настраиваю Neutralino..."
    
    Set-Location "desktop"
    
    if (-not (Test-Path ".tmp")) {
        log_step "Инициализирую Neutralino проект..."
        neu update
        if ($LASTEXITCODE -ne 0) {
            throw "Ошибка инициализации Neutralino"
        }
    }
    
    log_success "Neutralino настроен"
    Set-Location $OriginalLocation
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
    
    log_success "Backend сервер запущен (PID: $($Global:BackendProcess.Id))"
}

function Start-NeutralinoApp {
    log_step "Запускаю Neutralino desktop приложение..."
    
    Set-Location "desktop"
    
    log_success "🖥️ Запускаю GUI приложение..."
    $Global:NeutralinoProcess = Start-Process -FilePath "neu" -ArgumentList "run" -PassThru -NoNewWindow
    
    Set-Location $OriginalLocation
    
    Start-Sleep -Seconds 4
    
    if ($Global:NeutralinoProcess.HasExited) {
        throw "Neutralino приложение не запустилось"
    }
    
    log_success "🎉 GUI приложение запущено! (PID: $($Global:NeutralinoProcess.Id))"
}

function Cleanup {
    log_step "Выполняю cleanup..."
    
    try {
        if ($Global:BackendProcess -and -not $Global:BackendProcess.HasExited) {
            log_info "Останавливаю backend сервер (PID: $($Global:BackendProcess.Id))..."
            $Global:BackendProcess.Kill()
            $Global:BackendProcess.WaitForExit(5000)
        }
        
        if ($Global:NeutralinoProcess -and -not $Global:NeutralinoProcess.HasExited) {
            log_info "Останавливаю Neutralino app (PID: $($Global:NeutralinoProcess.Id))..."
            $Global:NeutralinoProcess.Kill()
            $Global:NeutralinoProcess.WaitForExit(5000)
        }
        
        Get-Process -Name "neutralino*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*server.js*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        
        log_success "Background процессы остановлены"
    } catch {
        log_warning "Ошибка остановки процессов: $_"
    }
    
    Set-Location $OriginalLocation
    log_success "🏁 GUI сессия завершена"
}

# Главная функция
function Main {
    Show-Logo
    log_info "Запуск ZeroEnhanced GUI..."
    log_info "====================================="
    
    Set-Location (Split-Path $MyInvocation.MyCommand.Path)
    Set-Location ".."
    
    Test-GUISystemDependencies
    Install-NodeModules -Path "." -Name "Core"
    Install-NodeModules -Path "backend" -Name "Backend"
    Install-NodeModules -Path "desktop/react-src" -Name "Desktop React"
    Build-ReactApp
    Initialize-Neutralino
    Start-Backend
    
    Write-Host ""
    log_success "🎉 Все компоненты готовы!"
    log_info ""
    
    Start-NeutralinoApp
    
    log_info "GUI приложение работает. Для завершения нажмите Ctrl+C"
    log_info "Backend API доступен на: http://localhost:3001"
    
    while (-not $Global:NeutralinoProcess.HasExited) {
        Start-Sleep -Seconds 1
    }
}

Main

try {
    Cleanup
} catch {
    log_error "Критическая ошибка: $_"
    log_info "Для диагностики запустите с флагом -Debug"
    exit 1
} 