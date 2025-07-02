#!/bin/bash

# 🐳 ZeroEnhanced Docker Setup Script
# Автоматическая настройка Docker образа и контейнера

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функции для красивого вывода
log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${PURPLE}🔥 $1${NC}"; }

# Константы
DOCKER_IMAGE_NAME="zet-sandbox-image"
SANDBOX_CONTAINER_NAME="zet-sandbox"
DOCKERFILE_PATH="./docker-sandbox/Dockerfile"
SANDBOX_DIR="./sandbox"

# Переходим в корневую директорию проекта
cd "$(dirname "$0")/.."

# Проверка Docker
check_docker() {
    log_step "Проверка Docker..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен!"
        log_info "Установите Docker: ./script/install-system-packages.sh"
        exit 1
    fi
    
    if ! docker ps &> /dev/null; then
        log_error "Docker daemon не запущен!"
        log_info "Запустите Docker: sudo systemctl start docker"
        exit 1
    fi
    
    log_success "Docker готов к работе"
}

# Проверка существования образа
check_image_exists() {
    docker image inspect "$DOCKER_IMAGE_NAME:latest" &> /dev/null
}

# Проверка существования контейнера
check_container_exists() {
    docker container inspect "$SANDBOX_CONTAINER_NAME" &> /dev/null
}

# Проверка что контейнер запущен
check_container_running() {
    local status=$(docker inspect -f '{{.State.Running}}' "$SANDBOX_CONTAINER_NAME" 2>/dev/null)
    [ "$status" = "true" ]
}

# Создание sandbox директории
create_sandbox_dir() {
    log_step "Создание sandbox директории..."
    
    if [ ! -d "$SANDBOX_DIR" ]; then
        mkdir -p "$SANDBOX_DIR"
        log_success "Директория $SANDBOX_DIR создана"
    else
        log_info "Директория $SANDBOX_DIR уже существует"
    fi
    
    # Создаем тестовый файл
    if [ ! -f "$SANDBOX_DIR/README.md" ]; then
        cat > "$SANDBOX_DIR/README.md" << 'EOF'
# ZetGui Sandbox

Эта директория монтируется в Docker контейнер как `/workspace`.

Здесь вы можете:
- Создавать и редактировать файлы через AI
- Выполнять команды в безопасной среде
- Тестировать код без риска для основной системы

## Структура

```
sandbox/
├── README.md     # Этот файл
├── projects/     # Ваши проекты (создается автоматически)
└── temp/         # Временные файлы
```

Все файлы здесь доступны в контейнере по пути `/workspace/`.
EOF
        
        mkdir -p "$SANDBOX_DIR/projects"
        mkdir -p "$SANDBOX_DIR/temp"
        log_success "Создан базовый README и структура директорий"
    fi
}

# Сборка Docker образа
build_docker_image() {
    log_step "Сборка Docker образа..."
    
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile не найден: $DOCKERFILE_PATH"
        exit 1
    fi
    
    log_info "Собираю образ $DOCKER_IMAGE_NAME:latest..."
    if docker build -t "$DOCKER_IMAGE_NAME:latest" -f "$DOCKERFILE_PATH" "./docker-sandbox/" --no-cache; then
        log_success "Образ $DOCKER_IMAGE_NAME:latest собран успешно"
    else
        log_error "Ошибка сборки Docker образа"
        exit 1
    fi
}

# Создание и запуск контейнера
create_container() {
    log_step "Создание Docker контейнера..."
    
    # Останавливаем и удаляем существующий контейнер если есть
    if check_container_exists; then
        log_info "Останавливаю существующий контейнер..."
        docker stop "$SANDBOX_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$SANDBOX_CONTAINER_NAME" 2>/dev/null || true
    fi
    
    # Создаем новый контейнер
    log_info "Создаю новый контейнер $SANDBOX_CONTAINER_NAME..."
    
    local absolute_sandbox_path=$(realpath "$SANDBOX_DIR")
    
    if docker create \
        --name "$SANDBOX_CONTAINER_NAME" \
        --tty \
        --interactive \
        --workdir "/workspace" \
        --volume "$absolute_sandbox_path:/workspace:Z" \
        "$DOCKER_IMAGE_NAME:latest" \
        /bin/bash; then
        log_success "Контейнер $SANDBOX_CONTAINER_NAME создан"
    else
        log_error "Ошибка создания контейнера"
        exit 1
    fi
}

# Запуск контейнера
start_container() {
    log_step "Запуск контейнера..."
    
    if check_container_running; then
        log_info "Контейнер уже запущен"
        return 0
    fi
    
    if docker start "$SANDBOX_CONTAINER_NAME"; then
        log_success "Контейнер $SANDBOX_CONTAINER_NAME запущен"
    else
        log_error "Ошибка запуска контейнера"
        exit 1
    fi
}

