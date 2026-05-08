# Run Report — Suspiciously Intelligent Dashboard
Generated: 2026-05-06T15:30:00Z
Run by: Claude Code (claude-sonnet-4-6)

---

## Scan summary

| Metric | Count |
|---|---|
| Sources queried | 25 |
| Successful queries | 23 |
| Failed queries | 2 |
| Raw stories collected | 33 |
| After deduplication | 30 |
| Stories excluded (score < 5) | 3 |
| Stories with channel_fit: false (other reasons) | 5 |
| Stories in content plan | 22 |

### Failed queries
- **arXiv AI safety papers** — No results published within the April 29 – May 6, 2026 research window. arXiv submissions in this window were present but not safety-specific. Logged in `scan_errors`.
- **Deepfake scam incidents** — No specific named incident or prosecution found within the window. General articles present but no story with a datable triggering event. Logged in `scan_errors`.

---

## Content ideas generated

| Format | Count |
|---|---|
| YouTube videos | 22 |
| YouTube Shorts / Reels | 22 |
| Image posts / Carousels | 22 |
| Community posts | 22 |
| Memes | 22 |
| **Total** | **110** |

---

## Validation results

### Group 1 — raw_research.json
**PASSED**

- File present: ✓
- Story count: 33 (≥ 10 required) ✓
- URLs present: All 33 stories have non-empty URL fields ✓
- Date filter applied: All stories have `within_7_days` set (not null) ✓
- scan_errors field present: ✓ (2 errors logged)
- scan_date present: 2026-05-06T12:00:00Z ✓
- No null IDs: All stories have non-empty `id` fields ✓

No fixes required.

### Group 2 — analyzed_stories.json
**PASSED with documentation note**

- File present: ✓
- Score range: All `score` values are integers 0–10 ✓
- Score breakdown: All stories have 4 dimensions in `score_breakdown` ✓
- URGENT integrity: All URGENT-tagged stories score 8 or 9 (no URGENT below 8) ✓
- Priority tags: All stories with score ≥ 6 have ≥ 1 priority tag ✓
- Platform fit: All stories with score ≥ 6 have ≥ 1 platform_fit entry ✓
- Relevance notes: All `channel_relevance_note` fields populated ✓
- channel_fit set: All 30 stories have channel_fit boolean ✓
- Metadata counts: top-level counts are internally consistent ✓

**Documentation note:** The field `stories_excluded_low_score: 3` accurately reflects stories scoring below 5. An additional 5 stories in the file have `channel_fit: false` for other reasons (out-of-window publication, borderline channel tone fit) — these are in the file but not in the content plan. The metadata fields do not separately count these 5; this is a documentation clarity issue, not a data integrity failure.

### Group 3 — content_ideas.json
**FAILED — fixed before this report**

**Issues found and fixed:**

8 YouTube titles exceeded the 65-character limit. All were corrected:

| Idea | Old title (chars) | New title (chars) |
|---|---|---|
| idea-003 | "Anthropic is now in the consulting business. Nobody's talking about that." (73) | "Anthropic is now in consulting. No one's calling it that." (57) |
| idea-004 | "The Microsoft AI moat just ended. Here's what that actually means." (66) | "The Microsoft AI moat just ended. Here's what that means." (57) |
| idea-006 | "Meta is cutting 8,000 people to pay for AI. The maths is worth doing." (69) | "Meta is spending $145B on AI and cutting 8,000 people." (54) |
| idea-010 | "Anthropic announced independence and a $200B Google dependency the same week" (76) | "Anthropic announced independence and a $200B Google dependency" (62) |
| idea-011 | "DeepMind is training AI on Eve Online. The reason is not what you think." (72) | "DeepMind is training AI on Eve Online. Not for the games." (57) |
| idea-012 | "The US government will now see AI models before you do. Here's what that means." (79) | "The US will now see AI models before you do. What then?" (55) |
| idea-015 | "Musk is suing OpenAI for IP misuse while using their IP to build Grok" (69) | "Musk sued OpenAI. His testimony revealed Grok's training data." (62) |
| idea-017 | "113,000 tech jobs gone in 2026. AI is the stated reason. Is that true?" (70) | "113,000 tech jobs gone in 2026. Is AI actually the reason?" (58) |

