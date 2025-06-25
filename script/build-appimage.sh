#!/bin/bash
set -e

# 🚀 ZetGui AppImage Builder Script
# Организованная сборка с версионированием

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

# Получаем информацию о проекте
get_project_info() {
    log_step "Getting project information..."
    
    # Проверяем что мы в корне проекта
    if [ ! -f "package.json" ]; then
        log_error "package.json not found! Run this script from ZeroEnhanced root directory"
        exit 1
    fi
    
    # Извлекаем версию из package.json
    VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "1.0.0")
    PROJECT_NAME=$(node -p "require('./package.json').name" 2>/dev/null || echo "zetgui")
    DESCRIPTION=$(node -p "require('./package.json').description" 2>/dev/null || echo "ZetGui AppImage")
    
    # Получаем информацию о git коммите
    if command -v git &> /dev/null && [ -d ".git" ]; then
        GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        GIT_DATE=$(git log -1 --format=%cd --date=iso 2>/dev/null || date)
        GIT_AUTHOR=$(git log -1 --format=%an 2>/dev/null || echo "unknown")
    else
        GIT_COMMIT="unknown"
        GIT_BRANCH="unknown" 
        GIT_DATE=$(date)
        GIT_AUTHOR="unknown"
    fi
    
    BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    BUILD_DIR="build/build-${VERSION}"
    
    log_info "Project: $PROJECT_NAME"
    log_info "Version: $VERSION"
    log_info "Git: $GIT_BRANCH@$GIT_COMMIT"
    log_info "Build dir: $BUILD_DIR"
}

# Проверяем зависимости
check_dependencies() {
    log_step "Checking dependencies..."
    
    local deps_ok=true
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Please install Node.js 18+"
        deps_ok=false
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "npm not found. Please install npm"
        deps_ok=false
    fi
    
    if ! command -v docker &> /dev/null; then
        log_warning "Docker not found. AppImage will require Docker on target system"
    fi
    
    if [ "$deps_ok" = false ]; then
        exit 1
    fi
    
    log_success "All dependencies checked"
}

# Создаем структуру для билда
prepare_build_dir() {
    log_step "Preparing build directory..."
    
    # Создаем директории
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$BUILD_DIR/AppDir"
    mkdir -p "$BUILD_DIR/source"
    mkdir -p "$BUILD_DIR/artifacts"
    
    log_success "Build directory prepared: $BUILD_DIR"
}

# Билдим все компоненты
build_components() {
    log_step "Building all components..."
    
    # Backend
    log_info "Building backend..."
    cd backend
    npm install --silent
    npm run build --silent
    cd ..
    log_success "Backend built"
    
    # Frontend 
    log_info "Building frontend..."
    cd desktop/react-src
    npm install --silent
    npm run build --silent
    cd ../..
    log_success "Frontend built"
    
    # CLI
    log_info "Building CLI..."
    npm install --silent
    npx tsc > /dev/null 2>&1
    log_success "CLI built"
}

# Собираем источники в билд директорию
collect_sources() {
    log_step "Collecting sources..."
    
    # Копируем собранные компоненты
    cp -r backend/dist "$BUILD_DIR/source/backend-dist"
    cp -r backend/node_modules "$BUILD_DIR/source/backend-node_modules"
    cp backend/package.json "$BUILD_DIR/source/backend-package.json"
    
    cp -r desktop/react-src/build "$BUILD_DIR/source/frontend-build"
    
    cp -r dist "$BUILD_DIR/source/cli-dist"
    cp -r node_modules "$BUILD_DIR/source/cli-node_modules"
    cp package.json "$BUILD_DIR/source/cli-package.json"
    
    # Копируем дополнительные файлы
    cp -r docker-sandbox "$BUILD_DIR/source/"
    cp -r asset "$BUILD_DIR/source/" 2>/dev/null || log_warning "No asset directory found"
    
    log_success "Sources collected"
}

