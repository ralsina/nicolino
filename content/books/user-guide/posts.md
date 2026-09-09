The Posts feature is the core blogging functionality of Nicolino. It processes markdown files with frontmatter and renders them as HTML pages.

## How It Works

Posts are markdown files stored in the `content/posts/` directory (configurable via `posts_dir` in config). Each post can have:

- **Frontmatter** (YAML metadata at the top of the file)
- **Markdown content**
- **Optional language variants** (e.g., `post.es.md` for Spanish)

## Frontmatter

Add metadata to your posts using YAML frontmatter:

<pre><code class="language-yaml">---
title: My Post Title
date: 2024-01-15
tags: tag1, tag2
categories: technology
---

# Post Content

Your markdown content here...
</code></pre>

**Available Fields:**

- `title` - Post title (required)
- `date` - Publication date (defaults to file modification time)
- `updated` - Last updated date (optional)
- `tags` - Comma-separated tags
- `categories` - Comma-separated categories
- `link` - External link URL (for link posts)
- `description` - Post description/summary
- `image` - Featured image path
- `draft` - Set to `true` to keep the post out of builds (see below)
- `expires` - Date after which the post is excluded from builds (see below)

## Post Lifecycle

Posts can be kept out of the built site in three ways:

**Drafts.** Mark a post with `draft: true` in its frontmatter and it is
excluded from builds until you remove the flag or build with
`--drafts`:

```yaml
---
title: Work in progress
draft: true
---
```

**Future posts.** A post dated in the future is not built until its
date arrives, so you can write scheduled posts ahead of time. Build
with `--future` to include them anyway (useful for previews).

**Expired posts.** Mark a post with an `expires` date and it drops out
of the site automatically once that date passes, including from RSS
feeds, listings, tags, and the search index. Any date format works,
including natural language:

```yaml
---
title: Holiday announcement
expires: 2027-01-15
---
```

Both `--drafts` and `--future` work with `nicolino build` and
`nicolino auto`, so you can preview non-published content locally while
keeping production builds clean. When a post stops being built (for
example because it just expired), its previously generated HTML page is
removed from the output.

## Social Sharing

Posts and pages get [OpenGraph](https://ogp.me/) and Twitter Card
metadata so they preview nicely when shared. Set `description` and
`preview_image` in the frontmatter to control them:

```yaml
---
title: My post
date: 2024-01-15
description: A short, punchy summary
preview_image: /images/cover.jpg
---
```

Without them, Nicolino derives a description from the post's summary
and skips the image tags. See
[Social sharing metadata](templates.md#social-sharing-metadata) for
details.

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
  2024-01-15-my-post.html
  subdir/
    another-post.html
```

## Shortcodes

Posts support [shortcodes](shortcodes.md) for adding dynamic content.

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
