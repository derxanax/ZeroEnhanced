# PowerShell версия для Windows
# 🐳 ZeroEnhanced Docker Setup Script

Write-Host "🐳 ZeroEnhanced Docker Setup для Windows" -ForegroundColor Cyan

# Константы
$DOCKER_IMAGE_NAME = "zet-sandbox-image"
$SANDBOX_CONTAINER_NAME = "zet-sandbox"
$DOCKERFILE_PATH = ".\docker-sandbox\Dockerfile"
$SANDBOX_DIR = ".\sandbox"

# Переходим в корневую директорию проекта
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $scriptPath "..")

# Функции для проверки Docker
function Test-Docker {
    try {
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            $null = docker ps 2>$null
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

function Test-DockerDesktop {
    try {
        $dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
        return ($dockerProcess -ne $null)
    } catch {
        return $false
    }
}

function Test-ImageExists {
    try {
        $null = docker image inspect "$DOCKER_IMAGE_NAME`:latest" 2>$null
        return $true
    } catch {
        return $false
    }
}

function Test-ContainerExists {
    try {
        $null = docker container inspect $SANDBOX_CONTAINER_NAME 2>$null
        return $true
    } catch {
        return $false
    }
}

function Test-ContainerRunning {
    try {
        $status = docker inspect -f '{{.State.Running}}' $SANDBOX_CONTAINER_NAME 2>$null
        return ($status -eq "true")
    } catch {
        return $false
    }
}

# Проверка Docker
function Check-Docker {
    Write-Host "🔍 Проверка Docker..." -ForegroundColor Purple
    
    if (-not (Test-Docker)) {
        Write-Host "❌ Docker не установлен или не запущен!" -ForegroundColor Red
        Write-Host "💡 Установите Docker Desktop:" -ForegroundColor Yellow
        Write-Host "   .\script\install-system-packages.ps1" -ForegroundColor White
        exit 1
    }
    
    Write-Host "✅ Docker готов к работе" -ForegroundColor Green
}

# Создание sandbox директории
function Create-SandboxDir {
    Write-Host "📁 Создание sandbox директории..." -ForegroundColor Purple
    
    if (-not (Test-Path $SANDBOX_DIR)) {
        New-Item -ItemType Directory -Path $SANDBOX_DIR | Out-Null
        Write-Host "✅ Директория $SANDBOX_DIR создана" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Директория $SANDBOX_DIR уже существует" -ForegroundColor Cyan
    }
    
    # Создаем тестовый файл
    $readmePath = Join-Path $SANDBOX_DIR "README.md"
    if (-not (Test-Path $readmePath)) {
        $readmeContent = @"
# ZetGui Sandbox

Эта директория монтируется в Docker контейнер как /workspace.

Здесь вы можете:
- Создавать и редактировать файлы через AI
- Выполнять команды в безопасной среде  
- Тестировать код без риска для основной системы

## Структура

sandbox/
├── README.md     # Этот файл
├── projects/     # Ваши проекты
└── temp/         # Временные файлы

Все файлы здесь доступны в контейнере по пути /workspace/.
"@
        Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
        
        New-Item -ItemType Directory -Path (Join-Path $SANDBOX_DIR "projects") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $SANDBOX_DIR "temp") -Force | Out-Null
        
        Write-Host "✅ Создан базовый README и структура директорий" -ForegroundColor Green
    }
}

# Сборка Docker образа
function Build-DockerImage {
    Write-Host "🔨 Сборка Docker образа..." -ForegroundColor Purple
    
    if (-not (Test-Path $DOCKERFILE_PATH)) {
        Write-Host "❌ Dockerfile не найден: $DOCKERFILE_PATH" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "📦 Собираю образ $DOCKER_IMAGE_NAME`:latest..." -ForegroundColor Yellow
    
    try {
        docker build -t "$DOCKER_IMAGE_NAME`:latest" -f $DOCKERFILE_PATH "./docker-sandbox/" --no-cache
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Образ собран успешно" -ForegroundColor Green
        } else {
            throw "Docker build failed"
        }
    } catch {
        Write-Host "❌ Ошибка сборки Docker образа" -ForegroundColor Red
        exit 1
    }
}

# Создание контейнера
function Create-Container {
    Write-Host "🐳 Создание Docker контейнера..." -ForegroundColor Purple
    
    # Останавливаем и удаляем существующий контейнер если есть
    if (Test-ContainerExists) {
        Write-Host "ℹ️ Останавливаю существующий контейнер..." -ForegroundColor Cyan
        docker stop $SANDBOX_CONTAINER_NAME 2>$null | Out-Null
        docker rm $SANDBOX_CONTAINER_NAME 2>$null | Out-Null
    }
    
    # Создаем новый контейнер
    Write-Host "ℹ️ Создаю новый контейнер $SANDBOX_CONTAINER_NAME..." -ForegroundColor Cyan
    
    $absoluteSandboxPath = (Resolve-Path $SANDBOX_DIR).Path
    
    try {
        $volumeMount = "${absoluteSandboxPath}:/workspace"
        docker create --name $SANDBOX_CONTAINER_NAME --tty --interactive --workdir "/workspace" --volume $volumeMount "$DOCKER_IMAGE_NAME`:latest" /bin/bash
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Контейнер $SANDBOX_CONTAINER_NAME создан" -ForegroundColor Green
        } else {
            throw "Container creation failed"
        }
    } catch {
        Write-Host "❌ Ошибка создания контейнера" -ForegroundColor Red
        exit 1
    }
}