# Создаем AppDir структуру
create_appdir() {
    log_step "Creating AppDir structure..."
    
    local APPDIR="$BUILD_DIR/AppDir"
    
    # Создаем структуру директорий
    mkdir -p "$APPDIR/usr/bin"
    mkdir -p "$APPDIR/usr/lib/zetgui"
    mkdir -p "$APPDIR/usr/share/applications"
    mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
    mkdir -p "$APPDIR/usr/share/pixmaps"
    
    # Копируем файлы приложения
    cp -r "$BUILD_DIR/source/backend-dist" "$APPDIR/usr/lib/zetgui/backend"
    cp -r "$BUILD_DIR/source/backend-node_modules" "$APPDIR/usr/lib/zetgui/backend/node_modules"
    cp "$BUILD_DIR/source/backend-package.json" "$APPDIR/usr/lib/zetgui/backend/package.json"
    
    cp -r "$BUILD_DIR/source/frontend-build" "$APPDIR/usr/lib/zetgui/www"
    
    cp -r "$BUILD_DIR/source/cli-dist" "$APPDIR/usr/lib/zetgui/cli"
    cp -r "$BUILD_DIR/source/cli-node_modules" "$APPDIR/usr/lib/zetgui/cli/node_modules"
    cp "$BUILD_DIR/source/cli-package.json" "$APPDIR/usr/lib/zetgui/cli/package.json"
    
    cp -r "$BUILD_DIR/source/docker-sandbox" "$APPDIR/usr/lib/zetgui/"
    
    # Иконка
    if [ -f "$BUILD_DIR/source/asset/ZET.png" ]; then
        cp "$BUILD_DIR/source/asset/ZET.png" "$APPDIR/zetgui.png"
        cp "$BUILD_DIR/source/asset/ZET.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/zetgui.png"
        cp "$BUILD_DIR/source/asset/ZET.png" "$APPDIR/usr/share/pixmaps/zetgui.png"
    else
        log_warning "No icon found, creating default"
        # Создаем простую иконку
        echo "Creating default icon..."
        convert -size 256x256 xc:'#1e40af' -font DejaVu-Sans-Bold -pointsize 72 -fill white -gravity center -annotate +0+0 "ZET" "$APPDIR/zetgui.png" 2>/dev/null || {
            # Fallback если ImageMagick не установлен
            echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > "$APPDIR/zetgui.png"
        }
        cp "$APPDIR/zetgui.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/zetgui.png"
        cp "$APPDIR/zetgui.png" "$APPDIR/usr/share/pixmaps/zetgui.png"
    fi
    
    log_success "AppDir structure created"
}

# Создаем launcher
create_launcher() {
    log_step "Creating launcher..."
    
    cat > "$BUILD_DIR/AppDir/usr/bin/zetgui" << 'EOF'
#!/bin/bash

# ZetGui Launcher Script
APP_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
ZETGUI_DIR="$APP_DIR/lib/zetgui"

# Проверяем Docker
if ! command -v docker &> /dev/null; then
    if command -v zenity &> /dev/null; then
        zenity --error --text="Docker не найден!\n\nДля работы ZetGui требуется Docker.\nУстановите Docker и перезапустите приложение." --width=400
    else
        echo "❌ Docker не найден! Для работы ZetGui требуется Docker."
        echo "📋 Установите Docker: https://docs.docker.com/get-docker/"
    fi
    exit 1
fi

# Устанавливаем переменные окружения
export NODE_PATH="$ZETGUI_DIR/backend/node_modules:$ZETGUI_DIR/cli/node_modules"
cd "$ZETGUI_DIR"

# Запускаем CLI
echo "🚀 Starting ZetGui CLI..."
cd "$ZETGUI_DIR/cli"
exec node main.js "$@"
EOF

    chmod +x "$BUILD_DIR/AppDir/usr/bin/zetgui"
    log_success "Launcher created"
}

# Создаем .desktop файл
create_desktop_file() {
    log_step "Creating desktop entry..."
    
    cat > "$BUILD_DIR/AppDir/usr/share/applications/zetgui.desktop" << EOF
[Desktop Entry]
Type=Application
Name=ZetGui
Comment=$DESCRIPTION
Comment[ru]=ИИ терминал и IDE с интеграцией Docker
Exec=zetgui
Icon=zetgui
Categories=Development;IDE;
Keywords=AI;Terminal;IDE;Docker;qZET;Assistant;
StartupNotify=true
EOF

    cp "$BUILD_DIR/AppDir/usr/share/applications/zetgui.desktop" "$BUILD_DIR/AppDir/"
    log_success "Desktop entry created"
}

# Создаем AppRun
create_apprun() {
    log_step "Creating AppRun..."
    
    cat > "$BUILD_DIR/AppDir/AppRun" << 'EOF'
#!/bin/bash

# AppRun script for ZetGui
APP_DIR="$(dirname "$(readlink -f "$0")")"
export PATH="$APP_DIR/usr/bin:$PATH"
export LD_LIBRARY_PATH="$APP_DIR/usr/lib:$LD_LIBRARY_PATH"

exec "$APP_DIR/usr/bin/zetgui" "$@"
EOF

    chmod +x "$BUILD_DIR/AppDir/AppRun"
    log_success "AppRun created"
}

# Скачиваем appimagetool
download_appimagetool() {
    local tool_path="$BUILD_DIR/appimagetool-x86_64.AppImage"
    
    if [ ! -f "$tool_path" ]; then
        log_step "Downloading appimagetool..."
        wget -q -O "$tool_path" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "$tool_path"
        log_success "appimagetool downloaded"
    fi
}

# Создаем AppImage
build_appimage() {
    log_step "Building AppImage..."
    
    download_appimagetool
    
    local appimage_name="ZetGui-${VERSION}-x86_64.AppImage"
    local tool_path="$BUILD_DIR/appimagetool-x86_64.AppImage"
    
    cd "$BUILD_DIR"
    ARCH=x86_64 "./$(basename $tool_path)" AppDir "artifacts/$appimage_name" 2>&1 | grep -v "WARNING\|Please consider"
    cd ..
    
    if [ -f "$BUILD_DIR/artifacts/$appimage_name" ]; then
        log_success "AppImage created: $appimage_name"
        ls -lh "$BUILD_DIR/artifacts/$appimage_name"
    else
        log_error "AppImage creation failed!"
        exit 1
    fi
}

