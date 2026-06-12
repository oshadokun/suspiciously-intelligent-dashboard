# Daily Scan Automation — Suspiciously Intelligent

This document describes the automated daily scan system: what it does, how to install it, how to test it, and what to do when something goes wrong.

---

## What the daily automation does

Every day at 6:00 AM the system:

1. **Runs the AI pipeline** — invokes Claude Code CLI (`claude`) with the prompt in `daily_scan_prompt.txt`, which tells it to execute all 5 phases of the editorial pipeline (research, analyse, content, dashboard, validate) and write fresh output files to the project root.

2. **Freshness gate** — after the pipeline finishes, checks that all 4 critical JSON files (`raw_research.json`, `analyzed_stories.json`, `content_ideas.json`, `data.json`) have a `LastWriteTime` newer than the scan start time. If any file is stale (i.e. pre-existing and not overwritten by Claude), the run is marked `stale_output` and archiving is blocked.

3. **Validates outputs** — checks that all required files exist and that all JSON files parse correctly. If any critical file is missing or malformed the archive and latest-folder updates are skipped and the run is marked `validation_failed`.

4. **Archives the run** — copies all output files to `/scans/YYYY-MM-DD/`. If that folder already exists (same-day re-run) the script creates `/scans/YYYY-MM-DD_01/`, `_02/`, etc.

5. **Updates `/scans/latest/`** — overwrites all files in the latest folder so the dashboard always serves the newest scan.

6. **Updates `scan_manifest.json`** — appends a new entry with full metrics (story counts, risk counts, top story, etc.) without touching historical entries.

7. **Writes a log file** — creates `/logs/YYYY-MM-DD_daily_scan.log` with start/end timestamps, all metrics, and a success/failure status.

---

## Requirements

| Requirement | Notes |
|---|---|
| Windows 10 or 11 | Task Scheduler + PowerShell 5.1 |
| Claude Code CLI installed | `claude` must be in PATH or `%APPDATA%\npm\` |
| Claude account authenticated | Run `claude auth login` once before scheduling |
| Internet access at 6:00 AM | The pipeline fetches live AI news via WebSearch |

---

## Files created by this system

| File | Purpose |
|---|---|
| `run_daily_scan.ps1` | Main orchestration script |
| `daily_scan_prompt.txt` | Prompt passed to Claude CLI |
| `install_daily_scan_task.ps1` | Registers the scheduled task |
| `uninstall_daily_scan_task.ps1` | Removes the scheduled task |
| `test_daily_scan.ps1` | Infrastructure test (no AI) |
| `/logs/` | Directory for daily log files |
| `/logs/failed_scan_manifest.json` | Index of every failed scan run |
| `/scans_failed/` | Diagnostic snapshots for failed runs |

---

## How to install the scheduled task

Open PowerShell in the project folder and run:

```powershell
.\install_daily_scan_task.ps1
```

The task runs at 6:00 AM by default. To use a different time:

```powershell
.\install_daily_scan_task.ps1 -Time "07:30"
```

To preview what the script would do without making changes:

```powershell
.\install_daily_scan_task.ps1 -WhatIf
```

The task is registered as:
- **Task name:** `SuspiciouslyIntelligentDailyScan`
- **Runs as:** current Windows user (S4U logon — no password stored)
- **Execution policy:** Bypass (for the script only)
- **Timeout:** 4 hours (generous for the AI pipeline)
- **On failure:** retries once after 30 minutes

To verify the task was created:

```powershell
Get-ScheduledTask -TaskName 'SuspiciouslyIntelligentDailyScan' | Format-List
```

---

## How to uninstall the scheduled task

```powershell
.\uninstall_daily_scan_task.ps1
```

This removes the scheduled task but does not delete any scripts, logs, or scan archives.

---

## How to run a manual scan immediately

Run the full pipeline right now (invokes Claude):

```powershell
.\run_daily_scan.ps1
```

Run with existing files (no AI, for testing):

```powershell
.\run_daily_scan.ps1 -SkipScan
```

Validate and log without writing any files:

```powershell
.\run_daily_scan.ps1 -DryRun
```

---

## How to run a manual infrastructure test

Run `test_daily_scan.ps1` to test archiving, logging, and manifest updates without invoking Claude:

```powershell
.\test_daily_scan.ps1
```

This script:
- Runs `run_daily_scan.ps1 -SkipScan` using the current JSON files in the project root
- Checks that a new archive folder was created
- Checks that `/scans/latest/` was updated
- Checks that a log file was written
- Checks that `scan_manifest.json` was updated with an entry that has all required fields
- Prints a PASS/FAIL summary for each check

All checks should pass on a healthy installation. If any fail, check the log file for details.

---

## Where logs are stored

```
/logs/
  2026-05-19_daily_scan.log       <- first run of the day
  2026-05-19_daily_scan_01.log    <- second run (same day)
  2026-05-19_daily_scan_02.log    <- third run (same day)
