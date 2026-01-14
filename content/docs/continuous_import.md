---
title: Continuous Import
---

The **continuous import** feature allows you to import content from external RSS/Atom feeds into your Nicolino site. This enables **data ownership** - you can mirror content from third-party platforms (like GitHub releases, blog feeds, or any other RSS/Atom source) and have full control over it in your own site.

## Why Use Continuous Import?

Many platforms host content that you create:

- **GitHub releases** for your software projects
- **Blog posts** on platforms like Medium, Blogger, or WordPress
- **Podcast episodes** from podcast hosting services
- **News feeds** from various sources

With continuous import, you can:

- **Own your data** - Import and host copies of your content on your own site
- **Customize presentation** - Apply your own styling and templates
- **Preserve content** - Keep your content even if the original platform shuts down
- **Centralize** - Aggregate content from multiple sources in one place
- **Control** - Full control over how content is displayed and organized

## How It Works

1. **Configure feeds** in `conf.yml` with URLs and template settings
2. **Run `nicolino import`** to fetch and import new items from feeds
3. **Posts are generated** in your content folder using your templates
4. **Build your site** normally with the imported content included

The import process:

- Fetches RSS/Atom feeds via HTTP
- Parses feed items (entries, articles, etc.)
- Generates markdown files with frontmatter
- Applies your custom Jinja2-like templates
- Skips posts that already exist (based on title matching)

## Configuration

Add a `continuous_import` section to your `conf.yml`:

```yaml
continuous_import:
  # A friendly name for this feed (used for logging)
  my_feed_name:
    # One or more feed URLs
    urls:
      - "https://example.com/feed.xml"
      - "https://example.com/atom.xml"

    # Template file (from user_templates/ directory)
    template: "my_feed.tmpl"

    # Where to save imported posts (relative to content/)
    output_folder: "posts/imported"

    # File extension for generated posts
    format: "md"

    # Comma-separated tags to add to all posts
    tags: "imported, external"

    # Optional: language override
    lang: "en"

    # Optional: metadata field mappings (defaults shown)
    metadata:
      title: "title"
      date: "published"
```

### Configuration Options

- **`urls`** - Array of feed URLs (RSS or Atom)
- **`template`** - Template filename from `user_templates/` directory
- **`output_folder`** - Where to save imported posts (relative to `content/`)
- **`format`** - File extension: `"md"` for markdown, `"html"` for HTML
- **`tags`** - Comma-separated tags to add to all imported posts
- **`lang`** - Language code (optional, defaults to site default)
- **`metadata`** - Field mappings for extracting data from feed items

## Creating Templates

Templates are stored in the `user_templates/` directory (not bundled with Nicolino). They use Crinja templating (Jinja2-like syntax).

### Available Template Variables

- **`{{ title }}`** - Feed item title
- **`{{ link }}`** - Original URL of the feed item
- **`{{ content }}`** - Feed item content (HTML or text)
- **`{{ updated }}`** - Publication/last update date
- **`{{ item.XXX }}`** - Any field from the feed item (access via dot notation)

### Example Template

```markdown
{{ content }}

[View Original]({{ link }})

**Imported:** {{ updated }}
```

## Usage

### Import All Configured Feeds

```bash
nicolino import
```

### Import a Specific Feed

```bash
nicolino import --feed my_feed_name
```

### Import and Build

```bash
nicolino import && nicolino build
```

## Example: Importing GitHub Releases

Here's a complete example of how to import GitHub releases for your project.

### 1. Create the Template

Create `user_templates/github_release.tmpl`:

```markdown
{{ content }}

[View on GitHub]({{ link }})
```

### 2. Configure the Feed

Add to your `conf.yml`:

```yaml
continuous_import:
  nicolino_releases:
    urls:
      - "https://github.com/YOUR_USERNAME/YOUR_REPO/releases.atom"
    template: "github_release.tmpl"
    output_folder: "posts/releases"
    format: "md"
    tags: "releases, your_project"
    lang: "en"
```

### 3. Run the Import

```bash
nicolino import --feed nicolino_releases
```

This will create markdown files in `content/posts/releases/` like:

- `2026-01-13-release-v050.md`
- `2025-11-25-release-v040.md`
- etc.

### 4. Build Your Site

```bash
nicolino build
```

Your releases will now appear on your site with full styling, search integration, and any other features you have enabled.

