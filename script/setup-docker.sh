#!/bin/bash

# ZetGui Docker Setup
# Настройка Docker контейнера для песочницы

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции для красивого вывода
log_info() { echo -e "${CYAN}ℹ  $1${NC}"; }
log_success() { echo -e "${GREEN}✓  $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠  $1${NC}"; }
log_error() { echo -e "${RED}✗  $1${NC}"; }
log_step() { echo -e "${PURPLE}*  $1${NC}"; }

# Анимация загрузки
show_loading() {
    local message="$1"
    local duration=${2:-3}
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    
    for ((i=0; i<duration*10; i++)); do
        printf "\r${CYAN}${chars:i%10:1}  $message${NC}"
        sleep 0.1
    done
    printf "\r${GREEN}✓  $message${NC}\n"
}

# Красивый логотип
show_logo() {
    clear
    echo -e "${CYAN}"
    echo "██████╗ ███████╗████████╗     ██████╗ ██╗   ██╗██╗"
    echo "╚════██╗██╔════╝╚══██╔══╝    ██╔════╝ ██║   ██║██║"
    echo " █████╔╝█████╗     ██║       ██║  ███╗██║   ██║██║"
    echo "██╔═══╝ ██╔══╝     ██║       ██║   ██║██║   ██║██║"
    echo "███████╗███████╗   ██║       ╚██████╔╝╚██████╔╝██║"
    echo "╚══════╝╚══════╝   ╚═╝        ╚═════╝  ╚═════╝ ╚═╝"
    echo -e "${NC}"
    echo -e "${BLUE}Docker Setup Manager${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
}

# Константы
DOCKER_IMAGE_NAME="zet-sandbox-image"
DOCKER_CONTAINER_NAME="zet-sandbox"
DOCKERFILE_PATH="docker-sandbox/Dockerfile"

# Проверка Docker
check_docker() {
    log_step "Проверка Docker"
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker не найден в системе"
        log_info "Установите Docker: https://docs.docker.com/get-docker/"
        return 1
    fi
    
    if ! docker ps >/dev/null 2>&1; then
        log_error "Docker daemon не запущен"
        log_info "Запустите Docker daemon"
        log_info "Linux: sudo systemctl start docker"
        log_info "macOS/Windows: запустите Docker Desktop"
        return 1
    fi
    
    log_success "Docker готов к работе"
    return 0
}

# Проверка Dockerfile
check_dockerfile() {
    log_step "Проверка Dockerfile"
    
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile не найден: $DOCKERFILE_PATH"
        log_info "Создаю базовый Dockerfile"
        create_dockerfile
    else
        log_success "Dockerfile найден: $DOCKERFILE_PATH"
    fi
}

# Создание Dockerfile
create_dockerfile() {
    log_step "Создание Dockerfile"
    
    mkdir -p "$(dirname "$DOCKERFILE_PATH")"
    
    cat > "$DOCKERFILE_PATH" << 'EOF'
# ZetGui Sandbox Container
FROM ubuntu:22.04

# Установка основных пакетов
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    python3 \
    python3-pip \
    nodejs \
    npm \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Создание рабочей директории
WORKDIR /workspace

# Создание пользователя sandbox
RUN useradd -m -s /bin/bash sandbox && \
    chown -R sandbox:sandbox /workspace

USER sandbox

# Команда по умолчанию
CMD ["bash"]
EOF
    
    log_success "Dockerfile создан: $DOCKERFILE_PATH"
}

# Сборка Docker образа
build_image() {
    log_step "Сборка Docker образа"
    
    if docker images | grep -q "$DOCKER_IMAGE_NAME"; then
        log_warning "Образ $DOCKER_IMAGE_NAME уже существует"
        read -p "Пересобрать образ? (y/N): " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            log_info "Пропускаю сборку образа"
            return 0
        fi
    fi
    
    show_loading "Сборка Docker образа" 5
    
    if docker build -t "$DOCKER_IMAGE_NAME" -f "$DOCKERFILE_PATH" .; then
        log_success "Docker образ собран: $DOCKER_IMAGE_NAME"
        return 0
    else
        log_error "Ошибка сборки Docker образа"
        return 1
    fi
}

# Создание контейнера
create_container() {
    log_step "Создание Docker контейнера"
    
    if docker ps -a | grep -q "$DOCKER_CONTAINER_NAME"; then
        log_warning "Контейнер $DOCKER_CONTAINER_NAME уже существует"
        
        local status=$(docker inspect -f '{{.State.Status}}' "$DOCKER_CONTAINER_NAME" 2>/dev/null)
        case "$status" in
            "running")
                log_success "Контейнер уже запущен"
                return 0
                ;;
            "exited")
                log_info "Запускаю остановленный контейнер"
                if docker start "$DOCKER_CONTAINER_NAME"; then
                    log_success "Контейнер запущен"
                    return 0
                else
                    log_error "Не удалось запустить контейнер"
                    return 1
                fi
                ;;
            *)
                log_warning "Контейнер в состоянии: $status"
                read -p "Пересоздать контейнер? (y/N): " choice
                if [[ "$choice" =~ ^[Yy]$ ]]; then
                    log_info "Удаляю старый контейнер"
                    docker rm -f "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1
                else
                    return 0
                fi
                ;;
        esac
    fi
    
    log_info "Создаю новый контейнер"
    show_loading "Создание контейнера" 2
    
    if docker run -d \
        --name "$DOCKER_CONTAINER_NAME" \
        --network bridge \
        -v "$(pwd)/sandbox:/workspace/sandbox" \
        "$DOCKER_IMAGE_NAME" \
        tail -f /dev/null; then
        log_success "Контейнер создан и запущен: $DOCKER_CONTAINER_NAME"
        return 0
    else
        log_error "Ошибка создания контейнера"
        return 1
    fi
}

