#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the Suspiciously Intelligent daily editorial scan pipeline.

.DESCRIPTION
    Invokes Claude Code CLI to execute the 5-phase AI news pipeline,
    validates all output files, checks file freshness, archives the run
    to /scans/YYYY-MM-DD/, updates /scans/latest/, updates
    scan_manifest.json, and writes a timestamped log to /logs/.

    Hard failure (no_ai_engine / scan_error / timeout / stale_output):
    - Archive is skipped
    - /scans/latest/ is NOT updated
    - scan_manifest.json is NOT appended to
    - A failure entry is written to /logs/failed_scan_manifest.json
    - Diagnostics are copied to /scans_failed/YYYY-MM-DD_HHMMSS/

.PARAMETER SkipScan
    Skip the Claude CLI invocation and use existing JSON files as-is.
    The freshness gate is also skipped. For infrastructure testing only.

.PARAMETER DryRun
    Validate and log without writing any archive or manifest files.

.PARAMETER ScanTimeoutMinutes
    Maximum minutes to wait for Claude to finish. Default: 90.

.PARAMETER PromptFile
    Prompt file passed to Claude. Default: daily_scan_prompt.txt.
    Falls back to AGENT_README.md if not found.

.EXAMPLE
    .\run_daily_scan.ps1
    .\run_daily_scan.ps1 -SkipScan
    .\run_daily_scan.ps1 -DryRun
#>

param(
    [switch]$SkipScan,
    [switch]$DryRun,
    [int]   $ScanTimeoutMinutes = 90,
    [string]$PromptFile = 'daily_scan_prompt.txt'
)

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
$SCRIPT_VERSION = '1.4'
$REQUIRED_FILES = @(
    'raw_research.json',
    'analyzed_stories.json',
    'content_ideas.json',
    'data.json',
    'ideas.md',
    'run_report.md'
)
$CRITICAL_JSON = @(
    'raw_research.json',
    'analyzed_stories.json',
    'content_ideas.json',
    'data.json'
)
# Statuses that are hard failures: no archive, no latest update, no success manifest entry
$HARD_FAIL_STATUSES = @('no_ai_engine', 'scan_error', 'timeout', 'stale_output', 'validation_failed')

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$SourceDir          = $PSScriptRoot
$ScansRoot          = Join-Path $SourceDir 'scans'
$LatestDir          = Join-Path $ScansRoot 'latest'
$LogsDir            = Join-Path $SourceDir 'logs'
$ManifestPath       = Join-Path $ScansRoot 'scan_manifest.json'
$FailedManifestPath = Join-Path $LogsDir 'failed_scan_manifest.json'
$ScansFailedRoot    = Join-Path $SourceDir 'scans_failed'

