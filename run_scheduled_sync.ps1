# Standalone Scheduled Sync & Fallback Runner for 5-Platform Motorcycle Tracker (09:05 AM KST)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$WorkDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkDir) { $WorkDir = "c:\Users\KCAR24N20051\Desktop\바이크" }
Set-Location -LiteralPath $WorkDir

$logDir = Join-Path $WorkDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "scheduler.log"

function Write-SchedLog([string]$msg) {
    $ts = ([DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9))).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -LiteralPath $logFile -Value "[$ts] $msg" -Encoding UTF8
}

Write-SchedLog "Scheduled daily sync/backup check started."

# 1. Wait up to 180s for network/DNS after PC wake/boot
$netReady = $false
for ($w = 1; $w -le 36; $w++) {
    try {
        $null = [System.Net.Dns]::GetHostAddresses("api.github.com")
        $netReady = $true
        break
    } catch {
        Start-Sleep -Seconds 5
    }
}
if (-not $netReady) {
    Write-SchedLog "ERROR: Network did not become ready within 180 seconds."
    exit 1
}

$today = ([DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9))).ToString("yyyy-MM-dd")
$baseRaw = "https://raw.githubusercontent.com/JisuKim-pokju82/c2c-bike-trend-tracker/main"

function Test-CloudUpdatedToday {
    try {
        $raw = Invoke-RestMethod -Uri "$baseRaw/competitor_trend.json?t=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" -TimeoutSec 15
        foreach ($r in @($raw)) {
            if ($null -ne $r -and $r.date -eq $today -and [int]$r.daangnBikeCount -gt 0 -and [int]$r.reitwagenCount -gt 0 -and [int]$r.passoCount -gt 0 -and [int]$r.batumaeCount -gt 0) {
                return $true
            }
        }
    } catch {}
    return $false
}

function Sync-CloudToLocal {
    foreach ($rel in @(
        "index.html", "competitor_trend.html", "competitor_trend.json", "competitor_trend.csv", "competitor_trend_data.js",
        "database/bike_daily_summary_db.csv", "database/bike_vehicle_master_db.csv", "database/db_manifest.json", "database/portfolio_by_date.json",
        "raw_data/raw_bikes_$today.csv", "raw_data/raw_bikes_latest.csv"
    )) {
        try {
            $dest = Join-Path $WorkDir ($rel -replace '/', '\')
            $dir  = Split-Path -Parent $dest
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Invoke-WebRequest -Uri "$baseRaw/${rel}?t=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" -OutFile $dest -UseBasicParsing -TimeoutSec 30
        } catch {}
    }
}

# 2. Check if GitHub Cloud already completed today's 09:00 AM update
if (Test-CloudUpdatedToday) {
    Write-SchedLog "Cloud already updated complete 5-platform data for $today. Syncing fresh files to local folder..."
    Sync-CloudToLocal
    Write-SchedLog "SUCCESS: Local folder synced with Cloud ($today)."
    exit 0
}

# 3. If Cloud has not completed yet, trigger GitHub Cloud workflow_dispatch first (runs on fast ubuntu-latest)
$ghExe = "C:\Program Files\GitHub CLI\gh.exe"
if (Test-Path $ghExe) {
    try {
        Write-SchedLog "Cloud not yet updated for $today. Dispatching GitHub Cloud ubuntu-latest workflow..."
        & $ghExe workflow run "daily_bike_tracker.yml" --repo "JisuKim-pokju82/c2c-bike-trend-tracker" | Out-Null
        for ($waitMin = 1; $waitMin -le 12; $waitMin++) {
            Start-Sleep -Seconds 30
            if (Test-CloudUpdatedToday) {
                Write-SchedLog "Cloud workflow finished for $today! Syncing fresh files to local folder..."
                Sync-CloudToLocal
                Write-SchedLog "SUCCESS: Dispatched Cloud run & synced local folder ($today)."
                exit 0
            }
        }
    } catch {
        Write-SchedLog "Cloud dispatch warning: $($_.Exception.Message)"
    }
}

# 4. Ultimate Fallback: Run local collection + GitHub upload directly (up to 2 retries)
for ($attempt = 1; $attempt -le 2; $attempt++) {
    try {
        Write-SchedLog "Starting local fallback collection & upload (attempt $attempt/2)..."
        & "$WorkDir\collect_bike_trend.ps1"
        & "$WorkDir\upload_to_github.ps1"
        Write-SchedLog "SUCCESS: Local fallback collection & GitHub sync completed for $today."
        exit 0
    } catch {
        Write-SchedLog "WARNING (attempt $attempt/2 failed): $($_.Exception.Message)"
        if ($attempt -lt 2) { Start-Sleep -Seconds 30 } else { exit 1 }
    }
}
