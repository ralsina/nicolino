The Import feature fetches content from external sources like RSS/Atom feeds, JSON APIs, and headless CMSs.

## How It Works

The Import feature:

- Fetches content from configured feeds and APIs
- Maps feed fields to your content structure
- Generates posts or pages using templates
- Uses stable IDs to update existing content instead of creating duplicates
- Supports both markdown and HTML output formats

## Why Would You Use It?

There are many use cases for importing content:

- Migrating from another platform to Nicolino
- Keeping your content up-to-date with external sources
- Creating a content hub from multiple sources

For example, suppose you are writing the site for a software project. You want
to automatically have the release announcements on your site. You can configure
the Import feature to fetch the latest releases from GitHub and generate posts
using a template.

Or if you want to use a headless CMS, you can configure the Import feature to
fetch content from your CMS and generate posts or pages using templates.

You can even run something like [PocketBase](https://pocketbase.io/) and use it
like a CMS! We have [detailed instructions for that.](/pocketbase.html)

## Configuration

Configure imports in `conf.yml`:

```yaml
import:
  # Name of this feed (for logging)
  releases:
    urls:
      - "https://github.com/user/repo/releases.atom"
    fields:
      title: title
      date: updated
      content: content
    output_folder: "posts/releases"
    format: "md"
    template: "release.tmpl"
    tags: "releases"
```

## Feed Sources

### RSS/Atom Feeds

```yaml
import:
  blog_feed:
    urls:
      - "https://example.com/feed.xml"
      - "https://example.com/atom.xml"
    fields:
      title: title
      date: published
      content: content
      excerpt: description
    output_folder: "posts/imported"
    format: "md"
    template: "post.tmpl"
```

### JSON APIs

```yaml
import:
  cms_posts:
    urls:
      - "https://cms.example.com/api/posts"
    feed_format: json
    fields:
      title: title
      date: created_at
      content: body
      tags: tags
    output_folder: posts
    format: html
    template: cms_post.tmpl
    lang: en
```

For authenticated APIs, set the token directly:

```yaml
import:
  cms_posts:
    urls:
      - "https://cms.example.com/api/posts"
    token: "your-api-token-here"
    feed_format: json
```

Or use an environment variable named `NICOLINO_IMPORT_{FEEDNAME}_TOKEN`:

```bash
export NICOLINO_IMPORT_CMS_POSTS_TOKEN="your-api-token-here"
```

Then omit the `token` field in the config - it will be used automatically.

## Field Mapping

The `fields` section maps feed fields to Nicolino's frontmatter:

```yaml
fields:
  # Left side: template variable name
  # Right side: field name in the feed
  title: title
  date: published
  content: body
  tags: keywords
  excerpt: summary
  slug: slug
```

## Static Fields

Add static fields that don't come from the feed:

```yaml
import:
  my_feed:
    # ...
    static:
      lang: en
      author: "John Doe"
```

## Templates

Templates use Crinja (Jinja2-like) syntax:

```jinja
---
title: {{title}}
date: {{date}}
tags: {{tags|join(",")}}
lang: {{lang}}
---

{{content|safe}}
```

Place templates in `user_templates/` directory.

## Output Formats

### Markdown

```yaml
format: "md"
```

Content is written as markdown with frontmatter. Use `{{content}}` in templates (no `|safe` filter needed).

### HTML

```yaml
format: "html"
```

Content is written as HTML with frontmatter. Use `{{content|safe}}` in templates to prevent HTML escaping.

## Stable IDs and Content Updates

The import command uses stable IDs from feeds to:

- **Update existing content** instead of creating duplicates
- **Track content** even if titles or dates change
- **Prevent data loss** from feed changes

### Filename Format

When a feed provides an ID/guid field:

```
{hash}-{title}.{ext}
```

For example: `a1b2c3d4-my-post-title.html`

The 8-character hash is derived from the feed item's stable ID, ensuring the filename remains consistent even if the title changes.

### Without IDs

If the feed doesn't provide IDs, falls back to:

```
{date}-{slug}.{ext}
```

## Running Imports

```bash
# Import all configured feeds
nicolino import

# Import a specific feed
nicolino import --feed releases

# Import multiple feeds
nicolino import --feed releases --feed blog
```

## Examples

### GitHub Releases

```yaml
import:
  github_releases:
    urls:
      - "https://github.com/user/project/releases.atom"
    fields:
      title: title
      date: updated
      content: content
    output_folder: "posts/releases"
    format: "md"
    template: "github_release.tmpl"
    tags: "releases"
```

### Pocketbase CMS

See the [Pocketbase guide](/pocketbase) for a complete headless CMS setup.

```yaml
import:
  posts:
    urls:
      - "http://localhost:8090/api/collections/posts/records"
    feed_format: json
    # token can be set here or via NICOLINO_IMPORT_POSTS_TOKEN env var
    fields:
      title: title
      date: published
      content: content
      tags: tags
      slug: slug
      excerpt: excerpt
    output_folder: posts
    format: html
    template: pocketbase_post.tmpl
    lang: en
```

## Date Parsing

Nicolino automatically parses dates in many formats:

- **Natural language** - "tomorrow", "2 weeks ago", "next Monday"
- **RFC 2822** - "Wed, 02 Oct 2002 13:00:00 GMT"
- **ISO 8601** - "2022-01-01T00:00:00Z"
- **HTTP dates** - via HTTP.parse_time
- **Pocketbase format** - "2026-01-29 11:57:28.164Z"

If date parsing fails, the import will log an error and skip that item.

## Tags

Tags can come from multiple sources:

1. **Feed field** - Mapped via `fields:`
2. **Static tags** - Via `tags:` config
3. **Combined** - Both sources merged

```yaml
import:
  my_feed:
    # ...
    fields:
      tags: tags
    tags: "imported,rss"
```

## Language

Set the language for imported content:

```yaml
import:
  my_feed:
    lang: es
```

This adds `lang: es` to the frontmatter.

## Overwrite Behavior

The import command **always overwrites** existing files with the same ID. This ensures:

- Content updates from feeds are reflected in your site
- Changed titles are handled gracefully (old file deleted, new one created)
- Your site stays in sync with the source

To prevent accidental data loss, consider using version control for your content directory.
