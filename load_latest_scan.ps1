#Requires -Version 5.1
<#
.SYNOPSIS
    Loads a scan from /scans/ into the project working directory.

.DESCRIPTION
    Without arguments, copies /scans/latest/ into the project root so the
    dashboard can be opened immediately.  Pass -ScanDate to load a specific
    historical scan.  Pass -ListOnly to browse available scans without
    copying anything.

.PARAMETER ScanDate
    Date string to load, e.g. "2026-05-06" or "2026-05-08_01".
    Omit to load /scans/latest/.

.PARAMETER TargetDir
    Destination directory. Defaults to the script's own directory.

.PARAMETER ListOnly
    Print the scan manifest and exit without copying files.

.EXAMPLE
    .\load_latest_scan.ps1
    .\load_latest_scan.ps1 -ListOnly
    .\load_latest_scan.ps1 -ScanDate 2026-05-06
    .\load_latest_scan.ps1 -ScanDate 2026-05-08_01 -TargetDir C:\somewhere\else
#>

param(
    [string]$ScanDate  = '',
    [string]$TargetDir = $PSScriptRoot,
    [switch]$ListOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScansRoot    = Join-Path $PSScriptRoot 'scans'
$ManifestPath = Join-Path $ScansRoot 'scan_manifest.json'
$FILES        = @('raw_research.json','analyzed_stories.json','content_ideas.json','data.json','ideas.md','run_report.md')

# -- List available scans ------------------------------------------------------

Write-Host ""
Write-Host "  load_latest_scan.ps1" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ScansRoot)) {
    Write-Host "  No scans directory found." -ForegroundColor Yellow
    Write-Host "  Run .\archive_scan.ps1 after a pipeline run to create the first archive." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

$manifest = @()
if (Test-Path $ManifestPath) {
    try {
        $manifest = @(Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch {
        Write-Warning "  Could not parse scan_manifest.json."
    }
}

if ($manifest.Count -eq 0) {
    Write-Host "  No scans in manifest yet." -ForegroundColor Yellow
    if ($ListOnly) { Write-Host ""; exit 0 }
} else {
    Write-Host "  Available scans ($($manifest.Count) total):" -ForegroundColor White
    Write-Host ""
    $sorted = $manifest | Sort-Object date -Descending
    $latestFolder = $sorted | Select-Object -First 1 -ExpandProperty folder
    foreach ($entry in $sorted) {
        $tag   = if ($entry.folder -eq $latestFolder) { '  [LATEST]' } else { '' }
        $color = if ($entry.folder -eq $latestFolder) { 'Green' } else { 'Gray' }
        $short = if ($entry.top_story.Length -gt 60) { $entry.top_story.Substring(0,57)+'...' } else { $entry.top_story }
        Write-Host ("  {0,-22}{1,3} stories  {2}{3}" -f $entry.folder, $entry.story_count, $short, $tag) -ForegroundColor $color
    }
    Write-Host ""
}

if ($ListOnly) { exit 0 }

# -- Resolve source directory --------------------------------------------------

if ($ScanDate -ne '') {
    # Match exact folder name or date prefix
    $match = Get-ChildItem $ScansRoot -Directory |
             Where-Object { $_.Name -eq $ScanDate -or $_.Name -like "$ScanDate*" } |
             Sort-Object Name -Descending |
             Select-Object -First 1
    if (-not $match) {
        Write-Host "  ERROR: No scan folder found matching: $ScanDate" -ForegroundColor Red
        Write-Host "  Use -ListOnly to see available scans." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    $SourceDir  = $match.FullName
    $SourceLabel = $match.Name
} else {
    $SourceDir   = Join-Path $ScansRoot 'latest'
    $SourceLabel = 'latest'
    if (-not (Test-Path $SourceDir)) {
        Write-Host "  ERROR: /scans/latest/ not found." -ForegroundColor Red
        Write-Host "  Run .\archive_scan.ps1 first." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

# -- Copy files ----------------------------------------------------------------

Write-Host "  Loading from : scans/$SourceLabel" -ForegroundColor Cyan
Write-Host "  Target dir   : $TargetDir" -ForegroundColor Cyan
Write-Host ""

$copied  = 0
$skipped = 0
foreach ($f in $FILES) {
    $src = Join-Path $SourceDir $f
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $TargetDir $f) -Force
        Write-Host "  [+] $f" -ForegroundColor Green
        $copied++
    } else {
        Write-Host "  [-] $f  (not in source)" -ForegroundColor Yellow
        $skipped++
    }
}

Write-Host ""
Write-Host "  $copied file(s) loaded" $(if ($skipped -gt 0) { "  ($skipped missing from source)" } else { '' }) -ForegroundColor White
Write-Host "  Open dashboard.html in your browser to view." -ForegroundColor Cyan

# Show matched manifest entry if loading a dated scan
if ($ScanDate -ne '' -and $manifest.Count -gt 0) {
    $entry = $manifest | Where-Object { $_.folder -eq $SourceLabel } | Select-Object -First 1
    if ($entry) {
        Write-Host ""
        Write-Host ("  Scan date  : {0}" -f $entry.date) -ForegroundColor Gray
        Write-Host ("  Stories    : {0}  Verified: {1}  High-risk: {2}" -f $entry.story_count, $entry.verified_count, $entry.high_risk_count) -ForegroundColor Gray
    }
}

Write-Host ""
