# Dashboard Loading Architecture

## One-click launch (recommended)

```powershell
.\start_dashboard.ps1
```

What it does:
1. Checks if the server is already running on port 8765
2. If not, starts `serve.ps1` in a separate PowerShell window (no blocking)
3. Waits until the server responds (up to 10 seconds)
4. Opens `http://localhost:8765/dashboard.html` in your **default browser** — not VS Code Simple Browser

To stop the server:

```powershell
.\stop_dashboard.ps1
```

Finds and kills the process listening on port 8765.

---

## How data gets into the dashboard

The dashboard tries three data sources in priority order:

| Priority | Source | How |
|---|---|---|
| 1 | `/scans/latest/` | `fetch()` on startup |
| 2 | Manual import | User uploads via **Import new scan** |
| 3 | Embedded fallback | Hardcoded in `dashboard.html` |

The active source is shown as a badge in the header:
- **Latest scan** (green) — loaded from `/scans/latest/`
- **Imported snapshot** (blue) — loaded via manual import
- **Embedded fallback** (amber) — demo data, no scan found

---

## Automatic loading from /scans/latest/

On every page load the dashboard calls `tryLoadLatestScan()`, which:

1. Fetches `scans/latest/data.json` and `scans/latest/content_ideas.json`
2. Validates the JSON structure (required fields, correct types)
3. Replaces embedded data with the loaded scan
4. Updates the header badge to **Latest scan**
5. Clears any warning banner

The **Reload latest** button in the header repeats this on demand without reloading the page. Workflow states are preserved across reloads because they are stored by story ID — only new story IDs start as `Discovered`.

---

## Fallback behaviour

If loading fails, the dashboard falls back to the embedded demo data (the May 6 2026 scan baked into `dashboard.html`) and shows a warning banner explaining why.

The two most common failure cases:

### Opened via file:// (most common on first use)

When you double-click `dashboard.html` to open it, browsers use the `file://`
protocol and block cross-origin requests to other local files.  The banner reads:

> *Latest scan not found — using embedded fallback data. Run **serve.ps1** ...*

**Fix**: run `serve.ps1` (see below).

### /scans/latest/ is empty or missing

If `archive_scan.ps1` has never been run, or the files were deleted, the banner reads:

> *Latest scan not found — check that /scans/latest/data.json exists...*

**Fix**: run `.\archive_scan.ps1` after the next pipeline run, or run
`.\load_latest_scan.ps1` to copy a historical scan into `latest/`.

---

## Recommended workflow: serve.ps1

`serve.ps1` starts a zero-dependency local HTTP server that removes the
`file://` restriction:

```powershell
# In the project folder:
.\serve.ps1
```

This:
1. Starts an HTTP listener on `http://localhost:8765`
2. Opens `http://localhost:8765/dashboard.html` in your default browser
3. Serves all files under the project root — including `/scans/latest/`

The dashboard will now load the latest scan automatically on every open.
Press **Ctrl+C** in the terminal to stop the server.

### Custom port

```powershell
.\serve.ps1 -Port 9000
```

### Start without opening browser

```powershell
.\serve.ps1 -NoBrowser
```

---

## Manual import (alternative, no server needed)

If you prefer not to run a server, the **Import new scan** button in the
header lets you load specific JSON files from any location:

1. Click **Import new scan**
2. Upload `data.json` (from any `scans/YYYY-MM-DD/` folder)
3. Upload `content_ideas.json` (from the same folder)

The header badge updates to **Imported snapshot**. Workflow states are preserved.

---

## Validation

Before accepting any loaded data, the dashboard validates:

| Check | Rule |
|---|---|
| Root type | Must be a JSON object |
| `stories` field | Must be an array with ≥ 1 entry |
| Each story: `id` | Required, non-empty |
| Each story: `headline` | Required, non-empty |
| Each story: `score` | Must be a number |
| Each story: `priority_tags` | Must be an array |
| `content_ideas` | Must have ≥ 1 entry with `idea_id` |

If validation fails, the import is rejected with a specific error message. The
previous active data is not modified.

---

## Load log

Every load attempt is recorded in memory and logged to the browser console.
To inspect it:

1. Open browser DevTools (F12)
2. In the Console tab, type: `SI_LOAD_LOG`

Each entry:

```json
{
  "time":    "2026-05-08T14:22:00Z",
  "type":    "success",
  "source":  "latest",
  "message": "Loaded 22 stories from scans/latest/data.json"
}
```

Log types: `success`, `fallback`, `import`, `error`, `file-protocol`.

---

## Browser compatibility

| Browser | file:// works | http://localhost works |
|---|---|---|
| Chrome 60+ | No (blocked) | Yes |
| Edge 79+ | No (blocked) | Yes |
| Firefox | No (default) | Yes |
| Safari | No | Yes |

All modern browsers work correctly when served via `serve.ps1`. The embedded
fallback ensures the dashboard is never blank even when opened directly.

---

## Offline limitations

| Limitation | Notes |
|---|---|
| `file://` auto-load | Not possible without a server. The embedded fallback always works, but it will be stale after the first real scan. |
| serve.ps1 is manual | You must start the server in a terminal. There is no background service. |
| Single-user | No multi-user sync; localStorage and scans are local to one machine. |
| No WebSocket push | The dashboard does not poll for scan updates. Press **Reload latest** or refresh the page. |
