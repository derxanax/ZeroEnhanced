#!/bin/bash

# ZetGui Web Launcher
# Запуск веб-версии приложения

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
    echo -e "${BLUE}Web Application Launcher${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
}

# Переменные для процессов
BACKEND_PID=""
FRONTEND_PID=""

# Порты
BACKEND_PORT=3001
FRONTEND_PORT=3000

# Проверка зависимостей
function check_web_dependencies() {
    log_step "Проверяю Web зависимости..."
    
    if ! command -v node >/dev/null 2>&1; then
        log_warning "Node.js не найден."
        return 1
    fi
    log_success "Node.js найден."

    if ! command -v npm >/dev/null 2>&1; then
        log_warning "npm не найден."
        return 1
    fi
    log_success "npm найден."

    if [ "$NO_DOCKER" = false ]; then
        if ! command -v docker > /dev/null 2>&1 || ! docker info > /dev/null 2>&1; then
            log_warning "Docker не найден или не запущен. Функциональность AI будет ограничена."
        else
            log_success "Docker найден и запущен."
        fi
    fi

    log_success "Все зависимости в порядке"
    return 0
}

# Проверка портов
check_ports() {
    log_step "Проверка портов"
    
    # Проверка backend порта
    if lsof -Pi :$BACKEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "Порт $BACKEND_PORT уже занят"
        local pid=$(lsof -ti:$BACKEND_PORT)
        log_info "Процесс на порту $BACKEND_PORT: PID $pid"
        
        read -p "Завершить процесс и продолжить? (y/N): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            kill $pid 2>/dev/null || true
            sleep 2
        else
            log_error "Не могу запустить backend на занятом порту"
            return 1
        fi
    fi
    
    # Проверка frontend порта
    if lsof -Pi :$FRONTEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "Порт $FRONTEND_PORT уже занят"
        local pid=$(lsof -ti:$FRONTEND_PORT)
        log_info "Процесс на порту $FRONTEND_PORT: PID $pid"
        
        read -p "Завершить процесс и продолжить? (y/N): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            kill $pid 2>/dev/null || true
            sleep 2
        else
            log_error "Не могу запустить frontend на занятом порту"
            return 1
        fi
    fi
    
    log_success "Порты свободны"
    return 0
}

# Сборка backend
build_backend() {
    log_step "Сборка backend"
    
    if [ ! -f "backend/tsconfig.json" ]; then
        log_warning "Backend tsconfig.json не найден"
        return 0
    fi
    
    cd backend
    
    show_loading "Компиляция backend TypeScript" 3
    
    if npm run build 2>/dev/null || tsc 2>/dev/null; then
        log_success "Backend собран успешно"
        cd ..
        return 0
    else
        log_warning "Ошибка сборки backend, попробую запустить через ts-node"
        cd ..
        return 0
    fi
}

# Сборка frontend
build_frontend() {
    log_step "Сборка frontend"
    
    cd desktop/react-src
    
    if [ ! -f "package.json" ]; then
        log_error "Frontend package.json не найден"
        cd ../..
        return 1
    fi
    
    show_loading "Сборка React приложения" 5
    
    if npm run build 2>/dev/null; then
        log_success "Frontend собран успешно"
        cd ../..
        return 0
    else
        log_warning "Ошибка сборки frontend, запущу в dev режиме"
        cd ../..
        return 0
    fi
}

# Запуск backend
function start_backend() {
    log_step "Запускаю backend сервер..."
    cd "backend"
    local port=3001
    if lsof -i:$port >/dev/null; then
        log_error "Порт $port уже занят. Освободите его."
        exit 1
    fi
    log_success "Backend запускается на порту $port..."
    PORT=$port npx ts-node src/server.ts &
    BACKEND_PID=$!
    cd ..
    sleep 3
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        log_error "Backend не запустился."
        exit 1
    fi
    log_success "🎉 Backend сервер запущен на порту $port!"
}

