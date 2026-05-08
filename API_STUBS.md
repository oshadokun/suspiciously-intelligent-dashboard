# API Stubs — Integration Reference
## Connecting the Dashboard to Live Data Sources

> This file is a reference for when you are ready to move from prototype to live scanning.
> It contains the API endpoints, authentication patterns, response shapes, and mapping logic
> needed to connect each source to the dashboard's data schema.
>
> **Nothing in this file runs in prototype mode.** It is documentation for future integration.

---

## Integration architecture

```
Live sources → Fetch workers → Normalise to raw_research schema → 
Analyze (Claude API or local scorer) → Write analyzed_stories.json → 
Dashboard reads data.json → Display
```

The dashboard is designed so that `data.json` is the only file that needs to change for a live update. The fetch-analyze-write pipeline runs separately (via cron, GitHub Actions, or a local script) and replaces `data.json` on completion.

---

## Source 1 — News API (newsapi.org)

**What it covers:** TechCrunch, The Verge, Wired, Ars Technica, VentureBeat, CNBC, Bloomberg, Reuters

**Authentication:** API key in header or query param
**Free tier:** 100 requests/day, headlines only (no full text)
**Paid tier:** Full content, higher rate limits

```javascript
async function fetchNewsAPI(queries, apiKey) {
  const results = [];
  for (const query of queries) {
    const url = new URL('https://newsapi.org/v2/everything');
    url.searchParams.set('q', query);
    url.searchParams.set('language', 'en');
    url.searchParams.set('sortBy', 'publishedAt');
    url.searchParams.set('pageSize', '20');
    url.searchParams.set('from', sevenDaysAgo());
    url.searchParams.set('apiKey', apiKey);
    
    const res = await fetch(url.toString());
    const data = await res.json();
    
    if (data.status === 'ok') {
      results.push(...data.articles.map(a => ({
        id: slugify(a.title),
        headline: a.title,
        summary: a.description || '',
        url: a.url,
        source: a.source.name,
        published_date: a.publishedAt,
        within_7_days: isWithin7Days(a.publishedAt),
        verified: false,
        speculation: false,
        duplicate_of: null
      })));
    }
  }
  return results;
}
```

**Queries to use:**
```javascript
const NEWS_API_QUERIES = [
  'OpenAI', 'Anthropic', 'Google DeepMind', 'Meta AI',
  'artificial intelligence regulation', 'AI lawsuit',
  'AI deepfake', 'AI jobs', 'large language model',
  'AI safety', 'AI benchmark', 'AI chip', 'NVIDIA AI'
];
```

---

## Source 2 — Reddit (public JSON API, no auth required)

**What it covers:** r/artificial, r/MachineLearning, r/ChatGPT, r/singularity, r/LocalLLaMA

**Authentication:** None required for read-only access
**Rate limit:** ~60 requests/minute