# Создание директории sandbox
create_sandbox_directory() {
    log_step "Создание директории sandbox"
    
    if [ ! -d "sandbox" ]; then
        mkdir -p sandbox
        log_success "Директория sandbox создана"
    else
        log_success "Директория sandbox уже существует"
    fi
    
    # Создаем тестовый файл
    if [ ! -f "sandbox/README.md" ]; then
        cat > "sandbox/README.md" << 'EOF'
# ZetGui Sandbox

Эта директория монтируется в Docker контейнер для безопасного выполнения кода.

## Структура
- `/workspace/sandbox/` - рабочая директория в контейнере
- Все файлы здесь доступны из контейнера

## Использование
Весь код, который выполняется через AI, будет запускаться в изолированном контейнере.
EOF
        log_success "Файл README.md создан в sandbox/"
    fi
}

# Тестирование контейнера
test_container() {
    log_step "Тестирование контейнера"
    
    show_loading "Проверка работы контейнера" 2
    
    # Тест 1: Основные команды
    if docker exec "$DOCKER_CONTAINER_NAME" echo "Hello from container" >/dev/null 2>&1; then
        log_success "Базовые команды работают"
    else
        log_error "Ошибка выполнения команд в контейнере"
        return 1
    fi
    
    # Тест 2: Python
    if docker exec "$DOCKER_CONTAINER_NAME" python3 --version >/dev/null 2>&1; then
        log_success "Python3 доступен"
    else
        log_warning "Python3 недоступен"
    fi
    
    # Тест 3: Node.js
    if docker exec "$DOCKER_CONTAINER_NAME" node --version >/dev/null 2>&1; then
        log_success "Node.js доступен"
    else
        log_warning "Node.js недоступен"
    fi
    
    # Тест 4: Монтирование
    local test_file="sandbox/docker_test_$(date +%s).txt"
    echo "Test content" > "$test_file"
    
    if docker exec "$DOCKER_CONTAINER_NAME" cat "/workspace/$(basename "$test_file")" >/dev/null 2>&1; then
        log_success "Монтирование работает"
        rm -f "$test_file"
    else
        log_error "Ошибка монтирования директории"
        rm -f "$test_file"
        return 1
    fi
    
    return 0
}

# Показать информацию о контейнере
show_container_info() {
    log_step "Информация о контейнере"
    echo
    
    local image_size=$(docker images --format "table {{.Size}}" --filter "reference=$DOCKER_IMAGE_NAME" | tail -n 1)
    log_info "Образ: $DOCKER_IMAGE_NAME ($image_size)"
    
    local container_status=$(docker inspect -f '{{.State.Status}}' "$DOCKER_CONTAINER_NAME" 2>/dev/null)
    log_info "Контейнер: $DOCKER_CONTAINER_NAME ($container_status)"
    
    local sandbox_path=$(realpath sandbox 2>/dev/null)
    log_info "Sandbox: $sandbox_path"
    
    echo
    log_info "Команды для работы:"
    echo -e "  ${BLUE}Войти в контейнер:${NC} docker exec -it $DOCKER_CONTAINER_NAME bash"
    echo -e "  ${BLUE}Остановить:${NC} docker stop $DOCKER_CONTAINER_NAME"
    echo -e "  ${BLUE}Запустить:${NC} docker start $DOCKER_CONTAINER_NAME"
    echo -e "  ${BLUE}Удалить:${NC} docker rm -f $DOCKER_CONTAINER_NAME"
}

# Главная функция
main() {
    show_logo
    
    log_info "Начинаю настройку Docker окружения"
    echo
    
    # Проверки
    if ! check_docker; then
        exit 1
    fi
    echo
    
    check_dockerfile
    echo
    
    # Сборка и создание
    if ! build_image; then
        exit 1
    fi
    echo
    
    create_sandbox_directory
    echo
    
    if ! create_container; then
        exit 1
    fi
    echo
    
    # Тестирование
    if ! test_container; then
        log_warning "Некоторые тесты не прошли, но контейнер создан"
    else
        log_success "Все тесты пройдены успешно"
    fi
    echo
    
    show_container_info
    echo
    
    log_success "Docker окружение готово к работе!"
}

# Проверка директории
check_directory() {
    if [ ! -f "package.json" ]; then
        log_error "Скрипт должен запускаться из корневой директории проекта"
        log_info "Перейдите в директорию с package.json"
        exit 1
    fi
}

# Обработка аргументов
case "${1:-}" in
    --rebuild|-r)
        log_info "Режим пересборки образа"
        docker rmi -f "$DOCKER_IMAGE_NAME" 2>/dev/null || true
        ;;
    --clean|-c)
        log_info "Очистка Docker ресурсов"
        docker rm -f "$DOCKER_CONTAINER_NAME" 2>/dev/null || true
        docker rmi -f "$DOCKER_IMAGE_NAME" 2>/dev/null || true
        log_success "Очистка завершена"
        exit 0
        ;;
    --help|-h)
        echo "Использование: $0 [опции]"
        echo "Опции:"
        echo "  --rebuild, -r    Пересобрать Docker образ"
        echo "  --clean, -c      Удалить контейнер и образ"
        echo "  --help, -h       Показать эту справку"
        exit 0
        ;;
esac

# Обработка Ctrl+C
trap 'echo; log_info "Прерывание настройки"; exit 0' INT

# Запуск
check_directory
main "$@" 