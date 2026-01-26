Nicolino is configured through a single `conf.yml` file in your project root. This YAML file controls all aspects of your site.

## Basic Structure

A minimal configuration file looks like this:

```yaml
# Site metadata
title: "My Site"
description: "A site built with Nicolino"
url: "https://example.com"
footer: "© 2025 Me"

# Theme
theme: "default"

# Paths
output: "output/"
content: "content/"
posts: "posts/"
galleries: "galleries/"

# Features
features:
  - posts
  - pages
```

## Translatable Settings

These fields can be overridden per language by creating a `conf.LANG.yml` file (e.g., `conf.es.yml`). Only include the fields you want to override - others will use these defaults.

**Site Metadata:**

- `title` - Site title
- `description` - Site description
- `url` - Site URL (used for feeds, sitemap)
- `footer` - Footer text

**Localization:**

- `date_output_format` - Date format (strftime format)
- `locale` - System locale

**Taxonomies:**

- Classification systems for your content (tags, categories, etc.)
- See [Taxonomies](taxonomies.md) for details

## Non-Translatable Settings

**Theme:**

- `theme` - Theme to use (default or custom in `themes/`)
- `color_scheme` - Base16 color scheme for syntax highlighting

**Paths:**

- `output` - Output directory
- `content` - Content directory
- `posts` - Posts subdirectory within content/
- `galleries` - Galleries subdirectory within content/

**Image Processing:**

- `image_large` - Max width for large images (default: 1920)
- `image_thumb` - Max width for thumbnails (default: 640)

**Language:**

- `language` - Default language code (default: "en")

**Pandoc Format Associations:**

- `pandoc_formats` - Maps file extensions to Pandoc formats

```yaml
pandoc_formats:
  .rst: rst
  .txt: rst
```

**Logging:**

- `verbosity` - Output verbosity (0=fatal, 1=errors, 2=warnings, 3=info, 4=debug, 5=trace)

## Features

The `features` list enables or disables site features. Only enabled features are active:

```yaml
features:
  - assets          # Copy assets/ directory to output
  - base16          # Generate CSS color schemes
  - books           # Documentation books
  - folder_indexes  # Auto-generate index pages for directories
  - galleries       # Image galleries with thumbnails
  - images          # Image processing and optimization
  - listings        # Syntax-highlighted code listings
  - pages           # Static pages
  - pandoc          # Pandoc document conversion
  - posts           # Blog posts with RSS
  - search          # Site search index
  - sitemap         # XML sitemap generation
  - taxonomies      # Tags, categories, etc.
  - archive         # Post archive by date
```

## Folder Indexes

Configure which directories should not have auto-generated index pages:

```yaml
folder_indexes:
  exclude_dirs: []
```

Most features (galleries, listings, tags, archive) automatically register their output folders. Use this only for custom exclusions.

## Multilingual Sites

For multilingual sites, create `conf.LANG.yml` files to override settings per language:

**conf.es.yml** (Spanish overrides):
```yaml
title: "Mi Sitio"
description: "Descripción del sitio"
footer: "© 2025. Todos los derechos reservados."
locale: "es_ES.UTF-8"
date_output_format: "%e de %B, %Y"
```

Only include the translatable settings you want to override. Paths, theme, and other non-translatable settings remain the same across all languages.

## Continuous Import

Import content from external feeds:

```yaml
continuous_import:
  my_feed:
    urls:
      - "https://example.com/feed.atom"
    template: "my_template.tmpl"
    output_folder: "posts/imported"
    format: "md"
    tags: "imported, external"
    metadata:
      title: "title"
      date: "published"
```

See [Continuous Import](cli/continuous_import.md) for details.

## Complete Example

```yaml
# Site metadata
title: "My Awesome Blog"
description: "Yet another blog about technology"
url: "https://example.com"
footer: "© 2025. All rights reserved."

# Theme
theme: "default"
color_scheme: "default"

# Paths
output: "output/"
content: "content/"
posts: "posts/"
galleries: "galleries/"

# Image processing
image_large: 1920
image_thumb: 640

# Localization
language: "en"
date_output_format: "%B %e, %Y"
locale: "en_US.UTF-8"

# Pandoc format associations
pandoc_formats:
  .rst: rst
  .txt: rst

# Logging
verbosity: 3

# Taxonomies
taxonomies:
  tags:
    title: "Tags"
    term_title: "Posts tagged {{term.name}}"
    location: "tags/"

# Features
features:
  - assets
  - base16
  - books
  - folder_indexes
  - galleries
  - images
  - listings
  - pages
  - pandoc
  - posts
  - sitemap
  - search
  - taxonomies
  - archive
```

## Validation

You can validate your configuration file at any time:

```bash
nicolino validate
```

This will check for syntax errors and configuration issues before you build.
