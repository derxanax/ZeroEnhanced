#!/bin/bash

echo "🚀 Установка всех зависимостей для ZeroEnhanced..."

# Переходим в корневую директорию проекта
cd "$(dirname "$0")/.."

# Root dependencies
echo "📦 Устанавливаем корневые зависимости..."
npm install --yes --silent

# Backend
echo "📦 Устанавливаем зависимости backend..."
cd backend
npm install --yes --silent
cd ..

# Desktop
echo "🖥️ Устанавливаем зависимости desktop..."
cd desktop
npm install --yes --silent

# React app
echo "⚛️ Устанавливаем зависимости React app..."
cd react-src
npm install --legacy-peer-deps --yes --silent
cd ../..

echo "✅ Все зависимости установлены!"
echo ""
echo "Для запуска проекта используйте:"
echo "Backend: cd backend && npm run dev"
echo "Desktop GUI: cd desktop && npm run dev"
echo "" 