# ---------------------------------------------------------------------------
# Create /logs/ if needed
# ---------------------------------------------------------------------------
if (-not (Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir | Out-Null
}

# Collision-safe log file name
$DateStr    = (Get-Date).ToString('yyyy-MM-dd')
$LogBase    = "${DateStr}_daily_scan"
$LogPath    = Join-Path $LogsDir "${LogBase}.log"
$LogCounter = 0
while (Test-Path $LogPath) {
    $LogCounter++
    $LogPath = Join-Path $LogsDir ('{0}_{1:D2}.log' -f $LogBase, $LogCounter)
}
$LogRelPath = 'logs\' + (Split-Path $LogPath -Leaf)

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
function Write-Log {
    param(
        [string]$Msg,
        [string]$Level = 'INFO'
    )
    $ts   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $line = "[$ts] [$Level] $Msg"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Write-LogRaw {
    param([string]$Text)
    Add-Content -Path $LogPath -Value $Text -Encoding UTF8
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
$StartTime          = Get-Date
$Status             = 'success'
$ScanWasSkipped     = $SkipScan.IsPresent
$ValidationErrors   = New-Object System.Collections.ArrayList
$FreshnessErrors    = New-Object System.Collections.ArrayList
$ArchiveFolder      = ''
$LatestUpdated      = $false
$ClaudeAvailable    = $false
$ClaudeExit         = $null
$FreshnessFailed    = $false
$ValidationFailed   = $false

# Metrics
$RawStoryCount      = 0
$AnalyzedStoryCount = 0
$ContentIdeaCount   = 0
$VerifiedCount      = 0
$SingleSourceCount  = 0
$HighRiskCount      = 0
$UnderreportedCount = 0
$TopCluster         = 'unknown'
$TopStory           = ''

# ============================================================================
# STEP 1 -- HEADER
# ============================================================================
Write-Log "============================================================"
Write-Log "Suspiciously Intelligent Daily Scan v$SCRIPT_VERSION"
Write-Log "Start:    $($StartTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
Write-Log "SkipScan: $($SkipScan.IsPresent)  DryRun: $($DryRun.IsPresent)"
Write-Log "============================================================"

# ============================================================================
# STEP 2 -- PREREQUISITES
# ============================================================================
Write-Log '--- Prerequisites ---'

if (-not (Test-Path $ScansRoot)) {
    Write-Log 'Creating /scans/ directory' 'WARN'
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $ScansRoot | Out-Null
    }
}

# Resolve prompt file
$PromptPath = Join-Path $SourceDir $PromptFile
if (-not (Test-Path $PromptPath)) {
    $PromptPath = Join-Path $SourceDir 'AGENT_README.md'
    Write-Log "Prompt file '$PromptFile' not found -- falling back to AGENT_README.md" 'WARN'
}
Write-Log "Prompt: $PromptPath"

# ============================================================================
# STEP 3 -- AI SCAN (unless -SkipScan)
# ============================================================================
if (-not $ScanWasSkipped) {
    Write-Log '--- AI scan phase ---'

    # Locate claude CLI
    $ClaudePath = $null
    $claudeCmd  = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $ClaudePath = $claudeCmd.Source
    } else {
        $candidates = @(
            (Join-Path $env:APPDATA 'npm\claude.cmd'),
            (Join-Path $env:APPDATA 'npm\claude'),
            (Join-Path $env:LOCALAPPDATA 'Programs\claude\claude.exe')
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) {
                $ClaudePath = $c
                break
            }
        }
    }

    if (-not $ClaudePath) {
        Write-Log 'claude CLI not found in PATH or common locations.' 'ERROR'
        Write-Log 'Ensure Claude Code CLI is installed: https://claude.ai/code' 'ERROR'
        $ScanWasSkipped  = $true
        $ClaudeAvailable = $false
        $Status          = 'no_ai_engine'
    } else {
        $ClaudeAvailable = $true
        Write-Log "claude CLI: $ClaudePath"

        $PromptContent = Get-Content $PromptPath -Raw -Encoding UTF8
        Write-Log "Prompt length: $($PromptContent.Length) chars"
        Write-Log "Timeout: ${ScanTimeoutMinutes} minutes"

        $TempPrompt = [System.IO.Path]::GetTempFileName()
        $TempStdOut = [System.IO.Path]::GetTempFileName()
        $TempStdErr = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $TempPrompt -Value $PromptContent -Encoding UTF8

        try {
            Write-Log 'Starting claude process...'
            Push-Location $SourceDir

            # Claude Code starts an interactive session by default. Use --print
            # and pipe the full prompt through PowerShell so the multi-line
            # instruction is preserved as one input instead of being split by
            # Start-Process argument handling.
            $job = Start-Job -ScriptBlock {
                param($ClaudePath, $PromptContent, $SourceDir, $TempStdOut, $TempStdErr)

                Set-Location $SourceDir
                $PromptContent | & $ClaudePath --print --dangerously-skip-permissions --add-dir $SourceDir 1> $TempStdOut 2> $TempStdErr

                if ($null -eq $LASTEXITCODE) {
                    [pscustomobject]@{ ExitCode = 0 }
                } else {
                    [pscustomobject]@{ ExitCode = [int]$LASTEXITCODE }
                }
            } -ArgumentList $ClaudePath, $PromptContent, $SourceDir, $TempStdOut, $TempStdErr

            $Completed = Wait-Job -Job $job -Timeout ($ScanTimeoutMinutes * 60)

            if ($Completed) {
                $jobResult = Receive-Job -Job $job
                $ClaudeExit = if ($jobResult -and $null -ne $jobResult.ExitCode) {
                    [int]$jobResult.ExitCode
                } else {
                    -1
                }
            } else {
                $ClaudeExit = -1
            }

            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

            if (-not $Completed) {
                Write-Log "Claude timed out after ${ScanTimeoutMinutes} minutes" 'ERROR'
                $Status = 'timeout'
            } else {
                Write-Log "Claude exited with code: $ClaudeExit"
                if ($ClaudeExit -ne 0) {
                    Write-Log 'Non-zero exit code from claude -- treating as scan_error' 'ERROR'
                    $Status = 'scan_error'
                }
            }

        } catch {
            Write-Log "Error running claude: $_" 'ERROR'
            $Status     = 'scan_error'
            $ClaudeExit = -1
        } finally {
            Pop-Location

            if (Test-Path $TempStdOut) {
                $out = Get-Content $TempStdOut -Raw -Encoding UTF8
                if ($out) {
                    Write-LogRaw '--- claude output ---'
                    $preview = if ($out.Length -gt 2000) {
                        '...(truncated)...' + $out.Substring($out.Length - 2000)
                    } else { $out }
                    Write-LogRaw $preview
                    Write-LogRaw '--- end claude output ---'
                }
                Remove-Item $TempStdOut -ErrorAction SilentlyContinue
            }
            if (Test-Path $TempStdErr) {
                $err = Get-Content $TempStdErr -Raw -Encoding UTF8
                if ($err) {
                    Write-LogRaw '--- claude stderr ---'
                    Write-LogRaw $err
                }
                Remove-Item $TempStdErr -ErrorAction SilentlyContinue
            }
            if (Test-Path $TempPrompt) {
                Remove-Item $TempPrompt -ErrorAction SilentlyContinue
            }
        }
    }
} else {
    Write-Log '--- Scan phase skipped (using existing files) ---'
}

