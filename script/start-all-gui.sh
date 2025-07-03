#!/bin/bash

# ZetGui Desktop GUI Starter
# Запуск десктопного приложения на базе Neutralino

set -e

NO_DOCKER=false
DEBUG=false
HELP=false

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции логирования с символами
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
    echo -e "${BLUE}Desktop GUI Application Starter${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-docker)
            NO_DOCKER=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help|-h)
            HELP=true
            shift
            ;;
        *)
            log_error "Неизвестный параметр: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
done

if [ "$HELP" = true ]; then
    show_logo
    echo -e "${YELLOW}Использование:${NC}"
    echo "  ./start-all-gui.sh              # Стандартный запуск с Docker"
    echo "  ./start-all-gui.sh --no-docker  # Запуск без Docker"
    echo "  ./start-all-gui.sh --debug      # Debug режим"
    echo "  ./start-all-gui.sh --help       # Показать справку"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
PROJECT_ROOT="$(pwd)"
ORIGINAL_DIR="$(pwd)"

source "$SCRIPT_DIR/check-dependencies.sh"

function cleanup() {
    log_step "Выполняю cleanup..."
    
    if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        log_info "Останавливаю backend сервер (PID: $BACKEND_PID)..."
        kill "$BACKEND_PID" 2>/dev/null || true
        wait "$BACKEND_PID" 2>/dev/null || true
    fi
    
    if [ -n "$NEUTRALINO_PID" ] && kill -0 "$NEUTRALINO_PID" 2>/dev/null; then
        log_info "Останавливаю Neutralino app (PID: $NEUTRALINO_PID)..."
        kill "$NEUTRALINO_PID" 2>/dev/null || true
        wait "$NEUTRALINO_PID" 2>/dev/null || true
    fi
    
    pkill -f "neutralino" 2>/dev/null || true
    pkill -f "node.*server\.js" 2>/dev/null || true
    
    cd "$ORIGINAL_DIR"
    log_success "GUI сессия завершена"
}

trap cleanup EXIT
trap cleanup SIGINT
trap cleanup SIGTERM

# Вспомогательная функция для проверки команд
check_command() {
    local cmd=$1
    local version_str=$2
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_warning "$cmd не найден."
        return 1
    fi
    log_success "$cmd найден."
    return 0
}

# Проверка зависимостей GUI
function check_gui_dependencies() {
    log_step "Проверяю GUI зависимости..."
    
    local missing_deps=()
    
    check_command "node" "v18" || missing_deps+=("node")
    check_command "npm" "" || missing_deps+=("npm")
    
    if [ "$NO_DOCKER" = false ]; then
        check_docker_available || missing_deps+=("docker")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Отсутствуют следующие зависимости: ${missing_deps[*]}"
        log_info "Пожалуйста, установите их и попробуйте снова."
        exit 1
    fi
    
    log_success "Все GUI зависимости в порядке"
}

# Функция для проверки доступности Docker
function check_docker_available() {
    log_step "Проверка доступности Docker"
    if ! command -v docker > /dev/null 2>&1; then
        log_warning "Docker не установлен."
        return 1
    fi
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker демон не запущен. Пожалуйста, запустите Docker."
        return 1
    fi
    log_success "Docker доступен и запущен."
    return 0
}

function setup_docker_environment() {
    if [ "$NO_DOCKER" = true ]; then
        log_warning "Docker отключен по параметру --no-docker"
        return 0
    fi
    
    log_step "Настраиваю Docker окружение для GUI..."
    
    if ! check_docker_running; then
        log_warning "Docker не запущен, пытаюсь настроить..."
        "$SCRIPT_DIR/setup-docker.sh"
    fi
    
    if ! check_docker_image "zet-sandbox-image:latest"; then
        log_warning "Docker образ не найден, собираю..."
        "$SCRIPT_DIR/setup-docker.sh" --rebuild
    fi
    
    if ! check_docker_container "zet-sandbox"; then
        log_warning "Контейнер не найден, создаю..."
        "$SCRIPT_DIR/setup-docker.sh"
    fi
    
    log_success "Docker окружение готово для GUI"
}

function install_node_modules() {
    local path="$1"
    local name="$2"
    
    log_step "Проверяю npm модули в $name..."
    
    if [ ! -f "$path/package.json" ]; then
        log_warning "package.json не найден в $path"
        return 0
    fi
    
    cd "$path"
    
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        log_info "Устанавливаю зависимости для $name..."
        npm install
        log_success "Зависимости $name установлены"
    else
        log_success "Зависимости $name уже установлены"
    fi
    
    cd "$PROJECT_ROOT"
}

function build_react_app() {
    log_step "Собираю React приложение..."
    
    cd "desktop/react-src"
    
    if [ ! -d "build" ] || [ ! -f "build/index.html" ]; then
        log_info "Собираю React build..."
        npm run build
        log_success "React приложение собрано"
    else
        log_success "React build уже существует"
    fi
    
    cd "$PROJECT_ROOT"
}

function setup_neutralino() {
    log_step "Настраиваю Neutralino..."
    cd "desktop"
    
    # Запускаем через npx
    if npx neu update; then
        log_success "Neutralino обновлен"
    else
        log_error "Ошибка обновления Neutralino"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
}

function start_backend() {
    log_step "Запускаю backend сервер..."
    
    cd "backend"
    
    if [ ! -f "src/server.ts" ]; then
        log_error "Не найден исходный файл backend: src/server.ts"
        exit 1
    fi
    
    local port=3001
    # Проверяем, свободен ли порт
    if lsof -i:$port >/dev/null; then
        log_error "Порт $port уже занят. Пожалуйста, освободите его и попробуйте снова."
        exit 1
    fi

    log_success "Backend сервер запускается на порту $port через ts-node..."
    
    # Передаем порт через переменную окружения
    PORT=$port npx ts-node src/server.ts &
    BACKEND_PID=$!
    
    sleep 3
    
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        log_error "Backend сервер не запустился на порту $port"
        exit 1
    fi
    
    log_success "🎉 Backend сервер запущен на порту $port!"
    cd "$PROJECT_ROOT"
}

function start_gui() {
    log_step "Запускаю Neutralino приложение..."
    cd "desktop"
    
    # Запускаем через npx
    npx neu run -- --window-enable-inspector
    
    cd "$PROJECT_ROOT"
}

# Главная функция
main() {
    trap cleanup EXIT SIGINT SIGTERM
    
    echo "🖥️ Запуск ZeroEnhanced GUI..."
    echo "======================================"
    
    check_gui_dependencies
    install_node_modules "." "Core"
    install_node_modules "backend" "Backend"
    install_node_modules "desktop/react-src" "Desktop React"
    build_react_app
    setup_neutralino
    start_backend
    
    echo ""
    log_success "🎉 Все компоненты готовы!"
    echo ""
    
    start_gui
    
    log_info "GUI приложение работает. Для завершения нажмите Ctrl+C"
    log_info "Backend API доступен на: http://localhost:3001"
    
    wait "$NEUTRALINO_PID"
}

if [ "$DEBUG" = true ]; then
    set -x
fi

main "$@" 