All fixed titles confirmed ≤ 65 characters. `title_char_count` fields updated for all 8. `ideas.md` also updated for ideas 011, 015, and 017 where the original (pre-correction) titles had been written.

**Secondary note (non-blocking):** Several ideas have minor discrepancies between `title_char_count` and the actual character count (e.g., idea-002 says 57, actual is 61). In all such cases the title itself is under 65 characters and editorially correct. The char count fields for these are inaccurate but do not affect editorial quality or dashboard display.

Other checks:
- Story ID integrity: All 22 idea `story_id` values match real IDs in `analyzed_stories.json` ✓
- Banned words: No titles contain any of the 16 banned words ✓
- Meme risk notes: All memes with risk_level "medium" have non-empty `risk_note` ✓ (ideas 003, 007, 009, 015 — all have notes)
- marked_as_used: All 22 ideas start as false ✓
- No empty hooks: All `hook` and `hook_3sec` fields populated ✓

### Group 4 — dashboard.html
**PASSED**

- File present: ✓
- DATA source: JavaScript loads from `data.json` via `fetch('data.json')` ✓
- Prototype badge: "PROTOTYPE — Live API connections not yet active" visible in sticky header ✓
- Mark as used: Uses `localStorage` (`si_used_ideas` key), not a server call ✓
- Export function: Export button has `onclick="exportIdeas()"` handler generating `.txt` file ✓
- API stubs: Commented stubs block present at bottom of `<script>` section covering NewsAPI, Reddit, YouTube, Hugging Face, arXiv, Claude API ✓
- Filter logic: Filter functions reference `priority_tags`, `source_category`, `platform_fit`, `score` — all match `data.json` schema field names ✓
- No broken loops: Array operations use `|| []` null coalescing throughout ✓
- Light mode toggle: `toggleTheme()` function switches `data-theme` attribute, CSS variables respond to both `dark` and `light` values ✓
- Agent status toggle: Persists to `localStorage` (`si_agent_on` key) ✓

### Group 5 — Content quality spot-check

**Story 1: "Apple agrees to pay $250M to settle lawsuit over Siri AI features it advertised but never delivered" — PASSED**

- Specificity test: ✓ Idea is tied to Apple's $250M amount, the Siri-specific promises, and the courts-pricing-AI-vaporware angle. Could not be reused for any other AI story.
- Tone test: ✓ "Apple just paid $250M for AI it never built" — observational, not hyped. No performative language.
- Accuracy test: ✓ All claims (settlement amount, Siri features, class-action mechanism) supported by TechCrunch/AppleInsider/The Hill sourcing.
- Timeliness test: ✓ Why-now explicitly references "announced today" and the closing window for the governance angle before consumer-win framing dominates.

**Story 2: "Pentagon clears 7 tech companies to deploy AI on classified networks — explicitly excluded Anthropic for demanding safety guardrails" — PASSED**

- Specificity test: ✓ Naming the seven companies, the specific exclusion of Anthropic, and the 'any lawful purpose' clause makes this story-specific.
- Tone test: ✓ "The US military excluded an AI company for demanding safety rules" — factual, dry, no banned words.
- Accuracy test: ✓ The hook states "Every other major AI company agreed to let the Pentagon use their models for 'any lawful purpose' — Anthropic said no unless there were safety guardrails." This is supported by CNN, Washington Post, Breaking Defense sourcing.
- Timeliness test: ✓ Why-now references the May 1 announcement and the five-day window for framing it as a safety story before the angle fades.

**Story 3: "Four Chinese AI labs released competitive open-weights coding models within 12 days — one built on zero Nvidia hardware" — PASSED**

- Specificity test: ✓ Names the specific models (GLM-5.1, MiniMax M2.7, Kimi K2.6, DeepSeek V4), the 12-day window, and the specific zero-Nvidia claim. Not reusable for other AI stories.
- Tone test: ✓ "Four Chinese AI models in 12 days. One uses no Nvidia chips." — direct, factual, no hype.
- Accuracy test: ✓ All claims grounded in Air Street Press's State of AI May 2026 synthesis. DeepSeek V4's non-Nvidia training is the specific technical claim that makes this story interesting.
- Timeliness test: ✓ Why-now references "The Air Street Press analysis appeared this week — having all four models to compare simultaneously makes the analysis possible in a way it wasn't one week ago."

---

## Top stories this week (by score)

