The Search feature provides full-text search functionality using MiniSearch, a lightweight JavaScript search library.

## How It Works

The Search feature:

1. **Indexes** all content during build
2. **Generates** a searchable JSON index
3. **Loads** the index dynamically when users first search
4. **Searches** entirely in the browser (no server required)

## Search Widget

The search box appears in the site navigation header:

- **Collapsed** by default (2em wide)
- **Expands** on focus to 15em
- **Requires** 3+ characters to search
- **Shows** results in a dropdown list

## Search Results

Results display:

- **Title** - Linked and bolded
- **Relevance** - Ranked by relevance score
- **Navigation** - Click to navigate to result

## Search Index

The search index is generated at `/search.json`:

```json
[
  {
    "title": "Post Title",
    "text": "Post content...",
    "url": "/posts/post-title.html",
    "id": 0
  }
]
```

## What Gets Indexed

Search indexes:

- **Post titles** - Boosted (higher weight)
- **Post content** - Main text content
- **Page titles** - Static page headings
- **Page content** - Static page text
- **Gallery descriptions** - If available

## Configuration

Enable the Search feature in `conf.yml`:

```yaml
features:
  - search
```

## Search Options

The search uses these defaults:

- **Fuzzy matching** - 0.2 tolerance for typos
- **Boost** - Title matches weighted 2x higher than content
- **Min characters** - Requires 3 characters to search

## In-Memory Search

Search happens entirely in the browser:

1. First search loads the JSON index (~50-100KB for typical sites)
2. Subsequent searches use cached index
3. No server requests during searching
4. Instant results as you type

## Search in Templates

The search widget is included in `templates/page.tmpl`. The JavaScript is in `assets/search.js`.

## Performance

- **Fast** - Searches execute in milliseconds
- **Offline** - Once loaded, works without internet
- **Scalable** - Handles thousands of pages efficiently

## Limitations

- Searches post/page content only
- Doesn't search code blocks or listings
- Doesn't search PDF documents
- Index size grows with content size

## Customization

You can customize search behavior by editing `assets/search.js`:

- Change minimum character requirement
- Adjust fuzzy matching tolerance
- Modify ranking algorithm
- Add result highlighting
