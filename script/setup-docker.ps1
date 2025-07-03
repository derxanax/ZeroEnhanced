# ZetGui Docker Setup Manager  
# Настройка и управление Docker контейнером для безопасного выполнения команд

param(
    [string]$Action = "setup",
    [switch]$Help
)

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
    Write-Host "Docker Setup Manager" -ForegroundColor Blue
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
}

# Переходим в корневую директорию проекта
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $scriptPath "..")

# Константы
$IMAGE_NAME = "zet-sandbox-image:latest"
$CONTAINER_NAME = "zet-sandbox"
$SANDBOX_DIR = ".\sandbox"
$DOCKERFILE_PATH = ".\docker-sandbox\Dockerfile"

# Автоопределение системы
function Get-SystemInfo {
    log_step "Определение системы..."
    
    $systemInfo = @{
        Type = "windows"
        OS = [Environment]::OSVersion.VersionString
        Arch = $env:PROCESSOR_ARCHITECTURE
        Version = [Environment]::OSVersion.Version
        User = $env:USERNAME
        Computer = $env:COMPUTERNAME
    }
    
    # Определение Docker архитектуры
    switch ($systemInfo.Arch) {
        "AMD64" { $systemInfo.DockerArch = "amd64" }
        "ARM64" { $systemInfo.DockerArch = "arm64" }
        default { $systemInfo.DockerArch = "amd64" }
    }
    
    log_info "Система: $($systemInfo.Type)"
    log_info "ОС: $($systemInfo.OS)"
    log_info "Архитектура: $($systemInfo.Arch) -> Docker: $($systemInfo.DockerArch)"
    log_info "Пользователь: $($systemInfo.User)"
    
    return $systemInfo
}

# Проверка Docker
function Test-Docker {
    log_step "Проверка Docker..."
    
    # Проверка установки Docker
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        log_error "Docker не установлен!"
        log_info "Установите Docker Desktop для Windows:"
        log_info "https://docs.docker.com/desktop/windows/install/"
        return $false
    }
    
    # Проверка Docker daemon
    try {
        $null = docker info 2>$null
    } catch {
        log_error "Docker daemon не запущен!"
        log_info "Запустите Docker Desktop"
        return $false
    }
    
    # Проверка доступа к Docker
    try {
        $null = docker ps 2>$null
        $dockerVersion = (docker --version).Split(' ')[2].TrimEnd(',')
        log_success "Docker работает: $dockerVersion"
        return $true
    } catch {
        log_error "Нет доступа к Docker!"
        log_info "Убедитесь что Docker Desktop запущен и доступен"
        return $false
    }
}

# Создание sandbox директории
function New-SandboxDirectory {
    log_step "Создание sandbox директории..."
    
    if (-not (Test-Path $SANDBOX_DIR)) {
        New-Item -ItemType Directory -Path $SANDBOX_DIR -Force | Out-Null
        log_success "Создана директория: $SANDBOX_DIR"
    } else {
        log_success "Директория уже существует: $SANDBOX_DIR"
    }
    
    # Создаем базовые поддиректории
    $subDirs = @("workspace", "projects", "temp", "logs")
    foreach ($dir in $subDirs) {
        $fullPath = Join-Path $SANDBOX_DIR $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
        
        # Создаем .gitkeep файлы
        $gitkeepPath = Join-Path $fullPath ".gitkeep"
        if (-not (Test-Path $gitkeepPath)) {
            "" | Out-File -FilePath $gitkeepPath -Encoding UTF8
        }
    }
    
    # Проверка прав доступа
    try {
        $testFile = Join-Path $SANDBOX_DIR "test.tmp"
        "test" | Out-File -FilePath $testFile -Encoding UTF8
        Remove-Item $testFile -Force
        log_success "Sandbox структура готова"
        return $true
    } catch {
        log_error "Нет прав записи в $SANDBOX_DIR"
        return $false
    }
}