```javascript
const AI_SUBREDDITS = [
  'artificial', 'MachineLearning', 'ChatGPT',
  'singularity', 'LocalLLaMA', 'AIWeirdness'
];

async function fetchRedditSubreddit(subreddit, sort = 'hot', limit = 25) {
  const url = `https://www.reddit.com/r/${subreddit}/${sort}.json?limit=${limit}`;
  const res = await fetch(url, {
    headers: { 'User-Agent': 'SuspiciouslyIntelligentBot/1.0' }
  });
  const data = await res.json();
  
  return data.data.children
    .filter(p => p.data.score > 100)
    .map(p => ({
      id: `reddit-${p.data.id}`,
      headline: p.data.title,
      summary: p.data.selftext?.slice(0, 300) || `${p.data.score} upvotes, ${p.data.num_comments} comments`,
      url: `https://reddit.com${p.data.permalink}`,
      source: `r/${subreddit}`,
      source_category: 'sentiment',
      published_date: new Date(p.data.created_utc * 1000).toISOString(),
      within_7_days: isWithin7Days(new Date(p.data.created_utc * 1000).toISOString()),
      verified: false,
      speculation: false,
      duplicate_of: null,
      raw_excerpt: `Score: ${p.data.score} | Comments: ${p.data.num_comments}`
    }));
}
```

---

## Source 3 — YouTube Data API v3

**What it covers:** Trending AI videos, channel performance, comment sentiment
**Authentication:** Google API key (OAuth for private data)
**Free tier:** 10,000 units/day

```javascript
async function fetchYouTubeTrendingAI(apiKey) {
  const sevenDaysAgoISO = sevenDaysAgo();
  const url = new URL('https://www.googleapis.com/youtube/v3/search');
  url.searchParams.set('part', 'snippet');
  url.searchParams.set('q', 'artificial intelligence news');
  url.searchParams.set('type', 'video');
  url.searchParams.set('order', 'viewCount');
  url.searchParams.set('publishedAfter', sevenDaysAgoISO);
  url.searchParams.set('maxResults', '20');
  url.searchParams.set('key', apiKey);
  
  const res = await fetch(url.toString());
  const data = await res.json();
  
  return data.items.map(v => ({
    id: `yt-${v.id.videoId}`,
    headline: v.snippet.title,
    summary: v.snippet.description?.slice(0, 200) || '',
    url: `https://youtube.com/watch?v=${v.id.videoId}`,
    source: v.snippet.channelTitle,
    source_category: 'sentiment',
    published_date: v.snippet.publishedAt,
    within_7_days: true
  }));
}
```

---

## Source 4 — Hugging Face API (no auth required)

**What it covers:** Trending models, new model releases, community activity

```javascript
async function fetchHuggingFaceTrending() {
  const res = await fetch(
    'https://huggingface.co/api/models?sort=trending&limit=20&direction=-1'
  );
  const models = await res.json();
  
  return models.map(m => ({
    id: `hf-${m.id.replace('/', '-')}`,
    headline: `New trending model on Hugging Face: ${m.id}`,
    summary: `${m.modelId} — ${m.downloads?.toLocaleString() || 'N/A'} downloads. Tags: ${m.tags?.join(', ') || 'none'}`,
    url: `https://huggingface.co/${m.id}`,
    source: 'Hugging Face',
    source_category: 'open_source',
    published_date: m.lastModified,
    within_7_days: isWithin7Days(m.lastModified),
    verified: true,
    speculation: false,
    duplicate_of: null
  }));
}
```

---

## Source 5 — arXiv (RSS feed, no auth required)

**What it covers:** Latest AI/ML research papers (cs.AI, cs.LG, cs.CL)

```javascript
async function fetchArxivFeed(category = 'cs.AI') {
  const url = `https://export.arxiv.org/rss/${category}`;
  const res = await fetch(url);
  const text = await res.text();
  
  const parser = new DOMParser();
  const xml = parser.parseFromString(text, 'text/xml');
  const items = xml.querySelectorAll('item');
  
  return Array.from(items).slice(0, 15).map(item => ({
    id: `arxiv-${item.querySelector('link')?.textContent?.split('/').pop()}`,
    headline: item.querySelector('title')?.textContent,
    summary: item.querySelector('description')?.textContent?.replace(/<[^>]+>/g, '').slice(0, 300),
    url: item.querySelector('link')?.textContent,
    source: 'arXiv',
    source_category: 'research',
    published_date: item.querySelector('pubDate')?.textContent,
    within_7_days: true,
    verified: true,
    speculation: false,
    duplicate_of: null
  }));
}
```

---

## Source 6 — GitHub Trending (no auth required)

**What it covers:** Trending AI repositories

```javascript
async function fetchGitHubTrendingAI() {
  const today = new Date().toISOString().split('T')[0];
  const weekAgo = sevenDaysAgo().split('T')[0];
  
  const url = `https://api.github.com/search/repositories?q=topic:artificial-intelligence+created:>${weekAgo}&sort=stars&order=desc&per_page=10`;
  const res = await fetch(url, {
    headers: { 'Accept': 'application/vnd.github.v3+json' }
  });
  const data = await res.json();
  
  return (data.items || []).map(repo => ({
    id: `gh-${repo.full_name.replace('/', '-')}`,
    headline: `Trending AI repo: ${repo.full_name} — ${repo.stargazers_count} stars`,
    summary: repo.description || 'No description available',
    url: repo.html_url,
    source: 'GitHub',
    source_category: 'open_source',
    published_date: repo.created_at,
    within_7_days: isWithin7Days(repo.created_at),
    verified: true,
    speculation: false,
    duplicate_of: null
  }));
}
```

---

## Source 7 — Claude API (for re-analysis and scoring)

**What it covers:** Automated analysis of raw stories to produce scored output

```javascript
async function analyseStoriesWithClaude(rawStories, apiKey) {
  const systemPrompt = `You are an AI news analyst for a YouTube channel called Suspiciously Intelligent.
Score each story on: recency (0-3), source confirmation (0-3), public interest (0-2), content opportunity (0-2).
Return only valid JSON matching the analyzed_stories schema. No commentary.`;

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify({
      model: 'claude-opus-4-5',
      max_tokens: 8192,
      system: systemPrompt,
      messages: [{
        role: 'user',
        content: `Analyse these stories and return scored JSON:\n\n${JSON.stringify(rawStories, null, 2)}`
      }]
    })
  });
  
  const data = await res.json();
  const text = data.content[0].text;
  
  // Strip markdown code blocks if present
  const clean = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
  return JSON.parse(clean);
}
```

---

## Helper functions

```javascript
function sevenDaysAgo() {
  const d = new Date();
  d.setDate(d.getDate() - 7);
  return d.toISOString();
}

