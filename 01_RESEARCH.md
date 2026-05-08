# Phase 1 — Research
## Live Source Scanning

> **Input:** None (this is the first phase)
> **Output:** `raw_research.json`
> **Tools used:** WebSearch, Bash (for date confirmation)

---

## Step 1 — Confirm the date

Before running any searches, confirm today's date using Bash:

```bash
date
```

The research window is: **today minus 7 days to today.**
Record the window in your scan metadata.
Reject any story you cannot confirm falls within this window.

---

## Step 2 — Run all searches

Execute each query below using WebSearch. Run them in order.
After each group, note how many results were returned.
If a query returns zero results, log it in `scan_errors` and move on.

Do not skip queries. Even if you expect a category to be thin, run it.

---

### Group A — AI Company Moves

```
OpenAI news this week
Anthropic announcement this week
Google DeepMind news this week
Meta AI news this week
Microsoft AI news this week
xAI Grok news this week
NVIDIA AI news this week
```

**What to look for:**
- Leadership changes
- New products or features announced
- Unusual public statements or policy shifts
- Funding rounds, acquisitions, partnerships
- Anything that contradicts a company's previous public positioning

---

### Group B — Model Releases and Benchmarks

```
new AI model released this week
LLM benchmark results this week
AI model update this week
open source model release this week
```

**What to look for:**
- New model launches with claimed capability improvements
- Benchmark results (treat claims sceptically — check who ran the benchmark)
- Fine-tuned or specialised model releases
- Model releases that received unusual community reaction

---

### Group C — Regulation and Legal

```
AI regulation news this week
AI lawsuit filed this week
EU AI Act enforcement 2025
AI copyright ruling this week
AI government policy this week
```

**What to look for:**
- New legislation or regulatory guidance
- Court rulings involving AI companies
- Government statements on AI (especially enforcement, not just speeches)
- Lawsuits from creators, workers, or consumers

---

### Group D — Tools Going Viral

```
AI tool going viral this week
new AI app trending this week
AI product launch this week
AI tool Product Hunt this week
```

**What to look for:**
- Consumer or professional AI tools getting unusual traction
- Tools that sparked debate (about usefulness, ethics, or novelty)
- Products with interesting business models or controversial features
- Tools that reveal something about where AI is actually being adopted

---

### Group E — Open Source

```
Hugging Face trending models this week
GitHub trending AI repositories this week
open source LLM release this week
AI community release this week
```

**What to look for:**
- Notable model releases on Hugging Face
- GitHub repositories gaining unusual velocity
- Open-source projects that challenge or replicate commercial products
- Community reactions to open-source releases

---

### Group F — AI Research

```
arXiv AI paper notable this week
AI research breakthrough this week
AI safety paper this week
AI capabilities research this week
```

**What to look for:**
- Papers with significant capability claims
- Safety or alignment research with practical implications
- Research that challenges existing assumptions about AI
- Anything that got picked up by non-technical press (and check if the coverage is accurate)

---

### Group G — Jobs and Workplace

```
AI replacing workers this week
AI job displacement news this week
AI automation layoffs this week
AI workplace productivity this week
```

**What to look for:**
- Specific company announcements about AI-driven headcount changes
- Studies on AI's actual productivity effects (check methodology)
- Worker or union responses to AI deployment
- Cases where AI automation went wrong

---

### Group H — Safety, Scams, and Deepfakes

```
AI deepfake news this week
AI scam this week
AI generated fraud this week
AI safety incident this week
AI misuse this week
```

**What to look for:**
- Specific incidents involving deepfakes (not just general warnings)
- New AI-powered scam techniques or documented cases
- Safety incidents at AI labs
- Cases where AI caused measurable harm

---

### Group I — Public Sentiment

```
AI Reddit discussion trending this week
AI controversy this week
AI public backlash this week
AI debate this week
AI Twitter controversy this week
```

**What to look for:**
- Reddit threads with unusual upvote velocity on AI topics
- Public debates on X/Twitter about AI (look for genuine discourse, not just hot takes)
- Polls or surveys on AI attitudes published this week
- Moments where AI coverage itself became the story

---

### Group J — Hardware and Infrastructure

```
AI chip news this week
AI data centre investment this week
NVIDIA news this week
AI infrastructure this week
AI energy consumption news this week
```

**What to look for:**
- New chip announcements (including from non-NVIDIA players)
- Data centre construction or energy deals
- Supply chain news affecting AI hardware
- Reports on AI's energy or water consumption

---

### Group K — Underreported

```
AI policy this week site:reuters.com
AI news this week site:ft.com
AI this week site:bloomberg.com
AI labour this week
AI ethics this week underreported
```

**What to look for:**
- Stories that appeared in serious financial or specialist press but not in tech media
- Slow-burn stories that have been developing for weeks without big coverage
- International AI news (non-US, non-UK)
- Stories that are factually significant but lack the drama to go viral

---

## Step 3 — Record raw results

For every story you find that:
- Has a real URL
- Was published within the last 7 days (or cannot be confirmed as older)
- Is about AI specifically (not just tangentially)

...create an entry in `raw_research.json` following the schema in `DATA_SCHEMAS.md`.

**Minimum 10 stories required to proceed.** If you have fewer than 10 with real URLs, widen your search before continuing.

---

## Step 4 — Check for duplicates before writing

Before writing the file, scan your collected stories for obvious duplicates — the same event covered by multiple outlets. **Do not remove them yet** (that happens in Phase 2). Instead, set `"duplicate_of": "id_of_first_entry"` on the later ones.

---

## Step 5 — Write raw_research.json

Write the complete file to the working directory.
Include `scan_errors` even if the list is empty.
Include the count of `queries_run` and `queries_succeeded`.

---

## Phase 1 completion check

Before moving to Phase 2, confirm:

- [ ] `raw_research.json` exists
- [ ] File contains at least 10 stories with real URLs
- [ ] All stories have `within_7_days` set (true or false — not null)
- [ ] `scan_errors` field is present
- [ ] `scan_date` is set to actual current timestamp

If any check fails, fix it before proceeding.
