# Phase 2 — Analyze
## Scoring, Deduplication, and Classification

> **Input:** `raw_research.json`
> **Output:** `analyzed_stories.json`
> **Tools used:** Read file, Write file, structured reasoning

---

## Overview

Phase 2 is the analyzer. It takes the raw stories from Phase 1 and:

1. Deduplicates stories about the same event
2. Scores each story on four dimensions
3. Classifies each story by priority, platform fit, and risk
4. Decides which stories move into the content plan
5. Writes the structured output file

**Be rigorous here.** The quality of content ideas in Phase 3 depends entirely on the quality of analysis in Phase 2.

---

## Step 1 — Read the raw data

Read `raw_research.json`. Note:
- Total story count
- How many are marked `within_7_days: false` (exclude these immediately)
- How many are marked as duplicates (`duplicate_of` is not null)

---

## Step 2 — Deduplicate

Group all stories that cover **the same event or announcement**.

Rules for grouping:
- Same company + same event = same story, even if the angle differs slightly
- Same research finding = same story, even if different outlets emphasise different aspects
- Same product launch = same story

For each group:
- Choose the **canonical story** (prefer the most detailed, most reputable, or earliest source)
- List all sources that covered it in the `sources` array
- Set `source_count` to the total number of sources
- Set `verified: true` if `source_count >= 2`
- Discard the duplicate entries (they are now merged into the canonical)

Keep a mental note of your final deduplicated count for the schema metadata field `total_after_dedup`.

---

## Step 3 — Score each story

Apply this scoring rubric to every story that passed the duplicate and date filters.

### Scoring rubric (max 10 points)

#### Dimension 1 — Recency (max 3 points)

| Score | Condition |
|---|---|
| 3 | Published today |
| 2 | Published yesterday |
| 1 | Published 2–4 days ago |
| 0 | Published 5–7 days ago or date unknown |

#### Dimension 2 — Source confirmation (max 3 points)

| Score | Condition |
|---|---|
| 3 | 3 or more distinct sources confirmed the story |
| 2 | Exactly 2 sources confirmed |
| 1 | 1 source only — story is plausible but unverified |
| 0 | Source is unclear, paywalled, or unverifiable |

#### Dimension 3 — Public interest signal (max 2 points)

| Score | Condition |
|---|---|
| 2 | Evidence of active discussion: Reddit thread, Twitter/X trending, YouTube comments, or news engagement data |
| 1 | Story was shared broadly but limited discussion found |
| 0 | No evidence of public engagement found |

**How to assess this:** Look at whether your search results include Reddit links, social sharing data, or comments. If the story appeared only in trade press with no apparent public reaction, score 0 or 1.

#### Dimension 4 — Content opportunity (max 2 points)

| Score | Condition |
|---|---|
| 2 | Strong, specific angle that fits the Suspiciously Intelligent channel — an unexpected detail, a contradiction, an underreported implication |
| 1 | Reasonable topic but the angle is obvious or well-covered |
| 0 | No clear angle, generic news update, or story requires making something up to be interesting |

**Reference `CHANNEL_BRIEF.md`** when scoring this dimension. Use the "Story fit criteria" and "Frames that work well" sections to guide your assessment.

---

## Step 4 — Assign priority tags

Based on total score, assign one or more priority tags:

| Tag | Condition |
|---|---|
| `URGENT` | Score ≥ 8 AND story is time-sensitive (unlikely to be relevant in 2+ weeks) |
| `WATCH` | Score 6–7 AND story is developing (more likely to grow) |
| `CONTENT OPPORTUNITY` | Score ≥ 6 AND Content opportunity dimension scored 2 |
| `HIGH RISK` | Story involves safety incident, legal action, or sensitive subject requiring careful framing |
| `UNDERREPORTED` | Score ≥ 5 AND story appeared only in specialist/financial press, not mainstream tech media |

