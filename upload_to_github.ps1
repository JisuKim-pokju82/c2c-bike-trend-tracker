$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$gh = "C:\Program Files\GitHub CLI\gh.exe"
$token = (& $gh auth token).Trim()
$headers = @{
    "Authorization"        = "Bearer $token"
    "Accept"               = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent"           = "Antigravity-Agent"
}

$Owner = "JisuKim-pokju82"
$Repo  = "c2c-bike-trend-tracker"
$WorkDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkDir) { $WorkDir = "c:\Users\KCAR24N20051\Desktop\바이크" }
$TodayDate = ([DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9))).ToString("yyyy-MM-dd")

# 1. Sync data, scripts, and dashboard HTML via Git Data API (fast multi-file commit, non-forced)
$refInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/git/ref/heads/main" -Headers $headers -Method Get
$baseCommitSha = $refInfo.object.sha
$commitInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/git/commits/$baseCommitSha" -Headers $headers -Method Get
$baseTreeSha = $commitInfo.tree.sha

$filesToUpload = @(
    "README.md",
    "collect_bike_trend.ps1",
    "upload_to_github.ps1",
    "register_windows_task.ps1",
    "index.html",
    "competitor_trend.html",
    "competitor_trend.csv",
    "competitor_trend.json",
    "competitor_trend_data.js",
    "raw_data/raw_bikes_2026-11-16.csv",
    "raw_data/raw_bikes_$($TodayDate).csv",
    "raw_data/raw_bikes_latest.csv",
    "raw_data/daangn_bike_urls_$($TodayDate).csv",
    "database/bike_daily_summary_db.csv",
    "database/bike_vehicle_master_db.csv",
    "database/db_manifest.json",
    "database/portfolio_by_date.json",
    "snapshots/daangn_bike_$($TodayDate).json",
    "snapshots/daangn_bike_latest.json",
    "snapshots/reitwagen_$($TodayDate).json",
    "snapshots/reitwagen_latest.json",
    "snapshots/passo_used_$($TodayDate).json",
    "snapshots/passo_used_latest.json",
    "snapshots/batumae_$($TodayDate).json",
    "snapshots/batumae_latest.json"
)

$treeItems = New-Object System.Collections.Generic.List[object]
foreach ($relPath in $filesToUpload) {
    $fullPath = Join-Path $WorkDir ($relPath -replace '/', '\')
    if (-not (Test-Path $fullPath)) { continue }
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    $b64 = [Convert]::ToBase64String($bytes)
    $blobBody = @{ content = $b64; encoding = "base64" } | ConvertTo-Json -Compress
    $blobRes = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/git/blobs" -Headers $headers -Method Post -ContentType "application/json" -Body $blobBody
    $treeItems.Add([ordered]@{
        path = $relPath
        mode = "100644"
        type = "blob"
        sha  = $blobRes.sha
    })
}

$treeBody = @{ base_tree = $baseTreeSha; tree = $treeItems } | ConvertTo-Json -Depth 5 -Compress
$newTree = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/git/trees" -Headers $headers -Method Post -ContentType "application/json" -Body $treeBody

if ($newTree.sha -ne $baseTreeSha) {
    $commitBody = @{
        message = "chore(data): sync 5-platform motorcycle trend & RAW data ($TodayDate)"
        tree    = $newTree.sha
        parents = @($baseCommitSha)
    } | ConvertTo-Json -Compress
    $newCommit = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/git/commits" -Headers $headers -Method Post -ContentType "application/json" -Body $commitBody

    $refUpdateBody = @{ sha = $newCommit.sha; force = $false } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/git/refs/heads/main" -Headers $headers -Method Patch -ContentType "application/json" -Body $refUpdateBody | Out-Null
    Write-Host "Synced ($TodayDate) data & dashboard to GitHub ($($newCommit.sha))!" -ForegroundColor Green
}

# 2. Ensure .github/workflows/daily_bike_tracker.yml is committed via Contents API PUT
#    (Contents API triggers GitHub's push event so Actions Cron Scheduler officially registers cron '0 1 * * *')
$wfRel = ".github/workflows/daily_bike_tracker.yml"
$wfFull = Join-Path $WorkDir ($wfRel -replace '/', '\')
if (Test-Path $wfFull) {
    $wfBytes = [System.IO.File]::ReadAllBytes($wfFull)
    $wfB64   = [Convert]::ToBase64String($wfBytes)
    $remoteWf = $null
    try {
        $remoteWf = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/contents/$wfRel" -Headers $headers -Method Get
    } catch {}

    $remoteCleanB64 = if ($remoteWf -and $remoteWf.content) { ($remoteWf.content -replace '\s+', '') } else { "" }
    if ($remoteCleanB64 -ne $wfB64) {
        $putBody = [ordered]@{
            message = "ci(schedule): register daily 10:00 KST (01:00 UTC) 5-platform cloud cron schedule"
            content = $wfB64
            branch  = "main"
        }
        if ($remoteWf -and $remoteWf.sha) { $putBody["sha"] = $remoteWf.sha }
        $putJson = $putBody | ConvertTo-Json -Compress
        $putRes = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/contents/$wfRel" -Headers $headers -Method Put -ContentType "application/json" -Body $putJson
        Write-Host "Registered workflow schedule via Contents API ($($putRes.commit.sha))!" -ForegroundColor Cyan
    }
}
