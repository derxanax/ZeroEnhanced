#!/bin/bash

# ZetGui Dependencies Installer
# Полная установка всех необходимых зависимостей

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
    echo -e "${BLUE}Dependencies Installer${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
}

# Проверка Node.js
check_nodejs() {
    log_step "Проверка Node.js"
    
    if command -v node >/dev/null 2>&1; then
        local version=$(node --version)
        log_success "Node.js найден: $version"
        return 0
    else
        log_error "Node.js не найден"
        return 1
    fi
}

# Проверка npm
check_npm() {
    log_step "Проверка npm"
    
    if command -v npm >/dev/null 2>&1; then
        local version=$(npm --version)
        log_success "npm найден: v$version"
        return 0
    else
        log_error "npm не найден"
        return 1
    fi
}

# Установка зависимостей для основного проекта
install_main_dependencies() {
    log_step "Установка зависимостей основного проекта"
    
    if [ ! -f "package.json" ]; then
        log_error "package.json не найден в корневой директории"
        return 1
    fi
    
    show_loading "Загрузка npm зависимостей" 3
    
    if npm install; then
        log_success "Зависимости основного проекта установлены"
    else
        log_error "Ошибка установки зависимостей основного проекта"
        return 1
    fi
}

# Установка зависимостей для backend
install_backend_dependencies() {
    log_step "Установка зависимостей backend"
    
    if [ -d "backend" ] && [ -f "backend/package.json" ]; then
        cd backend || return 1
        
        show_loading "Установка backend зависимостей" 2
        
        if npm install; then
            log_success "Backend зависимости установлены"
            cd ..
        else
            log_error "Ошибка установки backend зависимостей"
            cd ..
            return 1
        fi
    else
        log_warning "Backend директория или package.json не найдены - пропускаю"
    fi
}

# Установка зависимостей для desktop
install_desktop_dependencies() {
    log_step "Установка зависимостей desktop"
    
    if [ -d "desktop/react-src" ] && [ -f "desktop/react-src/package.json" ]; then
        cd desktop/react-src || return 1
        
        show_loading "Установка desktop зависимостей" 2
        
        if npm install; then
            log_success "Desktop зависимости установлены"
            cd ../..
        else
            log_error "Ошибка установки desktop зависимостей"
            cd ../..
            return 1
        fi
    else
        log_warning "Desktop директория или package.json не найдены - пропускаю"
    fi
}

# Глобальная установка TypeScript
install_typescript() {
    log_step "Проверка TypeScript"
    
    if command -v tsc >/dev/null 2>&1; then
        local version=$(tsc --version)
        log_success "TypeScript уже установлен: $version"
    else
        log_info "Устанавливаю TypeScript глобально"
        show_loading "Установка TypeScript" 2
        
        if npm install -g typescript; then
            log_success "TypeScript установлен"
        else
            log_error "Ошибка установки TypeScript"
            return 1
        fi
    fi
}

# Проверка и установка зависимостей
main() {
    show_logo
    
    log_info "Начинаю установку всех зависимостей проекта"
    echo
    
    # Проверка основных требований
    if ! check_nodejs || ! check_npm; then
        log_error "Необходимо установить Node.js и npm"
        log_info "Скачайте с https://nodejs.org/"
        exit 1
    fi
    
    echo
    
    # Установка TypeScript
    install_typescript
    echo
    
    # Установка зависимостей
    install_main_dependencies
    echo
    
    install_backend_dependencies
    echo
    
    install_desktop_dependencies
    echo
    
    log_success "Установка зависимостей завершена"
    
    # Проверка финального состояния
    log_step "Финальная проверка"
    echo
    
    if [ -d "node_modules" ]; then
        log_success "Основные зависимости: ОК"
    else
        log_warning "Основные зависимости: Не найдены"
    fi
    
    if [ -d "backend/node_modules" ]; then
        log_success "Backend зависимости: ОК"
    else
        log_warning "Backend зависимости: Не найдены"
    fi
    
    if [ -d "desktop/react-src/node_modules" ]; then
        log_success "Desktop зависимости: ОК"
    else
        log_warning "Desktop зависимости: Не найдены"
    fi
    
    echo
    log_info "Готово! Можно переходить к сборке проекта"
}

# Обработка Ctrl+C
trap 'echo; log_info "Прерывание установки"; exit 0' INT

# Запуск
main "$@" 