# ============================================================================
# STEP 3.5 -- FRESHNESS GATE
# Skipped when -SkipScan is set (infrastructure testing mode).
# Compares each critical JSON file's LastWriteTime to $StartTime.
# Any file older than scan start is stale -- guard blocks archive/latest.
# Runs even on scan_error so we can recover when Claude exits non-zero but
# produced valid fresh output (e.g. stream idle timeout after completion).
# ============================================================================
if (-not $ScanWasSkipped) {
    Write-Log '--- Freshness gate ---'
    foreach ($jf in $CRITICAL_JSON) {
        $jp = Join-Path $SourceDir $jf
        if (Test-Path $jp) {
            $lwt = (Get-Item $jp).LastWriteTime
            if ($lwt -le $StartTime) {
                $msg = "STALE: $jf (LastWriteTime $($lwt.ToString('yyyy-MM-ddTHH:mm:ss')), scan started $($StartTime.ToString('yyyy-MM-ddTHH:mm:ss')))"
                Write-Log "  $msg" 'ERROR'
                $FreshnessErrors.Add($msg) | Out-Null
                $FreshnessFailed = $true
            } else {
                Write-Log "  FRESH: $jf (modified $($lwt.ToString('HH:mm:ss')))"
            }
        }
    }
    if ($FreshnessFailed) {
        Write-Log 'FRESHNESS GATE FAILED -- archive and latest update blocked.' 'ERROR'
        $Status = 'stale_output'
    } else {
        Write-Log '  All critical files are fresh.'
    }
}

# ============================================================================
# STEP 4 -- VALIDATE OUTPUT FILES
# ============================================================================
Write-Log '--- Validating output files ---'

foreach ($f in $REQUIRED_FILES) {
    $fp = Join-Path $SourceDir $f
    if (Test-Path $fp) {
        Write-Log "  OK      $f"
    } else {
        $msg = "MISSING: $f"
        Write-Log "  $msg" 'WARN'
        $ValidationErrors.Add($msg) | Out-Null
        if ($CRITICAL_JSON -contains $f) { $ValidationFailed = $true }
    }
}

