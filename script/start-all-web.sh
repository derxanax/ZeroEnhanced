#!/bin/bash

echo "🌐 Запуск ZeroEnhanced Web версии..."

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
            kill $BACKEND_PID 2>/dev/null
            exit 1
        fi
    done
else
    echo "✅ Backend сервер уже запущен"
fi

# Запускаем Web версию
echo "🌐 Запускаем Web интерфейс..."
cd desktop/react-src
npm start &
WEB_PID=$!

echo ""
echo "🎉 ZeroEnhanced Web запущен!"
echo "📍 Backend: http://localhost:3003"
echo "🌐 Web GUI: http://localhost:3000"
echo ""
echo "Нажмите Ctrl+C для остановки..."

# Cleanup при выходе
trap 'kill $BACKEND_PID $WEB_PID 2>/dev/null' EXIT

# Ждем сигнала завершения
wait 