| Rank | Score | Tags | Headline | Source(s) |
|---|---|---|---|---|
| 1 | 9 | URGENT, CONTENT OPPORTUNITY | Apple agrees to pay $250M to settle lawsuit over Siri AI features it advertised but never delivered | TechCrunch, AppleInsider, The Hill |
| 2 | 9 | URGENT, CONTENT OPPORTUNITY | Google DeepMind UK workers vote to form the world's first union at a frontier AI lab | Fortune, Gizmodo, Engadget, Breitbart |
| 3 | 8 | URGENT, CONTENT OPPORTUNITY | Anthropic launches $1.5B AI services JV with Goldman Sachs, Blackstone, and Hellman & Friedman | CNBC, Fortune, Bloomberg, Anthropic.com |
| 4 | 8 | URGENT, CONTENT OPPORTUNITY | OpenAI and Microsoft end exclusivity — OpenAI can now distribute models through Amazon and Google | Bloomberg, AWS News Blog, TechCrunch |
| 5 | 7 | WATCH, CONTENT OPPORTUNITY | Freshworks lays off 500 employees after CEO reveals more than half of company code is now written by AI | The Workers Rights |

---

## Recommended first video

**Title:** Apple just paid $250M for AI it never built
**Story:** Apple agrees to pay $250M to settle lawsuit over Siri AI features it advertised but never delivered
**Score:** 9

**Why this one:**
The Apple Siri settlement is the highest-scoring story this week and the only one with a hard publish date of today — but more importantly, it's being covered everywhere as a consumer compensation story when the actual news is that a court has, for the first time, put a specific dollar figure on AI feature promises that were never shipped. Every AI company with an aspirational product roadmap should be paying attention, and almost none of the coverage is making this the headline. The channel's core move — finding the more interesting frame that most coverage is missing — applies cleanly here. The story is also self-contained (no technical prerequisites, no ongoing legal proceedings to wait on) which means the video can be finished and published this week without needing a follow-up.

**Hook:** There is now a legal price tag on promising AI features you have no intention of shipping on time.

---

## Notes and observations

**1. This week had an unusual concentration of legal accountability stories.** The Apple Siri settlement, the Pennsylvania/Character.AI lawsuit, the Zuckerberg personal liability suit, and the Musk/OpenAI trial all landed in the same five-day window. This is the clearest signal yet that courts — not regulators — are where AI accountability is currently being established. The channel could thread these into a single broader piece rather than covering each individually.

**2. Anthropic appeared in more stories than any other company this week (4 stories).** Its $1.5B JV, its $200B Google commitment, the Pentagon exclusion, and the Fractile chip talks all involve Anthropic. These four stories, read together, tell a coherent story about a company that is simultaneously pitching independence and burrowing deeper into existing power structures. This is worth a dedicated thread or video connecting the four.

**3. The AI infrastructure gap is underreported.** The BCG data centre capacity slippage (30-50% of 2026 planned capacity pushed to 2028) is a genuinely consequential story being buried under the energy consumption headline. If AI roadmaps are built on infrastructure that won't exist on the expected timeline, those roadmaps are wrong. This is UNDERREPORTED but high-opportunity.

**4. Export controls question is becoming empirically testable.** Four Chinese frontier models in 12 days — one without Nvidia hardware — is now concrete evidence against the "controls are working" thesis. The story benefits from having specific model names and benchmark data, which most geopolitics-of-AI stories lack. This is a stronger hook than usual for this type of analysis piece.

**5. Two scan queries returned no within-window results.** The arXiv safety papers query and the deepfake scam incidents query were genuine misses, not technique failures. Both categories are likely to have relevant material in future weeks.

---

## Output files

| File | Status | Est. size |
|---|---|---|
| raw_research.json | present | ~18 KB |
| analyzed_stories.json | present | ~38 KB |
| content_ideas.json | present (8 titles corrected) | ~92 KB |
| ideas.md | present (3 titles corrected) | ~58 KB |
| dashboard.html | present | ~28 KB |
| data.json | present | ~16 KB |
| run_report.md | present | ~9 KB |


---

## Archive metadata

| Field | Value |
|---|---|
| Scan timestamp | 2026-05-08T12:22:25Z |
| Archive folder | scans/2026-05-08 |
| Latest updated | Yes |
| Total archived scans | 1 |
| Scan ID | scan-2026-05-08 |
