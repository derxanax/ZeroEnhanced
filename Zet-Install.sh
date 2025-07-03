#!/bin/bash

# ZetGui Installation Manager
# Главное меню для установки и настройки ZetGui

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
    echo -e "${BLUE}ZetGui Installation Manager${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
}

# Анимация приветствия
show_welcome() {
    show_loading "Загрузка системы" 2
    show_loading "Проверка окружения" 1
    show_loading "Подготовка интерфейса" 1
    echo
    log_success "Система готова к работе"
    echo
}

# Показать главное меню
show_menu() {
    echo -e "${CYAN}Выберите действие:${NC}"
    echo
    echo -e "${BLUE}  1  ${NC}Проверить системные зависимости"
    echo -e "${BLUE}  2  ${NC}Установить все зависимости проекта (npm, TypeScript)"
    echo -e "${BLUE}  3  ${NC}Настроить Docker контейнер (отдельно)"
    echo -e "${BLUE}  4  ${NC}Собрать все компоненты"
    echo
    echo -e "${YELLOW}  5  ${NC}Запустить CLI версию"
    echo -e "${YELLOW}  6  ${NC}Запустить Desktop GUI"
    echo -e "${YELLOW}  7  ${NC}Запустить Web версию"
    echo
    echo -e "${PURPLE}  8  ${NC}Создать AppImage (Linux)"
    echo -e "${PURPLE}  9  ${NC}Показать информацию о системе"
    echo
    echo -e "${RED}  0  ${NC}Выход"
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
}

# Выполнить действие
execute_action() {
    local choice="$1"
    
    case $choice in
        1)
            log_step "Проверка системных зависимостей"
            ./script/check-dependencies.sh --system
            ;;
        2)
            log_step "Установка зависимостей проекта"
            log_info "Устанавливаю системные пакеты"
            ./script/install-system-packages.sh
            echo
            log_info "Устанавливаю npm зависимости"
            ./script/install-all-Dependencies.sh
            ;;
        3)
            log_step "Настройка Docker контейнера"
            ./script/setup-docker.sh
            ;;
        4)
            log_step "Сборка всех компонентов"
            ./script/build-all.sh
            ;;
        5)
            log_step "Запуск CLI версии"
            ./script/start-all-cli.sh
            ;;
        6)
            log_step "Запуск Desktop GUI"
            ./script/start-all-gui.sh
            ;;
        7)
            log_step "Запуск Web версии"
            ./script/start-all-web.sh
            ;;
        8)
            log_step "Создание AppImage"
            ./script/build-appimage.sh
            ;;
        9)
            log_step "Информация о системе"
            ./script/check-dependencies.sh --info
            ;;
        0)
            echo
            log_success "До свидания!"
            exit 0
            ;;
        *)
            log_error "Неверный выбор: $choice"
            ;;
    esac
}

# Основной цикл
main_loop() {
    while true; do
        show_logo
        show_menu
        
        echo -n -e "${CYAN}Ваш выбор: ${NC}"
        read -r choice
        
        echo
        execute_action "$choice"
        
        echo
        echo -e "${BLUE}Нажмите Enter для продолжения...${NC}"
        read -r
    done
}

# Проверка что скрипт запущен из правильной директории
check_directory() {
    if [ ! -f "package.json" ] || [ ! -d "script" ]; then
        log_error "Скрипт должен запускаться из корневой директории ZetGui"
        log_info "Перейдите в директорию с package.json и script/"
        exit 1
    fi
}

# Главная функция
main() {
    check_directory
    show_logo
    show_welcome
    main_loop
}

# Обработка Ctrl+C
trap 'echo; log_info "Прерывание работы"; exit 0' INT

# Запуск
main "$@"