function isWithin7Days(dateStr) {
  if (!dateStr) return false;
  const date = new Date(dateStr);
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 7);
  return date >= cutoff;
}

function slugify(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 60);
}
```

---

## Suggested automation schedule

| Task | Frequency | Tool |
|---|---|---|
| Full research scan | Daily at 07:00 UTC | GitHub Actions / cron |
| Claude re-analysis | After each scan | Claude API |
| Dashboard data update | After analysis | Write data.json |
| Idea marking sync | Real-time | localStorage (client-side) |
| Weekly content report | Mondays 08:00 UTC | Scheduled run + email |

---

## Environment variables (when running live)

Create a `.env` file in the working directory (never commit this):

```
NEWS_API_KEY=your_newsapi_org_key
YOUTUBE_API_KEY=your_google_api_key
ANTHROPIC_API_KEY=your_anthropic_key
REDDIT_USER_AGENT=SuspiciouslyIntelligentBot/1.0
```

Load in Node.js: `require('dotenv').config()`
Load in Python: `from dotenv import load_dotenv`

---

## Airtable / Notion / Google Sheets integration

The content_ideas.json format is designed for direct import into any of these tools.

**Airtable:** Use the Airtable API to POST each idea as a record. Map `marked_as_used` to a checkbox field. Use `story_id` as a linked record to a Stories table.

**Notion:** Use the Notion API to create database entries. Map priority_tags to multi-select properties.

**Google Sheets:** Use the Sheets API to append rows. One row per content idea. Map all fields to columns.

```javascript
// Example: push to Airtable
async function pushToAirtable(ideas, airtableKey, baseId, tableId) {
  const records = ideas.map(idea => ({
    fields: {
      'Title': idea.formats.youtube_video.title,
      'Story': idea.story_headline,
      'Score': idea.story_score,
      'Format': 'YouTube Video',
      'Hook': idea.formats.youtube_video.hook,
      'Status': idea.marked_as_used ? 'Used' : 'Available'
    }
  }));
  
  await fetch(`https://api.airtable.com/v0/${baseId}/${tableId}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${airtableKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ records: records.slice(0, 10) }) // Airtable max 10 per request
  });
}
```
