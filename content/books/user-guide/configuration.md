Nicolino is configured through a single `conf.yml` file in your project root. This YAML file controls all aspects of your site.

## Basic Structure

A minimal configuration file looks like this:

```yaml
site:
  title: "My Site"
  description: "A site built with Nicolino"
  url: "https://example.com"

options:
  theme: "minimal"
  output: "output/"
  content: "content/"

features:
  - posts
  - pages
```

## Site Settings

The `site` section contains metadata about your site that's available in templates as `site.*` variables:

```yaml
site:
  title: "My Site"              # Site title (available as site.title)
  description: "Site description" # Site description
  url: "https://example.com"    # Site URL (used for feeds, sitemap)
  footer: "© 2025 Me"           # Optional footer text
  color_scheme: "darcula"       # Base16 color scheme for syntax highlighting

  # Navigation items shown in the theme's nav bar
  nav_items:
    - "<a href='/about'>About</a>"
    - "<a href='/contact'>Contact</a>"
```

## Options

The `options` section controls site behavior:

```yaml
options:
  # Theme selection
  theme: "minimal"              # Theme to use (default, minimal, or custom)

  # Output formatting
  pretty_html: true             # Format HTML for readability

  # Image processing
  image_large: 1920             # Max width for large images
  image_thumb: 640              # Max width for thumbnails

  # Paths
  output: "output/"             # Output directory
  content: "content/"           # Content directory
  posts: "posts/"               # Posts subdirectory within content/
  galleries: "galleries/"       # Galleries subdirectory within content/

  # Localization
  date_output_format: "%B %e, %Y"  # Date format (strftime format)
  locale: "en_US.UTF-8"         # System locale
  language: "en"                # Default language code

  # Pandoc format associations
  formats:
    .rst: rst                   # File extension -> Pandoc format
    .txt: rst

  # Verbosity (0=fatal, 1=errors, 2=warnings, 3=info, 4=debug, 5=trace)
  verbosity: 3
```

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
  - similarity      # "Similar posts" feature
  - sitemap         # XML sitemap generation
  - taxonomies      # Tags, categories, etc.
  - archive         # Post archive by date
```

## Taxonomies

Configure classification systems for your content:

```yaml
taxonomies:
  tags:
    title: "🏷 Tags"
    term_title: "Posts tagged {{term.name}}"
    location: "tags/"

  categories:
    title: "Categories"
    term_title: "Posts in {{term.name}}"
    location: "categories/"
```

## Folder Indexes

Configure which directories should not have auto-generated index pages:

```yaml
folder_indexes:
  exclude_dirs:
    - "books/"
    - "galleries/"
    - "tags/"
```

## Languages

For multilingual sites, override settings per language:

```yaml
languages:
  es:
    site:
      title: "Mi Sitio"
      description: "Descripción del sitio"
    options:
      date_output_format: "%e de %B, %Y"
      locale: "es_ES.UTF-8"
      language: "es"
```

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

## Complete Example

```yaml
site:
  title: "My Awesome Blog"
  description: "Yet another blog about technology"
  url: "https://example.com"
  footer: "© 2025. All rights reserved."
  color_scheme: "darcula"
  nav_items:
    - "<a href='/about'>About</a>"
    - "<a href='/archive'>Archive</a>"
    - "<a href='/tags'>Tags</a>"

options:
  theme: "minimal"
  pretty_html: true
  image_large: 1920
  image_thumb: 640
  output: "output/"
  content: "content/"
  posts: "posts/"
  galleries: "galleries/"
  date_output_format: "%B %e, %Y"
  locale: "en_US.UTF-8"
  language: "en"
  verbosity: 3

taxonomies:
  tags:
    title: "Tags"
    term_title: "Posts tagged {{term.name}}"
    location: "tags/"

features:
  - assets
  - base16
  - books
  - folder_indexes
  - galleries
  - images
  - listings
  - pages
  - posts
  - search
  - sitemap
  - taxonomies
  - archive
```

## Validation

You can validate your configuration file at any time:

```bash
nicolino validate
```

This will check for syntax errors and configuration issues before you build.
