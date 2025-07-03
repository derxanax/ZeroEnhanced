#!/bin/bash

# ZetGui CLI Launcher
# Запуск консольной версии AI Terminal

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
    echo -e "${BLUE}CLI Terminal Launcher${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
}

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
    
    # Проверка TypeScript
    if ! command -v tsc >/dev/null 2>&1; then
        log_warning "TypeScript не найден глобально"
        log_info "Попробую установить: npm install -g typescript"
        if ! npm install -g typescript; then
            log_error "Не удалось установить TypeScript"
            return 1
        fi
    fi
    
    # Проверка зависимостей проекта
    if [ ! -d "node_modules" ]; then
        log_warning "Зависимости проекта не установлены"
        log_info "Запускаю установку: npm install"
        if ! npm install; then
            log_error "Не удалось установить зависимости"
            return 1
        fi
    fi
    
    log_success "Все зависимости в порядке"
    return 0
}

# Сборка проекта
build_project() {
    log_step "Сборка проекта"
    
    show_loading "Компиляция TypeScript" 2
    
    if [ -f "tsconfig.json" ]; then
        if tsc; then
            log_success "Проект собран успешно"
            return 0
        else
            log_error "Ошибка сборки проекта"
            return 1
        fi
    else
        log_warning "tsconfig.json не найден - пропускаю сборку"
        return 0
    fi
}

# Запуск CLI приложения
start_cli() {
    log_step "Запуск CLI терминала"
    
    # Проверяем наличие скомпилированных файлов
    if [ -f "dist/main.js" ]; then
        log_info "Запускаю скомпилированную версию"
        show_loading "Инициализация терминала" 1
        echo
        log_success "Zet CLI готов к работе!"
        echo
        node dist/main.js
    elif [ -f "src/main.ts" ]; then
        log_info "Запускаю через ts-node"
        
        # Проверяем ts-node
        if ! command -v ts-node >/dev/null 2>&1; then
            log_warning "ts-node не найден, устанавливаю"
            if ! npm install -g ts-node; then
                log_error "Не удалось установить ts-node"
                return 1
            fi
        fi
        
        show_loading "Инициализация терминала" 1
        echo
        log_success "Zet CLI готов к работе!"
        echo
        ts-node src/main.ts
    else
        log_error "Не найден main.js или main.ts файл"
        log_info "Проверьте структуру проекта"
        return 1
    fi
}

# Проверка окружения
check_environment() {
    log_step "Проверка окружения"
    
    # Проверка конфигурации
    if [ -f "Prod.json" ]; then
        local config=$(cat Prod.json 2>/dev/null)
        local prod_mode=$(echo "$config" | grep -o '"prod"[[:space:]]*:[[:space:]]*[^,}]*' | sed 's/.*:[[:space:]]*//')
        
        if [ "$prod_mode" = "true" ]; then
            log_info "Режим: Production"
        else
            log_info "Режим: Development"
        fi
    else
        log_warning "Конфигурация Prod.json не найдена"
    fi
    
    # Проверка серверов
    if [ -f "Prod.json" ]; then
        local domain=$(echo "$config" | grep -o '"domain"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
        if [ ! -z "$domain" ]; then
            log_info "API сервер: $domain"
        fi
    fi
    
    log_success "Окружение проверено"
}

# Главная функция
main() {
    show_logo
    
    log_info "Инициализация CLI терминала"
    echo
    
    # Проверки
    if ! check_dependencies; then
        log_error "Не удалось проверить зависимости"
        exit 1
    fi
    echo
    
    if ! build_project; then
        log_error "Не удалось собрать проект"
        exit 1
    fi
    echo
    
    check_environment
    echo
    
    # Запуск
    log_info "Все проверки пройдены, запускаю CLI"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
    
    start_cli
}

# Проверка директории
check_directory() {
    if [ ! -f "package.json" ] && [ ! -d "src" ]; then
        log_error "Скрипт должен запускаться из корневой директории проекта"
        log_info "Перейдите в директорию с package.json и src/"
        exit 1
    fi
}

# Обработка сигналов
cleanup() {
    echo
    log_info "Завершение работы CLI"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Запуск
check_directory
main "$@" 