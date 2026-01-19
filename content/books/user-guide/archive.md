The Archive feature generates chronological archive pages organizing your posts by year and month.

## How It Works

The Archive feature creates:

- A main archive page at `/archive/`
- Year-based organization (collapsible)
- Month-based listings under each year
- Automatic expansion of the current year

## Output Structure

```
output/
  archive/
    index.html
```

The archive page displays:

```
📁 2024
  📁 January (3)
  📁 February (5)
  📁 March (2)
📁 2023
  📁 December (4)
```

## Archive Navigation

Users can:

- Click a year to expand/collapse months
- Click a month to see posts from that month
- Navigate through chronological history

## Template

The archive uses `templates/archive.tmpl` for rendering. You can customize:

- Year/month grouping
- Display format
- Collapsible behavior
- Styling

## Configuration

Enable the Archive feature in `conf.yml`:

```yaml
features:
  - archive
```

The Archive feature requires the Posts feature to be enabled.

## Date Formats

Posts must have a `date` field in their frontmatter:

<pre><code class="language-yaml">---
title: My Post
date: 2024-01-15
---

Content...
</code></pre>

Archive uses the `date_output_format` from config for display:

```yaml
date_output_format: "%B %e, %Y"  # January 15, 2024
```

## Per-Language Archives

When using multiple languages, separate archives are generated:

```
output/
  archive/
    index.html      # Default language
  es/
    archive/
      index.html    # Spanish archive
```

## Integration

The archive automatically:

- Reads all published posts
- Groups by publication date
- Handles future-dated posts (excluded)
- Respects post status (draft posts excluded)

## Example Archive Structure

```
Archive

2024
├── January (5 posts)
│   ├── Post One
│   ├── Post Two
│   ├── Post Three
│   ├── Post Four
│   └── Post Five
└── February (3 posts)
    ├── Post Six
    ├── Post Seven
    └── Post Eight
```
