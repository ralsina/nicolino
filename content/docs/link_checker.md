---
title: Link Checker
---

The **link checker** feature validates all internal links in your built site to ensure they point to existing pages. This is especially useful when migrating content from other static site generators or when restructuring your site.

## Why Use the Link Checker?

### When Migrating from Other SSGs

When importing content from another static site generator (like Nikola, Hugo, Jekyll, or WordPress), internal links may break because:

- **URL structures differ** - `/posts/2024/my-post` vs `/archive/2024/my-post`
- **File extensions change** - `.html` vs `/` vs no extension
- **Category/tag URLs differ** - `/tag/python` vs `/categories/python`
- **Image paths differ** - `/images/photo.jpg` vs `/static/images/photo.jpg`
- **Pagination changes** - Different page numbering schemes

The link checker helps you find and fix all these broken links before publishing.

### For Site Maintenance

Even for sites you've built yourself, the link checker is valuable for:

- **Finding typos** - Catched `/post/about` instead of `/posts/about`
- **Orphaned pages** - Pages no one links to
- **Image validation** - Ensure all image references exist
- **Refactoring safety** - Verify links after reorganizing content

## How It Works

The link checker:

1. **Scans** all HTML files in your output directory
2. **Extracts** links from `<a>`, `<img>`, `<link>`, and `<script>` tags
3. **Validates** in-site links against actual files in the output
4. **Reports** broken links with source file and context

It **skips**:

- External links (to other domains)
- Anchor links (page-internal `#section` references)
- Non-HTML files (treated as dependencies, not validated as pages)

## Usage

### Check All Links

```bash
nicolino check_links
```

This will:

- Scan `output/` directory (or your configured output directory)
- Check all in-site links
- Display a summary of broken links
- Return exit code 1 if any broken links were found

### With Custom Output Directory

```bash
nicolino check_links --output build/
```

### Example Output

```
Checking links in output/...

Found 3 broken links:

❌ output/posts/old-post.html
   Links to: /posts/typo-post.html (broken)

❌ output/gallery/index.html
   Links to: /images/missing.jpg (broken)

❌ output/about.html
   Links to: /contact.html (broken)

Summary: 3 broken links found in 45 pages
```

## What Gets Checked

### Link Types

| Element | Attribute | Checked |
|---------|-----------|---------|
| `<a>` | `href` | ✅ |
| `<img>` | `src` | ✅ |
| `<link>` | `href` | ✅ |
| `<script>` | `src` | ✅ |

### Link Examples

| Link | Status | Reason |
|------|--------|--------|
| `/posts/my-post.html` | ✅ Validated | In-site link, checked |
| `https://example.com` | ⏭ Skipped | External link |
| `/posts/#intro` | ⏭ Skipped | Anchor link |
| `style.css` | ⏭ Skipped | No path separator |

## Migration Guide: Using Link Checker When Importing Sites

When migrating content from another SSG, use this workflow:

### 1. Import Your Content

First, bring your content into Nicolino using whatever method works:

- Copy markdown/html files manually
- Use a custom import script
- Use the continuous import feature for feeds

### 2. Build the Site

```bash
nicolino build
```

### 3. Check Links

```bash
nicolino check_links
```

### 4. Fix Broken Links

Common issues and fixes:

#### Changed URL Structure

If old links use `/archive/2024/` but Nicolino uses `/posts/`:

```bash
# Find all affected files
grep -r "/archive/" content/

# Replace with correct structure
find content -name "*.md" -exec sed -i 's|/archive/|/posts/|g' {} \;
```

#### Missing Extensions

If old links are `post.html` but should be `/post/`:

```bash
# Remove .html extensions from internal links
find content -name "*.md" -exec sed -i 's|\.html"|/|g' {} \;
```

#### Different Tag URLs

If tags moved from `/tag/` to `/tags/`:

```bash
find content -name "*.md" -exec sed -i 's|/tag/|/tags/|g' {} \;
```

### 5. Rebuild and Recheck

```bash
nicolino build
nicolino check_links
```

Repeat until all broken links are resolved.

## Real Example: Migrating from Nikola

When migrating from Nikola to Nicolino, common link differences include:

| Nikola | Nicolino | Fix |
|--------|----------|-----|
| `/posts/my-post.html` | `/posts/my-post/` | Remove `.html` |
| `/categories/python.html` | `/tags/python/` | Replace `categories` with `tags` |
| `/galleries/my-gallery/` | `/galleries/my-gallery/index.html` | Add `index.html` |
| `/listings/mylisting.html` | `/listings/mylisting/` | Same (no change) |

### Migration Script Example

```bash
#!/bin/bash
# Fix common Nikola → Nicolino link issues

find content/posts -name "*.md" -exec sed -i \
  -e 's|\.html"|/|g' \
  -e 's|/categories/|/tags/|g' \
  {} \;

echo "Fixed links in blog posts"
```

## Exit Codes

- `0` - No broken links found
- `1` - Broken links were found or error occurred

This makes it useful in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Build site
  run: nicolino build

- name: Check links
  run: nicolino check_links
```

## Configuration

The link checker uses the standard Nicolino output configuration:

```yaml
# In conf.yml
options:
  output: "output"  # Directory to check
```

No separate configuration is needed - just run the command!

## Limitations

- **Output directory only** - Checks the built site, not source files
- **HTML validation** - Only checks if linked files exist, doesn't validate HTML
- **JavaScript links** - Links generated by JavaScript are not checked
- **External links** - Doesn't verify external URLs (could use additional tools like `curl`)
- **Dynamic routes** - Doesn't check links that might be generated by server

## Tips for Effective Link Checking

### 1. Check Early and Often

```bash
# After importing content
nicolino build && nicolino check_links

# Before deploying
nicolino build && nicolino check_links
```

### 2. Use with Other Tools

Combine with HTML validators and external link checkers:

```bash
# Check internal links
nicolino check_links

# Check HTML validity (external tool)
html-validate output/

# Check external links (external tool)
markdown-link-check content/posts/
```

### 3. CI/CD Integration

Add to your deployment pipeline:

```bash
#!/bin/bash
set -e  # Exit on any error

nicolino build
nicolino check_links  # Will fail if broken links found
# Deploy only if above succeeds
rsync -av output/ server:/var/www/
```

### 4. Fix Systematically

When you find many broken links of the same type:

```bash
# Find all broken links of a pattern
grep -r "broken-link-pattern" output/

# Use find and sed to fix in bulk
find content -type f -exec sed -i 's|broken-link-pattern|correct-link|g' {} \+
```

## Troubleshooting

**"Too many broken links!"**

- Start with the highest-traffic pages (index, main posts)
- Fix common patterns first (URL structure changes)
- Re-run after each fix to see progress

**"Links to CSS/JS files reported as broken"**

- These are usually dependencies, not page links
- Verify `assets` feature is enabled
- Check that files exist in your content structure

**"External links being checked"**

- Shouldn't happen - external links are skipped
- Report this as a bug if you see it

**"Slow on large sites"**

- Link checking is O(n) where n = number of HTML files
- Very large sites (10k+ pages) may take a few seconds
- This is normal for thorough checking

## See Also

- [Continuous Import](/docs/continuous_import.html) - For importing content from feeds
- [Similarity Feature](/docs/similarity.html) - For finding related posts
- [Deployment](https://nicolino.ralsina.me) - General deployment practices
