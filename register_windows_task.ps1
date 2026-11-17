# Register Backup & Local-Sync Windows Scheduled Task for 10:35 AM KST
# - Primary execution: GitHub Actions Cloud Cron at 10:00 AM KST (runs even when PC is powered off)
# - Local 10:35 AM task:
#     1) If GitHub Cloud already updated today -> pulls fresh DB/CSV/JSON/JS down to local folder
#     2) If GitHub Cloud was delayed/skipped -> runs local collector + uploads to GitHub automatically
$ErrorActionPreference = 'Stop'
$TaskName = "CompetitorBikeTrend_DailyCollector"
$WorkDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkDir) { $WorkDir = (Get-Location).Path }

$InnerScript = @"
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-Location -LiteralPath '$WorkDir'
`$today = ([DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9))).ToString('yyyy-MM-dd')
`$baseRaw = 'https://raw.githubusercontent.com/JisuKim-pokju82/c2c-bike-trend-tracker/main'
`$alreadyUpdatedOnCloud = `$false
try {
    `$raw = (Invoke-RestMethod -Uri "`$baseRaw/competitor_trend.json?t=`$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" -TimeoutSec 15)
    if (`$raw -and @(`$raw | Where-Object { `$_.date -eq `$today }).Count -gt 0) { `$alreadyUpdatedOnCloud = `$true }
} catch {}
if (`$alreadyUpdatedOnCloud) {
    foreach (`$rel in @(
        'index.html', 'competitor_trend.html', 'competitor_trend.json', 'competitor_trend.csv', 'competitor_trend_data.js',
        'database/bike_daily_summary_db.csv', 'database/bike_vehicle_master_db.csv', 'database/db_manifest.json', 'database/portfolio_by_date.json',
        "raw_data/raw_bikes_`$today.csv", 'raw_data/raw_bikes_latest.csv'
    )) {
        try {
            `$dest = Join-Path '$WorkDir' (`$rel -replace '/', '\')
            `$dir  = Split-Path -Parent `$dest
            if (-not (Test-Path `$dir)) { New-Item -ItemType Directory -Path `$dir -Force | Out-Null }
            Invoke-WebRequest -Uri "`$baseRaw/`$rel" -OutFile `$dest -UseBasicParsing -TimeoutSec 30
        } catch {}
    }
} else {
    & '$WorkDir\collect_bike_trend.ps1'
    & '$WorkDir\upload_to_github.ps1'
}
"@

$EncodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($InnerScript))
$CmdArgs    = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $EncodedCmd"

$Action       = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $CmdArgs
$TriggerDaily = New-ScheduledTaskTrigger -Daily -At 10:35AM
$Settings     = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $TriggerDaily -Settings $Settings -Description "10:35 AM sync/backup for Daily 10:00 AM GitHub Cloud 5-Platform Motorcycle Tracker" -Force | Out-Null
Write-Host "Registered Windows Scheduled Task '$TaskName' (10:35 AM Cloud-to-Local sync & backup fallback)." -ForegroundColor Green
