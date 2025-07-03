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
check_dependencies() {
    log_step "Проверка зависимостей"
    
    # Проверка Node.js
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js не найден"
        log_info "Установите Node.js: https://nodejs.org/"
        return 1
    fi
    
    # Проверка npm
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm не найден"
        return 1
    fi
    
    # Проверка зависимостей backend
    if [ ! -d "backend/node_modules" ]; then
        log_warning "Backend зависимости не установлены"
        log_info "Устанавливаю backend зависимости"
        cd backend && npm install && cd ..
    fi
    
    # Проверка зависимостей frontend
    if [ ! -d "desktop/react-src/node_modules" ]; then
        log_warning "Frontend зависимости не установлены"
        log_info "Устанавливаю frontend зависимости"
        cd desktop/react-src && npm install && cd ../..
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
start_backend() {
    log_step "Запуск backend сервера"
    
    cd backend
    
    # Проверяем наличие собранного файла
    if [ -f "dist/server.js" ]; then
        log_info "Запускаю собранный backend"
        node dist/server.js > ../backend.log 2>&1 &
        BACKEND_PID=$!
    elif [ -f "src/server.ts" ]; then
        log_info "Запускаю backend через ts-node"
        if command -v ts-node >/dev/null 2>&1; then
            ts-node src/server.ts > ../backend.log 2>&1 &
            BACKEND_PID=$!
        else
            npx ts-node src/server.ts > ../backend.log 2>&1 &
            BACKEND_PID=$!
        fi
    else
        log_error "Не найден файл сервера backend"
        cd ..
        return 1
    fi
    
    cd ..
    
    # Ждем запуска backend
    show_loading "Ожидание запуска backend" 3
    
    for i in {1..10}; do
        if curl -s http://localhost:$BACKEND_PORT/health >/dev/null 2>&1; then
            log_success "Backend запущен на порту $BACKEND_PORT (PID: $BACKEND_PID)"
            return 0
        fi
        sleep 1
    done
    
    log_error "Backend не запустился за 10 секунд"
    return 1
}

# Запуск frontend
start_frontend() {
    log_step "Запуск frontend сервера"
    
    cd desktop/react-src
    
    # Проверяем наличие собранного приложения
    if [ -d "build" ] || [ -d "dist" ]; then
        log_info "Запускаю статический сервер для собранного приложения"
        
        # Используем serve для статических файлов
        if command -v serve >/dev/null 2>&1; then
            serve -s build -l $FRONTEND_PORT > ../../frontend.log 2>&1 &
            FRONTEND_PID=$!
        else
            log_info "Устанавливаю serve для статических файлов"
            npm install -g serve >/dev/null 2>&1
            serve -s build -l $FRONTEND_PORT > ../../frontend.log 2>&1 &
            FRONTEND_PID=$!
        fi
    else
        log_info "Запускаю frontend в dev режиме"
        npm start > ../../frontend.log 2>&1 &
        FRONTEND_PID=$!
    fi
    
    cd ../..
    
    # Ждем запуска frontend
    show_loading "Ожидание запуска frontend" 5
    
    for i in {1..20}; do
        if curl -s http://localhost:$FRONTEND_PORT >/dev/null 2>&1; then
            log_success "Frontend запущен на порту $FRONTEND_PORT (PID: $FRONTEND_PID)"
            return 0
        fi
        sleep 1
    done
    
    log_error "Frontend не запустился за 20 секунд"
    return 1
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
    show_logo
    
    log_info "Запуск веб-версии ZetGui"
    echo
    
    # Проверки
    if ! check_dependencies; then
        exit 1
    fi
    echo
    
    if ! check_ports; then
        exit 1
    fi
    echo
    
    # Сборка
    build_backend
    echo
    
    build_frontend
    echo
    
    # Запуск серверов
    if ! start_backend; then
        log_error "Не удалось запустить backend"
        exit 1
    fi
    echo
    
    if ! start_frontend; then
        log_error "Не удалось запустить frontend"
        cleanup
        exit 1
    fi
    echo
    
    # Открытие браузера
    sleep 2
    open_browser
    echo
    
    # Показ статуса
    show_status
    echo
    
    log_success "Все сервисы запущены!"
    log_info "Нажмите Ctrl+C для остановки всех сервисов"
    
    # Ожидание завершения
    while true; do
        sleep 1
        
        # Проверяем что процессы еще живы
        if [ ! -z "$BACKEND_PID" ] && ! kill -0 $BACKEND_PID 2>/dev/null; then
            log_error "Backend процесс завершился неожиданно"
            break
        fi
        
        if [ ! -z "$FRONTEND_PID" ] && ! kill -0 $FRONTEND_PID 2>/dev/null; then
            log_error "Frontend процесс завершился неожиданно"
            break
        fi
    done
    
    cleanup
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