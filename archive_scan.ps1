#Requires -Version 5.1
<#
.SYNOPSIS
    Archives a completed Suspiciously Intelligent pipeline run.

.DESCRIPTION
    Copies all pipeline outputs into a dated folder under /scans/, updates
    /scans/latest/, appends archive metadata to run_report.md, and updates
    scan_manifest.json.  Never overwrites previous dated folders.

.PARAMETER SourceDir
    Directory containing pipeline output files. Defaults to the script's
    own directory (the project root).

.PARAMETER DryRun
    Validates and reports without writing any files.

.EXAMPLE
    .\archive_scan.ps1
    .\archive_scan.ps1 -DryRun
    .\archive_scan.ps1 -SourceDir "C:\path\to\project"
#>

param(
    [string]$SourceDir = $PSScriptRoot,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -- Constants ----------------------------------------------------------------

$REQUIRED_FILES = @(
    'raw_research.json',
    'analyzed_stories.json',
    'content_ideas.json',
    'data.json',
    'ideas.md',
    'run_report.md'
)
$OPTIONAL_FILES = @('workspace_snapshot.json')

$ScansRoot    = Join-Path $SourceDir 'scans'
$LatestDir    = Join-Path $ScansRoot 'latest'
$ManifestPath = Join-Path $ScansRoot 'scan_manifest.json'
$Timestamp    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$DateStr      = (Get-Date).ToString('yyyy-MM-dd')

# -- Step 1: Validate required files ------------------------------------------

Write-Host ""
Write-Host "  archive_scan.ps1" -ForegroundColor Cyan
Write-Host "  $(if ($DryRun) {'DRY RUN - no files will be written'} else {'Archiving pipeline run...'})" -ForegroundColor $(if ($DryRun) {'Yellow'} else {'Cyan'})
Write-Host ""

$missing = $REQUIRED_FILES | Where-Object { -not (Test-Path (Join-Path $SourceDir $_)) }
if ($missing) {
    Write-Host "  ABORTED - missing required files:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "    [-] $_" -ForegroundColor Red }
    exit 1
}
$REQUIRED_FILES | ForEach-Object { Write-Host "  [+] $_" -ForegroundColor Green }
$OPTIONAL_FILES | ForEach-Object {
    if (Test-Path (Join-Path $SourceDir $_)) {
        Write-Host "  [+] $_ (optional)" -ForegroundColor DarkGreen
    }
}
Write-Host ""

# -- Step 2: Collision-safe dated folder name ----------------------------------

$FolderName = $DateStr
$Counter    = 0
while (Test-Path (Join-Path $ScansRoot $FolderName)) {
    $Counter++
    $FolderName = '{0}_{1:D2}' -f $DateStr, $Counter
}
$DestDir = Join-Path $ScansRoot $FolderName

Write-Host "  Target folder : scans/$FolderName" -ForegroundColor White
if ($Counter -gt 0) {
    Write-Host "  (collision detected - $Counter earlier scan(s) exist for $DateStr)" -ForegroundColor Yellow
}

# -- Step 3: Extract metadata from data.json -----------------------------------

$storyCount    = 0
$verifiedCount = 0
$highRiskCount = 0
$topStory      = ''
$scanDate      = $Timestamp
$topCluster    = ''

try {
    $dataJson  = Get-Content (Join-Path $SourceDir 'data.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $stories   = @($dataJson.stories)
    $storyCount    = $stories.Count
    $verifiedCount = @($stories | Where-Object { $_.verified -eq $true }).Count
    $highRiskCount = @($stories | Where-Object { $_.risk_level -eq 'high' }).Count
    $topStoryObj   = $stories | Sort-Object score -Descending | Select-Object -First 1
    $topStory      = if ($topStoryObj) { [string]$topStoryObj.headline } else { '' }
    $metaScanDateProp = $dataJson.meta.PSObject.Properties['scan_date']
    if ($metaScanDateProp) { $scanDate = [string]$metaScanDateProp.Value }
} catch {
    Write-Warning "  Could not parse data.json metadata: $_"
}

try {
    $analyzed  = Get-Content (Join-Path $SourceDir 'analyzed_stories.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $aStories  = if ($analyzed.PSObject.Properties['stories']) { @($analyzed.stories) } else { @($analyzed) }
    $catGroups = $aStories | Group-Object source_category | Sort-Object Count -Descending
    $topCluster = if ($catGroups) { [string]$catGroups[0].Name } else { '' }
} catch {
    Write-Warning "  Could not derive top_cluster from analyzed_stories.json: $_"
}

# -- Step 4: Load + update manifest -------------------------------------------

$scanId = "scan-$FolderName"

$newEntry = [ordered]@{
    scan_id        = $scanId
    date           = $scanDate
    folder         = $FolderName
    story_count    = $storyCount
    verified_count = $verifiedCount
    high_risk_count = $highRiskCount
    top_cluster    = $topCluster
    top_story      = $topStory
}

$manifest = [System.Collections.Generic.List[object]]::new()
if (Test-Path $ManifestPath) {
    try {
        $existing = Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        @($existing) | ForEach-Object { $manifest.Add($_) }
    } catch {
        Write-Warning "  Could not parse existing manifest; starting fresh."
    }
}
$manifest.Add([PSCustomObject]$newEntry)
$totalScans = $manifest.Count

# -- Step 5: Build archive metadata block for run_report.md -------------------

$archiveBlock = @"


---

## Archive metadata

| Field | Value |
|---|---|
| Scan timestamp | $Timestamp |
| Archive folder | scans/$FolderName |
| Latest updated | Yes |
| Total archived scans | $totalScans |
| Scan ID | $scanId |
"@

# -- Step 6: Write files (unless --DryRun) ------------------------------------

if (-not $DryRun) {
    # Create scans root
    if (-not (Test-Path $ScansRoot)) {
        New-Item -ItemType Directory -Path $ScansRoot | Out-Null
    }

    # Create dated archive folder
    New-Item -ItemType Directory -Path $DestDir | Out-Null

    # Copy files to dated folder
    foreach ($f in $REQUIRED_FILES + $OPTIONAL_FILES) {
        $src = Join-Path $SourceDir $f
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $DestDir $f)
        }
    }

    # Append archive block to source run_report.md, then re-copy to archive
    $reportPath = Join-Path $SourceDir 'run_report.md'
    Add-Content -Path $reportPath -Value $archiveBlock -Encoding UTF8
    Copy-Item -Path $reportPath -Destination (Join-Path $DestDir 'run_report.md') -Force

    # Update /scans/latest/
    if (-not (Test-Path $LatestDir)) {
        New-Item -ItemType Directory -Path $LatestDir | Out-Null
    }
    foreach ($f in $REQUIRED_FILES + $OPTIONAL_FILES) {
        $src = Join-Path $SourceDir $f
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $LatestDir $f) -Force
        }
    }

    # Write updated manifest
    ConvertTo-Json -InputObject ([object[]]$manifest) -Depth 5 | Set-Content -Path $ManifestPath -Encoding UTF8

    Write-Host "  Files archived  : scans/$FolderName" -ForegroundColor Green
    Write-Host "  Latest updated  : scans/latest/" -ForegroundColor Green
    Write-Host "  Manifest updated: $totalScans total scan(s)" -ForegroundColor Green
} else {
    Write-Host "  [DRY RUN] Would create: scans/$FolderName" -ForegroundColor Yellow
    Write-Host "  [DRY RUN] Would update: scans/latest/, scan_manifest.json, run_report.md" -ForegroundColor Yellow
}

# -- Summary -------------------------------------------------------------------

$topShort = if ($topStory.Length -gt 72) { $topStory.Substring(0,69) + '...' } else { $topStory }

Write-Host ""
Write-Host "  ------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Stories   : $storyCount   Verified: $verifiedCount   High-risk: $highRiskCount" -ForegroundColor White
Write-Host "  Top story : $topShort" -ForegroundColor White
Write-Host "  Scan ID   : $scanId" -ForegroundColor White
Write-Host "  ------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""
