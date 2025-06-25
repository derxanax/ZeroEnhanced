#!/bin/bash

# ZeroEnhanced - Главный скрипт управления
echo "
██████╗ ███████╗████████╗     ██████╗ ██╗   ██╗██╗
╚════██╗██╔════╝╚══██╔══╝    ██╔════╝ ██║   ██║██║
 █████╔╝█████╗     ██║       ██║  ███╗██║   ██║██║
██╔═══╝ ██╔══╝     ██║       ██║   ██║██║   ██║██║
███████╗███████╗   ██║       ╚██████╔╝╚██████╔╝██║
╚══════╝╚══════╝   ╚═╝        ╚═════╝  ╚═════╝ ╚═╝
"
echo "🚀 ZeroEnhanced - AI Terminal & IDE Management"
echo "=============================================="

# Переходим в корневую директорию проекта
cd "$(dirname "$0")"

show_menu() {
    echo ""
    echo "Выберите действие:"
    echo "1) 📦 Установить все зависимости"
    echo "2) 🔨 Собрать все компоненты"
    echo "3) 🖥️  Запустить CLI версию"
    echo "4) 🖥️  Запустить Desktop GUI"
    echo "5) 🌐 Запустить Web версию"
    echo "6) ❌ Выход"
    echo ""
    read -p "Введите номер (1-6): " choice
}

while true; do
    show_menu
    case $choice in
        1)
            echo "📦 Запуск установки зависимостей..."
            ./script/install-all-Dependencies.sh
            ;;
        2)
            echo "🔨 Запуск сборки всех компонентов..."
            ./script/build-all.sh
            ;;
        3)
            echo "🖥️ Запуск CLI версии..."
            ./script/start-all-cli.sh
            ;;
        4)
            echo "🖥️ Запуск Desktop GUI..."
            ./script/start-all-gui.sh
            ;;
        5)
            echo "🌐 Запуск Web версии..."
            ./script/start-all-web.sh
            ;;
        6)
            echo "👋 До свидания!"
            exit 0
            ;;
        *)
            echo "❌ Неверный выбор. Пожалуйста, выберите от 1 до 6."
            ;;
    esac
    
    echo ""
    read -p "Нажмите Enter для возврата в меню..."
done 