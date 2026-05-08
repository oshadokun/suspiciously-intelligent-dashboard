# Data Schemas — Suspiciously Intelligent Agent

> These schemas define the exact structure of every JSON file the agent produces.
> Follow them precisely. Do not add fields not listed here. Do not omit required fields.

---

## Schema 1 — raw_research.json

Produced by: Phase 1
Read by: Phase 2

```json
{
  "schema_version": "1.0",
  "scan_date": "2025-05-06T14:30:00Z",
  "research_window_days": 7,
  "scan_errors": [
    "Failed query: 'AI tool trending site:producthunt.com' — no results returned"
  ],
  "queries_run": 28,
  "queries_succeeded": 25,
  "stories": [
    {
      "id": "openai-gpt5-rumour-may25",
      "headline": "OpenAI hints at new model release timeline in internal memo",
      "summary": "A leaked internal document suggests OpenAI is accelerating its release schedule for its next flagship model, with engineers citing competitive pressure from Google DeepMind's Gemini updates. The memo references a target of Q3 2025.",
      "url": "https://example.com/article",
      "source": "The Verge",
      "source_category": "model_release",
      "published_date": "2025-05-04",
      "within_7_days": true,
      "verified": false,
      "speculation": true,
      "duplicate_of": null,
      "raw_excerpt": "Optional: short quote from the source if relevant"
    }
  ]
}
```

### Field definitions — raw_research.json

| Field | Type | Required | Notes |
|---|---|---|---|
| `schema_version` | string | yes | Always "1.0" |
| `scan_date` | ISO timestamp | yes | Exact time the scan ran |
| `research_window_days` | integer | yes | Always 7 |
| `scan_errors` | array of strings | yes | Empty array if no errors |
| `queries_run` | integer | yes | Total number of searches attempted |
| `queries_succeeded` | integer | yes | Searches that returned results |
| `stories[].id` | string | yes | Lowercase, hyphenated slug. Must be unique. |
| `stories[].headline` | string | yes | Exact or close paraphrase of source headline |
| `stories[].summary` | string | yes | 2–3 sentences. Your own words. |
| `stories[].url` | string | yes | **Must be a real URL you retrieved.** |
| `stories[].source` | string | yes | Publication name |
| `stories[].source_category` | string | yes | See allowed values below |
| `stories[].published_date` | ISO date or null | yes | null if not determinable |
| `stories[].within_7_days` | boolean | yes | false = exclude from analysis |
| `stories[].verified` | boolean | yes | true only if 2+ sources confirm |
| `stories[].speculation` | boolean | yes | true if based on rumour or prediction |
| `stories[].duplicate_of` | string or null | yes | ID of parent story if duplicate |
| `stories[].raw_excerpt` | string or null | no | Optional short quote |

### Allowed values — source_category

```
company_move
model_release
regulation
tools_viral
open_source
research
jobs
safety_scams
sentiment
hardware
underreported
```

---

## Schema 2 — analyzed_stories.json

Produced by: Phase 2
Read by: Phases 3 and 4

```json
{
  "schema_version": "1.0",
  "generated_at": "2025-05-06T15:00:00Z",
  "total_stories_raw": 48,
  "total_after_dedup": 31,
  "stories_excluded_low_score": 12,
  "stories_in_content_plan": 19,
  "stories": [
    {
      "id": "openai-safety-board-restructure",
      "headline": "OpenAI restructures its safety board following internal pressure",
      "summary": "OpenAI has made changes to its safety and oversight board, removing two external members and replacing them with current employees. The move follows a turbulent period of public criticism over the company's approach to safety commitments.",
      "url": "https://example.com/article",
      "sources": ["The Verge", "TechCrunch", "Wired"],
      "source_count": 3,
      "source_category": "company_move",
      "published_date": "2025-05-03",
      "within_7_days": true,
      "verified": true,
      "speculation": false,
      "score": 9,
      "score_breakdown": {
        "recency": 2,
        "source_confirmation": 3,
        "public_interest_signal": 2,
        "content_opportunity": 2
      },
      "priority_tags": ["URGENT", "CONTENT OPPORTUNITY"],
      "platform_fit": ["youtube_long", "youtube_short", "twitter_thread", "linkedin"],
      "risk_level": "medium",
      "opportunity_level": "high",
      "channel_relevance_note": "Classic Suspiciously Intelligent territory — a company saying one thing publicly while doing the opposite structurally.",
      "channel_fit": true
    }
  ]
}
```

