#!/bin/bash

# 🔍 ZeroEnhanced Dependencies Checker
# Helper функции для проверки системных и проектных зависимостей

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

# Проверка системных зависимостей
check_system_dependencies() {
    log_step "Проверка системных зависимостей..."
    
    local all_good=true
    
    # Node.js
    if command -v node &> /dev/null; then
        local node_version=$(node --version)
        local major_version=$(echo $node_version | sed 's/v\([0-9]*\)\..*/\1/')
        
        if [ "$major_version" -ge 18 ]; then
            log_success "Node.js: $node_version ✓"
        else
            log_warning "Node.js: $node_version (рекомендуется v18+)"
            all_good=false
        fi
    else
        log_error "Node.js не установлен"
        all_good=false
    fi
    
    # npm
    if command -v npm &> /dev/null; then
        local npm_version=$(npm --version)
        log_success "npm: v$npm_version ✓"
    else
        log_error "npm не установлен"
        all_good=false
    fi
    
    # TypeScript
    if command -v tsc &> /dev/null; then
        local tsc_version=$(tsc --version | sed 's/Version //')
        log_success "TypeScript: $tsc_version ✓"
    else
        log_warning "TypeScript не установлен глобально"
        log_info "Установите: npm install -g typescript"
    fi
    
    # Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | sed 's/Docker version //' | sed 's/,.*//')
        log_success "Docker: $docker_version ✓"
        
        # Проверка Docker daemon
        if docker ps &> /dev/null; then
            log_success "Docker daemon работает ✓"
        else
            log_error "Docker daemon не запущен"
            log_info "Запустите: sudo systemctl start docker"
            all_good=false
        fi
    else
        log_error "Docker не установлен"
        all_good=false
    fi
    
    # Git
    if command -v git &> /dev/null; then
        local git_version=$(git --version | sed 's/git version //')
        log_success "Git: $git_version ✓"
    else
        log_warning "Git не установлен"
    fi
    
    return $([ "$all_good" = true ] && echo 0 || echo 1)
}

# Проверка Docker окружения
check_docker_environment() {
    log_step "Проверка Docker окружения..."
    
    local all_good=true
    local image_name="zet-sandbox-image:latest"
    local container_name="zet-sandbox"
    
    # Проверка образа
    if docker image inspect "$image_name" &> /dev/null; then
        log_success "Docker образ $image_name существует ✓"
    else
        log_warning "Docker образ $image_name не найден"
        log_info "Создайте образ: ./script/setup-docker.sh"
        all_good=false
    fi
    
    # Проверка контейнера
    if docker container inspect "$container_name" &> /dev/null; then
        local status=$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null)
        if [ "$status" = "true" ]; then
            log_success "Docker контейнер $container_name запущен ✓"
        else
            log_warning "Docker контейнер $container_name остановлен"
            log_info "Запустите: docker start $container_name"
        fi
    else
        log_warning "Docker контейнер $container_name не создан"
        log_info "Создайте контейнер: ./script/setup-docker.sh"
        all_good=false
    fi
    
    # Проверка sandbox директории
    if [ -d "./sandbox" ]; then
        log_success "Sandbox директория существует ✓"
    else
        log_warning "Sandbox директория не найдена"
        log_info "Создайте директорию: ./script/setup-docker.sh"
        all_good=false
    fi
    
    return $([ "$all_good" = true ] && echo 0 || echo 1)
}

# Проверка npm зависимостей
check_npm_dependencies() {
    log_step "Проверка npm зависимостей..."
    
    local all_good=true
    local current_dir=$(pwd)
    
    # Переходим в корневую директорию проекта
    cd "$(dirname "$0")/.."
    
    # Корневые зависимости
    if [ -f "package.json" ]; then
        if [ -d "node_modules" ]; then
            log_success "Корневые npm зависимости установлены ✓"
        else
            log_warning "Корневые npm зависимости не установлены"
            all_good=false
        fi
    fi
    
    # Backend зависимости
    if [ -f "backend/package.json" ]; then
        if [ -d "backend/node_modules" ]; then
            log_success "Backend npm зависимости установлены ✓"
        else
            log_warning "Backend npm зависимости не установлены"
            all_good=false
        fi
    fi
    
    # Desktop React зависимости
    if [ -f "desktop/react-src/package.json" ]; then
        if [ -d "desktop/react-src/node_modules" ]; then
            log_success "React app npm зависимости установлены ✓"
        else
            log_warning "React app npm зависимости не установлены"
            all_good=false
        fi
    fi
    
    cd "$current_dir"
    
    if [ "$all_good" = false ]; then
        log_info "Установите зависимости: ./script/install-all-Dependencies.sh"
    fi
    
    return $([ "$all_good" = true ] && echo 0 || echo 1)
}

# Проверка портов
check_ports() {
    log_step "Проверка портов..."
    
    local ports=(3003 8080 3000)
    local conflicts=()
    
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            local process=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
            log_warning "Порт $port занят процессом: $process"
            conflicts+=("$port")
        else
            log_success "Порт $port свободен ✓"
        fi
    done
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        log_info "Для освобождения портов используйте: sudo lsof -ti:PORT | xargs kill"
        return 1
    fi
    
    return 0
}

