Import content from external RSS/Atom feeds or JSON APIs.

## Usage

```text
{{% shell command="bin/nicolino import --help" %}}
```

## Description

Fetches data from configured feeds or JSON APIs and generates posts based on templates. This allows you to automatically bring in content from services like Goodreads, YouTube, blogs, or use any JSON API as a headless CMS.

## Configuration

Add an `import` section to your conf.yml with feed configurations.

### Field Mappings

The `fields` section defines which source fields map to which metadata fields. Templates then use generic names like `{{title}}`, `{{date}}`, `{{content}}` instead of source-specific names.

### RSS/Atom Feeds

```yaml
import:
  goodreads:
    urls:
      - "https://www.goodreads.com/review/list_rss/USER_ID?shelf=read"
    fields:
      title: title
      date: user_read_at
      content: description
    output_folder: "posts/goodreads"
    format: "md"
    template: "goodreads.tmpl"
    tags: "books, goodreads"
    skip_titles:
      - "Book to Skip"
```

### JSON APIs (including Pocketbase)

For JSON APIs, set `feed_format: "json"` and provide the full API URL:

```yaml
import:
  blog:
    urls:
      - "http://localhost:8090/api/collections/articles/records?filter=status=\"published\""
    feed_format: "json"
    fields:
      title: title
      date: published
      tags: tags
      content: content
    static:
      tags: "blog, imported"
    output_folder: "posts"
    format: "html"
    template: "article.tmpl"
    lang: "en"
```

### Configuration Options

- `urls` - Array of URLs to fetch from (RSS, Atom, or JSON API)
- `feed_format` - Optional: `"json"` for JSON APIs, omit for RSS/Atom
- `fields` - Field mappings: `metadata_field: source_field`
- `static` - Static values added to all items (optional)
- `output_folder` - Where generated files go (relative to `content/`)
- `format` - File format: `md`, `html`, etc.
- `template` - Template filename, relative to the `import_templates` directory (see below)
- `lang` - Language code (default: `"en"`)
- `tags` - Comma-separated tags to add to all items
- `skip_titles` - Array of titles to skip
- `start_at` - Only import items after this date

### Template Location

Templates are looked up in the directory configured by the `import_templates` setting in conf.yml, which defaults to `user_templates`. The `template` option in a feed config is a path relative to that directory, so with the default:

```yaml
import_templates: "user_templates"
```

and `template: "import/article.tmpl"`, the template is expected at `user_templates/import/article.tmpl`.

### JSON Response Format

When using `feed_format: "json"`, the API response must contain the items either as a top-level array:

```json
[ { "title": "...", "content": "..." }, ... ]
```

or wrapped in an `items` key (any extra keys at the top level are ignored):

```json
{ "items": [ { "title": "...", "content": "..." }, ... ] }
```

Each element of the array is one item, and its fields are matched against your `fields` mapping.

### Templates

Templates use Crinja (Jinja2-like) syntax. The template receives variables based on your `fields` mapping:

```jinja
---
title: {{title}}
date: {{date}}
tags: {{tags}}
lang: {{lang}}
---

{{content|safe}}
```

Available template variables:
- All fields defined in your `fields` mapping
- `{{lang}}` - The configured language
- Any `static` fields you've defined

The `|safe` filter tells Crinja not to escape HTML (useful for HTML content).
