# Folder Indexes

The Folder Indexes feature automatically generates index pages for directories containing content files.

## How It Works

The Folder Indexes feature creates index pages for directories that don't have one, making navigation easier for hierarchical content structures.

## Directory Structure

Organize content in directories:

```
content/
  posts/
    2024/
      january/
        post1.md
        post2.md
      february/
        post3.md
    tutorials/
      beginner/
        lesson1.md
        lesson2.md
      advanced/
        topic1.md
```

## Generated Indexes

Folder indexes are automatically created:

```
output/
  posts/
    2024/
      index.html          # Lists january, february
      january/
        index.html        # Lists post1, post2
      february/
        index.html        # Lists post3
    tutorials/
      index.html          # Lists beginner, advanced
      beginner/
        index.html        # Lists lesson1, lesson2
```

## Index Page Content

Each index page includes:

- **Directory name** - As page title
- **Item list** - All items in the directory
- **Links** - To each item
- **Descriptions** - If available in frontmatter

## Custom Index Pages

You can override auto-generated indexes by creating your own:

```
content/posts/2024/index.md
```

Your custom index will be used instead of the auto-generated one.

## Frontmatter Support

Add frontmatter to directory items:

<pre><code class="language-yaml">---
title: "My Post"
description: "A great post"
---
</code></pre>

The index will use the title and description if available.

## Hierarchy Support

Folder indexes work at any depth:

```
content/
  category/
    subcategory/
      topic/
        article.md
```

Creates indexes at each level:
- `/category/`
- `/category/subcategory/`
- `/category/subcategory/topic/`

## Empty Directories

Directories without content files don't get indexes.

## Configuration

Enable the Folder Indexes feature in `conf.yml`:

```yaml
features:
  - folder_indexes
```

## Template

Folder indexes use `templates/folder_index.tmpl` for rendering. The default uses `templates/item_list.tmpl` for consistent styling.

## URL Behavior

Directory URLs work with or without trailing slash:

```
/posts/2024/        ← Shows index
/posts/2024         ← Redirects to index
```

## Sorting

Items in indexes are sorted:

- **Alphabetically** - By filename/title
- **Consistently** - Same order across builds

## Integration

Folder indexes integrate with:

- **Posts** - Blog post directories
- **Galleries** - Gallery collections
- **Listings** - Code listings
- **Pages** - Static page directories

## Use Cases

Folder indexes are great for:

- **Year/month archives** - Organized blog posts
- **Series/collections** - Related content grouped together
- **Documentation** - Hierarchical docs
- **Projects** - Portfolio work grouped by client/type

## Excluding Directories

To exclude a directory from auto-indexing, add a `.noindex` file:

```
content/posts/private/.noindex
```

This directory won't get an index page.
