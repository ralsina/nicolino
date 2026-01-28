Import content from external RSS/Atom feeds or Pocketbase CMS.

## Usage

```text
{{% shell command="bin/nicolino import --help" %}}
```

## Description

Fetches data from configured feeds or Pocketbase collections and generates
posts based on templates. This allows you to automatically bring in content from
services like Goodreads, YouTube, blogs, or use Pocketbase as a headless CMS.

## Configuration

Add a 'continuous_import' section to your conf.yml with feed configurations:

### RSS/Atom Feeds

```yaml
continuous_import:
  goodreads:
    urls:
      - "https://www.goodreads.com/review/list_rss/USER_ID?shelf=read"
    template: "goodreads.tmpl"
    output_folder: "posts/goodreads"
    format: "md"
    tags: "books, goodreads"
    skip_titles:
      - "Book to Skip"
    metadata:
      title: "title"
      date: ["user_read_at", "user_date_added", "published"]

  youtube:
    url: "https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID"
    template: "youtube.tmpl"
    output_folder: "posts/youtube"
    format: "md"
    tags: "video, youtube"
```

### Pocketbase CMS

To use Pocketbase as a headless CMS, add the `pocketbase_collection` field:

```yaml
continuous_import:
  blog:
    urls:
      - "http://localhost:8090"
    pocketbase_collection: "articles"
    pocketbase_filter: 'status = "published"'
    template: "pocketbase_article.tmpl"
    output_folder: "posts"
    format: "md"
    tags: "blog"
```

The `pocketbase_filter` uses Pocketbase's filter syntax to only import
published articles. Your Pocketbase collection should have these fields:
- `title` (text) - Article title
- `content` (text) - Article content (can be markdown)
- `status` (select) - Set to "published" for articles to import
- `published` (date) - Publication date (optional, falls back to created/updated)

Templates should be placed in `templates/continuous_import/` directory and
use Crinja (Jinja2-like) syntax. Available variables:

  - `{{ item.title }}` - The item title
  - `{{ item.link }}` - The item link (or `pocketbase://ID` for Pocketbase)
  - `{{ item.description }}` / `{{ item.content }}` - The item content
  - `{{ item.<field> }}` - Any other field from the feed item or Pocketbase record
