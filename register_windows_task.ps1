# Register Backup & Local-Sync Windows Scheduled Task for 10:05 AM KST (with WakeToRun, IgnoreNew, 180s Network-Wait, Cloud Sync & 3x Retry)
# - Primary execution: GitHub Actions ubuntu-latest Cloud Multi-Cron (09:38 / 09:52 / 10:03 / 10:18 / 10:34 / 10:52 KST) — runs even when PC is off
# - Local 10:05 AM task:
#     1) If GitHub Cloud already updated today -> pulls fresh DB/CSV/JSON/JS down to local folder
#     2) If GitHub Cloud was delayed/skipped -> runs local collector + uploads to GitHub with 3x retry
$ErrorActionPreference = 'Stop'
$TaskName = "CompetitorBikeTrend_DailyCollector"
$WorkDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkDir) { $WorkDir = (Get-Location).Path }

$InnerScript = @"
`$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-Location -LiteralPath '$WorkDir'

`$logDir = Join-Path '$WorkDir' 'logs'
if (-not (Test-Path `$logDir)) { New-Item -ItemType Directory -Path `$logDir -Force | Out-Null }
`$logFile = Join-Path `$logDir 'scheduler.log'
function Write-SchedLog([string]`$msg) {
    `$ts = ([DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9))).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -LiteralPath `$logFile -Value "[`$ts] `$msg" -Encoding UTF8
}

Write-SchedLog "Scheduled 10:05 AM check triggered."

# 1. Wait up to 180s for network/DNS after PC boot or sleep wake-up
`$netReady = `$false
for (`$w = 1; `$w -le 36; `$w++) {
    try {
        `$null = [System.Net.Dns]::GetHostAddresses('api.github.com')
        `$netReady = `$true
        break
    } catch {
        Start-Sleep -Seconds 5
    }
}
if (-not `$netReady) {
    Write-SchedLog "ERROR: Network did not become ready within 180 seconds."
    exit 1
}

# 2. Check if GitHub Cloud already updated today (10:00 AM KST schedule)
`$today = ([DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9))).ToString('yyyy-MM-dd')
`$baseRaw = 'https://raw.githubusercontent.com/JisuKim-pokju82/c2c-bike-trend-tracker/main'
`$alreadyUpdatedOnCloud = `$false
try {
    `$raw = Invoke-RestMethod -Uri "`$baseRaw/competitor_trend.json?t=`$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" -TimeoutSec 15
    foreach (`$r in @(`$raw)) {
        if (`$null -ne `$r -and `$r.date -eq `$today -and [int]`$r.daangnBikeCount -gt 0 -and [int]`$r.reitwagenCount -gt 0 -and [int]`$r.passoCount -gt 0 -and [int]`$r.batumaeCount -gt 0) {
            `$alreadyUpdatedOnCloud = `$true
        }
    }
} catch {}

if (`$alreadyUpdatedOnCloud) {
    Write-SchedLog "Cloud already updated complete 5-platform data for `$today. Syncing fresh files to local folder..."
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
    Write-SchedLog "SUCCESS: Local folder synced with Cloud (`$today)."
    exit 0
}

# 3. Fallback: Run local collection + GitHub upload with up to 3 retries
for (`$attempt = 1; `$attempt -le 3; `$attempt++) {
    try {
        Write-SchedLog "Cloud not yet updated for `$today. Starting local fallback collection & upload (attempt `$attempt/3)..."
        & '$WorkDir\collect_bike_trend.ps1'
        & '$WorkDir\upload_to_github.ps1'
        Write-SchedLog "SUCCESS: Local fallback collection & GitHub sync completed for `$today."
        exit 0
    } catch {
        Write-SchedLog "WARNING (attempt `$attempt/3 failed): `$(`$_.Exception.Message)"
        if (`$attempt -lt 3) { Start-Sleep -Seconds 30 } else { exit 1 }
    }
}
"@

$EncodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($InnerScript))
$CmdArgs    = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $EncodedCmd"

$Action       = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $CmdArgs
$TriggerDaily = New-ScheduledTaskTrigger -Daily -At 10:05AM
$Settings     = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -WakeToRun -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $TriggerDaily -Settings $Settings -Description "10:05 AM WakeToRun sync/backup for Daily 10:00 AM GitHub Cloud 5-Platform Motorcycle Tracker" -Force | Out-Null
Write-Host "Registered Windows Scheduled Task '$TaskName' (10:05 AM WakeToRun Cloud-to-Local sync & 3x-retry fallback)." -ForegroundColor Green