# Тестирование контейнера
test_container() {
    log_step "Тестирование контейнера..."
    
    # Тест 1: Проверка что контейнер запущен
    if ! check_container_running; then
        log_error "Контейнер не запущен"
        return 1
    fi
    
    # Тест 2: Выполнение простой команды
    log_info "Выполняю тестовую команду..."
    if docker exec "$SANDBOX_CONTAINER_NAME" echo "Hello from ZetGui sandbox!" > /dev/null; then
        log_success "Тестовая команда выполнена успешно"
    else
        log_error "Ошибка выполнения команды в контейнере"
        return 1
    fi
    
    # Тест 3: Проверка монтирования директории
    log_info "Проверяю монтирование sandbox директории..."
    if docker exec "$SANDBOX_CONTAINER_NAME" ls -la /workspace/README.md > /dev/null; then
        log_success "Sandbox директория смонтирована корректно"
    else
        log_error "Проблема с монтированием sandbox директории"
        return 1
    fi
    
    # Тест 4: Проверка установленных пакетов
    log_info "Проверяю установленные пакеты в контейнере..."
    if docker exec "$SANDBOX_CONTAINER_NAME" which curl > /dev/null && \
       docker exec "$SANDBOX_CONTAINER_NAME" which git > /dev/null && \
       docker exec "$SANDBOX_CONTAINER_NAME" which nano > /dev/null; then
        log_success "Все необходимые пакеты установлены"
    else
        log_warning "Некоторые пакеты могут отсутствовать в контейнере"
    fi
    
    log_success "Все тесты пройдены успешно!"
    return 0
}

# Показать информацию о контейнере
show_container_info() {
    log_step "Информация о контейнере..."
    
    echo -e "${CYAN}📊 Статус Docker окружения:${NC}"
    echo -e "${BLUE}  • Образ:     ${DOCKER_IMAGE_NAME}:latest${NC}"
    echo -e "${BLUE}  • Контейнер: ${SANDBOX_CONTAINER_NAME}${NC}"
    echo -e "${BLUE}  • Sandbox:   ${SANDBOX_DIR} → /workspace${NC}"
    
    if check_image_exists; then
        echo -e "${GREEN}  ✅ Образ существует${NC}"
    else
        echo -e "${RED}  ❌ Образ не найден${NC}"
    fi
    
    if check_container_exists; then
        if check_container_running; then
            echo -e "${GREEN}  ✅ Контейнер запущен${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Контейнер остановлен${NC}"
        fi
    else
        echo -e "${RED}  ❌ Контейнер не создан${NC}"
    fi
}

# Очистка (удаление контейнера и образа)
cleanup_docker() {
    log_step "Очистка Docker ресурсов..."
    
    # Останавливаем и удаляем контейнер
    if check_container_exists; then
        log_info "Удаляю контейнер $SANDBOX_CONTAINER_NAME..."
        docker stop "$SANDBOX_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$SANDBOX_CONTAINER_NAME" 2>/dev/null || true
        log_success "Контейнер удален"
    fi
    
    # Удаляем образ
    if check_image_exists; then
        log_info "Удаляю образ $DOCKER_IMAGE_NAME:latest..."
        docker rmi "$DOCKER_IMAGE_NAME:latest" 2>/dev/null || true
        log_success "Образ удален"
    fi
    
    log_success "Очистка завершена"
}

# Полная настройка
full_setup() {
    log_step "🎯 Полная настройка Docker окружения"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    check_docker
    create_sandbox_dir
    
    # Сборка образа (если не существует или forced rebuild)
    if ! check_image_exists || [ "$1" = "--rebuild" ]; then
        build_docker_image
    else
        log_info "Образ $DOCKER_IMAGE_NAME:latest уже существует"
    fi
    
    # Создание контейнера (если не существует)
    if ! check_container_exists; then
        create_container
    else
        log_info "Контейнер $SANDBOX_CONTAINER_NAME уже существует"
    fi
    
    start_container
    
    if test_container; then
        echo
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log_success "🎉 Docker окружение готово к работе!"
        show_container_info
        echo
        log_info "📋 Команды для управления:"
        log_info "   Проверка статуса: ./script/setup-docker.sh --status"
        log_info "   Перезапуск:       ./script/setup-docker.sh --restart"
        log_info "   Очистка:          ./script/setup-docker.sh --cleanup"
        echo
    else
        log_error "❌ Настройка завершилась с ошибками"
        exit 1
    fi
}

# Основная функция с параметрами
main() {
    case "${1:-setup}" in
        "setup"|"--setup")
            full_setup "$2"
            ;;
        "--rebuild")
            full_setup "--rebuild"
            ;;
        "--status")
            show_container_info
            ;;
        "--start")
            check_docker
            start_container
            ;;
        "--restart")
            check_docker
            if check_container_exists; then
                docker restart "$SANDBOX_CONTAINER_NAME"
                log_success "Контейнер перезапущен"
            else
                log_error "Контейнер не существует"
                exit 1
            fi
            ;;
        "--test")
            check_docker
            test_container
            ;;
        "--cleanup")
            cleanup_docker
            ;;
        "--help"|"-h")
            echo "🐳 ZeroEnhanced Docker Setup"
            echo "Использование: $0 [команда]"
            echo ""
            echo "Команды:"
            echo "  setup     - Полная настройка (по умолчанию)"
            echo "  --rebuild - Пересборка образа и контейнера"
            echo "  --status  - Показать статус"
            echo "  --start   - Запустить контейнер"
            echo "  --restart - Перезапустить контейнер"
            echo "  --test    - Протестировать контейнер"
            echo "  --cleanup - Удалить контейнер и образ"
            echo "  --help    - Показать эту справку"
            ;;
        *)
            log_error "Неизвестная команда: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
}

# Запуск
main "$@" 