foreach ($jf in $CRITICAL_JSON) {
    $jp = Join-Path $SourceDir $jf
    if (Test-Path $jp) {
        try {
            $raw    = Get-Content $jp -Raw -Encoding UTF8
            $parsed = $raw | ConvertFrom-Json
            if ($null -eq $parsed) { throw 'Parsed to null' }
            Write-Log "  JSON OK $jf"
        } catch {
            $msg = "INVALID JSON: $jf -- $_"
            Write-Log "  $msg" 'ERROR'
            $ValidationErrors.Add($msg) | Out-Null
            $ValidationFailed = $true
        }
    }
}

if ($ValidationFailed) {
    Write-Log 'CRITICAL validation failures -- archive and latest update blocked.' 'ERROR'
    if ($Status -eq 'success') { $Status = 'validation_failed' }
}

# ============================================================================
# STEP 5 -- EXTRACT METRICS
# ============================================================================
Write-Log '--- Extracting metrics ---'

try {
    $rawJson = Get-Content (Join-Path $SourceDir 'raw_research.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $stories = $rawJson.stories
    if ($null -ne $stories) { $RawStoryCount = @($stories).Count }
} catch {
    Write-Log "raw_research.json metric extraction failed: $_" 'WARN'
}

try {
    $aJson    = Get-Content (Join-Path $SourceDir 'analyzed_stories.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $aStories = @($aJson.stories)

    $propDedup = $aJson.PSObject.Properties['total_after_dedup']
    if ($propDedup) {
        $AnalyzedStoryCount = [int]$propDedup.Value
    } else {
        $AnalyzedStoryCount = $aStories.Count
    }

    $propPlan = $aJson.PSObject.Properties['stories_in_content_plan']
    if ($propPlan) {
        $ContentIdeaCount = [int]$propPlan.Value
    }

    $planStories        = @($aStories | Where-Object { $_.channel_fit -eq $true })
    $VerifiedCount      = @($planStories | Where-Object { $_.verified -eq $true }).Count
    $SingleSourceCount  = @($planStories | Where-Object { $_.verified -ne $true }).Count
    $HighRiskCount      = @($planStories | Where-Object { $_.risk_level -eq 'high' }).Count

    foreach ($s in $planStories) {
        $tags = @($s.priority_tags)
        if ($tags -contains 'UNDERREPORTED') { $UnderreportedCount++ }
    }

    $catGroups = $planStories | Group-Object source_category | Sort-Object Count -Descending
    if ($catGroups) { $TopCluster = [string]$catGroups[0].Name }

    $topObj = $planStories | Sort-Object score -Descending | Select-Object -First 1
    if ($topObj) { $TopStory = [string]$topObj.headline }

} catch {
    Write-Log "analyzed_stories.json metric extraction failed: $_" 'WARN'
}

try {
    $ciJson  = Get-Content (Join-Path $SourceDir 'content_ideas.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $propTI  = $ciJson.PSObject.Properties['total_ideas']
    if ($propTI) {
        $ContentIdeaCount = [int]$propTI.Value
    } elseif ($null -ne $ciJson.ideas) {
        $ContentIdeaCount = @($ciJson.ideas).Count
    }
} catch {
    Write-Log "content_ideas.json metric extraction failed: $_" 'WARN'
}

if (-not $TopStory) {
    try {
        $dJson     = Get-Content (Join-Path $SourceDir 'data.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $topDStory = @($dJson.stories) | Sort-Object score -Descending | Select-Object -First 1
        if ($topDStory) { $TopStory = [string]$topDStory.headline }
    } catch { }
}

Write-Log "  Raw stories:      $RawStoryCount"
Write-Log "  Analyzed stories: $AnalyzedStoryCount"
Write-Log "  Content ideas:    $ContentIdeaCount"
Write-Log "  Verified:         $VerifiedCount  Single-source: $SingleSourceCount"
Write-Log "  High-risk:        $HighRiskCount  Underreported: $UnderreportedCount"
Write-Log "  Top cluster:      $TopCluster"

# ---------------------------------------------------------------------------
# STEP 5.5 -- OUTPUT RECOVERY
# If Claude returned a non-zero exit code but all files are fresh and valid,
# the most likely cause is a stream idle timeout that fired after Claude had
# already finished writing output. Treat this as a success so the archive and
# latest/ update are not blocked by a transient API disconnect.
# ---------------------------------------------------------------------------
if ($Status -eq 'scan_error' -and -not $FreshnessFailed -and -not $ValidationFailed) {
    Write-Log '--- Output recovery: Claude exited non-zero but output is fresh and valid ---' 'WARN'
    Write-Log "  Overriding status: scan_error -> success  (likely stream timeout after completion)" 'WARN'
    $Status = 'success'
}

# ---------------------------------------------------------------------------
# Compute $HardFailed and $ShouldArchive
# $HardFailed = any condition that must prevent archive/latest/manifest writes
# $ShouldArchive = green-light for Steps 6-8
# ---------------------------------------------------------------------------
$HardFailed    = $ValidationFailed -or $FreshnessFailed -or ($HARD_FAIL_STATUSES -contains $Status)
$ShouldArchive = (-not $HardFailed) -and (-not $DryRun)

# ============================================================================
# STEP 6 -- ARCHIVE
# ============================================================================
if ($HardFailed) {
    Write-Log "--- Archive skipped (hard failure: $Status) ---" 'WARN'
} elseif ($DryRun) {
    Write-Log '--- Archive skipped (DryRun) ---'
    $ArchiveFolder = "DRY-RUN-$DateStr"
} else {
    Write-Log '--- Archiving scan ---'

    $FolderName    = $DateStr
    $FolderCounter = 0
    while (Test-Path (Join-Path $ScansRoot $FolderName)) {
        $FolderCounter++
        $FolderName = '{0}_{1:D2}' -f $DateStr, $FolderCounter
    }
    $DestDir       = Join-Path $ScansRoot $FolderName
    $ArchiveFolder = $FolderName

    if ($FolderCounter -gt 0) {
        Write-Log "  Collision -- using scans/$FolderName"
    }

    New-Item -ItemType Directory -Path $DestDir | Out-Null
    $FilesArchived = 0
    foreach ($f in $REQUIRED_FILES) {
        $src = Join-Path $SourceDir $f
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $DestDir $f)
            $FilesArchived++
        }
    }
    Write-Log "  Archived $FilesArchived files to scans/$FolderName"
}

# ============================================================================
# STEP 7 -- UPDATE /scans/latest/
# ============================================================================
if ($HardFailed) {
    Write-Log "--- Latest update skipped (hard failure: $Status) ---" 'WARN'
} elseif ($DryRun) {
    Write-Log '--- Latest update skipped (DryRun) ---'
} else {
    Write-Log '--- Updating /scans/latest/ ---'

    if (-not (Test-Path $LatestDir)) {
        New-Item -ItemType Directory -Path $LatestDir | Out-Null
    }

    foreach ($f in $REQUIRED_FILES) {
        $src = Join-Path $SourceDir $f
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $LatestDir $f) -Force
        }
    }

    $MissingFromLatest = 0
    foreach ($f in $CRITICAL_JSON) {
        if (-not (Test-Path (Join-Path $LatestDir $f))) {
            Write-Log "  WARNING: $f missing from /scans/latest/ after update" 'WARN'
            $MissingFromLatest++
        }
    }

    if ($MissingFromLatest -eq 0) {
        Write-Log '  /scans/latest/ updated OK'
        $LatestUpdated = $true
    } else {
        Write-Log "  $MissingFromLatest critical file(s) missing from /scans/latest/" 'WARN'
    }
}

