#!/bin/bash

# ZetGui System Packages Installer
# Установка системных зависимостей

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
    echo -e "${BLUE}System Packages Installer${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
}

# Определение дистрибутива
detect_distro() {
    log_step "Определение операционной системы"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        log_success "Система: $PRETTY_NAME"
    elif command -v lsb_release >/dev/null 2>&1; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VERSION=$(lsb_release -sr)
        log_success "Система: $DISTRO $VERSION"
    else
        log_error "Не удалось определить дистрибутив Linux"
        return 1
    fi
    
    return 0
}

# Установка Node.js
install_nodejs() {
    log_step "Установка Node.js"
    
    if command -v node >/dev/null 2>&1; then
        local version=$(node --version)
        log_success "Node.js уже установлен: $version"
        return 0
    fi
    
    show_loading "Установка Node.js" 5
    
    case "$DISTRO" in
        ubuntu|debian)
            # Установка через NodeSource репозиторий
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        fedora|rhel|centos)
            sudo dnf install -y nodejs npm
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm nodejs npm
            ;;
        opensuse*)
            sudo zypper install -y nodejs npm
            ;;
        *)
            log_warning "Неподдерживаемый дистрибутив для автоматической установки Node.js"
            log_info "Установите Node.js вручную: https://nodejs.org/"
            return 1
            ;;
    esac
    
    if command -v node >/dev/null 2>&1; then
        local version=$(node --version)
        log_success "Node.js установлен: $version"
        return 0
    else
        log_error "Ошибка установки Node.js"
        return 1
    fi
}

# Установка основных пакетов
install_basic_packages() {
    log_step "Установка основных пакетов"
    
    local packages=""
    
    case "$DISTRO" in
        ubuntu|debian)
            show_loading "Обновление списка пакетов" 2
            sudo apt-get update
            
            packages="curl wget git build-essential python3 python3-pip"
            show_loading "Установка пакетов" 3
            sudo apt-get install -y $packages
            ;;
        fedora|rhel|centos)
            packages="curl wget git gcc gcc-c++ make python3 python3-pip"
            show_loading "Установка пакетов" 3
            sudo dnf install -y $packages
            ;;
        arch|manjaro)
            packages="curl wget git base-devel python python-pip"
            show_loading "Установка пакетов" 3
            sudo pacman -S --noconfirm $packages
            ;;
        opensuse*)
            packages="curl wget git gcc gcc-c++ make python3 python3-pip"
            show_loading "Установка пакетов" 3
            sudo zypper install -y $packages
            ;;
        *)
            log_warning "Неподдерживаемый дистрибутив: $DISTRO"
            return 1
            ;;
    esac
    
    log_success "Основные пакеты установлены"
    return 0
}

# Установка Docker (опционально)
install_docker() {
    log_step "Проверка Docker"
    
    if command -v docker >/dev/null 2>&1; then
        local version=$(docker --version)
        log_success "Docker уже установлен: $version"
        return 0
    fi
    
    read -p "Установить Docker? (y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        log_info "Пропуск установки Docker"
        return 0
    fi
    
    show_loading "Установка Docker" 10
    
    case "$DISTRO" in
        ubuntu|debian)
            # Установка через официальный репозиторий Docker
            sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            sudo apt-get install -y ca-certificates curl gnupg lsb-release
            
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        fedora)
            sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine 2>/dev/null || true
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm docker
            ;;
        *)
            log_warning "Установите Docker вручную для вашего дистрибутива"
            log_info "Инструкции: https://docs.docker.com/engine/install/"
            return 1
            ;;
    esac
    
    # Настройка Docker
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker установлен"
        
        # Добавление пользователя в группу docker
        sudo usermod -aG docker $USER
        log_info "Пользователь $USER добавлен в группу docker"
        
        # Запуск и автозапуск Docker
        sudo systemctl enable docker
        sudo systemctl start docker
        log_success "Docker сервис запущен и добавлен в автозапуск"
        
        log_warning "Перезайдите в систему для применения изменений группы docker"
        return 0
    else
        log_error "Ошибка установки Docker"
        return 1
    fi
}

# Установка TypeScript глобально
install_typescript() {
    log_step "Установка TypeScript"
    
    if command -v tsc >/dev/null 2>&1; then
        local version=$(tsc --version)
        log_success "TypeScript уже установлен: $version"
        return 0
    fi
    
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm не найден, сначала установите Node.js"
        return 1
    fi
    
    show_loading "Установка TypeScript глобально" 3
    
    if npm install -g typescript; then
        local version=$(tsc --version)
        log_success "TypeScript установлен: $version"
        return 0
    else
        log_error "Ошибка установки TypeScript"
        return 1
    fi
}

# Проверка установленных пакетов
verify_installation() {
    log_step "Проверка установки"
    echo
    
    local all_good=true
    
    # Проверка Node.js
    if command -v node >/dev/null 2>&1; then
        local version=$(node --version)
        log_success "Node.js: $version"
    else
        log_error "Node.js: не найден"
        all_good=false
    fi
    
    # Проверка npm
    if command -v npm >/dev/null 2>&1; then
        local version=$(npm --version)
        log_success "npm: v$version"
    else
        log_error "npm: не найден"
        all_good=false
    fi
    
    # Проверка TypeScript
    if command -v tsc >/dev/null 2>&1; then
        local version=$(tsc --version)
        log_success "TypeScript: $version"
    else
        log_warning "TypeScript: не найден глобально"
    fi
    
    # Проверка Python
    if command -v python3 >/dev/null 2>&1; then
        local version=$(python3 --version)
        log_success "Python: $version"
    else
        log_warning "Python3: не найден"
    fi
    
    # Проверка Docker
    if command -v docker >/dev/null 2>&1; then
        local version=$(docker --version)
        log_success "Docker: $version"
    else
        log_warning "Docker: не установлен"
    fi
    
    # Проверка git
    if command -v git >/dev/null 2>&1; then
        local version=$(git --version)
        log_success "Git: $version"
    else
        log_warning "Git: не найден"
    fi
    
    echo
    
    if [ "$all_good" = true ]; then
        log_success "Все необходимые пакеты установлены"
        return 0
    else
        log_warning "Некоторые пакеты не установлены, но можно продолжать"
        return 0
    fi
}

# Главная функция
main() {
    show_logo
    
    log_info "Начинаю установку системных пакетов"
    echo
    
    # Проверка прав
    if [ "$EUID" -eq 0 ]; then
        log_error "Не запускайте скрипт от имени root"
        log_info "Скрипт сам запросит sudo когда необходимо"
            exit 1
    fi
    
    # Определение системы
    if ! detect_distro; then
        exit 1
    fi
    echo
    
    # Установка пакетов
    if ! install_basic_packages; then
        log_error "Ошибка установки основных пакетов"
        exit 1
    fi
    echo
    
    if ! install_nodejs; then
        log_error "Ошибка установки Node.js"
            exit 1
    fi
    echo
    
    install_typescript
    echo
    
    install_docker
    echo
    
    verify_installation
    echo
    
    log_success "Установка системных пакетов завершена!"
    log_info "Теперь можно установить зависимости проекта"
}

# Проверка что скрипт не запущен от root
check_user() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Не запускайте скрипт от имени root"
        exit 1
    fi
}

# Обработка Ctrl+C
trap 'echo; log_info "Прерывание установки"; exit 0' INT

# Запуск
check_user
main "$@" 