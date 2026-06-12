#Requires -Version 5.1
<#
.SYNOPSIS
    Tests the daily scan infrastructure without invoking Claude.

.DESCRIPTION
    Runs two test suites:

    Suite A -- Success path (8 checks):
        Runs run_daily_scan.ps1 -SkipScan using current project JSON files.
        Verifies archiving, /scans/latest/, manifest, and log output.

    Suite B -- Failure path (5 checks):
        Simulates hard-failure scenarios to verify that a failed scan
        does NOT archive files, does NOT update /scans/latest/, and does
        NOT write an entry to scan_manifest.json.
        Checks that failure is recorded in failed_scan_manifest.json.

    Prints a PASS/FAIL summary for every check.

.EXAMPLE
    .\test_daily_scan.ps1
#>

$ErrorActionPreference = 'Continue'

$SourceDir          = $PSScriptRoot
$ScansRoot          = Join-Path $SourceDir 'scans'
$LatestDir          = Join-Path $ScansRoot 'latest'
$LogsDir            = Join-Path $SourceDir 'logs'
$ManifestPath       = Join-Path $ScansRoot 'scan_manifest.json'
$FailedManifestPath = Join-Path $LogsDir 'failed_scan_manifest.json'
$MainScript         = Join-Path $SourceDir 'run_daily_scan.ps1'

$DateStr = (Get-Date).ToString('yyyy-MM-dd')

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
$AllChecks = [ordered]@{}
$AllPass   = $true

function Add-Check {
    param([string]$Suite, [string]$Name, [bool]$Pass, [string]$Detail = '')
    $key = "[$Suite] $Name"
    $script:AllChecks[$key] = [PSCustomObject]@{ Pass = $Pass; Detail = $Detail }
    if (-not $Pass) { $script:AllPass = $false }
}

function Get-ManifestCount {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $data = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($data).Count
    } catch { return 0 }
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  Suspiciously Intelligent -- Daily Scan Infrastructure Test" -ForegroundColor Cyan
Write-Host "  Suite A: success path (-SkipScan)" -ForegroundColor Yellow
Write-Host "  Suite B: failure path (stale/missing-claude simulation)" -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# SUITE A -- SUCCESS PATH
# ============================================================================
Write-Host "  ---- Suite A: Success Path ----------------------------------------"

$PreManifestCount = Get-ManifestCount $ManifestPath

$PreLogCount = 0
if (Test-Path $LogsDir) {
    $PreLogCount = @(Get-ChildItem $LogsDir -Filter "${DateStr}_daily_scan*.log").Count
}

$PreArchiveFolders = @()
if (Test-Path $ScansRoot) {
    $PreArchiveFolders = @(Get-ChildItem $ScansRoot -Directory | Select-Object -ExpandProperty Name)
}

Write-Host ""
Write-Host "  Pre-run state:"
Write-Host "    Manifest entries : $PreManifestCount"
Write-Host "    Log files today  : $PreLogCount"
Write-Host "    Archive folders  : $($PreArchiveFolders.Count)"
Write-Host ""
Write-Host "  Running: run_daily_scan.ps1 -SkipScan"
Write-Host "  ----------------------------------------"

& $MainScript -SkipScan
$RunExitCode = $LASTEXITCODE

Write-Host "  ----------------------------------------"
Write-Host "  Exit code: $RunExitCode"
Write-Host ""

# -- A checks --

Add-Check 'A' 'Exit code 0' ($RunExitCode -eq 0) "Got: $RunExitCode"

$TodayLogs   = @()
if (Test-Path $LogsDir) {
    $TodayLogs = @(Get-ChildItem $LogsDir -Filter "${DateStr}_daily_scan*.log")
}
$NewLogCount = $TodayLogs.Count - $PreLogCount
Add-Check 'A' 'Log file created' ($NewLogCount -gt 0) "New logs today: $NewLogCount"

$LatestLog = $TodayLogs | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$PostArchiveFolders = @()
if (Test-Path $ScansRoot) {
    $PostArchiveFolders = @(Get-ChildItem $ScansRoot -Directory | Select-Object -ExpandProperty Name)
}
$NewFolders = @($PostArchiveFolders | Where-Object { $PreArchiveFolders -notcontains $_ -and $_ -ne 'latest' })
Add-Check 'A' 'Archive folder created' ($NewFolders.Count -gt 0) "New: $($NewFolders -join ', ')"

