# PowerShell версия для Windows
Write-Host "🌐 Запуск ZeroEnhanced Web версии..." -ForegroundColor Green

# Переходим в корневую директорию проекта
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $scriptPath "..")

# Проверяем, запущен ли backend
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3003/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
    Write-Host "✅ Backend сервер уже запущен" -ForegroundColor Green
    $backendRunning = $true
} catch {
    Write-Host "🚀 Запускаем backend сервер..." -ForegroundColor Yellow
    Set-Location backend
    $backendProcess = Start-Process -FilePath "npm" -ArgumentList "run", "dev" -PassThru -WindowStyle Hidden
    Set-Location ..
    
    Write-Host "⏳ Ждем запуска backend сервера..." -ForegroundColor Yellow
    $timeout = 30
    for ($i = 1; $i -le $timeout; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3003/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
            Write-Host "✅ Backend сервер запущен!" -ForegroundColor Green
            $backendRunning = $true
            break
        } catch {
            Start-Sleep -Seconds 1
        }
        if ($i -eq $timeout) {
            Write-Host "❌ Timeout: Backend сервер не запустился" -ForegroundColor Red
            if ($backendProcess) { Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue }
            exit 1
        }
    }
}

# Запускаем Web версию
Write-Host "🌐 Запускаем Web интерфейс..." -ForegroundColor Green
Set-Location desktop/react-src
$webProcess = Start-Process -FilePath "npm" -ArgumentList "start" -PassThru

Write-Host ""
Write-Host "🎉 ZeroEnhanced Web запущен!" -ForegroundColor Green
Write-Host "📍 Backend: http://localhost:3003" -ForegroundColor Cyan
Write-Host "🌐 Web GUI: http://localhost:3000" -ForegroundColor Cyan
Write-Host ""
Write-Host "Нажмите Ctrl+C для остановки..." -ForegroundColor Yellow

# Cleanup при выходе
try {
    # Ждем сигнала завершения
    while ($true) {
        Start-Sleep -Seconds 1
    }
} finally {
    Write-Host "🛑 Останавливаем сервисы..." -ForegroundColor Yellow
    if ($backendProcess) { Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue }
    if ($webProcess) { Stop-Process -Id $webProcess.Id -Force -ErrorAction SilentlyContinue }
} 