#!/bin/bash

# ZetGui Smart Build System
# Умная сборка всех компонентов с Docker и валидацией

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
    echo -e "${CYAN}"
    echo "██████╗ ███████╗████████╗     ██████╗ ██╗   ██╗██╗"
    echo "╚════██╗██╔════╝╚══██╔══╝    ██╔════╝ ██║   ██║██║"
    echo " █████╔╝█████╗     ██║       ██║  ███╗██║   ██║██║"
    echo "██╔═══╝ ██╔══╝     ██║       ██║   ██║██║   ██║██║"
    echo "███████╗███████╗   ██║       ╚██████╔╝╚██████╔╝██║"
    echo "╚══════╝╚══════╝   ╚═╝        ╚═════╝  ╚═════╝ ╚═╝"
    echo -e "${NC}"
    echo -e "${BLUE}ZetGui Smart Build System${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
}

# Переходим в корневую директорию проекта
cd "$(dirname "$0")/.."

# Подключаем helper функции если доступны
if [ -f "./script/check-dependencies.sh" ]; then
    source "./script/check-dependencies.sh"
fi

# Создание директорий для сборки
create_build_directories() {
    log_step "Создание директорий сборки"
    
    mkdir -p dist
    mkdir -p build
    mkdir -p desktop/www
    
    log_success "Директории созданы"
}

# Сборка Backend
build_backend() {
    log_step "Сборка backend"
    
    if [ -f "backend/package.json" ]; then
        cd backend
        
        if npm run --silent 2>&1 | grep -q "build"; then
            log_info "Запускаю npm run build"
            if npm run build; then
                log_success "Backend собран успешно"
            else
                log_error "Ошибка сборки backend"
                cd ..
                return 1
            fi
        else
            log_warning "Backend build script не настроен, пропускаю"
        fi
        
        cd ..
    else
        log_warning "Backend package.json не найден"
    fi
}

# Сборка CLI компонентов
build_cli() {
    log_step "Сборка CLI компонентов"
    
    if [ -f "src/main.ts" ] && [ -f "tsconfig.json" ]; then
        log_info "Компилирую TypeScript"
        
        if npx tsc; then
            log_success "CLI компоненты собраны"
        else
            log_error "Ошибка компиляции TypeScript"
            return 1
        fi
    else
        log_warning "TypeScript файлы или tsconfig.json не найдены"
    fi
}

# Сборка React приложения
build_react_app() {
    log_step "Сборка React приложения"
    
    if [ -f "desktop/react-src/package.json" ]; then
        cd desktop/react-src
        
        log_info "Запускаю npm run build"
        if npm run build --silent; then
            log_success "React приложение собрано"
            
            cd ..
            log_info "Копирую сборку в desktop/www"
            
            if cp -r react-src/build/* www/ 2>/dev/null; then
                log_success "Файлы скопированы в desktop/www/"
            else
                log_error "Не удалось скопировать build файлы"
                cd ..
                return 1
            fi
            
            cd ..
        else
            log_error "Ошибка сборки React приложения"
            cd ../..
            return 1
        fi
    else
        log_warning "React app package.json не найден"
    fi
}

# Валидация собранных файлов
validate_build() {
    log_step "Валидация собранных файлов"
    
    local all_good=true
    
    if docker image inspect "zet-sandbox-image:latest" &> /dev/null; then
        log_success "Docker образ создан"
    else
        log_warning "Docker образ не найден"
    fi
    
    if [ -f "desktop/www/index.html" ]; then
        log_success "React сборка готова"
    else
        log_error "React сборка не найдена"
        all_good=false
    fi
    
    if [ -f "src/main.js" ] || [ -f "dist/main.js" ]; then
        log_success "CLI компоненты готовы"
    else
        log_warning "CLI компоненты не найдены"
    fi
    
    if [ -d "backend/dist" ] || [ -d "backend/build" ]; then
        log_success "Backend сборка готова"
    else
        log_warning "Backend сборка не найдена (возможно, не настроена)"
    fi
    
    if [ "$all_good" = true ]; then
        log_success "Все ключевые компоненты собраны успешно"
        return 0
    else
        log_error "Некоторые компоненты не собрались"
        return 1
    fi
}

# Показать результаты сборки
show_build_results() {
    log_step "Результаты сборки"
    
    echo -e "${CYAN}Готовые файлы:${NC}"
    
    if [ -d "desktop/www" ] && [ "$(ls -A desktop/www 2>/dev/null)" ]; then
        echo -e "${BLUE}  * Desktop GUI: desktop/www/${NC}"
    fi
    
    if [ -d "backend/dist" ] && [ "$(ls -A backend/dist 2>/dev/null)" ]; then
        echo -e "${BLUE}  * Backend: backend/dist/${NC}"
    fi
    
    if [ -f "src/main.js" ]; then
        echo -e "${BLUE}  * CLI: src/ (compiled JS files)${NC}"
    fi
    
    if docker image inspect "zet-sandbox-image:latest" &> /dev/null; then
        echo -e "${BLUE}  * Docker образ: zet-sandbox-image:latest${NC}"
    fi
    
    echo -e "${CYAN}Команды для запуска:${NC}"
    echo -e "${BLUE}  * CLI версия:    ./script/start-all-cli.sh${NC}"
    echo -e "${BLUE}  * Desktop GUI:   ./script/start-all-gui.sh${NC}"
    echo -e "${BLUE}  * Web версия:    ./script/start-all-web.sh${NC}"
}

# Основная функция
main() {
    clear
    show_logo
    echo
    
    if command -v check_system_dependencies &> /dev/null; then
        log_info "Проверяю зависимости"
        if ! check_system_dependencies &> /dev/null; then
            log_warning "Некоторые зависимости отсутствуют, но продолжаю сборку"
        fi
    fi
    
    create_build_directories
    
    local build_failed=false
    
    if ! build_backend; then
        build_failed=true
    fi
    
    if ! build_cli; then
        build_failed=true
    fi
    
    if ! build_react_app; then
        build_failed=true
    fi
    
    if validate_build; then
        echo
        echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
        log_success "Сборка завершена успешно"
        show_build_results
        echo
    else
        log_error "Сборка завершилась с ошибками"
        exit 1
    fi
}

# Запуск
main "$@" 