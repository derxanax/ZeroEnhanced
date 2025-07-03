#!/bin/bash

# ZetGui AppImage Builder
# Создание AppImage для Linux

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
    echo -e "${BLUE}AppImage Builder${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
}

# Константы
APP_NAME="ZetGui"
APP_VERSION="1.0.0"
ARCH=$(uname -m)
BUILD_DIR="build-appimage"
APPDIR="$BUILD_DIR/${APP_NAME}.AppDir"

# Проверка Linux
check_linux() {
    log_step "Проверка операционной системы"
    
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "AppImage можно создать только в Linux"
        return 1
    fi
    
    log_success "Операционная система: Linux"
    return 0
}

# Проверка зависимостей
check_dependencies() {
    log_step "Проверка зависимостей"
    
    local missing_deps=()
    
    # Проверка основных инструментов
    if ! command -v wget >/dev/null 2>&1; then
        missing_deps+=("wget")
    fi
    
    if ! command -v file >/dev/null 2>&1; then
        missing_deps+=("file")
    fi
    
    if ! command -v desktop-file-validate >/dev/null 2>&1; then
        missing_deps+=("desktop-file-utils")
    fi
    
    # Проверка Node.js и npm
    if ! command -v node >/dev/null 2>&1; then
        missing_deps+=("nodejs")
    fi
    
    if ! command -v npm >/dev/null 2>&1; then
        missing_deps+=("npm")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Отсутствующие зависимости: ${missing_deps[*]}"
        log_info "Установите их командой:"
        
        if command -v apt-get >/dev/null 2>&1; then
            log_info "sudo apt-get install ${missing_deps[*]}"
        elif command -v dnf >/dev/null 2>&1; then
            log_info "sudo dnf install ${missing_deps[*]}"
        elif command -v pacman >/dev/null 2>&1; then
            log_info "sudo pacman -S ${missing_deps[*]}"
        fi
        
        return 1
    fi
    
    log_success "Все зависимости найдены"
    return 0
}

# Загрузка appimagetool
download_appimagetool() {
    log_step "Загрузка appimagetool"
    
    local appimagetool_url=""
    case "$ARCH" in
        x86_64)
            appimagetool_url="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
            ;;
        i386|i686)
            appimagetool_url="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-i686.AppImage"
            ;;
        aarch64|arm64)
            appimagetool_url="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-aarch64.AppImage"
            ;;
        armhf)
            appimagetool_url="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-armhf.AppImage"
            ;;
        *)
            log_error "Неподдерживаемая архитектура: $ARCH"
            return 1
            ;;
    esac
    
    local appimagetool_path="$BUILD_DIR/appimagetool.AppImage"
    
    if [ ! -f "$appimagetool_path" ]; then
        show_loading "Загрузка appimagetool" 5
        
        if wget -q "$appimagetool_url" -O "$appimagetool_path"; then
            chmod +x "$appimagetool_path"
            log_success "appimagetool загружен"
        else
            log_error "Ошибка загрузки appimagetool"
            return 1
        fi
    else
        log_success "appimagetool уже загружен"
    fi
    
    return 0
}

# Подготовка директорий
prepare_directories() {
    log_step "Подготовка директорий"
    
    # Очистка старой сборки
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
    
    # Создание структуры AppDir
    mkdir -p "$APPDIR/usr/bin"
    mkdir -p "$APPDIR/usr/lib"
    mkdir -p "$APPDIR/usr/share/applications"
    mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
    mkdir -p "$APPDIR/usr/share/pixmaps"
    
    log_success "Директории созданы"
    return 0
}

# Сборка приложения
build_application() {
    log_step "Сборка приложения"
    
    # Проверка зависимостей проекта
    if [ ! -d "node_modules" ]; then
        log_info "Устанавливаю зависимости проекта"
        show_loading "Установка npm зависимостей" 3
        npm install
    fi
    
    # Сборка TypeScript
    if [ -f "tsconfig.json" ]; then
        log_info "Компилирую TypeScript"
        show_loading "Компиляция TypeScript" 2
        
        if command -v tsc >/dev/null 2>&1; then
            tsc
        else
            npx tsc
        fi
    fi
    
    # Сборка desktop приложения если есть
    if [ -d "desktop/react-src" ]; then
        log_info "Собираю desktop React приложение"
        cd desktop/react-src
        
        if [ ! -d "node_modules" ]; then
            npm install
        fi
        
        show_loading "Сборка React приложения" 5
        npm run build
        cd ../..
    fi
    
    log_success "Приложение собрано"
    return 0
}