# ============================================================================
# STEP 8 -- UPDATE scan_manifest.json (success path only)
# ============================================================================
if ($ShouldArchive) {
    Write-Log '--- Updating scan_manifest.json ---'

    $NowUTC = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $ScanId = "scan-$ArchiveFolder"

    $NewEntry = [ordered]@{
        scan_id              = $ScanId
        scan_timestamp       = $NowUTC
        archive_folder       = $ArchiveFolder
        latest_updated       = $LatestUpdated
        raw_story_count      = $RawStoryCount
        analyzed_story_count = $AnalyzedStoryCount
        content_idea_count   = $ContentIdeaCount
        verified_count       = $VerifiedCount
        single_source_count  = $SingleSourceCount
        high_risk_count      = $HighRiskCount
        underreported_count  = $UnderreportedCount
        top_cluster          = $TopCluster
        top_story            = $TopStory
        log_file             = $LogRelPath
        status               = $Status
    }

    $manifest = New-Object System.Collections.Generic.List[object]
    if (Test-Path $ManifestPath) {
        try {
            $existing = Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            @($existing) | ForEach-Object { $manifest.Add($_) | Out-Null }
        } catch {
            Write-Log "Could not parse existing manifest -- starting fresh: $_" 'WARN'
        }
    }
    $manifest.Add([PSCustomObject]$NewEntry) | Out-Null

    ConvertTo-Json -InputObject ([object[]]$manifest) -Depth 5 |
        Set-Content -Path $ManifestPath -Encoding UTF8

    Write-Log "  scan_id=$ScanId  total scans=$($manifest.Count)"
}