### Field definitions — analyzed_stories.json

| Field | Type | Required | Notes |
|---|---|---|---|
| `schema_version` | string | yes | Always "1.0" |
| `generated_at` | ISO timestamp | yes | |
| `total_stories_raw` | integer | yes | Count from raw_research.json |
| `total_after_dedup` | integer | yes | After merging duplicates |
| `stories_excluded_low_score` | integer | yes | Scored < 5 |
| `stories_in_content_plan` | integer | yes | Scored ≥ 6 |
| `stories[].id` | string | yes | Same as raw ID or canonical duplicate ID |
| `stories[].headline` | string | yes | |
| `stories[].summary` | string | yes | May be expanded from raw version |
| `stories[].url` | string | yes | Primary/best source URL |
| `stories[].sources` | array of strings | yes | All publications covering this story |
| `stories[].source_count` | integer | yes | Length of sources array |
| `stories[].source_category` | string | yes | |
| `stories[].published_date` | ISO date or null | yes | |
| `stories[].within_7_days` | boolean | yes | Must be true for all included stories |
| `stories[].verified` | boolean | yes | true if source_count ≥ 2 |
| `stories[].speculation` | boolean | yes | |
| `stories[].score` | integer 0–10 | yes | Sum of score_breakdown |
| `stories[].score_breakdown` | object | yes | See scoring rubric in 02_ANALYZE.md |
| `stories[].priority_tags` | array of strings | yes | At least one for score ≥ 6 |
| `stories[].platform_fit` | array of strings | yes | See allowed values below |
| `stories[].risk_level` | string | yes | "low" / "medium" / "high" |
| `stories[].opportunity_level` | string | yes | "low" / "medium" / "high" |
| `stories[].channel_relevance_note` | string | yes | 1 sentence, your voice |
| `stories[].channel_fit` | boolean | yes | true if score ≥ 6 and fits channel tone |

### Allowed values — priority_tags
```
URGENT
WATCH
CONTENT OPPORTUNITY
HIGH RISK
UNDERREPORTED
```

### Allowed values — platform_fit
```
youtube_long
youtube_short
linkedin
instagram_reel
twitter_thread
image_post
community_poll
```

---

## Schema 3 — content_ideas.json

Produced by: Phase 3
Read by: Phase 4

```json
{
  "schema_version": "1.0",
  "generated_at": "2025-05-06T15:30:00Z",
  "total_ideas": 19,
  "ideas": [
    {
      "idea_id": "idea-001",
      "story_id": "openai-safety-board-restructure",
      "story_headline": "OpenAI restructures its safety board following internal pressure",
      "story_score": 9,
      "formats": {
        "youtube_video": {
          "title": "OpenAI quietly changed who's watching it. That should concern you.",
          "title_char_count": 58,
          "hook": "There's something unusual about how this was announced — or rather, how it wasn't.",
          "structure": [
            "What the safety board was originally supposed to do",
            "Who just left and who replaced them — and why that matters",
            "What OpenAI's public commitments actually say vs. what this move does",
            "How this compares to similar governance changes at other AI labs",
            "What this tells us about how AI self-regulation actually works in practice"
          ],
          "target_audience": "Tech-adjacent professionals who follow AI policy loosely and want the real version of events",
          "why_now": "The change was made quietly this week and most coverage has only reported the facts — nobody has drawn the governance implication yet",
          "estimated_length_mins": 12
        },
        "youtube_short": {
          "hook_3sec": "OpenAI just changed who watches OpenAI.",
          "caption": "This week's safety board shuffle is more significant than the press covered. Here's the 60-second version.",
          "visual_concept": "Split screen: OpenAI's published safety commitments on one side, the new board composition on the other. No voiceover needed — let the contrast speak.",
          "suggested_length_sec": 60,
          "cta": "Full breakdown on the main channel."
        },
        "image_post": {
          "slide_titles": [
            "OpenAI's safety board just changed",
            "Who was on it before",
            "Who's on it now",
            "What their own policy says about independence",
            "Why this is worth paying attention to"
          ],
          "main_message": "A structural change in AI oversight happened this week. Here's what it means in plain language.",
          "visual_direction": "Clean dark background, minimal text per slide, source citations on each fact slide. No stock images.",
          "caption": "Filed under: things that happened quietly. OpenAI restructured its safety board this week. The details are in the slides."
        },
        "community_post": {
          "question_or_poll": "Should AI companies be allowed to self-regulate their own safety oversight — or does that need to be external by law?",
          "poll_options": [
            "Self-regulation can work if the commitment is genuine",
            "External legal oversight is the only thing that works",
            "It depends on the company",
            "We don't have enough information to judge yet"
          ],
          "engagement_rationale": "No obviously correct answer — all options are defensible. Forces the audience to think rather than react."
        },
        "meme": {
          "concept": "OpenAI's safety board being made of OpenAI employees framed as 'asking the test-setter to also mark the test.'",
          "caption": "totally normal governance stuff",
          "risk_level": "low",
          "risk_note": null
        }
      },
      "marked_as_used": false
    }
  ]
}
```

