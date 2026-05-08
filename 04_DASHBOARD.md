# Phase 4 — Dashboard Generation
## Build the HTML Intelligence Dashboard

> **Input:** `analyzed_stories.json`, `content_ideas.json`
> **Output:** `dashboard.html`, `data.json`
> **Tools used:** Read files, Write files

---

## Overview

Phase 4 builds the self-contained HTML dashboard. It is a control panel for the Suspiciously Intelligent channel team — giving them a clear view of what's happening in AI, what content to make, and which stories are highest priority.

**Architecture principle:** Data is separate from display logic.
- `data.json` holds all the content (generated from your JSON files)
- `dashboard.html` loads `data.json` and renders it
- This means the dashboard can be updated by replacing `data.json` without touching the HTML

---

## Step 1 — Build data.json

Read `analyzed_stories.json` and `content_ideas.json`.
Merge them into a single `data.json` payload following the schema in `DATA_SCHEMAS.md`.

The `executive_summary` field should be 3–5 sentences written in the channel's voice, summarising the current AI landscape based on what you actually found in Phase 1. Do not write generic copy — reference the specific stories and themes you found.

---

## Step 2 — Build dashboard.html

Write a single self-contained HTML file with embedded CSS and JavaScript.
The JavaScript should fetch `data.json` from the same directory and render the dashboard dynamically.

**No external dependencies** except optionally Chart.js (load from `https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js` if you use it).

---

## Dashboard sections — required

### Section 1 — Agent control panel (top of page)

Must include:
- **Prototype badge** — clearly visible: `"PROTOTYPE — Live API connections not yet active"`
- **Agent status toggle** — ON/OFF button. When OFF, visually dims the dashboard. State persists in localStorage.
- **Last scan timestamp** — pulled from `data.json` meta
- **Scan button** — labelled "Scan sources" — in prototype mode, shows a toast: "Live scanning requires API keys. See API_STUBS.md"
- **Export button** — labelled "Export ideas" — downloads a `.txt` file of all ideas not marked as used

### Section 2 — Executive summary

Pull from `data.json.executive_summary`.
Display as a styled paragraph with the current scan date.
Include a small stat row: total stories found, stories in content plan, total ideas generated.

### Section 3 — Trending topics table

A filterable, sortable table of all stories from `analyzed_stories.json` where `channel_fit: true`.

Columns:
- Priority (badge: URGENT = red, WATCH = amber, CONTENT OPPORTUNITY = green, HIGH RISK = dark red, UNDERREPORTED = blue)
- Score (1–10, displayed as a number with a small bar)
- Headline (links to the story URL — opens in new tab)
- Category
- Sources (count)
- Verified (yes/no badge)
- Platform fit (icon row)
- Actions (View ideas button)

Filtering:
- Filter by priority tag (multi-select checkboxes)
- Filter by source_category (dropdown)
- Filter by platform (dropdown)
- Search bar (searches headline text)

Sorting:
- Sortable by score (default descending), date, category

### Section 4 — Content recommendation cards

Display all content ideas from `content_ideas.json`.

Group by format:
- YouTube videos
- YouTube Shorts / Reels
- Image posts
- Community posts
- Memes

Each card must include:
- Story headline it is tied to
- Story score and priority tags
- Format-specific content (title, hook, structure for videos / hook and visual concept for shorts / etc.)
- "Mark as used" button — toggles `marked_as_used` in localStorage. Visually strikes out the card.
- Story URL link
- Opportunity score badge (pulled from `opportunity_level`)

### Section 5 — Platform recommendation panel

A compact panel showing which platforms have the most content opportunities this week:
- List each platform with a count of qualifying stories and ideas
- Highlight the top recommended platform based on story scores and platform fit counts

### Section 6 — Source audit panel

Show:
- Which source categories were scanned (all 11 from Phase 1)
- How many stories were found per category
- Any failed queries (from `scan_errors` in raw_research.json)
- A note: "Sources are verified by cross-referencing against multiple outlets"

### Section 7 — Risk/opportunity matrix (optional but recommended)

A simple 2x2 grid or scatter view plotting stories by `risk_level` (x-axis) and `opportunity_level` (y-axis). Stories in the high-opportunity, low-risk quadrant are labelled prominently.

If using Chart.js, use a scatter chart. If not, use a CSS grid layout.

---

## Design requirements

### Colour scheme
- Dark mode by default
- Background: #0f1117 (very dark navy-black)
- Surface: #1a1d27
- Border: #2a2d3a
- Text primary: #e8eaf0
- Text secondary: #8b90a4
- Accent: #6366f1 (indigo)
- URGENT: #ef4444
- WATCH: #f59e0b
- CONTENT OPPORTUNITY: #10b981
- HIGH RISK: #991b1b
- UNDERREPORTED: #3b82f6
- Light mode toggle: switches to light backgrounds (implement fully)

