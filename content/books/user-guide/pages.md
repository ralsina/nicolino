# Pages

The Pages feature processes standalone markdown files as individual pages, without the blog post metadata and structure.

## How It Works

Pages are markdown files that don't require frontmatter or blog-specific features. They're perfect for:

- About pages
- Contact pages
- Policy pages
- Static content

## File Organization

Pages can be placed anywhere in your content directory:

```
content/
  about.md
  contact.md
  privacy.md
  legal/
    terms.md
```

## Frontmatter (Optional)

Pages can include simple frontmatter:

```markdown
---
title: About Us
noindex: true
---

# About Us

Content here...
```

**Available Fields:**
- `title` - Page title (defaults to first heading or filename)
- `noindex` - Add `noindex` meta tag (for search engines)
- `description` - Page description

## Output

Pages maintain their directory structure in the output:

```
content/
  about.md → output/about.html
  legal/
    terms.md → output/legal/terms.html
```

## Differences from Posts

| Feature | Posts | Pages |
|---------|-------|-------|
| Frontmatter | Required (metadata) | Optional |
| Date-based URLs | Optional | No |
| Taxonomies | Yes (tags/categories) | No |
| RSS feed | Yes | No |
| Related posts | Yes | No |
| Best for | Blog content | Static pages |

## Configuration

Enable the Pages feature in `conf.yml`:

```yaml
features:
  - pages
```

## Example

```markdown
---
title: About
---

# About Nicolino

Nicolino is a fast static site generator written in Crystal.
```

This renders to `/about.html` with the site template wrapper.