### Field definitions — content_ideas.json

| Field | Type | Required | Notes |
|---|---|---|---|
| `idea_id` | string | yes | Sequential: "idea-001", "idea-002" etc. |
| `story_id` | string | yes | **Must match an ID in analyzed_stories.json** |
| `story_headline` | string | yes | Copied from analyzed_stories.json |
| `story_score` | integer | yes | Copied from analyzed_stories.json |
| `formats.youtube_video.title` | string | yes | Under 65 chars — enforce this |
| `formats.youtube_video.title_char_count` | integer | yes | Computed length of title |
| `formats.youtube_video.hook` | string | yes | One sentence. Intrigue, not clickbait. |
| `formats.youtube_video.structure` | array 5 items | yes | Specific to this story |
| `formats.youtube_video.target_audience` | string | yes | Specific description |
| `formats.youtube_video.why_now` | string | yes | Must reference timing of specific story |
| `formats.youtube_video.estimated_length_mins` | integer | yes | |
| `formats.youtube_short.hook_3sec` | string | yes | Deliverable in 3 seconds |
| `formats.youtube_short.caption` | string | yes | |
| `formats.youtube_short.visual_concept` | string | yes | Specific visual direction |
| `formats.youtube_short.suggested_length_sec` | integer | yes | 30–90 |
| `formats.youtube_short.cta` | string | yes | |
| `formats.image_post.slide_titles` | array 4–7 | yes | |
| `formats.image_post.main_message` | string | yes | |
| `formats.image_post.visual_direction` | string | yes | |
| `formats.image_post.caption` | string | yes | |
| `formats.community_post.question_or_poll` | string | yes | |
| `formats.community_post.poll_options` | array or null | yes | null if open question |
| `formats.community_post.engagement_rationale` | string | yes | |
| `formats.meme.concept` | string | yes | |
| `formats.meme.caption` | string | yes | |
| `formats.meme.risk_level` | string | yes | "low" / "medium" / "high" |
| `formats.meme.risk_note` | string or null | yes | Required if risk_level is medium or high |
| `marked_as_used` | boolean | yes | Always starts as false |

---

## Schema 4 — data.json

Produced by: Phase 4
Read by: dashboard.html (client-side JavaScript)

This is the data payload the dashboard loads. It is a simplified, display-ready version of analyzed_stories.json and content_ideas.json merged together.

```json
{
  "meta": {
    "generated_at": "2025-05-06T15:45:00Z",
    "research_window": "Last 7 days",
    "is_prototype": true,
    "prototype_note": "PROTOTYPE — Live API connections not yet active. Data from manual WebSearch scan.",
    "total_stories": 19,
    "total_ideas": 19
  },
  "executive_summary": "Three to five sentence overview of the current AI landscape based on your research. Write this in the channel's voice — observational, not hyped.",
  "stories": [
    {
      "id": "openai-safety-board-restructure",
      "headline": "OpenAI restructures its safety board following internal pressure",
      "summary": "Short version for dashboard display — 1–2 sentences.",
      "url": "https://example.com",
      "sources": ["The Verge", "TechCrunch"],
      "score": 9,
      "priority_tags": ["URGENT", "CONTENT OPPORTUNITY"],
      "source_category": "company_move",
      "risk_level": "medium",
      "opportunity_level": "high",
      "platform_fit": ["youtube_long", "youtube_short", "twitter_thread"],
      "verified": true,
      "idea_id": "idea-001"
    }
  ],
  "top_video_recommendation": {
    "idea_id": "idea-001",
    "story_id": "openai-safety-board-restructure",
    "title": "OpenAI quietly changed who's watching it. That should concern you.",
    "rationale": "Highest score this week, underreported governance angle, strong fit for the channel's sceptical framing."
  }
}
```
