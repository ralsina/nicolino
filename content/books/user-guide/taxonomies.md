The Taxonomies feature organizes content into categories and tags, with automatic index page generation.

## How It Works

Taxonomies add classification to your content:

- **Tags** - Free-form labels for content
- **Categories** - Hierarchical grouping

Content with taxonomies gets:

- Individual index pages per term
- Cross-references between related content
- RSS feeds per taxonomy term

## Setting Up Taxonomies

Configure taxonomies in `conf.yml`:

```yaml
taxonomies:
  tags:
    directory: "tags"
    title: "Tags"
  categories:
    directory: "categories"
    title: "Categories"
```

## Using Taxonomies in Posts

Add tags and categories to post frontmatter:

<pre><code class="language-yaml">---
title: My Post
tags: crystal, ssg, tutorial
categories: technology, programming
---

Content...
</code></pre>

## Generated Pages

For each tag/category, an index page is created:

```
output/
  tags/
    crystal.html
    ssg.html
    tutorial.html
    index.html      # All tags
  categories/
    technology.html
    programming.html
    index.html      # All categories
```

## Taxonomy Index Pages

Each taxonomy term page shows:

- **Term name** - The tag or category
- **Post list** - All posts with that term
- **Post metadata** - Date, title, summary
- **RSS feed** - Term-specific feed

## URLs

Taxonomy pages follow this pattern:

```
/tags/crystal.html
/categories/technology.html
```

## Multilingual Taxonomies

When using multiple languages, taxonomies are language-specific:

```
tags/
  index.html        # Default language
  crystal.html
es/
  tags/
    index.html      # Spanish tags
    cristal.html
```

## Template

Taxonomies use `templates/taxonomy.tmpl` for rendering. Customize the display of:

- Term name
- Post list
- Post summaries
- Styling

## RSS Feeds

Each taxonomy term gets its own RSS feed:

```
/tags/crystal.rss.xml
/categories/technology.rss.xml
```

## Configuration

Enable the Taxonomies feature in `conf.yml`:

```yaml
features:
  - taxonomies
```

The Taxonomies feature requires the Posts feature to be enabled.

## Custom Taxonomies

You can define additional taxonomies beyond tags and categories:

```yaml
taxonomies:
  tags:
    directory: "tags"
    title: "Tags"
  categories:
    directory: "categories"
    title: "Categories"
  topics:
    directory: "topics"
    title: "Topics"
```

## Accessing Taxonomies in Templates

Posts include taxonomy data for rendering:

```crystal
# In template context
taxonomies = post.taxonomies
tags = taxonomies["tags"]?
categories = taxonomies["categories"]?
```

## Best Practices

1. **Be consistent** - Use similar tags across posts
2. **Use lowercase** - Tags are case-sensitive
3. **Hyphens over spaces** - Use `web-development` not `web development`
4. **Specific over generic** - `crystal-tutorial` not `tutorial`