## Real Example: Nicolino Releases

The Nicolino project itself uses continuous import to fetch its own releases from GitHub:

**Configuration:**
```yaml
continuous_import:
  nicolino_releases:
    urls:
      - "https://github.com/ralsina/nicolino/releases.atom"
    template: "nicolino_release.tmpl"
    output_folder: "posts/releases"
    format: "md"
    tags: "releases, nicolino"
```

**Template** (`user_templates/nicolino_release.tmpl`):
```markdown
{{ content }}

[View on GitHub]({{ link }})
```

**Result:**
- Releases are automatically imported as blog posts
- Each release gets its own page with proper styling
- Tags are automatically applied
- Releases appear in the main blog feed and tag pages
- Search indexing includes all release content
- Related posts feature suggests similar releases

## Advanced Usage

### Multiple Feeds

You can import from multiple sources:

```yaml
continuous_import:
  # Your project's releases
  my_project:
    urls: ["https://github.com/user/project/releases.atom"]
    template: "github_release.tmpl"
    output_folder: "posts/releases"
    tags: "releases"

  # Your blog on another platform
  my_blog:
    urls: ["https://medium.com/feed/@username"]
    template: "blog_post.tmpl"
    output_folder: "posts/blog"
    tags: "blog, medium"

  # Podcast episodes
  my_podcast:
    urls: ["https://podcast.example.com/feed.xml"]
    template: "podcast_episode.tmpl"
    output_folder: "posts/episodes"
    tags: "podcast"
```

### Custom Metadata Mapping

If a feed has non-standard fields, map them explicitly:

```yaml
continuous_import:
  custom_feed:
    urls: ["https://example.com/custom.xml"]
    template: "custom.tmpl"
    metadata:
      title: "headline"        # Use 'headline' field as title
      date: "publishDate"       # Use 'publishDate' field as date
```

### Date Handling

The importer tries multiple date formats automatically:

- RFC 2822 (common in RSS/email)
- ISO 8601
- HTTP dates
- Custom formats via Cronic

If dates can't be parsed, the item is skipped with a warning.

## How Duplicate Detection Works

The import process prevents duplicate posts by checking titles:

1. **Fetch** feed items from all configured URLs
2. **Check** each item's title against existing posts
3. **Skip** if a post with that title already exists
4. **Create** new post if no match found

This means:

- Re-running `nicolino import` is safe - it won't create duplicates
- You can delete imported posts and re-import to regenerate them
- Editing an imported post manually won't cause it to be re-imported (title matches)

## Limitations

- **Read-only** - Imported posts are one-way. Changes to imported content won't sync back to the source.
- **Title-based** - Duplicate detection relies on exact title matches. If a feed changes titles, it may create duplicates.
- **Feed format** - Only supports RSS and Atom formats.
- **HTML content** - Feed content is typically HTML; it's imported as-is. Use markdown if you need to edit posts manually.

## Best Practices

1. **Version control your templates** - Keep `user_templates/` in git
2. **Test templates** - Try importing to a test folder first
3. **Review imports** - Check imported posts before building
4. **Custom tags** - Use descriptive tags for imported content
5. **Separate folders** - Keep different feed types in separate folders
6. **Backup first** - Especially when testing new configurations

## Template Tips

- Keep templates simple - focus on structure, not styling
- Use `{{ content }}` to include the full feed content
- Link back to the original source with `{{ link }}`
- Add metadata that's useful for your site
- Test with a single feed item before bulk importing

## Troubleshooting

**Template not found:**
- Check that template file exists in `user_templates/`
- Verify the template name matches config

**No posts imported:**
- Check that the feed URL is accessible
- Verify feed format (RSS/Atom)
- Check logs for parsing errors

**Dates not parsing:**
- Feed may use non-standard date format
- Check the feed XML for date field names
- Add custom metadata mapping if needed

**Wrong content in posts:**
- Review your template syntax
- Check available template variables
- Test template with `{{ item | dump }}` to see all data

## See Also

- [Similarity Feature](/docs/similarity.html) - Related posts functionality
- [Templates Documentation](https://crinja.github.io/) - Crinja templating reference
- [RSS 2.0 Specification](https://www.rssboard.org/rss-specification) - RSS format
- [Atom Format](https://www.rfc-editor.org/rfc/rfc4287) - Atom format