# Копирование файлов
copy_files() {
    log_step "Копирование файлов приложения"
    
    # Копирование исполняемых файлов
    if [ -f "dist/main.js" ]; then
        cp dist/main.js "$APPDIR/usr/bin/${APP_NAME,,}"
        chmod +x "$APPDIR/usr/bin/${APP_NAME,,}"
    elif [ -f "src/main.ts" ]; then
        # Создание обертки для ts-node
        cat > "$APPDIR/usr/bin/${APP_NAME,,}" << EOF
#!/bin/bash
DIR="\$(dirname "\$(readlink -f "\$0")")"
cd "\$DIR/../.."
node dist/main.js "\$@"
EOF
        chmod +x "$APPDIR/usr/bin/${APP_NAME,,}"
        
        # Копирование source файлов
        mkdir -p "$APPDIR/usr/share/${APP_NAME,,}"
        cp -r src "$APPDIR/usr/share/${APP_NAME,,}/"
        cp -r dist "$APPDIR/usr/share/${APP_NAME,,}/" 2>/dev/null || true
        cp package.json "$APPDIR/usr/share/${APP_NAME,,}/"
        cp -r node_modules "$APPDIR/usr/share/${APP_NAME,,}/"
    else
        log_error "Не найден исполняемый файл приложения"
        return 1
    fi
    
    # Копирование Node.js если нужно
    local node_path=$(which node)
    if [ -f "$node_path" ]; then
        cp "$node_path" "$APPDIR/usr/bin/"
    fi
    
    log_success "Файлы приложения скопированы"
    return 0
}

# Создание .desktop файла
create_desktop_file() {
    log_step "Создание .desktop файла"
    
    cat > "$APPDIR/usr/share/applications/${APP_NAME,,}.desktop" << EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=AI Terminal & IDE Management
Exec=${APP_NAME,,}
Icon=${APP_NAME,,}
Categories=Development;Utility;
Terminal=false
StartupNotify=true
EOF

    # Проверка .desktop файла
    if desktop-file-validate "$APPDIR/usr/share/applications/${APP_NAME,,}.desktop"; then
        log_success ".desktop файл создан и валиден"
    else
        log_warning ".desktop файл создан, но содержит ошибки"
    fi
    
    # Создание символической ссылки
    ln -sf "usr/share/applications/${APP_NAME,,}.desktop" "$APPDIR/${APP_NAME,,}.desktop"
    
    return 0
}

# Копирование иконки
copy_icon() {
    log_step "Копирование иконки"
    
    local icon_found=false
    
    # Поиск иконки в различных местах
    local icon_paths=(
        "asset/ZET.png"
        "assets/icon.png"
        "resources/icon.png"
        "desktop/resources/icon.png"
        "icon.png"
    )
    
    for icon_path in "${icon_paths[@]}"; do
        if [ -f "$icon_path" ]; then
            cp "$icon_path" "$APPDIR/usr/share/icons/hicolor/256x256/apps/${APP_NAME,,}.png"
            cp "$icon_path" "$APPDIR/usr/share/pixmaps/${APP_NAME,,}.png"
            ln -sf "usr/share/pixmaps/${APP_NAME,,}.png" "$APPDIR/${APP_NAME,,}.png"
            log_success "Иконка скопирована: $icon_path"
            icon_found=true
            break
        fi
    done
    
    if [ "$icon_found" = false ]; then
        log_warning "Иконка не найдена, создаю заглушку"
        # Создание простой заглушки иконки
        cat > "$APPDIR/usr/share/pixmaps/${APP_NAME,,}.png" << 'EOF'
# Placeholder icon
EOF
        ln -sf "usr/share/pixmaps/${APP_NAME,,}.png" "$APPDIR/${APP_NAME,,}.png"
    fi
    
    return 0
}

