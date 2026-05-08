# Suspiciously Intelligent Dashboard

An offline editorial intelligence system for the *Suspiciously Intelligent* YouTube channel. Runs a full weekly research-to-content pipeline locally, stores results as versioned scan archives, and presents everything through a single self-contained HTML dashboard.

No cloud services. No subscriptions. No data leaving your machine.

---

## What it does

Each week, the pipeline:

1. Searches 20+ sources across six story categories (company moves, model releases, regulation, jobs, hardware, safety/scams)
2. Scores every story on a 0-10 rubric (recency, source confirmation, public interest, content opportunity)
3. Generates 75 content ideas — YouTube videos, Shorts, image posts, community posts, and memes — one idea set per story
4. Produces a `data.json` summary and `content_ideas.json` payload for the dashboard
5. Validates all outputs and writes a `run_report.md`
6. Archives the complete run into a dated scan folder

The dashboard loads the latest archive automatically, shows story scores and tags, lets you mark ideas as used, and exports your workspace.

---

## Quick start

```powershell
.\start_dashboard.ps1
```

This checks whether the server is already running, starts it if not, waits for HTTP 200, then opens `http://localhost:8765/dashboard.html` in your default browser — bypassing VS Code's Simple Browser.

To stop the server:

```powershell
.\stop_dashboard.ps1
```

---

## Architecture

The dashboard is a single HTML file (`dashboard.html`) that fetches JSON from a local HTTP server. There is no build step, no framework, no CDN dependency.

```
dashboard.html
    |
    | fetch() on load
    v
http://localhost:8765/scans/latest/data.json
http://localhost:8765/scans/latest/content_ideas.json
```

**Why a local server?** Browsers block `fetch()` calls when a page is opened via `file://`. `serve.ps1` starts a zero-dependency PowerShell HTTP listener that removes this restriction while keeping everything offline.

**Data sources in priority order:**

| Priority | Source | Badge |
|---|---|---|
| 1 | `/scans/latest/` via `fetch()` | green — Latest scan |
| 2 | Manual import via dashboard UI | blue — Imported snapshot |
| 3 | Embedded fallback in `dashboard.html` | amber — Embedded fallback |

---

## Dashboard features

- **Story cards** — scored 0-10 with URGENT / WATCH / CONTENT OPPORTUNITY / HIGH RISK / UNDERREPORTED tags
- **Content idea browser** — 5 formats per story (video, Short/Reel, image post, community post, meme)
- **Mark as used** — persisted to localStorage by story ID; survives page reloads
- **Workspace export** — exports current workflow state and content ideas as JSON
- **Manual import** — load any historical scan without restarting the server
- **Reload latest** — re-fetches `/scans/latest/` without a page reload
- **Filter and sort** — by score, tag, platform, or risk level

---

## Workflow

### Run the pipeline

The pipeline is five sequential phases, each with its own prompt file in the project root:

| Phase | Prompt | Output |
|---|---|---|
| 1 | `01_RESEARCH.md` | `raw_research.json` |
| 2 | `02_ANALYZE.md` | `analyzed_stories.json` |
| 3 | `03_CONTENT.md` | `content_ideas.json`, `ideas.md` |
| 4 | `04_DASHBOARD.md` | `data.json` |
| 5 | `05_VALIDATE.md` | `run_report.md` |

After all five phases complete:

```powershell
.\archive_scan.ps1
```

This copies all outputs into a dated folder under `scans/`, updates `scans/latest/`, and appends archive metadata to `run_report.md`.

### Load a historical scan

```powershell
.\load_latest_scan.ps1               # load scans/latest/
.\load_latest_scan.ps1 -ListOnly     # browse all archived scans
.\load_latest_scan.ps1 -ScanDate 2026-05-08_01
```

---

## Scan archive structure

```
scans/
  scan_manifest.json          # index of all archived scans
  latest/                     # symlink-equivalent: always the most recent run
    data.json
    content_ideas.json
    analyzed_stories.json
    raw_research.json
    ideas.md
    run_report.md
  2026-05-08/                 # first scan of the day
    ...same files...
  2026-05-08_01/              # collision-safe: second scan same day
    ...same files...
```

Folder naming is collision-safe: if `2026-05-08` already exists, `archive_scan.ps1` creates `2026-05-08_01`, then `2026-05-08_02`, and so on.

---

## Scoring rubric

Each story is scored 0-10 across four dimensions:

| Dimension | Max | Notes |
|---|---|---|
| Recency | 3 | Within 48h = 3, within 7 days = 2, older = 0-1 |
| Source confirmation | 3 | 3+ independent sources = 3 |
| Public interest signal | 2 | Search/social volume |
| Content opportunity | 2 | Channel fit and angle availability |

Priority tags:
- **URGENT** — score >= 8 and time-sensitive (days, not weeks)
- **CONTENT OPPORTUNITY** — content opportunity dimension = 2
- **WATCH** — score 6-7, developing story worth monitoring
- **HIGH RISK** — named individuals, contested facts, or legal sensitivity
- **UNDERREPORTED** — score >= 5 but sourced only from specialist press

---

## PowerShell compatibility

All scripts are compatible with **Windows PowerShell 5.1** and **PowerShell 7+**.

Key compatibility decisions:
- No ternary operators (`? :`) — replaced with `if/else`
- No null-conditional operators (`?.`) — replaced with explicit property checks
- No non-ASCII characters in script files — box-drawing chars and Unicode symbols in strings caused CP1252 decoding to inject curly-quote string terminators under PS5.1
- All scripts use only ASCII characters (U+0000-U+007F)

---

## Scripts reference

| Script | Purpose |
|---|---|
| `start_dashboard.ps1` | One-click launcher — starts server, waits for HTTP 200, opens browser |
| `stop_dashboard.ps1` | Stops server by finding and killing the process on port 8765 |
| `serve.ps1` | Zero-dependency local HTTP server on port 8765 (configurable) |
| `archive_scan.ps1` | Archives a completed pipeline run into a dated scan folder |
| `load_latest_scan.ps1` | Copies a scan archive back into the working directory |

---

## Workspace export / import

The dashboard **Export** button writes a JSON snapshot of:
- all story IDs and their workflow states
- which ideas are marked as used
- current filter settings

This snapshot can be shared with a collaborator or loaded on another machine via **Import new scan**.

---

## Project files

| File | Purpose |
|---|---|
| `dashboard.html` | The complete dashboard — single self-contained HTML file |
| `CHANNEL_BRIEF.md` | Editorial voice, title rules, banned words, tone guidelines |
| `DATA_SCHEMAS.md` | JSON schema definitions for all pipeline output files |
| `AGENT_README.md` | Instructions for running the pipeline with an AI assistant |
| `API_STUBS.md` | Placeholder API integration points for future live data |
| `DASHBOARD_LOADING.md` | How data loading, fallback, and validation work |
| `SCAN_ARCHIVE.md` | Archive system design and folder conventions |
| `01_RESEARCH.md` — `05_VALIDATE.md` | Phase-by-phase pipeline prompt files |

---

## Prototype status

This is a working prototype. Live data connections are not yet active — all scan data is produced via manual AI-assisted research using the phase prompt files. The `API_STUBS.md` file documents the integration points where live source APIs would connect.

The `PROTOTYPE` badge in the dashboard header reflects this status.
