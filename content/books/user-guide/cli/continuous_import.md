Import content from external RSS/Atom feeds.
## Usage

```text
{{% shell command="bin/nicolino import --help" %}}
```

## Description

Fetches data from configured feeds and generates posts based on templates.
This allows you to automatically bring in content from services like
Goodreads, YouTube, blogs, etc.

## Configuration

Add a 'continuous_import' section to your conf.yml with feed configurations:

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
```text

Templates should be placed in `templates/continuous_import/` directory and
use Crinja (Jinja2-like) syntax. Available variables:
  - `{{ item.title }}` - The item title
  - `{{ item.link }}` - The item link
  - `{{ item.description }}` - The item description
  - `{{ item.<field> }}` - Any other field from the feed item