# Создаем README для билда
create_build_readme() {
    log_step "Creating build README..."
    
    cat > "$BUILD_DIR/README.md" << EOF
# ZetGui AppImage Build $VERSION

## 📦 Build Information

| Field | Value |
|-------|-------|
| **Version** | \`$VERSION\` |
| **Build Date** | \`$BUILD_DATE\` |
| **Git Commit** | \`$GIT_COMMIT\` |
| **Git Branch** | \`$GIT_BRANCH\` |
| **Git Author** | \`$GIT_AUTHOR\` |
| **Git Date** | \`$GIT_DATE\` |

## 🚀 What's Included

This AppImage contains the complete ZetGui application:

- **🔧 Backend API Server** - Enhanced with all CLI functionality
- **⚛️ React Frontend** - Beautiful three-panel GUI interface  
- **💻 CLI Interface** - Command-line version for advanced users
- **🐳 Docker Integration** - Sandbox environment for safe execution
- **🤖 AI Assistant** - qZET (modified Qwen) with natural language processing

## 📁 Directory Structure

\`\`\`
build-$VERSION/
├── AppDir/              # AppImage source directory
├── source/              # Compiled application sources  
├── artifacts/           # Built AppImage files
├── appimagetool-*       # AppImage builder tool
└── README.md           # This file
\`\`\`

## 🔧 Requirements

- **Linux x86_64** system
- **Docker** installed and running
- **Modern browser** (for web interface)

## 🚀 Usage

1. **Make executable:**
   \`\`\`bash
   chmod +x ZetGui-$VERSION-x86_64.AppImage
   \`\`\`

2. **Run:**
   \`\`\`bash
   ./ZetGui-$VERSION-x86_64.AppImage
   \`\`\`

3. **Access web interface:**
   - Automatically opens at \`http://localhost:3003\`
   - Three-panel layout: FileExplorer | Terminal | AI Chat

## ✨ Features Implemented

### 🎯 Web Version Improvements
- ✅ **Full CLI Parity** - All CLI features now available in web
- ✅ **Three-Panel Layout** - FileExplorer (left) | Terminal (center) | AI Chat (right)  
- ✅ **Real-time Terminal** - WebSocket integration for live command execution
- ✅ **Session Management** - Proper pageId handling and cleanup
- ✅ **Beautiful UI** - SVG icons, modern design, professional gradients

### 🤖 AI Integration  
- ✅ **Auto-execution** - Commands run automatically when confirm=false
- ✅ **File Operations** - Create/edit files through AI requests
- ✅ **Error Handling** - Robust error handling like CLI version
- ✅ **Request Tracking** - Real-time remaining requests display

### 🐳 Docker Terminal
- ✅ **WebSocket Terminal** - Real-time command execution
- ✅ **Command History** - Scrollable terminal with history
- ✅ **Status Indicators** - Connection and execution status
- ✅ **Auto-scroll** - Terminal automatically scrolls to latest output

## 🏗️ Build Process

This AppImage was built using the automated build script that:

1. ✅ Extracts version from \`package.json\`
2. ✅ Builds all components (backend, frontend, CLI)
3. ✅ Creates organized build directory structure
4. ✅ Packages everything into portable AppImage
5. ✅ Generates this documentation

## 🐛 Troubleshooting

### AppImage won't start
- Check Docker is installed: \`docker --version\`
- Check permissions: \`chmod +x ZetGui-*.AppImage\`

### Web interface doesn't open
- Manually open: \`http://localhost:3003\`
- Check port 3003 is not in use: \`netstat -tlnp | grep 3003\`

### Docker errors
- Ensure Docker daemon is running: \`sudo systemctl start docker\`
- Check Docker permissions: \`docker ps\`

## 📞 Support

- **Repository**: [ZetGui GitHub](https://github.com/your-username/zetgui)
- **Issues**: Report bugs and feature requests
- **Documentation**: Check README.md in repository

---

*Built with ❤️ by the ZetGui team*
EOF

    log_success "Build README created"
}

# Основная функция
main() {
    echo
    log_step "🎯 ZetGui AppImage Build Process Started"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    get_project_info
    check_dependencies
    prepare_build_dir
    build_components
    collect_sources
    create_appdir
    create_launcher
    create_desktop_file
    create_apprun
    build_appimage
    create_build_readme
    
    echo
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_success "🎉 ZetGui AppImage Build Completed!"
    echo
    log_info "📦 Build Directory: $BUILD_DIR"
    log_info "🚀 AppImage: $BUILD_DIR/artifacts/ZetGui-${VERSION}-x86_64.AppImage"
    log_info "📋 Documentation: $BUILD_DIR/README.md"
    echo
    log_step "💡 Quick test:"
    echo -e "${CYAN}   cd $BUILD_DIR/artifacts${NC}"
    echo -e "${CYAN}   chmod +x ZetGui-${VERSION}-x86_64.AppImage${NC}"
    echo -e "${CYAN}   ./ZetGui-${VERSION}-x86_64.AppImage${NC}"
    echo
}

# Запуск
main "$@" 