# Создание Dockerfile если не существует
function New-Dockerfile {
    log_step "Проверка Dockerfile..."
    
    if (-not (Test-Path $DOCKERFILE_PATH)) {
        log_info "Создаю Dockerfile..."
        
        $dockerDir = Split-Path $DOCKERFILE_PATH -Parent
        if (-not (Test-Path $dockerDir)) {
            New-Item -ItemType Directory -Path $dockerDir -Force | Out-Null
        }
        
        $dockerfileContent = @'
# ZetGui Sandbox Container
# Безопасная среда выполнения для AI команд

FROM ubuntu:22.04

# Переменные окружения
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=20
ENV PYTHON_VERSION=3.11

# Установка базовых пакетов
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    nano \
    vim \
    htop \
    tree \
    jq \
    unzip \
    zip \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Установка Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs

# Обновление npm
RUN npm install -g npm@latest

# Установка полезных npm пакетов
RUN npm install -g \
    typescript \
    ts-node \
    nodemon \
    prettier \
    eslint

# Установка Python пакетов
RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install \
    requests \
    beautifulsoup4 \
    pandas \
    numpy \
    flask \
    fastapi \
    uvicorn

# Создание рабочего пользователя
RUN useradd -m -s /bin/bash zetuser \
    && echo "zetuser:zetpass" | chpasswd \
    && usermod -aG sudo zetuser

# Создание рабочих директорий
RUN mkdir -p /workspace /projects /tmp/zet \
    && chown -R zetuser:zetuser /workspace /projects /tmp/zet

# Настройка sudo без пароля для zetuser
RUN echo "zetuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Переключение на рабочего пользователя
USER zetuser
WORKDIR /workspace

# Настройка bash
RUN echo 'export PS1="\[\033[36m\]zet-sandbox\[\033[0m\]:\[\033[32m\]\w\[\033[0m\]$ "' >> ~/.bashrc \
    && echo 'alias ll="ls -la"' >> ~/.bashrc \
    && echo 'alias la="ls -la"' >> ~/.bashrc

# Создание информационного файла
RUN echo "ZetGui Sandbox Container" > ~/README.txt \
    && echo "======================" >> ~/README.txt \
    && echo "Node.js: $(node --version)" >> ~/README.txt \
    && echo "npm: $(npm --version)" >> ~/README.txt \
    && echo "Python: $(python3 --version)" >> ~/README.txt \
    && echo "Build: $(date)" >> ~/README.txt

# Порты для веб-приложений
EXPOSE 3000 8000 8080 5000

# Команда по умолчанию
CMD ["/bin/bash"]
'@
        
        $dockerfileContent | Out-File -FilePath $DOCKERFILE_PATH -Encoding UTF8
        log_success "Dockerfile создан: $DOCKERFILE_PATH"
    } else {
        log_success "Dockerfile уже существует: $DOCKERFILE_PATH"
    }
}

# Сборка Docker образа
function Build-DockerImage {
    param($SystemInfo)
    
    log_step "Сборка Docker образа..."
    
    # Удаляем старый образ если существует
    try {
        docker image inspect $IMAGE_NAME *>$null
        log_info "Удаляю старый образ..."
        docker rmi $IMAGE_NAME *>$null
    } catch {
        # Образ не существует, продолжаем
    }
    
    log_info "Собираю образ: $IMAGE_NAME"
    log_info "Архитектура: $($SystemInfo.DockerArch)"
    
    $dockerDir = Split-Path $DOCKERFILE_PATH -Parent
    
    try {
        # Сборка с параметрами для текущей архитектуры
        docker build `
            --platform "linux/$($SystemInfo.DockerArch)" `
            --tag $IMAGE_NAME `
            --file $DOCKERFILE_PATH `
            $dockerDir `
            --progress=plain
        
        log_success "Образ собран успешно: $IMAGE_NAME"
        
        # Показываем информацию об образе
        $imageInfo = docker images $IMAGE_NAME --format "{{.Size}}"
        log_info "Размер образа: $imageInfo"
        
        return $true
    } catch {
        log_error "Ошибка сборки образа: $_"
        return $false
    }
}

# Создание и настройка контейнера
function New-Container {
    log_step "Настройка контейнера..."
    
    # Останавливаем и удаляем существующий контейнер
    try {
        docker container inspect $CONTAINER_NAME *>$null
        log_info "Останавливаю существующий контейнер..."
        docker stop $CONTAINER_NAME *>$null
        docker rm $CONTAINER_NAME *>$null
    } catch {
        # Контейнер не существует, продолжаем
    }
    
    # Получаем абсолютный путь к sandbox
    $sandboxAbsPath = (Resolve-Path $SANDBOX_DIR).Path
    
    log_info "Создаю контейнер: $CONTAINER_NAME"
    log_info "Монтирую: $sandboxAbsPath -> /workspace"
    
    try {
        # Создание контейнера с настройками
        docker create `
            --name $CONTAINER_NAME `
            --hostname "zet-sandbox" `
            --volume "${sandboxAbsPath}:/workspace" `
            --workdir "/workspace" `
            --interactive `
            --tty `
            --restart unless-stopped `
            --memory="2g" `
            --cpus="2.0" `
            --network bridge `
            --publish 3000:3000 `
            --publish 8000:8000 `
            --publish 8080:8080 `
            --publish 5000:5000 `
            $IMAGE_NAME
        
        log_success "Контейнер создан: $CONTAINER_NAME"
        
        # Запускаем контейнер
        docker start $CONTAINER_NAME
        log_success "Контейнер запущен"
        
        # Ждем пока контейнер полностью запустится
        Start-Sleep -Seconds 2
        
        # Проверяем статус
        $status = docker inspect -f '{{.State.Status}}' $CONTAINER_NAME
        log_info "Статус контейнера: $status"
        
        return $true
    } catch {
        log_error "Не удалось создать/запустить контейнер: $_"
        return $false
    }
}

