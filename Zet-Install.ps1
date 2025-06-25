# PowerShell версия для Windows
# ZeroEnhanced - Главный скрипт управления

Write-Host @"
██████╗ ███████╗████████╗     ██████╗ ██╗   ██╗██╗
╚════██╗██╔════╝╚══██╔══╝    ██╔════╝ ██║   ██║██║
 █████╔╝█████╗     ██║       ██║  ███╗██║   ██║██║
██╔═══╝ ██╔══╝     ██║       ██║   ██║██║   ██║██║
███████╗███████╗   ██║       ╚██████╔╝╚██████╔╝██║
╚══════╝╚══════╝   ╚═╝        ╚═════╝  ╚═════╝ ╚═╝
"@ -ForegroundColor Cyan

Write-Host "🚀 ZeroEnhanced - AI Terminal & IDE Management" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green

# Переходим в корневую директорию проекта
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

function Show-Menu {
    Write-Host ""
    Write-Host "Выберите действие:" -ForegroundColor Yellow
    Write-Host "1) 📦 Установить все зависимости" -ForegroundColor White
    Write-Host "2) 🔨 Собрать все компоненты" -ForegroundColor White
    Write-Host "3) 🖥️  Запустить CLI версию" -ForegroundColor White
    Write-Host "4) 🖥️  Запустить Desktop GUI" -ForegroundColor White
    Write-Host "5) 🌐 Запустить Web версию" -ForegroundColor White
    Write-Host "6) ❌ Выход" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "Введите номер (1-6)"
    return $choice
}

while ($true) {
    $choice = Show-Menu
    
    switch ($choice) {
        "1" {
            Write-Host "📦 Запуск установки зависимостей..." -ForegroundColor Green
            & ".\script\install-all-Dependencies.ps1"
        }
        "2" {
            Write-Host "🔨 Запуск сборки всех компонентов..." -ForegroundColor Green
            & ".\script\build-all.ps1"
        }
        "3" {
            Write-Host "🖥️ Запуск CLI версии..." -ForegroundColor Green
            & ".\script\start-all-cli.ps1"
        }
        "4" {
            Write-Host "🖥️ Запуск Desktop GUI..." -ForegroundColor Green
            & ".\script\start-all-gui.ps1"
        }
        "5" {
            Write-Host "🌐 Запуск Web версии..." -ForegroundColor Green
            & ".\script\start-all-web.ps1"
        }
        "6" {
            Write-Host "👋 До свидания!" -ForegroundColor Green
            exit 0
        }
        default {
            Write-Host "❌ Неверный выбор. Пожалуйста, выберите от 1 до 6." -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Read-Host "Нажмите Enter для возврата в меню..."
} 