### Typography
- Font stack: system-ui, -apple-system, sans-serif
- No external font imports
- Body: 14px / 1.6
- Headings: 16–24px, weight 600
- Monospace for scores and technical fields

### Layout
- Max width: 1400px, centred
- Sidebar for filters (desktop), collapsible on mobile
- Main content area for tables and cards
- Sticky header with control panel

### Interactions
- Filter changes update table and cards immediately (no page reload)
- "Mark as used" persists across sessions (localStorage)
- "Export ideas" generates clean `.txt` output
- Sort columns by clicking header
- Story URL opens in new tab
- Toast notifications for button actions

---

## API integration stubs

Include the following as commented JavaScript blocks at the bottom of the `<script>` section. Label them clearly.

```javascript
// ============================================================
// LIVE API INTEGRATION STUBS
// Uncomment and configure to enable live scanning
// See API_STUBS.md for full implementation guide
// ============================================================

// --- News APIs ---
// async function fetchNewsAPI(query, apiKey) {
//   const url = `https://newsapi.org/v2/everything?q=${encodeURIComponent(query)}&sortBy=publishedAt&pageSize=20&apiKey=${apiKey}`;
//   const res = await fetch(url);
//   const data = await res.json();
//   return data.articles.map(a => ({
//     headline: a.title,
//     url: a.url,
//     source: a.source.name,
//     published_date: a.publishedAt,
//     summary: a.description
//   }));
// }

// --- Reddit ---
// async function fetchRedditHot(subreddit, limit = 25) {
//   const res = await fetch(`https://www.reddit.com/r/${subreddit}/hot.json?limit=${limit}`);
//   const data = await res.json();
//   return data.data.children.map(p => ({
//     headline: p.data.title,
//     url: `https://reddit.com${p.data.permalink}`,
//     source: `r/${subreddit}`,
//     upvotes: p.data.ups,
//     comment_count: p.data.num_comments
//   }));
// }

// --- YouTube Data API ---
// async function fetchYouTubeTrending(query, apiKey) {
//   const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&q=${encodeURIComponent(query)}&type=video&order=date&publishedAfter=${sevenDaysAgo()}&key=${apiKey}`;
//   const res = await fetch(url);
//   return res.json();
// }

// --- Hugging Face ---
// async function fetchHuggingFaceTrending() {
//   const res = await fetch('https://huggingface.co/api/models?sort=trending&limit=20&direction=-1');
//   return res.json();
// }

// --- arXiv RSS ---
// async function fetchArxivAI() {
//   const res = await fetch('https://export.arxiv.org/rss/cs.AI');
//   const text = await res.text();
//   const parser = new DOMParser();
//   const xml = parser.parseFromString(text, 'text/xml');
//   return Array.from(xml.querySelectorAll('item')).slice(0, 20).map(item => ({
//     headline: item.querySelector('title')?.textContent,
//     url: item.querySelector('link')?.textContent,
//     summary: item.querySelector('description')?.textContent
//   }));
// }

// --- Claude API (for re-analysis) ---
// async function reanalyseWithClaude(stories, apiKey) {
//   const res = await fetch('https://api.anthropic.com/v1/messages', {
//     method: 'POST',
//     headers: {
//       'Content-Type': 'application/json',
//       'x-api-key': apiKey,
//       'anthropic-version': '2023-06-01'
//     },
//     body: JSON.stringify({
//       model: 'claude-opus-4-5',
//       max_tokens: 4096,
//       messages: [{ role: 'user', content: `Analyse these AI stories and return scored JSON: ${JSON.stringify(stories)}` }]
//     })
//   });
//   return res.json();
// }

// --- Helper ---
// function sevenDaysAgo() {
//   const d = new Date();
//   d.setDate(d.getDate() - 7);
//   return d.toISOString();
// }
```

---

## Phase 4 completion check

Before moving to Phase 5, confirm:

- [ ] `data.json` exists and is valid JSON
- [ ] `dashboard.html` exists
- [ ] Dashboard loads without JavaScript errors (check logic manually by reading the code)
- [ ] DATA object in dashboard references correct fields from `data.json` schema
- [ ] Prototype badge is visible and prominent
- [ ] "Mark as used" uses localStorage (not a server call)
- [ ] "Export ideas" generates text output of unmarked ideas
- [ ] All 7 dashboard sections are present
- [ ] API stubs are present as commented code
- [ ] Light mode toggle works
- [ ] Filters function correctly in the JavaScript logic

If any check fails, fix it before proceeding.
