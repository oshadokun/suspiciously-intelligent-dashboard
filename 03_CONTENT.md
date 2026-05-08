# Phase 3 — Content Generation
## Story-Tied Ideas for Every Format

> **Input:** `analyzed_stories.json`
> **Output:** `content_ideas.json`, `ideas.md`
> **Tools used:** Read file, Write file

---

## Overview

Phase 3 generates specific, story-tied content ideas for every story in the content plan.

**The cardinal rule of this phase:**
Every single content idea must be traceable to a specific story by ID.
If you find yourself writing an idea that could apply to any AI story — discard it and start again.

---

## Step 1 — Read the data

Read `analyzed_stories.json`.
Filter for stories where `channel_fit: true`.
Order them by `score` descending — highest score first.

---

## Step 2 — For each story, generate all five formats

Work through each qualifying story in order. For every story, produce all five content formats:

1. YouTube long-form video
2. YouTube Short / Reel
3. Image post / carousel
4. Community post
5. Meme / satirical post

Do not skip formats. If a format genuinely cannot work for a specific story, write a brief note explaining why instead of generating a weak idea.

---

## Format 1 — YouTube Long-Form Video

### Title rules (enforce strictly)
- Maximum 65 characters — count them
- Sentence case — not Title Case, not ALL CAPS
- Must contain a specific claim or a specific question
- Must not contain: "shocking," "insane," "mind-blowing," "everything," "the truth about," "you need to know," "will change," "forever"
- Should feel like something a smart, curious person would say — not a YouTube algorithm hack

### Hook rules
- One sentence
- Creates genuine intrigue — not panic, not hype
- Should make the viewer feel like they're about to learn something specific and real
- Test: would this hook embarrass an intelligent person if they said it out loud? If yes, rewrite it.

### Structure rules
- Exactly 5 points
- Each point is specific to this story — not generic AI content
- The structure should build an argument, not just list facts
- Point 5 should land on something the viewer will think about after the video ends

### Why now — rules
- Must reference the specific timing of this story
- Must explain why this cannot wait — what will change if the channel covers it next week instead?
- "This is a big topic" is not a valid why-now. Cite the specific event and its window.

---

## Format 2 — YouTube Short / Reel

### Hook rules (3 seconds)
- Must be deliverable in under 3 seconds of speaking — roughly 10–12 words maximum
- Must create immediate curiosity or tension
- Avoid questions that the viewer can immediately answer themselves
- Good: "OpenAI just changed who watches OpenAI." (7 words, implies something is wrong)
- Bad: "Did you know AI can write code now?" (answerable, no tension)

### Visual concept rules
- Describe specifically what appears on screen — not "show relevant visuals"
- Consider what would work without sound (a large portion of Reels are watched muted)
- If the story involves a document, announcement, or product — show it
- Split screens, text overlays, and simple graphics work better than talking-head for Shorts

### CTA rules
- One action only
- Prefer driving to the long-form video if one exists for this story
- Keep it under 10 words

---

## Format 3 — Image Post / Carousel

### Slide structure rules
- First slide: hook — one sentence or phrase that makes someone stop scrolling
- Slides 2–N: supporting information, one idea per slide
- Last slide: takeaway, question, or CTA
- 4–7 slides total — not fewer than 4, not more than 7

### Visual direction rules
- Be specific: what is the background colour, what is the text style, what is the information hierarchy?
- Describe it as if briefing a designer — they should be able to execute without asking questions
- Avoid "clean and minimal" as the only direction — that tells a designer nothing

### Caption rules
- The caption should add something the slides don't say — not just narrate the slides
- Can be longer than a typical caption — carousel posts allow for it
- Should end with a signal to save or share, not a generic "follow for more"

---

## Format 4 — Community Post

### Question rules
- Must be genuinely open — no obviously correct answer
- Both sides of any poll must be defensible with a reasonable argument
- Avoid questions that make the audience feel judged for one answer
- The best questions reveal something interesting about how people think, not just their preferences