# ============================================================================
# STEP 8.5 -- RECORD FAILURE to /logs/failed_scan_manifest.json
# ============================================================================
if ($HardFailed -and -not $DryRun) {
    Write-Log '--- Recording failure to failed_scan_manifest.json ---' 'WARN'

    $NowUTC = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    $NextAction = 'Check log file for details.'
    if ($Status -eq 'no_ai_engine') {
        $NextAction = 'Install Claude Code CLI and ensure it is in PATH. Then re-run run_daily_scan.ps1.'
    } elseif ($Status -eq 'timeout') {
        $NextAction = "Increase -ScanTimeoutMinutes (current: ${ScanTimeoutMinutes}). Check Claude auth: claude auth status."
    } elseif ($Status -eq 'scan_error') {
        $NextAction = 'Run claude manually in project folder. Check log for error details.'
    } elseif ($Status -eq 'stale_output') {
        $NextAction = 'Run pipeline manually: open Claude Code in project folder, execute all 5 phases, then run .\run_daily_scan.ps1 -SkipScan.'
    } elseif ($Status -eq 'validation_failed') {
        $NextAction = 'Check missing/invalid files listed in log. Run pipeline manually then .\run_daily_scan.ps1 -SkipScan.'
    }

    $StaleFilesSummary  = if ($FreshnessErrors.Count -gt 0) { $FreshnessErrors -join ' | ' } else { '' }
    $ValidationSummary  = if ($ValidationErrors.Count -gt 0) { $ValidationErrors -join ' | ' } else { '' }
    $ClaudeExitStr      = if ($null -ne $ClaudeExit) { [string]$ClaudeExit } else { 'N/A' }

    $FailEntry = [ordered]@{
        scan_id           = 'failed-' + $DateStr + '-' + $StartTime.ToString('HHmmss')
        scan_timestamp    = $NowUTC
        start_time        = $StartTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        failure_reason    = $Status
        claude_available  = $ClaudeAvailable
        claude_exit_code  = $ClaudeExitStr
        stale_files       = $StaleFilesSummary
        validation_errors = $ValidationSummary
        log_file          = $LogRelPath
        next_action       = $NextAction
    }

    $failedManifest = New-Object System.Collections.Generic.List[object]
    if (Test-Path $FailedManifestPath) {
        try {
            $existingFailed = Get-Content $FailedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            @($existingFailed) | ForEach-Object { $failedManifest.Add($_) | Out-Null }
        } catch {
            Write-Log "Could not parse existing failed manifest -- starting fresh: $_" 'WARN'
        }
    }
    $failedManifest.Add([PSCustomObject]$FailEntry) | Out-Null

    ConvertTo-Json -InputObject ([object[]]$failedManifest) -Depth 5 |
        Set-Content -Path $FailedManifestPath -Encoding UTF8

    Write-Log "  Failure recorded: $($FailEntry.scan_id)  total failures=$($failedManifest.Count)"
}