```

Each log contains:
- Start and end timestamps
- Whether the AI scan ran or was skipped
- Claude CLI output (last 2000 chars if long)
- File validation results
- Extracted metrics (story counts, verified, high-risk, etc.)
- Archive folder created
- Latest folder update status
- Manifest update confirmation
- Final status (`success`, `validation_failed`, `no_ai_engine`, `timeout`, etc.)

---

## Where archived scans are stored

```
/scans/
  scan_manifest.json            <- index of all runs
  latest/                       <- always the most recent scan
  2026-05-18/                   <- historical archive
  2026-05-19/                   <- next day's archive
  2026-05-19_01/                <- same-day re-run
```

Each dated folder contains:
- `raw_research.json`
- `analyzed_stories.json`
- `content_ideas.json`
- `ideas.md`
- `data.json`
- `run_report.md`

Historical folders are never overwritten. Each new run creates a new folder.

---

## How /scans/latest/ is updated

After a successful validation, the script copies all six output files from the project root into `/scans/latest/`, overwriting the previous versions.

The dashboard (`dashboard.html`) reads from `/scans/latest/` via the local HTTP server. After a daily run, refreshing the browser will show the newest scan data.

**Critical files checked before and after update:**
- `raw_research.json`
- `analyzed_stories.json`
- `content_ideas.json`
- `data.json`

If any of these is missing from `/scans/latest/` after the copy, the run logs a warning but does not roll back (the archive folder contains the correct copies for manual recovery).

---

## How to confirm the dashboard has the newest scan

1. Start the dashboard: `.\start_dashboard.ps1`
2. Check the scan date shown in the dashboard header
3. Or check the manifest: the most recent entry in `scan_manifest.json` shows the timestamp and story count

To verify via PowerShell:

```powershell
$m = Get-Content .\scans\scan_manifest.json | ConvertFrom-Json
$m | Select-Object -Last 1 | Format-List
```

---

## scan_manifest.json format

Each entry written by `run_daily_scan.ps1` includes:

| Field | Description |
|---|---|
| `scan_id` | e.g. `scan-2026-05-19` |
| `scan_timestamp` | UTC timestamp of when archiving completed |
| `archive_folder` | e.g. `2026-05-19` or `2026-05-19_01` |
| `latest_updated` | `true` if `/scans/latest/` was successfully updated |
| `raw_story_count` | Stories collected in Phase 1 (before dedup) |
| `analyzed_story_count` | Stories after deduplication |
| `content_idea_count` | Stories in the content plan |
| `verified_count` | Stories confirmed by 2+ sources |
| `single_source_count` | Stories with only 1 source |
| `high_risk_count` | Stories with `risk_level: high` |
| `underreported_count` | Stories tagged UNDERREPORTED |
| `top_cluster` | Most common source category |
| `top_story` | Highest-scoring story headline |
| `log_file` | Relative path to the log for this run |
| `status` | `success`, `validation_failed`, `no_ai_engine`, `timeout`, `scan_error` |

Historical entries created by `archive_scan.ps1` use a smaller field set and remain untouched.

---

## Successful vs failed scans

A run is considered **successful** only when all of the following are true:

1. Claude CLI was found and exited with code 0.
2. All 4 critical JSON files have a `LastWriteTime` newer than the scan start time (freshness gate passed).
3. All 6 required output files exist and all 4 JSON files parse correctly.

When all conditions are met: the run is archived to `/scans/YYYY-MM-DD/`, `/scans/latest/` is updated, and an entry is appended to `scan_manifest.json`.

A run is a **hard failure** when any of the following are true:

| Condition | Status code | Caused by |
|---|---|---|
| Claude CLI not found | `no_ai_engine` | Claude not installed or not in PATH |
| Claude exited non-zero | `scan_error` | Claude crash, auth error, unhandled exception |
| Claude timed out | `timeout` | Pipeline took longer than `-ScanTimeoutMinutes` |
| Any critical JSON file not updated by Claude | `stale_output` | AI pipeline did not run; pre-existing files left in place |
| Required file missing or invalid JSON | `validation_failed` | Output was written but is corrupt or incomplete |

On a hard failure:
- `/scans/YYYY-MM-DD/` is **not created**
- `/scans/latest/` is **not updated** (dashboard continues to show previous scan)
- `scan_manifest.json` is **not appended to**
- A failure entry is written to **`/logs/failed_scan_manifest.json`**
- Diagnostic files are copied to **`/scans_failed/YYYY-MM-DD_HHMMSS/`**

### Checking for failures

```powershell
# See all failed runs
$f = Get-Content .\logs\failed_scan_manifest.json | ConvertFrom-Json
$f | Select-Object scan_id, failure_reason, next_action | Format-Table -AutoSize

