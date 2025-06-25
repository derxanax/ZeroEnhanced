# PowerShell версия для Windows
Write-Host "🔨 Сборка всех компонентов ZeroEnhanced..." -ForegroundColor Green

# Переходим в корневую директорию проекта
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $scriptPath "..")

# Build Backend
Write-Host "📦 Собираем backend..." -ForegroundColor Yellow
Set-Location backend
try {
    npm run build --silent
} catch {
    Write-Host "⚠️ Backend build не настроен, пропускаем..." -ForegroundColor DarkYellow
}
Set-Location ..

# Build Desktop React App
Write-Host "⚛️ Собираем React приложение..." -ForegroundColor Yellow
Set-Location desktop/react-src
npm run build --silent
Set-Location ../..

# Copy React build to Desktop www
Write-Host "📁 Копируем сборку в desktop/www..." -ForegroundColor Yellow
Set-Location desktop
if (!(Test-Path "www")) { New-Item -ItemType Directory -Name "www" }
try {
    Copy-Item -Path "react-src/build/*" -Destination "www/" -Recurse -Force
} catch {
    Write-Host "⚠️ Не удалось скопировать build файлы" -ForegroundColor DarkYellow
}
Set-Location ..

# Build CLI
Write-Host "🖥️ Собираем CLI компоненты..." -ForegroundColor Yellow
Set-Location src
try {
    npx tsc
} catch {
    Write-Host "⚠️ CLI TypeScript сборка не настроена" -ForegroundColor DarkYellow
}
Set-Location ..

Write-Host "✅ Сборка завершена!" -ForegroundColor Green
Write-Host ""
Write-Host "Готовые файлы:" -ForegroundColor Cyan
Write-Host "- Desktop GUI: desktop/www/" -ForegroundColor White
Write-Host "- Backend: backend/dist/ (если настроено)" -ForegroundColor White
Write-Host "- CLI: src/ (скомпилированные .js файлы)" -ForegroundColor White
Write-Host "" 