# Тест контейнера
function Test-Container {
    log_step "Тестирование контейнера..."
    
    # Проверка работы контейнера
    try {
        docker exec $CONTAINER_NAME echo "Container is working" *>$null
    } catch {
        log_error "Контейнер не отвечает"
        return $false
    }
    
    # Тест основных команд
    log_info "Тестирую команды в контейнере..."
    
    # Node.js
    try {
        $nodeVersion = docker exec $CONTAINER_NAME node --version 2>$null
        log_success "Node.js: $nodeVersion"
    } catch {
        log_error "Node.js не работает в контейнере"
        return $false
    }
    
    # Python
    try {
        $pythonVersion = docker exec $CONTAINER_NAME python3 --version 2>$null
        log_success "Python: $pythonVersion"
    } catch {
        log_error "Python не работает в контейнере"
        return $false
    }
    
    # Проверка монтирования
    try {
        docker exec $CONTAINER_NAME test -d "/workspace" *>$null
        docker exec $CONTAINER_NAME test -w "/workspace" *>$null
        log_success "Workspace монтирован и доступен для записи"
    } catch {
        log_error "Проблемы с монтированием workspace"
        return $false
    }
    
    # Создаем тестовый файл
    $testFile = "test-$(Get-Date -Format 'yyyyMMddHHmmss').txt"
    try {
        docker exec $CONTAINER_NAME sh -c "echo 'Container test' > /workspace/$testFile"
        if (Test-Path (Join-Path $SANDBOX_DIR $testFile)) {
            Remove-Item (Join-Path $SANDBOX_DIR $testFile) -Force
            log_success "Файловая система работает корректно"
        } else {
            log_error "Проблемы с файловой системой"
            return $false
        }
    } catch {
        log_error "Проблемы с файловой системой: $_"
        return $false
    }
    
    log_success "Все тесты пройдены!"
    return $true
}

# Показать информацию о контейнере
function Show-ContainerInfo {
    log_step "Информация о контейнере..."
    
    Write-Host ""
    Write-Host "📦 Контейнер:" -ForegroundColor Cyan
    Write-Host "   • Имя: $CONTAINER_NAME" -ForegroundColor Blue
    Write-Host "   • Образ: $IMAGE_NAME" -ForegroundColor Blue
    Write-Host "   • Sandbox: $SANDBOX_DIR" -ForegroundColor Blue
    
    try {
        docker container inspect $CONTAINER_NAME *>$null
        $status = docker inspect -f '{{.State.Status}}' $CONTAINER_NAME
        $created = (docker inspect -f '{{.Created}}' $CONTAINER_NAME).Split('T')[0]
        Write-Host "   • Статус: $status" -ForegroundColor Blue
        Write-Host "   • Создан: $created" -ForegroundColor Blue
        
        Write-Host ""
        Write-Host "🔗 Команды:" -ForegroundColor Cyan
        Write-Host "   • Войти в контейнер: docker exec -it $CONTAINER_NAME bash" -ForegroundColor Blue
        Write-Host "   • Остановить: docker stop $CONTAINER_NAME" -ForegroundColor Blue
        Write-Host "   • Запустить: docker start $CONTAINER_NAME" -ForegroundColor Blue
        Write-Host "   • Логи: docker logs $CONTAINER_NAME" -ForegroundColor Blue
        
        Write-Host ""
        Write-Host "🌐 Порты:" -ForegroundColor Cyan
        Write-Host "   • 3000 -> 3000 (React/Node.js)" -ForegroundColor Blue
        Write-Host "   • 8000 -> 8000 (Python/FastAPI)" -ForegroundColor Blue
        Write-Host "   • 8080 -> 8080 (Web servers)" -ForegroundColor Blue
        Write-Host "   • 5000 -> 5000 (Flask)" -ForegroundColor Blue
    } catch {
        Write-Host "   • Контейнер не создан" -ForegroundColor Red
    }
    Write-Host ""
}

