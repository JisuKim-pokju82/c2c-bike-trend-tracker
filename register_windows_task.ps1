# Register Invisible Windows Scheduled Task (wscript.exe -> launch_hidden.vbs -> run_scheduled_sync.ps1)
# - Short 70-char argument (never hits 8,191-char limit!)
# - Zero console window popup (WindowStyle 0 via WScript.Shell)
$ErrorActionPreference = 'Stop'
$TaskName = "CompetitorBikeTrend_DailyCollector"
$WorkDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkDir) { $WorkDir = "c:\Users\KCAR24N20051\Desktop\바이크" }
$VbsPath  = Join-Path $WorkDir "launch_hidden.vbs"

$Action       = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "//B //NoLogo `"$VbsPath`"" -WorkingDirectory $WorkDir
$TriggerDaily = New-ScheduledTaskTrigger -Daily -At 10:02AM
$Settings     = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -WakeToRun -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $TriggerDaily -Settings $Settings -Description "Daily 10:02 AM invisible sync/dispatch/backup for 5-Platform Motorcycle Tracker" -Force | Out-Null
Write-Host "Registered Invisible Windows Scheduled Task '$TaskName' (wscript.exe -> launch_hidden.vbs at 10:02 AM daily)." -ForegroundColor Green
