# Register Backup Windows Scheduled Task for 10:15 AM KST (skips if GitHub Cloud already updated today)
$ErrorActionPreference = 'Stop'
$TaskName = "CompetitorBikeTrend_DailyCollector"
$WorkDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkDir) { $WorkDir = (Get-Location).Path }

$InnerScript = @"
Set-ExecutionPolicy Bypass -Scope Process -Force
Set-Location -LiteralPath '$WorkDir'
`$today = ([DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9))).ToString('yyyy-MM-dd')
`$alreadyUpdatedOnCloud = `$false
try {
    `$raw = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/JisuKim-pokju82/c2c-bike-trend-tracker/main/competitor_trend.json' -TimeoutSec 15)
    if (`$raw -and @(`$raw | Where-Object { `$_.date -eq `$today }).Count -gt 0) { `$alreadyUpdatedOnCloud = `$true }
} catch {}
if (-not `$alreadyUpdatedOnCloud) {
    & '$WorkDir\collect_bike_trend.ps1'
    & '$WorkDir\upload_to_github.ps1'
}
"@

$EncodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($InnerScript))
$CmdArgs    = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $EncodedCmd"

$Action       = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $CmdArgs
$TriggerDaily = New-ScheduledTaskTrigger -Daily -At 10:15AM
$Settings     = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $TriggerDaily -Settings $Settings -Description "Backup 10:15 AM check for Daily 10:00 AM GitHub Cloud 5-Platform Motorcycle Tracker" -Force | Out-Null
Write-Host "Backup Windows Scheduled Task '$TaskName' registered (10:15 AM fallback if GitHub Cloud cron ever delays)." -ForegroundColor Green
