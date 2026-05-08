# Phase 5 — Validation
## Self-Check, Fix, and Run Report

> **Input:** All output files from Phases 1–4
> **Output:** `run_report.md` (plus fixes to any failing files)
> **Tools used:** Read files, Write files, logical validation

---

## Overview

Phase 5 validates every output file produced in this run. It is not a formality — if a check fails, you must fix the underlying file before writing the run report.

Work through each validation group in order. Fix failures as you find them.

---

## Validation Group 1 — raw_research.json

Read `raw_research.json` and check:

| Check | Pass condition | Fix if failing |
|---|---|---|
| File exists | File is present in working directory | Re-run Phase 1 |
| Story count | At least 10 stories present | Note in report — partial run |
| URLs present | Every story has a non-empty `url` field | Remove stories without URLs |
| Date filter applied | Every story has `within_7_days` set (not null) | Set to false if date unknown |
| scan_errors present | Field exists (may be empty array) | Add empty array |
| scan_date present | Field is an ISO timestamp | Add current timestamp |
| No null IDs | Every story has a non-empty `id` field | Generate slugs for any missing |

---

## Validation Group 2 — analyzed_stories.json

Read `analyzed_stories.json` and check:

| Check | Pass condition | Fix if failing |
|---|---|---|
| File exists | File is present | Re-run Phase 2 |
| Score range | All `score` values are integers 0–10 | Cap or floor any out-of-range values |
| Score breakdown | Every story has 4 dimensions in `score_breakdown` | Add missing dimensions as 0 |
| URGENT integrity | No story tagged URGENT has score < 8 | Remove URGENT tag from low-scoring stories |
| Priority tags | Every story with score ≥ 6 has ≥ 1 priority tag | Add WATCH tag as default |
| Platform fit | Every story with score ≥ 6 has ≥ 1 platform_fit | Add most appropriate platform |
| Relevance notes | No `channel_relevance_note` is empty or null | Write note for any blank entries |
| channel_fit set | Every story has `channel_fit` boolean | Set to true if score ≥ 6, false otherwise |
| Metadata counts | top-level counts match actual array counts | Recalculate and correct |

---

## Validation Group 3 — content_ideas.json

Read `content_ideas.json` and check:

| Check | Pass condition | Fix if failing |
|---|---|---|
| File exists | File is present | Re-run Phase 3 |
| Story ID integrity | Every `story_id` matches a real ID in analyzed_stories.json | Fix or remove orphaned ideas |
| Title length | Every `youtube_video.title_char_count` ≤ 65 | Shorten title and update count |
| Title char count | `title_char_count` equals actual character count of `title` | Recalculate |
| Banned words | No titles contain banned words (see list below) | Rewrite affected titles |
| Meme risk notes | Every meme with risk_level "medium" or "high" has a non-empty `risk_note` | Add risk note |
| marked_as_used | All ideas start as false | Set any null values to false |
| No empty hooks | No `hook` or `hook_3sec` field is empty | Write hooks for any blank entries |

### Banned words list (check all YouTube titles)
```
shocking
insane
mind-blowing
everything
the truth about
you need to know
will change
forever
crazy
unbelievable
incredible
epic
game changer
game-changer
gamechanger
revolutionary
```

---

## Validation Group 4 — dashboard.html

Read `dashboard.html` and check the JavaScript logic:

| Check | Pass condition | Fix if failing |
|---|---|---|
| File exists | File is present | Re-run Phase 4 |
| DATA source | JS loads from data.json, not hardcoded | Refactor to use fetch or inline JSON |
| Prototype badge | HTML contains "PROTOTYPE" text | Add badge to header |
| Mark as used | Uses localStorage, not server call | Rewrite to use localStorage |
| Export function | Export button has a click handler that generates text | Add handler if missing |
| API stubs present | Commented stubs block is present | Add from 04_DASHBOARD.md |
| Filter logic | Filter functions reference correct data keys | Check key names match data.json schema |
| No broken loops | Array operations check for null/undefined | Add null checks |