### Poll option rules (if using a poll)
- 3–4 options maximum
- Include at least one "middle" option to avoid false binary
- Options must be mutually exclusive
- Avoid joke options — this audience responds to substance

### Engagement rationale
- Explain specifically why this question will generate real discussion for this audience
- "People are interested in AI" is not a rationale. Be specific about the tension or trade-off the question exposes.

---

## Format 5 — Meme / Satirical Post

### Concept rules
- The joke must come from observation, not invention
- Must be grounded in a real, specific detail from the story
- Should make the audience feel clever for getting it — not embarrassed for the channel
- Works best when it exposes a contradiction, absurdity, or irony that is actually there in the news

### Risk assessment
Apply one of three risk levels:

**Low risk:** Satirises a company's decision, product, or public statement. No named individuals targeted. Factually grounded.

**Medium risk:** Involves named executives or public figures in a mildly critical framing. Clearly satirical. Could be taken out of context.
→ Write a `risk_note` explaining the specific concern and how the caption mitigates it.

**High risk:** Could be defamatory, could be confused for a real statement, targets a private individual, or involves a sensitive topic (safety incident, legal matter, health).
→ Write a detailed `risk_note`. Consider recommending against publishing.

---

## Step 3 — Write content_ideas.json

Follow the schema in `DATA_SCHEMAS.md` exactly.

Before writing each idea, run the following self-checks:

### Title check (YouTube videos)
- [ ] Under 65 characters? (Count the characters)
- [ ] Sentence case?
- [ ] Contains a specific claim or question?
- [ ] Free of banned words ("shocking," "insane," "mind-blowing," "everything," "forever," "truth about," "need to know," "will change")?

### Generic idea check (all formats)
- [ ] Does this idea reference a specific story by ID?
- [ ] Could this idea apply to ANY AI story from the past year? If yes — it's too generic. Rewrite or discard.

### Hook check
- [ ] Does the hook create genuine intrigue without being dishonest?
- [ ] Would an intelligent person be comfortable saying this hook out loud?

---

## Step 4 — Write ideas.md

Write a human-readable version of the content plan. This is what the channel team will actually read and use.

Structure it as follows:

```markdown
# Suspiciously Intelligent — Content Plan
Generated: [timestamp]
Stories in plan: N
Total ideas: N

---

## Priority order

[Rank stories by score, highest first. One line per story: score, headline, priority tags]

---

## Story: [headline]
**Score:** N | **Tags:** [tags] | **Source:** [url]

### YouTube video
**Title:** [title] ([char count] chars)
**Hook:** [hook]
**Structure:**
1. [point]
2. [point]
3. [point]
4. [point]
5. [point]
**Target:** [audience]
**Why now:** [rationale]
**Length:** ~N mins

### YouTube Short / Reel
**Hook (3 sec):** [hook]
**Visual:** [concept]
**Length:** N seconds
**CTA:** [cta]
**Caption:** [caption]

### Image post / Carousel
**Slides:** [title 1] / [title 2] / [title 3] / ...
**Caption:** [caption]
**Visual direction:** [direction]

### Community post
**Question:** [question]
**Poll options:** [options or N/A]
**Why it works:** [rationale]

### Meme
**Concept:** [concept]
**Caption:** [caption]
**Risk:** [level] — [note if applicable]

---
[repeat for each story]
```

---

## Phase 3 completion check

Before moving to Phase 4, confirm:

- [ ] `content_ideas.json` exists with schema-compliant structure
- [ ] Every idea has a valid `story_id` matching a story in `analyzed_stories.json`
- [ ] Every YouTube title is under 65 characters (check `title_char_count` field)
- [ ] No titles contain banned words
- [ ] Every meme with risk_level "medium" or "high" has a `risk_note`
- [ ] `ideas.md` exists and is readable
- [ ] `marked_as_used` is set to `false` on all ideas

If any check fails, fix it before proceeding.