# Создание AppRun скрипта
create_apprun() {
    log_step "Создание AppRun скрипта"
    
    cat > "$APPDIR/AppRun" << EOF
#!/bin/bash
DIR="\$(dirname "\$(readlink -f "\$0")")"
export PATH="\$DIR/usr/bin:\$PATH"
export LD_LIBRARY_PATH="\$DIR/usr/lib:\$LD_LIBRARY_PATH"

# Переход в временную директорию для работы
WORK_DIR="\$HOME/.${APP_NAME,,}"
mkdir -p "\$WORK_DIR"
cd "\$WORK_DIR"

# Копирование конфигураций если нужно
if [ ! -f "Prod.json" ] && [ -f "\$DIR/usr/share/${APP_NAME,,}/Prod.json" ]; then
    cp "\$DIR/usr/share/${APP_NAME,,}/Prod.json" .
fi

# Запуск приложения
exec "\$DIR/usr/bin/${APP_NAME,,}" "\$@"
EOF
    
    chmod +x "$APPDIR/AppRun"
    
    log_success "AppRun скрипт создан"
    return 0
}

# Создание AppImage
create_appimage() {
    log_step "Создание AppImage"
    
    local output_name="${APP_NAME}-${APP_VERSION}-${ARCH}.AppImage"
    
    show_loading "Сборка AppImage" 10
    
    # Установка переменных окружения для appimagetool
    export ARCH
    
    if "$BUILD_DIR/appimagetool.AppImage" "$APPDIR" "$output_name"; then
        log_success "AppImage создан: $output_name"
        
        # Информация о размере файла
        local size=$(du -h "$output_name" | cut -f1)
        log_info "Размер файла: $size"
        
        # Проверка возможности запуска
        if [ -x "$output_name" ]; then
            log_success "AppImage готов к запуску"
        else
            log_warning "AppImage создан, но может быть не исполняемым"
        fi
        
        return 0
    else
        log_error "Ошибка создания AppImage"
        return 1
    fi
}

# Очистка временных файлов
cleanup() {
    log_step "Очистка временных файлов"
    
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        log_success "Временные файлы удалены"
    fi
}

# Главная функция
main() {
    show_logo
    
    log_info "Создание AppImage для $APP_NAME"
    echo
    
    # Проверки
    if ! check_linux; then
        exit 1
    fi
    
    if ! check_dependencies; then
        exit 1
    fi
    echo
    
    # Подготовка
    prepare_directories
    echo
    
    if ! download_appimagetool; then
        exit 1
    fi
    echo
    
    # Сборка
    if ! build_application; then
        exit 1
    fi
    echo
    
    # Создание AppDir
    if ! copy_files; then
        exit 1
    fi
    echo
    
    create_desktop_file
    echo
    
    copy_icon
    echo
    
    create_apprun
    echo
    
    # Финальная сборка
    if ! create_appimage; then
        exit 1
    fi
    echo
    
    log_success "AppImage успешно создан!"
    
    # Показ информации
    local output_name="${APP_NAME}-${APP_VERSION}-${ARCH}.AppImage"
    echo
    log_info "Файл: $(realpath "$output_name")"
    log_info "Для запуска: ./$output_name"
    log_info "Для установки: переместите в ~/Applications/ или /opt/"
    
    # Спросить о очистке
    read -p "Удалить временные файлы? (Y/n): " choice
    if [[ ! "$choice" =~ ^[Nn]$ ]]; then
        cleanup
    fi
}

# Проверка директории
check_directory() {
    if [ ! -f "package.json" ]; then
        log_error "Скрипт должен запускаться из корневой директории проекта"
        log_info "Перейдите в директорию с package.json"
        exit 1
    fi
}

# Обработка аргументов
case "${1:-}" in
    --clean|-c)
        log_info "Очистка временных файлов"
        cleanup
        exit 0
        ;;
    --help|-h)
        echo "Использование: $0 [опции]"
        echo "Опции:"
        echo "  --clean, -c      Удалить временные файлы"
        echo "  --help, -h       Показать эту справку"
        exit 0
        ;;
esac

# Обработка Ctrl+C
trap 'echo; log_info "Прерывание сборки"; cleanup; exit 0' INT

# Запуск
check_directory
main "$@" 