# Очистка (удаление контейнера и образа)
function Remove-DockerResources {
    log_step "Очистка Docker ресурсов..."
    
    # Останавливаем и удаляем контейнер
    try {
        docker container inspect $CONTAINER_NAME *>$null
        log_info "Удаляю контейнер: $CONTAINER_NAME"
        docker stop $CONTAINER_NAME *>$null
        docker rm $CONTAINER_NAME *>$null
        log_success "Контейнер удален"
    } catch {
        # Контейнер не существует
    }
    
    # Удаляем образ
    try {
        docker image inspect $IMAGE_NAME *>$null
        log_info "Удаляю образ: $IMAGE_NAME"
        docker rmi $IMAGE_NAME *>$null
        log_success "Образ удален"
    } catch {
        # Образ не существует
    }
    
    log_success "Очистка завершена"
}

# Основная функция
function Main {
    $systemInfo = Get-SystemInfo
    Write-Host ""
    
    switch ($Action) {
        "setup" {
            Write-Host ""
            log_step "🎯 ZeroEnhanced Docker Container Setup"
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
            Write-Host ""
            
            if (-not (Test-Docker)) {
                log_error "Docker не готов к работе"
                exit 1
            }
            Write-Host ""
            
            if (-not (New-SandboxDirectory)) {
                log_error "Не удалось создать sandbox директорию"
                exit 1
            }
            Write-Host ""
            
            New-Dockerfile
            Write-Host ""
            
            if (Build-DockerImage $systemInfo) {
                Write-Host ""
                if (New-Container) {
                    Write-Host ""
                    if (Test-Container) {
                        Write-Host ""
                        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
                        log_success "🎉 Docker контейнер настроен и готов к работе!"
                        Show-ContainerInfo
                    } else {
                        log_error "Тесты контейнера провалились"
                        exit 1
                    }
                } else {
                    log_error "Не удалось настроить контейнер"
                    exit 1
                }
            } else {
                log_error "Не удалось собрать образ"
                exit 1
            }
        }
        "info" {
            $systemInfo = Get-SystemInfo
            Show-ContainerInfo
        }
        "test" {
            if (-not (Test-Container)) {
                exit 1
            }
        }
        "cleanup" {
            Remove-DockerResources
        }
        "rebuild" {
            log_step "Пересборка контейнера..."
            Remove-DockerResources
            Write-Host ""
            $Action = "setup"
            Main
        }
        default {
            log_error "Неизвестная команда: $Action"
            Write-Host "Используйте -Help для справки"
            exit 1
        }
    }
}

# Справка
if ($Help) {
    Write-Host "🐳 ZeroEnhanced Docker Container Setup"
    Write-Host "Использование: .\setup-docker.ps1 [-Action команда] [-Help]"
    Write-Host ""
    Write-Host "Команды:"
    Write-Host "  setup     - Полная настройка контейнера (по умолчанию)"
    Write-Host "  info      - Информация о контейнере"
    Write-Host "  test      - Тестирование контейнера"
    Write-Host "  cleanup   - Удаление контейнера и образа"
    Write-Host "  rebuild   - Пересборка контейнера с нуля"
    Write-Host ""
    Write-Host "Примеры:"
    Write-Host "  .\setup-docker.ps1"
    Write-Host "  .\setup-docker.ps1 -Action info"
    Write-Host "  .\setup-docker.ps1 -Action rebuild"
    exit 0
}

# Запуск
Main 