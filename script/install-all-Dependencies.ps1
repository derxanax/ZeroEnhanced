# PowerShell версия для Windows
Write-Host "🚀 Установка всех зависимостей для ZeroEnhanced..." -ForegroundColor Green

# Переходим в корневую директорию проекта
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $scriptPath "..")

# Root dependencies
Write-Host "📦 Устанавливаем корневые зависимости..." -ForegroundColor Yellow
npm install --yes --silent

# Backend
Write-Host "📦 Устанавливаем зависимости backend..." -ForegroundColor Yellow
Set-Location backend
npm install --yes --silent
Set-Location ..

# Desktop  
Write-Host "🖥️ Устанавливаем зависимости desktop..." -ForegroundColor Yellow
Set-Location desktop
npm install --yes --silent

# React app
Write-Host "⚛️ Устанавливаем зависимости React app..." -ForegroundColor Yellow
Set-Location react-src
npm install --legacy-peer-deps --yes --silent
Set-Location ../..

Write-Host "✅ Все зависимости установлены!" -ForegroundColor Green
Write-Host ""
Write-Host "Для запуска проекта используйте:" -ForegroundColor Cyan
Write-Host "Backend: cd backend && npm run dev" -ForegroundColor White
Write-Host "Desktop GUI: cd desktop && npm run dev" -ForegroundColor White 