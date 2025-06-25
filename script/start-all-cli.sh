#!/bin/bash

echo "🖥️ Запуск ZeroEnhanced CLI..."

# Переходим в корневую директорию проекта
cd "$(dirname "$0")/.."

# Проверяем, запущен ли backend
if ! curl -s http://localhost:3003/health > /dev/null 2>&1; then
    echo "🚀 Запускаем backend сервер..."
    cd backend
    npm run dev &
    BACKEND_PID=$!
    cd ..
    
    echo "⏳ Ждем запуска backend сервера..."
    for i in {1..30}; do
        if curl -s http://localhost:3003/health > /dev/null 2>&1; then
            echo "✅ Backend сервер запущен!"
            break
        fi
        sleep 1
        if [ $i -eq 30 ]; then
            echo "❌ Timeout: Backend сервер не запустился"
            exit 1
        fi
    done
else
    echo "✅ Backend сервер уже запущен"
fi

# Запускаем CLI
echo "🖥️ Запускаем CLI интерфейс..."
cd src
npx ts-node main.ts

# Cleanup при выходе
trap 'kill $BACKEND_PID 2>/dev/null' EXIT 