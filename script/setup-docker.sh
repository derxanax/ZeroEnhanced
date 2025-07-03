#!/bin/bash

# ZetGui Smart Docker Setup
# Гарантированная пересборка окружения с фиксом для SELinux

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
    echo -e "${BLUE}Smart Docker Setup${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
}

# Переходим в корневую директорию проекта
cd "$(dirname "$0")/.."

# Константы
DOCKER_IMAGE_NAME="zet-sandbox-image:latest"
DOCKER_CONTAINER_NAME="zet-sandbox"
DOCKERFILE_PATH="docker-sandbox/Dockerfile"

# Проверка Docker
check_docker() {
    log_step "Проверка Docker"
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен."
        return 1
    fi
    if ! docker info &> /dev/null; then
        log_error "Docker daemon не запущен. Запустите Docker Desktop или выполните 'sudo systemctl start docker'."
        return 1
    fi
    log_success "Docker готов к работе"
    return 0
}

# Создание Dockerfile
create_dockerfile() {
    log_step "Создание простого Dockerfile"
    mkdir -p "$(dirname "$DOCKERFILE_PATH")"
    cat > "$DOCKERFILE_PATH" << 'EOF'
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl git sudo && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
CMD ["/bin/bash"]
EOF
    log_success "Простой Dockerfile создан: $DOCKERFILE_PATH"
}

# Сборка Docker образа
build_image() {
    log_step "Сборка Docker образа (флаг --no-cache)"
    if docker build --no-cache -t "$DOCKER_IMAGE_NAME" -f "$DOCKERFILE_PATH" .; then
        log_success "Docker образ собран: $DOCKER_IMAGE_NAME"
        return 0
    else
        log_error "Ошибка сборки Docker образа"
        return 1
    fi
}

# Создание директории sandbox
create_sandbox_directory() {
    log_step "Подготовка директории sandbox"
    if [ ! -d "sandbox" ]; then
        mkdir -p sandbox
        log_info "Директория sandbox создана"
    fi
    if [ ! -f "sandbox/README.md" ]; then
        echo "# Sandbox" > sandbox/README.md
        echo "This directory is mounted into the container at /workspace" >> sandbox/README.md
    fi
    log_success "Директория sandbox готова"
}

# Применение SELinux контекста
handle_selinux() {
    if command -v sestatus &> /dev/null && sestatus | grep -q "SELinux status:[[:space:]]*enabled"; then
        log_step "Обнаружен SELinux. Применяю контекст безопасности..."
        if ! chcon -Rt container_file_t sandbox; then
            log_warning "Не удалось применить 'chcon'. Попробую с 'sudo'."
            if ! sudo chcon -Rt container_file_t sandbox; then
                log_error "Не удалось применить SELinux контекст даже с sudo."
                log_info "Возможно, потребуется выполнить 'sudo chcon -Rt container_file_t sandbox' вручную."
                return 1
            fi
        fi
        log_success "SELinux контекст 'container_file_t' применен к директории 'sandbox'."
    fi
    return 0
}

# Пересоздание контейнера
recreate_container() {
    log_step "Пересоздание Docker контейнера"
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER_NAME}$"; then
        log_warning "Контейнер $DOCKER_CONTAINER_NAME уже существует. Принудительно удаляю..."
        if ! docker rm -f "$DOCKER_CONTAINER_NAME"; then
            log_error "Не удалось удалить старый контейнер. Попробую с sudo."
            sudo docker rm -f "$DOCKER_CONTAINER_NAME"
        fi
        log_success "Старый контейнер удален"
    fi
    
    log_info "Создаю новый контейнер..."
    
    if ! docker run -d --name "$DOCKER_CONTAINER_NAME" -v "$(pwd)/sandbox:/workspace:z" -it "$DOCKER_IMAGE_NAME" /bin/bash; then
        log_error "Ошибка создания контейнера"
        return 1
    fi
    
    log_success "Контейнер создан и запущен: $DOCKER_CONTAINER_NAME"
    return 0
}

# Главная функция
main() {
    show_logo
    log_info "Начинаю полную пересборку Docker окружения"
    echo
    
    if ! check_docker; then exit 1; fi
    echo

    create_dockerfile
    echo
    
    if ! build_image; then exit 1; fi
    echo
    
    create_sandbox_directory
    echo
    
    if ! handle_selinux; then 
        log_warning "Продолжаю без настройки SELinux, но могут быть проблемы с доступом."
    fi
    echo
    
    if ! recreate_container; then exit 1; fi
    echo

    log_success "Docker окружение полностью пересобрано и готово к работе!"
    echo
    log_info "Для входа в контейнер: docker exec -it zet-sandbox bash"
    log_info "После этого команда 'ls' в контейнере должна работать."
}

# Запуск
main "$@" 