# Запуск контейнера
function Start-Container {
    Write-Host "🚀 Запуск контейнера..." -ForegroundColor Purple
    
    if (Test-ContainerRunning) {
        Write-Host "ℹ️ Контейнер уже запущен" -ForegroundColor Cyan
        return
    }
    
    try {
        docker start $SANDBOX_CONTAINER_NAME
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Контейнер запущен" -ForegroundColor Green
        } else {
            throw "Container start failed"
        }
    } catch {
        Write-Host "❌ Ошибка запуска контейнера" -ForegroundColor Red
        exit 1
    }
}

# Тестирование контейнера
function Test-Container {
    Write-Host "🧪 Тестирование контейнера..." -ForegroundColor Purple
    
    # Тест 1: Проверка что контейнер запущен
    if (-not (Test-ContainerRunning)) {
        Write-Host "❌ Контейнер не запущен" -ForegroundColor Red
        return $false
    }
    
    # Тест 2: Выполнение простой команды
    Write-Host "ℹ️ Выполняю тестовую команду..." -ForegroundColor Cyan
    try {
        $result = docker exec $SANDBOX_CONTAINER_NAME echo "Hello from ZetGui sandbox!" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Тестовая команда выполнена успешно" -ForegroundColor Green
        } else {
            Write-Host "❌ Ошибка выполнения команды в контейнере" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Ошибка выполнения команды в контейнере" -ForegroundColor Red
        return $false
    }
    
    # Тест 3: Проверка монтирования директории
    Write-Host "ℹ️ Проверяю монтирование sandbox директории..." -ForegroundColor Cyan
    try {
        $result = docker exec $SANDBOX_CONTAINER_NAME ls -la /workspace/README.md 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Sandbox директория смонтирована корректно" -ForegroundColor Green
        } else {
            Write-Host "❌ Проблема с монтированием sandbox директории" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Проблема с монтированием sandbox директории" -ForegroundColor Red
        return $false
    }
    
    # Тест 4: Проверка установленных пакетов
    Write-Host "ℹ️ Проверяю установленные пакеты в контейнере..." -ForegroundColor Cyan
    try {
        $curlCheck = docker exec $SANDBOX_CONTAINER_NAME which curl 2>$null
        $gitCheck = docker exec $SANDBOX_CONTAINER_NAME which git 2>$null
        $nanoCheck = docker exec $SANDBOX_CONTAINER_NAME which nano 2>$null
        
        if ($curlCheck -and $gitCheck -and $nanoCheck) {
            Write-Host "✅ Все необходимые пакеты установлены" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Некоторые пакеты могут отсутствовать в контейнере" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ Некоторые пакеты могут отсутствовать в контейнере" -ForegroundColor Yellow
    }
    
    Write-Host "✅ Все тесты пройдены успешно!" -ForegroundColor Green
    return $true
}

# Показать информацию о контейнере
function Show-ContainerInfo {
    Write-Host "📊 Информация о контейнере..." -ForegroundColor Purple
    
    Write-Host "📊 Статус Docker окружения:" -ForegroundColor Cyan
    Write-Host "  • Образ:     $DOCKER_IMAGE_NAME`:latest" -ForegroundColor Blue
    Write-Host "  • Контейнер: $SANDBOX_CONTAINER_NAME" -ForegroundColor Blue
    Write-Host "  • Sandbox:   $SANDBOX_DIR → /workspace" -ForegroundColor Blue
    
    if (Test-ImageExists) {
        Write-Host "  ✅ Образ существует" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Образ не найден" -ForegroundColor Red
    }
    
    if (Test-ContainerExists) {
        if (Test-ContainerRunning) {
            Write-Host "  ✅ Контейнер запущен" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ Контейнер остановлен" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Контейнер не создан" -ForegroundColor Red
    }
}

# Очистка
function Remove-DockerResources {
    Write-Host "🗑️ Очистка Docker ресурсов..." -ForegroundColor Purple
    
    # Останавливаем и удаляем контейнер
    if (Test-ContainerExists) {
        Write-Host "ℹ️ Удаляю контейнер $SANDBOX_CONTAINER_NAME..." -ForegroundColor Cyan
        docker stop $SANDBOX_CONTAINER_NAME 2>$null | Out-Null
        docker rm $SANDBOX_CONTAINER_NAME 2>$null | Out-Null
        Write-Host "✅ Контейнер удален" -ForegroundColor Green
    }
    
    # Удаляем образ
    if (Test-ImageExists) {
        Write-Host "ℹ️ Удаляю образ $DOCKER_IMAGE_NAME`:latest..." -ForegroundColor Cyan
        docker rmi "$DOCKER_IMAGE_NAME`:latest" 2>$null | Out-Null
        Write-Host "✅ Образ удален" -ForegroundColor Green
    }
    
    Write-Host "✅ Очистка завершена" -ForegroundColor Green
}

# Полная настройка
function Invoke-FullSetup {
    param([string]$Mode = "")
    
    Write-Host "🎯 Полная настройка Docker окружения" -ForegroundColor Purple
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    Check-Docker
    Create-SandboxDir
    
    # Сборка образа
    if (-not (Test-ImageExists) -or $Mode -eq "--rebuild") {
        Build-DockerImage
    } else {
        Write-Host "ℹ️ Образ $DOCKER_IMAGE_NAME`:latest уже существует" -ForegroundColor Cyan
    }
    
    # Создание контейнера
    if (-not (Test-ContainerExists)) {
        Create-Container
    } else {
        Write-Host "ℹ️ Контейнер $SANDBOX_CONTAINER_NAME уже существует" -ForegroundColor Cyan
    }
    
    Start-Container
    
    if (Test-Container) {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
        Write-Host "🎉 Docker окружение готово к работе!" -ForegroundColor Green
        Show-ContainerInfo
        Write-Host ""
        Write-Host "📋 Команды для управления:" -ForegroundColor Cyan
        Write-Host "   Проверка статуса: .\script\setup-docker.ps1 --status" -ForegroundColor White
        Write-Host "   Перезапуск:       .\script\setup-docker.ps1 --restart" -ForegroundColor White
        Write-Host "   Очистка:          .\script\setup-docker.ps1 --cleanup" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "❌ Настройка завершилась с ошибками" -ForegroundColor Red
        exit 1
    }
}

# Основная функция
function Main {
    param([string]$Command = "setup")
    
    switch ($Command) {
        "setup" { Invoke-FullSetup }
        "--setup" { Invoke-FullSetup }
        "--rebuild" { Invoke-FullSetup "--rebuild" }
        "--status" { Show-ContainerInfo }
        "--start" { 
            Check-Docker
            Start-Container 
        }
        "--restart" {
            Check-Docker
            if (Test-ContainerExists) {
                docker restart $SANDBOX_CONTAINER_NAME
                Write-Host "✅ Контейнер перезапущен" -ForegroundColor Green
            } else {
                Write-Host "❌ Контейнер не существует" -ForegroundColor Red
                exit 1
            }
        }
        "--test" {
            Check-Docker
            Test-Container
        }
        "--cleanup" { Remove-DockerResources }
        "--help" {
            Write-Host "🐳 ZeroEnhanced Docker Setup"
            Write-Host "Использование: .\script\setup-docker.ps1 [команда]"
            Write-Host ""
            Write-Host "Команды:"
            Write-Host "  setup     - Полная настройка (по умолчанию)"
            Write-Host "  --rebuild - Пересборка образа и контейнера"
            Write-Host "  --status  - Показать статус"
            Write-Host "  --start   - Запустить контейнер"
            Write-Host "  --restart - Перезапустить контейнер"
            Write-Host "  --test    - Протестировать контейнер"
            Write-Host "  --cleanup - Удалить контейнер и образ"
            Write-Host "  --help    - Показать эту справку"
        }
        default {
            Write-Host "❌ Неизвестная команда: $Command" -ForegroundColor Red
            Write-Host "Используйте --help для справки" -ForegroundColor Yellow
            exit 1
        }
    }
}

# Запуск
Main @args 