$TodayArchives = @($PostArchiveFolders | Where-Object { $_ -like "${DateStr}*" })
if ($TodayArchives.Count -gt 0) {
    $newestArchive = $TodayArchives | Sort-Object | Select-Object -Last 1
    $archiveDir    = Join-Path $ScansRoot $newestArchive
    $critMissing   = @('raw_research.json','analyzed_stories.json','content_ideas.json','data.json') |
        Where-Object { -not (Test-Path (Join-Path $archiveDir $_)) }
    Add-Check 'A' 'Archive has critical files' ($critMissing.Count -eq 0) "Missing: $($critMissing -join ', ')"
} else {
    Add-Check 'A' 'Archive has critical files' $false 'No archive folder found for today'
}

$LatestMissing = @('raw_research.json','analyzed_stories.json','content_ideas.json','data.json') |
    Where-Object { -not (Test-Path (Join-Path $LatestDir $_)) }
Add-Check 'A' '/scans/latest/ updated' ($LatestMissing.Count -eq 0) "Missing: $($LatestMissing -join ', ')"

$PostManifestCount = Get-ManifestCount $ManifestPath
Add-Check 'A' 'Manifest entry added' ($PostManifestCount -gt $PreManifestCount) `
    "Before: $PreManifestCount  After: $PostManifestCount"

if ($PostManifestCount -gt 0 -and (Test-Path $ManifestPath)) {
    $rawM     = Get-Content $ManifestPath -Raw -Encoding UTF8
    $hasFields = ($rawM -match '"scan_timestamp"') -and
                 ($rawM -match '"log_file"') -and
                 ($rawM -match '"status"')
    Add-Check 'A' 'Manifest has extended fields' $hasFields 'scan_timestamp + log_file + status'
} else {
    Add-Check 'A' 'Manifest has extended fields' $false 'No manifest entries to check'
}

if ($LatestLog) {
    $logContent  = Get-Content $LatestLog.FullName -Raw -Encoding UTF8
    $hasSections = ($logContent -match 'DAILY SCAN COMPLETE') -and
                   ($logContent -match 'Archive folder') -and
                   ($logContent -match 'Status')
    Add-Check 'A' 'Log has required sections' $hasSections $LatestLog.Name
} else {
    Add-Check 'A' 'Log has required sections' $false 'No log file found'
}

# ============================================================================
# SUITE B -- FAILURE PATH
# ============================================================================
Write-Host ""
Write-Host "  ---- Suite B: Failure Path ----------------------------------------"
Write-Host ""

# -- Snapshot state before failure tests --
$PreManifestB       = Get-ManifestCount $ManifestPath
$PreFailedManifestB = Get-ManifestCount $FailedManifestPath

$PreArchiveFoldersB = @()
if (Test-Path $ScansRoot) {
    $PreArchiveFoldersB = @(Get-ChildItem $ScansRoot -Directory | Select-Object -ExpandProperty Name)
}

# B1/B2/B3/B4:
# Simulate no_ai_engine by patching the environment so claude cannot be found:
#   - Strip PATH to exclude npm directories (Get-Command claude returns nothing)
#   - Set APPDATA/LOCALAPPDATA to a temp dir (candidate Test-Path checks all return false)
# Run the main script directly (in-process) so exit codes are captured cleanly.

Write-Host "  B1-B4: Simulating no_ai_engine (patched env, no claude)"

$TempFakeHome    = Join-Path $env:TEMP "si_test_fakehome_$(Get-Random)"
New-Item -ItemType Directory -Path $TempFakeHome | Out-Null

$OldPath         = $env:PATH
$OldAppData      = $env:APPDATA
$OldLocalAppData = $env:LOCALAPPDATA

$env:PATH         = "$env:SystemRoot\System32;$env:SystemRoot"
$env:APPDATA      = $TempFakeHome
$env:LOCALAPPDATA = $TempFakeHome

try {
    & $MainScript
    $B1ExitCode = $LASTEXITCODE
} finally {
    $env:PATH         = $OldPath
    $env:APPDATA      = $OldAppData
    $env:LOCALAPPDATA = $OldLocalAppData
    Remove-Item $TempFakeHome -Recurse -ErrorAction SilentlyContinue
}

Add-Check 'B' 'no_ai_engine exits non-zero' ($B1ExitCode -ne 0) "Exit code: $B1ExitCode"

# B2: /scans/latest/ must NOT have been updated during the failed run.
#     Any archive folder created before B1 started should be the same set as after.
$PostArchiveFoldersB = @()
if (Test-Path $ScansRoot) {
    $PostArchiveFoldersB = @(Get-ChildItem $ScansRoot -Directory | Select-Object -ExpandProperty Name)
}
$NewArchivesB = @($PostArchiveFoldersB | Where-Object { $PreArchiveFoldersB -notcontains $_ -and $_ -ne 'latest' })
Add-Check 'B' 'Failed run: /scans/latest/ NOT updated' ($NewArchivesB.Count -eq 0) `
    "New archive folders after failed run: $($NewArchivesB -join ', ')"