---

## Validation Group 5 — Content quality spot-check

Randomly select 3 content ideas and apply these quality checks manually:

For each selected idea:

1. **Specificity test:** Could this idea work for a different AI story published in the past 6 months? If yes — it is too generic and must be rewritten.

2. **Tone test:** Does the YouTube title or hook contain performative language that the channel's audience would find embarrassing? If yes — rewrite.

3. **Accuracy test:** Does the idea make a claim about the story that is not actually in the story? If yes — remove the unsupported claim.

4. **Timeliness test:** Does the why_now field reference something specific about this week? Or is it generic ("this is an important topic")? If generic — rewrite.

Document the result of each spot-check in the run report.

---

## Write run_report.md

After completing all validation and fixing all failures, write `run_report.md` with the following structure:

```markdown
# Run Report — Suspiciously Intelligent Dashboard
Generated: [ISO timestamp]
Run by: Claude Code

---

## Scan summary

| Metric | Count |
|---|---|
| Sources queried | N |
| Successful queries | N |
| Failed queries | N |
| Raw stories collected | N |
| After deduplication | N |
| Stories excluded (score < 5) | N |
| Stories in content plan | N |

### Failed queries
[List each failed query, or "None" if all succeeded]

---

## Content ideas generated

| Format | Count |
|---|---|
| YouTube videos | N |
| YouTube Shorts / Reels | N |
| Image posts | N |
| Community posts | N |
| Memes | N |
| **Total** | **N** |

---

## Validation results

### Group 1 — raw_research.json
[PASSED / FAILED — list any issues found and whether they were fixed]

### Group 2 — analyzed_stories.json
[PASSED / FAILED — list any issues found and whether they were fixed]

### Group 3 — content_ideas.json
[PASSED / FAILED — list any issues found and whether they were fixed]

### Group 4 — dashboard.html
[PASSED / FAILED — list any issues found and whether they were fixed]

### Group 5 — Quality spot-check
Story 1: [headline] — [PASSED / FAILED — notes]
Story 2: [headline] — [PASSED / FAILED — notes]
Story 3: [headline] — [PASSED / FAILED — notes]

---

## Top stories this week (by score)

| Rank | Score | Tags | Headline | Source(s) |
|---|---|---|---|---|
| 1 | N | [tags] | [headline] | [sources] |
| 2 | N | [tags] | [headline] | [sources] |
| 3 | N | [tags] | [headline] | [sources] |
| 4 | N | [tags] | [headline] | [sources] |
| 5 | N | [tags] | [headline] | [sources] |

---

## Recommended first video

**Title:** [exact title]
**Story:** [headline]
**Score:** N
**Why this one:**
[2–3 sentences explaining why this is the strongest video opportunity this week,
in the channel's voice]

**Hook:** [the video hook]

---

## Notes and observations

[Any patterns, anomalies, or observations from this run that would be useful for the channel team to know.
For example: a source category returned unusually thin results, a particular theme dominated this week,
a story was borderline excluded and might be worth a second look, etc.]

---

## Output files

| File | Status | Size |
|---|---|---|
| raw_research.json | [present/missing] | [size] |
| analyzed_stories.json | [present/missing] | [size] |
| content_ideas.json | [present/missing] | [size] |
| ideas.md | [present/missing] | [size] |
| dashboard.html | [present/missing] | [size] |
| data.json | [present/missing] | [size] |
| run_report.md | present | [size] |
```

---

## Phase 5 completion check

This is the final check before the agent stops.

- [ ] All six validation groups completed
- [ ] All failures were fixed (or documented as unfixable with reason)
- [ ] `run_report.md` is written
- [ ] All 7 output files are present
- [ ] Terminal summary is ready to print (see AGENT_README.md)

If any output file is missing and cannot be recovered, note it in the run report and print the terminal summary anyway — clearly marking the run as PARTIAL.