# See the most recent failure
$f | Select-Object -Last 1 | Format-List
```

Diagnostic files for each failure are in `/scans_failed/YYYY-MM-DD_HHMMSS/`:
- `diagnostics.txt` — failure reason, stale files, validation errors, next action
- The log file for that run

---

## What to do if a run fails

### Status: `no_ai_engine`
Claude CLI was not found. Fix:
```powershell
# Confirm claude is installed
claude --version

# If not installed, follow: https://claude.ai/code
# After installing, confirm it is in PATH:
Get-Command claude
```

### Status: `validation_failed`
One or more output files are missing or invalid JSON. The archive was not updated. Fix:
- Check the log file for which file failed
- Run the pipeline manually (see below)
- Once valid files exist, run `.\run_daily_scan.ps1 -SkipScan` to archive and update latest

### Status: `timeout`
Claude took longer than the configured timeout (default 90 minutes). Fix:
- Increase timeout: `.\run_daily_scan.ps1 -ScanTimeoutMinutes 120`
- Check if Claude is authenticated: `claude auth status`
- Check internet connectivity

### Status: `scan_error`
Claude CLI crashed or threw an unhandled error. Fix:
- Check the log for the error message
- Run `claude` manually in the project folder to see if it works
- Check Claude status: https://status.anthropic.com

### Running the pipeline manually after a failure

```powershell
# 1. Open Claude Code in the project folder
# 2. Run: read AGENT_README.md and execute all 5 phases

# 3. After Claude writes the output files, archive manually:
.\run_daily_scan.ps1 -SkipScan
```

---

## Customising the scan prompt

Edit `daily_scan_prompt.txt` to change the instructions passed to Claude. Keep the file short and free of special characters (quotes, backticks) to avoid command-line argument issues.

The default prompt tells Claude to read `AGENT_README.md` and run all 5 phases. You can add date-specific instructions or focus areas:

```
Read AGENT_README.md and execute all 5 pipeline phases completely without pausing.
Focus extra attention on regulation and safety stories this week.
Write all output files to the current working directory.
```

---

## Compatibility notes

- All scripts require **Windows PowerShell 5.1** (`powershell.exe`)
- Do NOT use `pwsh.exe` (PowerShell 7+) — the Task Scheduler action is hardcoded to `powershell.exe`
- Paths use `$PSScriptRoot` — no hardcoded paths
- All file writes use `-Encoding UTF8`
- Log output uses ASCII-safe characters only
