# Sitemap

The Sitemap feature automatically generates XML sitemaps for search engines.

## How It Works

The Sitemap feature creates:

- A main sitemap at `/sitemap.xml`
- Includes all pages, posts, and other content
- Automatically includes lastmod dates
- Follows sitemap protocol specifications

## Sitemap Location

```
output/
  sitemap.xml
```

Submit this URL to search engines:
```
https://yoursite.com/sitemap.xml
```

## Sitemap Contents

The sitemap includes:

- **Posts** - All published blog posts
- **Pages** - Static pages
- **Galleries** - Image gallery pages
- **Archive** - Archive pages
- **Taxonomy** - Tag and category pages
- **Book** - Documentation book pages
- **Index** - Main index page

## XML Format

Generated sitemap follows the standard format:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://example.com/</loc>
    <lastmod>2024-01-15</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://example.com/posts/my-post.html</loc>
    <lastmod>2024-01-15</lastmod>
    <priority>0.8</priority>
  </url>
</urlset>
```

## Configuration

Enable the Sitemap feature in `conf.yml`:

```yaml
features:
  - sitemap
```

## Site URL

Make sure your `site_url` is configured in `conf.yml`:

```yaml
site_url: "https://example.com"
```

This is used as the base URL for all sitemap entries.

## Lastmod Dates

The `lastmod` field is set based on:

- **Posts** - The post's `date` or `updated` field
- **Pages** - File modification time
- **Generated pages** - Build time

## Priority and Change Frequency

Default priorities are assigned:

- **Index/landing pages** - 1.0
- **Posts** - 0.8
- **Galleries/Pages** - 0.6
- **Archive/Taxonomy** - 0.5
- **Other pages** - 0.4

## Excluding Pages

To exclude pages from the sitemap, add `noindex: true` to frontmatter:

<pre><code class="language-yaml">---
title: Private Page
noindex: true
---

Content...
</code></pre>

## Multilingual Sitemaps

For multilingual sites, sitemaps include all language versions. Each language variant appears as a separate URL in the sitemap.

## Search Engine Submission

After generating your sitemap:

1. **Google Search Console**: Submit at https://search.google.com/search-console
2. **Bing Webmaster Tools**: Submit at https://www.bing.com/webmasters
3. **robots.txt**: Reference your sitemap (if you have one):

```txt
Sitemap: https://example.com/sitemap.xml
```