# Запуск frontend
function start_frontend_dev_server() {
    log_step "Запускаю frontend dev сервер..."
    cd "desktop/react-src"
    log_info "Frontend запускается на порту 3002..."
    npm start &
    FRONTEND_PID=$!
    cd ..
}

# Открытие браузера
open_browser() {
    log_step "Открытие браузера"
    
    local url="http://localhost:$FRONTEND_PORT"
    
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1
        log_success "Браузер открыт: $url"
    elif command -v open >/dev/null 2>&1; then
        open "$url" >/dev/null 2>&1
        log_success "Браузер открыт: $url"
    else
        log_info "Откройте браузер вручную: $url"
    fi
}

# Показать информацию о запущенных сервисах
show_status() {
    log_step "Информация о запущенных сервисах"
    echo
    
    log_info "Backend сервер:"
    echo -e "  ${BLUE}URL:${NC} http://localhost:$BACKEND_PORT"
    echo -e "  ${BLUE}PID:${NC} $BACKEND_PID"
    echo -e "  ${BLUE}Лог:${NC} backend.log"
    
    echo
    log_info "Frontend сервер:"
    echo -e "  ${BLUE}URL:${NC} http://localhost:$FRONTEND_PORT"
    echo -e "  ${BLUE}PID:${NC} $FRONTEND_PID"
    echo -e "  ${BLUE}Лог:${NC} frontend.log"
    
    echo
    log_info "Управление:"
    echo -e "  ${BLUE}Остановить все:${NC} Ctrl+C"
    echo -e "  ${BLUE}Логи backend:${NC} tail -f backend.log"
    echo -e "  ${BLUE}Логи frontend:${NC} tail -f frontend.log"
}

# Cleanup функция
cleanup() {
    echo
    log_step "Завершение работы серверов"
    
    if [ ! -z "$BACKEND_PID" ]; then
        log_info "Останавливаю backend (PID: $BACKEND_PID)"
        kill $BACKEND_PID 2>/dev/null || true
        wait $BACKEND_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$FRONTEND_PID" ]; then
        log_info "Останавливаю frontend (PID: $FRONTEND_PID)"
        kill $FRONTEND_PID 2>/dev/null || true
        wait $FRONTEND_PID 2>/dev/null || true
    fi
    
    # Дополнительная очистка портов
    local backend_pids=$(lsof -ti:$BACKEND_PORT 2>/dev/null || true)
    local frontend_pids=$(lsof -ti:$FRONTEND_PORT 2>/dev/null || true)
    
    if [ ! -z "$backend_pids" ]; then
        log_info "Принудительно завершаю процессы на порту $BACKEND_PORT"
        kill $backend_pids 2>/dev/null || true
    fi
    
    if [ ! -z "$frontend_pids" ]; then
        log_info "Принудительно завершаю процессы на порту $FRONTEND_PORT"
        kill $frontend_pids 2>/dev/null || true
    fi
    
    log_success "Веб-серверы остановлены"
    exit 0
}

# Главная функция
main() {
    trap cleanup EXIT SIGINT SIGTERM
    
    show_logo
    log_info "Запуск веб-версии ZetGui"
    echo ""
    
    # Проверки
    if ! check_web_dependencies; then
        exit 1
    fi

    # Установка зависимостей
    install_node_modules "." "Core"
    install_node_modules "backend" "Backend"
    install_node_modules "desktop/react-src" "Frontend"
    
    start_backend
    start_frontend_dev_server
    
    log_info "Веб-сервер и backend запущены."
    log_info "Нажмите Ctrl+C для завершения."
    
    wait
}

# Проверка директории
check_directory() {
    if [ ! -f "package.json" ] || [ ! -d "backend" ] || [ ! -d "desktop/react-src" ]; then
        log_error "Скрипт должен запускаться из корневой директории проекта"
        log_info "Убедитесь что существуют директории backend/ и desktop/react-src/"
        exit 1
    fi
}

# Установка trap для cleanup
trap cleanup SIGINT SIGTERM

# Запуск
check_directory
main "$@" 