# Полная проверка всех зависимостей
check_all_dependencies() {
    log_step "🎯 Полная проверка зависимостей ZeroEnhanced"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local system_ok=true
    local docker_ok=true
    local npm_ok=true
    local ports_ok=true
    
    if ! check_system_dependencies; then
        system_ok=false
    fi
    
    echo
    
    if ! check_docker_environment; then
        docker_ok=false
    fi
    
    echo
    
    if ! check_npm_dependencies; then
        npm_ok=false
    fi
    
    echo
    
    if ! check_ports; then
        ports_ok=false
    fi
    
    echo
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ "$system_ok" = true ] && [ "$docker_ok" = true ] && [ "$npm_ok" = true ] && [ "$ports_ok" = true ]; then
        log_success "🎉 Все зависимости в порядке! ZeroEnhanced готов к запуску."
        return 0
    else
        log_error "❌ Обнаружены проблемы с зависимостями"
        echo
        log_info "📋 Рекомендуемые действия:"
        
        if [ "$system_ok" = false ]; then
            log_info "   1. Установите системные пакеты: ./script/install-system-packages.sh"
        fi
        
        if [ "$docker_ok" = false ]; then
            log_info "   2. Настройте Docker окружение: ./script/setup-docker.sh"
        fi
        
        if [ "$npm_ok" = false ]; then
            log_info "   3. Установите npm зависимости: ./script/install-all-Dependencies.sh"
        fi
        
        if [ "$ports_ok" = false ]; then
            log_info "   4. Освободите занятые порты или остановите конфликтующие процессы"
        fi
        
        return 1
    fi
}

# Автоматическое исправление проблем
auto_fix_dependencies() {
    log_step "🔧 Автоматическое исправление зависимостей..."
    
    local script_dir="$(dirname "$0")"
    
    # Проверяем системные зависимости
    if ! check_system_dependencies &> /dev/null; then
        log_info "Устанавливаю системные зависимости..."
        if [ -f "$script_dir/install-system-packages.sh" ]; then
            bash "$script_dir/install-system-packages.sh"
        else
            log_warning "Скрипт install-system-packages.sh не найден"
        fi
    fi
    
    # Настраиваем Docker
    if ! check_docker_environment &> /dev/null; then
        log_info "Настраиваю Docker окружение..."
        if [ -f "$script_dir/setup-docker.sh" ]; then
            bash "$script_dir/setup-docker.sh"
        else
            log_warning "Скрипт setup-docker.sh не найден"
        fi
    fi
    
    # Устанавливаем npm зависимости
    if ! check_npm_dependencies &> /dev/null; then
        log_info "Устанавливаю npm зависимости..."
        if [ -f "$script_dir/install-all-Dependencies.sh" ]; then
            bash "$script_dir/install-all-Dependencies.sh"
        else
            log_warning "Скрипт install-all-Dependencies.sh не найден"
        fi
    fi
    
    log_success "Автоматическое исправление завершено"
}

# Показать подробную информацию о системе
show_system_info() {
    log_step "📊 Информация о системе..."
    
    echo -e "${CYAN}🖥️  Система:${NC}"
    echo -e "${BLUE}   • ОС: $(uname -s) $(uname -r)${NC}"
    echo -e "${BLUE}   • Архитектура: $(uname -m)${NC}"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${BLUE}   • Дистрибутив: $PRETTY_NAME${NC}"
    fi
    
    echo -e "${CYAN}🔧 Ресурсы:${NC}"
    echo -e "${BLUE}   • CPU: $(nproc) ядер${NC}"
    echo -e "${BLUE}   • RAM: $(free -h | awk '/^Mem:/ {print $2}')${NC}"
    echo -e "${BLUE}   • Диск: $(df -h . | awk 'NR==2 {print $4}') свободно${NC}"
    
    echo -e "${CYAN}📦 Установленные пакеты:${NC}"
    command -v node &> /dev/null && echo -e "${BLUE}   • Node.js: $(node --version)${NC}"
    command -v npm &> /dev/null && echo -e "${BLUE}   • npm: v$(npm --version)${NC}"
    command -v docker &> /dev/null && echo -e "${BLUE}   • Docker: $(docker --version | sed 's/Docker version //' | sed 's/,.*//')${NC}"
    command -v git &> /dev/null && echo -e "${BLUE}   • Git: $(git --version | sed 's/git version //')${NC}"
}

# Основная функция с параметрами
main() {
    case "${1:-check}" in
        "check"|"--check")
            check_all_dependencies
            ;;
        "--system")
            check_system_dependencies
            ;;
        "--docker")
            check_docker_environment
            ;;
        "--npm")
            check_npm_dependencies
            ;;
        "--ports")
            check_ports
            ;;
        "--fix")
            auto_fix_dependencies
            ;;
        "--info")
            show_system_info
            ;;
        "--help"|"-h")
            echo "🔍 ZeroEnhanced Dependencies Checker"
            echo "Использование: $0 [команда]"
            echo ""
            echo "Команды:"
            echo "  check    - Полная проверка всех зависимостей (по умолчанию)"
            echo "  --system - Проверка только системных зависимостей"
            echo "  --docker - Проверка только Docker окружения"
            echo "  --npm    - Проверка только npm зависимостей"
            echo "  --ports  - Проверка только портов"
            echo "  --fix    - Автоматическое исправление проблем"
            echo "  --info   - Информация о системе"
            echo "  --help   - Показать эту справку"
            ;;
        *)
            log_error "Неизвестная команда: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
}

# Если скрипт запущен напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 