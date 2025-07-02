#!/bin/bash

# ZeroEnhanced System Dependencies Installer
# Автоматическая установка системных пакетов для разных дистрибутивов

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

# Определение дистрибутива
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    else
        DISTRO="unknown"
    fi
    
    log_info "Detected system: $DISTRO $VERSION"
}

# Проверка установленных пакетов
check_installed() {
    local package=$1
    local version_cmd=$2
    
    if command -v $package &> /dev/null; then
        local version=$($version_cmd 2>/dev/null || echo "unknown")
        log_success "$package установлен: $version"
        return 0
    else
        log_warning "$package не установлен"
        return 1
    fi
}

# Установка через DNF (Fedora/RHEL/CentOS)
install_with_dnf() {
    log_step "Установка через DNF..."
    
    # Обновление системы
    sudo dnf update -y
    
    # Основные пакеты
    sudo dnf install -y curl wget git nano gcc-c++ make python3 python3-pip
    
    # Node.js через NodeSource
    if ! check_installed "node" "node --version"; then
        log_info "Устанавливаю Node.js через NodeSource..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo dnf install -y nodejs
    fi
    
    # Docker
    if ! check_installed "docker" "docker --version"; then
        log_info "Устанавливаю Docker..."
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Запуск и автозагрузка Docker
        sudo systemctl enable docker
        sudo systemctl start docker
        
        # Добавление пользователя в группу docker
        sudo usermod -aG docker $USER
        log_warning "Перезайдите в систему для применения прав Docker"
    fi
}

# Установка через APT (Ubuntu/Debian)
install_with_apt() {
    log_step "Установка через APT..."
    
    # Обновление системы
    sudo apt update && sudo apt upgrade -y
    
    # Основные пакеты
    sudo apt install -y curl wget git nano build-essential python3 python3-pip ca-certificates gnupg lsb-release
    
    # Node.js через NodeSource
    if ! check_installed "node" "node --version"; then
        log_info "Устанавливаю Node.js через NodeSource..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
    
    # Docker
    if ! check_installed "docker" "docker --version"; then
        log_info "Устанавливаю Docker..."
        
        # Удаление старых версий
        sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Установка Docker GPG ключа
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Добавление репозитория Docker
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Установка Docker
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Запуск и автозагрузка Docker
        sudo systemctl enable docker
        sudo systemctl start docker
        
        # Добавление пользователя в группу docker
        sudo usermod -aG docker $USER
        log_warning "Перезайдите в систему для применения прав Docker"
    fi
}

# Установка через Pacman (Arch Linux)
install_with_pacman() {
    log_step "Установка через Pacman..."
    
    # Обновление системы
    sudo pacman -Syu --noconfirm
    
    # Основные пакеты
    sudo pacman -S --noconfirm curl wget git nano base-devel python python-pip
    
    # Node.js
    if ! check_installed "node" "node --version"; then
        log_info "Устанавливаю Node.js..."
        sudo pacman -S --noconfirm nodejs npm
    fi
    
    # Docker
    if ! check_installed "docker" "docker --version"; then
        log_info "Устанавливаю Docker..."
        sudo pacman -S --noconfirm docker docker-compose
        
        # Запуск и автозагрузка Docker
        sudo systemctl enable docker
        sudo systemctl start docker
        
        # Добавление пользователя в группу docker
        sudo usermod -aG docker $USER
        log_warning "Перезайдите в систему для применения прав Docker"
    fi
}

# Установка TypeScript глобально
install_typescript() {
    if ! check_installed "tsc" "tsc --version"; then
        log_info "Устанавливаю TypeScript глобально..."
        sudo npm install -g typescript ts-node
    fi
}

# Проверка после установки
verify_installation() {
    log_step "Проверка установленных пакетов..."
    
    local all_good=true
    
    if ! check_installed "node" "node --version"; then all_good=false; fi
    if ! check_installed "npm" "npm --version"; then all_good=false; fi
    if ! check_installed "tsc" "tsc --version"; then all_good=false; fi
    if ! check_installed "docker" "docker --version"; then all_good=false; fi
    if ! check_installed "git" "git --version"; then all_good=false; fi
    
    # Проверка Docker daemon
    if ! sudo docker ps &> /dev/null; then
        log_error "Docker daemon не запущен"
        all_good=false
    else
        log_success "Docker daemon работает"
    fi
    
    if [ "$all_good" = true ]; then
        log_success "Все системные зависимости установлены и работают!"
        return 0
    else
        log_error "Некоторые зависимости установлены неправильно"
        return 1
    fi
}

# Основная функция
main() {
    echo
    log_step "🎯 ZeroEnhanced System Dependencies Installation"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Проверка прав sudo
    if ! sudo -n true 2>/dev/null; then
        log_info "Требуются права администратора для установки системных пакетов"
        sudo -v || {
            log_error "Отказано в доступе. Запустите скрипт с правами sudo."
            exit 1
        }
    fi
    
    detect_distro
    
    # Проверка что уже установлено
    log_step "Проверка текущих установок..."
    check_installed "node" "node --version"
    check_installed "npm" "npm --version"
    check_installed "tsc" "tsc --version"
    check_installed "docker" "docker --version"
    check_installed "git" "git --version"
    
    # Установка в зависимости от дистрибутива
    case $DISTRO in
        "fedora"|"rhel"|"centos"|"almalinux"|"rocky")
            install_with_dnf
            ;;
        "ubuntu"|"debian"|"pop"|"mint")
            install_with_apt
            ;;
        "arch"|"manjaro"|"endeavouros")
            install_with_pacman
            ;;
        *)
            log_error "Неподдерживаемый дистрибутив: $DISTRO"
            log_info "Поддерживаемые дистрибутивы: Fedora, Ubuntu, Debian, Arch Linux"
            exit 1
            ;;
    esac
    
    # Установка TypeScript
    install_typescript
    
    # Финальная проверка
    echo
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if verify_installation; then
        log_success "🎉 Установка системных зависимостей завершена!"
        echo
        log_info "📋 Следующие шаги:"
        log_info "   1. Перезайдите в систему (для прав Docker)"
        log_info "   2. Запустите: ./script/install-all-Dependencies.sh"
        log_info "   3. Запустите: ./Zet-Install.sh"
    else
        log_error "❌ Установка завершилась с ошибками"
        exit 1
    fi
    echo
}

main "$@" 