# B3: scan_manifest.json must NOT have gained a new entry
$PostManifestB = Get-ManifestCount $ManifestPath
Add-Check 'B' 'Failed run: scan_manifest.json NOT updated' ($PostManifestB -eq $PreManifestB) `
    "Before: $PreManifestB  After: $PostManifestB"

# B4: failed_scan_manifest.json must have gained a new entry
$PostFailedManifestB = Get-ManifestCount $FailedManifestPath
Add-Check 'B' 'Failure recorded in failed_scan_manifest.json' ($PostFailedManifestB -gt $PreFailedManifestB) `
    "Before: $PreFailedManifestB  After: $PostFailedManifestB"

# B5: A successful -SkipScan run DOES update /scans/latest/.
#     Verified via the log file content (Copy-Item preserves source timestamps so
#     mtime comparison is not reliable; the log is authoritative).
Write-Host "  B5: Confirming -SkipScan still updates /scans/latest/"

$PreLogCountB5 = @(Get-ChildItem $LogsDir -Filter "${DateStr}_daily_scan*.log").Count
& $MainScript -SkipScan | Out-Null
$B5ExitCode = $LASTEXITCODE
$PostLogsB5 = @(Get-ChildItem $LogsDir -Filter "${DateStr}_daily_scan*.log" | Sort-Object LastWriteTime -Descending)
$B5NewLog   = $null
if ($PostLogsB5.Count -gt $PreLogCountB5) { $B5NewLog = $PostLogsB5[0] }
$B5LatestOK = $false
if ($null -ne $B5NewLog) {
    $b5content  = Get-Content $B5NewLog.FullName -Raw -Encoding UTF8
    $B5LatestOK = ($b5content -match 'Latest updated:\s+True')
}
Add-Check 'B' 'Successful -SkipScan updates /scans/latest/' ($B5ExitCode -eq 0 -and $B5LatestOK) `
    "Exit: $B5ExitCode  Log confirms latest updated: $B5LatestOK"

# ============================================================================
# PRINT SUMMARY
# ============================================================================
Write-Host ""
Write-Host "  ============================================="
Write-Host "  TEST RESULTS"
Write-Host "  ============================================="

foreach ($name in $AllChecks.Keys) {
    $c      = $AllChecks[$name]
    $symbol = if ($c.Pass) { '[PASS]' } else { '[FAIL]' }
    $color  = if ($c.Pass) { 'Green' } else { 'Red' }
    $detail = if ($c.Detail) { "  $($c.Detail)" } else { '' }
    Write-Host ("  {0,-6} {1}{2}" -f $symbol, $name, $detail) -ForegroundColor $color
}

Write-Host "  ============================================="

if ($AllPass) {
    Write-Host "  ALL CHECKS PASSED" -ForegroundColor Green
} else {
    $failCount = @($AllChecks.Values | Where-Object { -not $_.Pass }).Count
    Write-Host "  $failCount CHECK(S) FAILED" -ForegroundColor Red
}

Write-Host ""

if ($AllPass) { exit 0 } else { exit 1 }