Rules:
- A story can have multiple tags
- `URGENT` requires score ≥ 8. Do not assign it to lower-scoring stories.
- `UNDERREPORTED` can apply to stories scoring 5 — this is the exception where a lower-scoring story still enters the content plan

---

## Step 5 — Determine platform fit

For each story, decide which content formats are appropriate.
Assign all that apply from this list:

```
youtube_long      — story has enough depth for 8–18 min video
youtube_short     — one clear hook that works in 60 seconds
linkedin          — has a business/professional angle
instagram_reel    — visually demonstrable or has strong hook
twitter_thread    — works as a sequence of punchy observations
image_post        — can be explained across 4–7 slides
community_poll    — raises a genuine question without an obvious answer
```

**Do not assign a format just to fill the list.** If a story does not work as a Reel, do not assign `instagram_reel`.

---

## Step 6 — Assess risk and opportunity level

For each story, set:

**`risk_level`**: "low" / "medium" / "high"
- High risk: involves named individuals in a negative context, legal proceedings, safety incidents, content that could be seen as defamatory
- Medium risk: involves criticism of a specific company or executive, covers speculation presented as fact, touches on contested topics
- Low risk: factual news, product announcements, research findings, public company statements

**`opportunity_level`**: "low" / "medium" / "high"
- High: strong specific angle, timely, fits channel positioning, audience will care
- Medium: decent story but angle is competitive or obvious
- Low: thin story, no real angle, or audience unlikely to engage

---

## Step 7 — Write channel relevance note

For each story, write one sentence in the channel's voice explaining why this story matters for Suspiciously Intelligent specifically.

Do not write "This is a good story about AI." Write the specific angle.

Examples of good relevance notes:
- "A safety board made of the company's own employees is structurally the same as having no safety board — that's the line of the video."
- "Three outlets ran this benchmark result without mentioning it was run by the company that built the model."
- "Workers in this industry have been told AI would augment their jobs for two years — this is the first concrete data showing the opposite."

---

## Step 8 — Exclude low-scoring stories

Stories with `score < 5` (and not tagged `UNDERREPORTED`) are excluded from the content plan.

They are **not deleted** from the file. Add a field `"channel_fit": false` to excluded stories so they remain auditable.

---

## Step 9 — Write analyzed_stories.json

Write the complete file following the schema in `DATA_SCHEMAS.md`.

Populate the top-level metadata fields:
- `total_stories_raw` — from raw_research.json
- `total_after_dedup` — after merging duplicates
- `stories_excluded_low_score` — count of stories with channel_fit: false
- `stories_in_content_plan` — count with channel_fit: true

---

## Phase 2 completion check

Before moving to Phase 3, confirm:

- [ ] `analyzed_stories.json` exists
- [ ] Every story has a `score` field with an integer value 0–10
- [ ] Every story has a `score_breakdown` object with 4 dimensions
- [ ] No story tagged `URGENT` has a score below 8
- [ ] Every story with score ≥ 6 has at least one priority tag
- [ ] Every story with score ≥ 6 has at least one platform_fit entry
- [ ] Every story has a `channel_relevance_note` — not empty
- [ ] `stories_in_content_plan` count matches the number of stories with `channel_fit: true`

If any check fails, fix it before proceeding.

---

## Analyzer mindset — notes for this phase

This phase requires judgment, not just mechanical application of rules. Some guidance:

**On source confirmation:** A story confirmed by TechCrunch and a blog that simply re-summarised TechCrunch is not a story confirmed by two independent sources. Look for independent reporting.

**On public interest:** Reddit upvotes and Twitter engagement are real signals but noisy ones. A thread with 4,000 upvotes means people reacted — it doesn't tell you the story is important. Use your judgment.

**On content opportunity:** The single most important question for this channel is: "Is there something here that other outlets missed or mis-framed?" If the answer is clearly yes, score 2. If you are inventing an angle that isn't really there, score 0.

**On risk:** Err on the side of marking things `HIGH RISK` if in doubt. It is better to flag and then decide not to proceed than to miss a risk entirely.
