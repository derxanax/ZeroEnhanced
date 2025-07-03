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

function check_gui_dependencies() {
    log_step "Проверяю GUI зависимости..."
    
    if ! command -v node >/dev/null 2>&1; then
        log_warning "Node.js не найден, запускаю автоматическую установку..."
        "$SCRIPT_DIR/install-all-Dependencies.sh"
    fi
    
    local missing_deps=()
    
    check_command "node" "v18" || missing_deps+=("node")
    check_command "npm" "" || missing_deps+=("npm")
    check_command "tsc" "" || missing_deps+=("typescript")
    
    if ! command -v neu >/dev/null 2>&1; then
        log_warning "Neutralino CLI не найден, устанавливаю..."
        npm install -g @neutralinojs/neu
        if ! command -v neu >/dev/null 2>&1; then
            log_error "Ошибка установки Neutralino CLI"
            missing_deps+=("neutralino")
        fi
    fi
    
    if [ "$NO_DOCKER" = false ]; then
        check_docker_available || missing_deps+=("docker")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "Отсутствующие зависимости: ${missing_deps[*]}"
        log_step "Запускаю автоматическую установку..."
        
        "$SCRIPT_DIR/install-all-Dependencies.sh"
        
        log_step "Зависимости установлены, повторная проверка..."
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "node")
                    check_command "node" "v18" || { log_error "Node.js все еще недоступен"; exit 1; }
                    ;;
                "npm")
                    check_command "npm" "" || { log_error "npm все еще недоступен"; exit 1; }
                    ;;
                "typescript")
                    check_command "tsc" "" || { log_error "TypeScript все еще недоступен"; exit 1; }
                    ;;
                "neutralino")
                    command -v neu >/dev/null 2>&1 || { log_error "Neutralino все еще недоступен"; exit 1; }
                    ;;
                "docker")
                    [ "$NO_DOCKER" = false ] && { check_docker_available || { log_error "Docker все еще недоступен"; exit 1; }; }
                    ;;
            esac
        done
    fi
    
    log_success "Все GUI зависимости проверены"
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

function build_typescript_projects() {
    log_step "Собираю TypeScript проекты..."
    
    local projects=(
        ".:/Core"
        "backend:/Backend"
        "desktop/react-src:/Desktop React"
    )
    
    for project in "${projects[@]}"; do
        local path="${project%:*}"
        local name="${project#*:}"
        
        if [ -f "$path/tsconfig.json" ]; then
            cd "$path"
            log_info "Компилирую TypeScript в $name..."
            npx tsc
            log_success "$name скомпилирован"
            cd "$PROJECT_ROOT"
        fi
    done
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
    
    if [ ! -d ".tmp" ]; then
        log_info "Инициализирую Neutralino проект..."
        neu update
    fi
    
    log_success "Neutralino настроен"
    cd "$PROJECT_ROOT"
}

function start_backend() {
    log_step "Запускаю backend сервер..."
    
    cd "backend"
    
    if [ ! -f "dist/server.js" ]; then
        log_warning "Компилированный backend не найден, компилирую..."
        npx tsc
    fi
    
    log_success "Backend сервер запускается на порту 3001..."
    node dist/server.js &
    BACKEND_PID=$!
    
    sleep 2
    
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        log_error "Backend сервер не запустился"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
}

function start_neutralino_app() {
    log_step "Запускаю Neutralino desktop приложение..."
    
    cd "desktop"
    
    log_success "🖥️ Запускаю GUI приложение..."
    neu run &
    NEUTRALINO_PID=$!
    
    sleep 3
    
    if ! kill -0 "$NEUTRALINO_PID" 2>/dev/null; then
        log_error "Neutralino приложение не запустилось"
        exit 1
    fi
    
    log_success "🎉 GUI приложение запущено!"
    cd "$PROJECT_ROOT"
}

function main() {
    echo "🖥️ Запуск ZeroEnhanced GUI..."
    echo "======================================"
    
    check_gui_dependencies
    setup_docker_environment
    install_node_modules "." "Core"
    install_node_modules "backend" "Backend"
    install_node_modules "desktop/react-src" "Desktop React"
    build_typescript_projects
    build_react_app
    setup_neutralino
    start_backend
    
    echo ""
    log_success "🎉 Все компоненты готовы!"
    echo ""
    
    start_neutralino_app
    
    log_info "GUI приложение работает. Для завершения нажмите Ctrl+C"
    log_info "Backend API доступен на: http://localhost:3001"
    
    wait "$NEUTRALINO_PID"
}

if [ "$DEBUG" = true ]; then
    set -x
fi

main "$@" 