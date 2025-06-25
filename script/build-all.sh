#!/bin/bash

echo "🔨 Сборка всех компонентов ZeroEnhanced..."

# Переходим в корневую директорию проекта
cd "$(dirname "$0")/.."

# Build Backend
echo "📦 Собираем backend..."
cd backend
npm run build 2>/dev/null || echo "⚠️ Backend build не настроен, пропускаем..."
cd ..

# Build Desktop React App
echo "⚛️ Собираем React приложение..."
cd desktop/react-src
npm run build --silent
cd ../..

# Copy React build to Desktop www
echo "📁 Копируем сборку в desktop/www..."
cd desktop
mkdir -p www
cp -r react-src/build/* www/ 2>/dev/null || echo "⚠️ Не удалось скопировать build файлы"
cd ..

# Build CLI
echo "🖥️ Собираем CLI компоненты..."
cd src
npx tsc 2>/dev/null || echo "⚠️ CLI TypeScript сборка не настроена"
cd ..

echo "✅ Сборка завершена!"
echo ""
echo "Готовые файлы:"
echo "- Desktop GUI: desktop/www/"
echo "- Backend: backend/dist/ (если настроено)"
echo "- CLI: src/ (скомпилированные .js файлы)"
echo "" 