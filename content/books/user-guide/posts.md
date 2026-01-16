# Posts

The Posts feature is the core blogging functionality of Nicolino. It processes markdown files with frontmatter and renders them as HTML pages.

## How It Works

Posts are markdown files stored in the `content/posts/` directory (configurable via `posts_dir` in config). Each post can have:

- **Frontmatter** (YAML metadata at the top of the file)
- **Markdown content**
- **Optional language variants** (e.g., `post.es.md` for Spanish)

## Frontmatter

Add metadata to your posts using YAML frontmatter:

```markdown
---
title: My Post Title
date: 2024-01-15
tags: tag1, tag2
categories: technology
---

# Post Content

Your markdown content here...
```

**Available Fields:**
- `title` - Post title (required)
- `date` - Publication date (defaults to file modification time)
- `updated` - Last updated date (optional)
- `tags` - Comma-separated tags
- `categories` - Comma-separated categories
- `link` - External link URL (for link posts)
- `description` - Post description/summary
- `image` - Featured image path

## File Organization

```
content/posts/
  my-post.md
  my-post.es.md
  2024-01-15-my-post.md
  subdir/
    another-post.md
```

## Output

Posts are rendered to `output/posts/` with the same directory structure:

```
output/posts/
  my-post.html
  my-post/index.html
  2024/
    01/
      15/
        my-post.html
```

## Shortcodes

Posts support [shortcodes](shortcodes.md) for adding dynamic content:

```markdown
{{< youtube id="dQw4w9WgXcQ" >}}
{{< gallery name="my-gallery" >}}
```

## Related Posts

When the Similarity feature is enabled, posts automatically show related posts based on content similarity.

## Taxonomies

Posts are automatically categorized into tags and categories. Separate index pages are generated for each taxonomy term.

## RSS Feeds

Posts are included in the main RSS feed at `/rss.xml`.

## Configuration

Enable the Posts feature in `conf.yml`:

```yaml
features:
  - posts
```

**Post-specific options:**
```yaml
posts: "posts/"  # Directory name within content/
```