# ============================================================================
# STEP 8.6 -- WRITE DIAGNOSTICS to /scans_failed/YYYY-MM-DD_HHMMSS/
# ============================================================================
if ($HardFailed -and -not $DryRun) {
    Write-Log '--- Writing failure diagnostics to /scans_failed/ ---' 'WARN'

    $FailTimestamp = $StartTime.ToString('yyyy-MM-dd_HHmmss')
    $FailedDir     = Join-Path $ScansFailedRoot $FailTimestamp

    if (-not (Test-Path $ScansFailedRoot)) {
        New-Item -ItemType Directory -Path $ScansFailedRoot | Out-Null
    }
    New-Item -ItemType Directory -Path $FailedDir | Out-Null

    $diagContent = @(
        "FAILED SCAN DIAGNOSTICS"
        "======================="
        "Start time:        $($StartTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
        "Failure reason:    $Status"
        "Claude available:  $ClaudeAvailable"
        "Claude exit code:  $(if ($null -ne $ClaudeExit) { $ClaudeExit } else { 'N/A' })"
        ""
        "Stale files:"
    )
    if ($FreshnessErrors.Count -gt 0) {
        foreach ($fe in $FreshnessErrors) { $diagContent += "  - $fe" }
    } else {
        $diagContent += "  (none)"
    }
    $diagContent += ""
    $diagContent += "Validation errors:"
    if ($ValidationErrors.Count -gt 0) {
        foreach ($ve in $ValidationErrors) { $diagContent += "  - $ve" }
    } else {
        $diagContent += "  (none)"
    }
    $diagContent += ""
    $diagContent += "Next action required:"
    $diagContent += "  $NextAction"
    $diagContent += ""
    $diagContent += "Full log: $LogRelPath"

    $diagContent | Set-Content -Path (Join-Path $FailedDir 'diagnostics.txt') -Encoding UTF8

    # Copy log file into the failure folder for self-contained diagnostics
    Copy-Item -Path $LogPath -Destination (Join-Path $FailedDir (Split-Path $LogPath -Leaf)) -ErrorAction SilentlyContinue

    Write-Log "  Diagnostics written: scans_failed/$FailTimestamp"
}

# ============================================================================
# STEP 9 -- FINAL LOG
# ============================================================================
$EndTime  = Get-Date
$Duration = [int]($EndTime - $StartTime).TotalSeconds

Write-Log "============================================================"
Write-Log "DAILY SCAN COMPLETE"
Write-Log "Status:              $Status"
Write-Log "Duration:            ${Duration}s"
Write-Log "Scan skipped:        $ScanWasSkipped"
Write-Log "Claude available:    $ClaudeAvailable"
if ($null -ne $ClaudeExit) {
    Write-Log "Claude exit code:    $ClaudeExit"
}
Write-Log "Archive folder:      $ArchiveFolder"
Write-Log "Latest updated:      $LatestUpdated"
Write-Log "Raw stories:         $RawStoryCount"
Write-Log "Analyzed stories:    $AnalyzedStoryCount"
Write-Log "Content ideas:       $ContentIdeaCount"
Write-Log "Verified:            $VerifiedCount"
Write-Log "Single-source:       $SingleSourceCount"
Write-Log "High-risk:           $HighRiskCount"
Write-Log "Underreported:       $UnderreportedCount"
Write-Log "Top cluster:         $TopCluster"
Write-Log "Top story:           $TopStory"
Write-Log "Log file:            $LogRelPath"

if ($FreshnessErrors.Count -gt 0) {
    Write-Log "Freshness failures ($($FreshnessErrors.Count)):"
    foreach ($fe in $FreshnessErrors) { Write-Log "  - $fe" }
}

if ($ValidationErrors.Count -gt 0) {
    Write-Log "Validation errors ($($ValidationErrors.Count)):"
    foreach ($e in $ValidationErrors) { Write-Log "  - $e" }
}

if ($HardFailed) {
    Write-Log "Hard failure -- no archive, no latest update, no manifest entry." 'ERROR'
    Write-Log "Failure log: $FailedManifestPath" 'ERROR'
}

Write-Log "============================================================"

if ($Status -eq 'success') { exit 0 } else { exit 1 }
