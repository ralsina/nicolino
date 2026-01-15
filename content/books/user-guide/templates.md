
Nicolino uses the **Crinja** templating engine (Jinja2-compatible) to render HTML pages. Templates are stored in the `templates/` directory and use the `.tmpl` file extension.

## Template Overview

Templates define how your content is rendered into HTML. Each feature (posts, galleries, listings, etc.) uses specific templates to generate its output pages.

## Core Templates

### `page.tmpl` - Main HTML Layout

The base template that wraps all pages. It provides:

- Complete HTML document structure (DOCTYPE, html, head, body)
- Meta tags for SEO, favicons, canonical URLs
- CSS includes (Pico CSS, theme.css, custom.css, highlight.js)
- JavaScript includes (VenoBox, MiniSearch, hyperscript, highlight.js)
- Header with site title, description, and navigation
- Main content area where page-specific content is rendered
- Footer with site footer text

**Used by**: All features as the wrapping template

### `title.tmpl` - Page Title with Breadcrumbs

Renders the page title with breadcrumb navigation:

- Breadcrumb navigation (Home >> Section >> Subsection >> Page)
  - Breadcrumbs collapse on hover to save space
  - Last breadcrumb (current page) stays visible
- Fallback to simple title link if no breadcrumbs
- Taxonomy links (tags, categories, etc.) if present

**Variables**:
- `breadcrumbs`: Array of `{name, link}` tuples for navigation
- `link`: URL for the page title (used when no breadcrumbs)
- `title`: Page title text
- `taxonomies`: Hash of taxonomy terms

**Used by**: `post.tmpl`, `gallery.tmpl`, and manually in code for index pages

## Content Templates

### `post.tmpl` - Blog Post/Article

Renders a blog post with:

- Title with breadcrumbs (via `title.tmpl` include)
- Post metadata (date, updated date, external link)
- Taxonomy links (tags, categories)
- Table of contents (if present)
- Main post HTML content
- Related posts section (if present)

**Variables**:
- `breadcrumbs`, `title`, `link`: Passed to `title.tmpl`
- `date`: Post publication date
- `metadata.updated`: Last updated date (optional)
- `metadata.link`: External source link (optional)
- `taxonomies`: Post taxonomies
- `toc`: Table of contents HTML (optional)
- `html`: Main post content
- `related_posts`: Array of related post links (optional)

**Used by**: `Markdown::File` for rendering blog posts

### `gallery.tmpl` - Image Gallery

Renders an image gallery with:

- Title with breadcrumbs (via `title.tmpl` include)
- Gallery introduction HTML content
- Grid of thumbnail images with lightbox links
- VenoBox lightbox integration for image viewing

**Variables**:
- `breadcrumbs`, `title`, `link`: Passed to `title.tmpl`
- `html`: Gallery introduction/description HTML
- `image_list`: Array of image paths

**Used by**: `Gallery` class for rendering gallery pages

### `index.tmpl` - Blog Index/Homepage

Renders a list of blog posts with:

- Post title with link
- Post date
- Post summary

**Variables**:
- `posts`: Array of post objects with `link`, `title`, `date`, `summary`

**Used by**: `Markdown.render_index` for generating index pages

## Feature-Specific Templates

### `archive.tmpl` - Blog Archive

Renders a chronological archive organized by year/month:

- Collapsible years (current year expanded by default)
- Months within each year
- Post list within each month

**Variables**:
- `years`: Array of year objects with `year`, `months` array
- `latest_year`: The year number of the most recent year

**Used by**: Archive feature for `/archive/index.html`

### `taxonomy.tmpl` - Taxonomy Index

Renders a simple list of taxonomy terms (tags, categories):

- Links to each term's index page

**Variables**:
- `taxonomy`: Taxonomy object with `terms` array

**Used by**: Taxonomy feature for taxonomy index pages (e.g., `/tags/`)

### `listing.tmpl` - Source Code Listing

Renders a syntax-highlighted code file with:

- Title
- Formatted code with syntax highlighting
- Collapsible raw source view

**Variables**:
- `title`: Listing title (filename)
- `code`: Syntax-highlighted HTML code
- `raw_content`: Escaped raw source code

**Used by**: Listings feature for individual code file pages

### `nicolino_release.tmpl` - GitHub Release

Simple template for imported GitHub releases:

- Release title as heading
- Release content body
- Link to GitHub release page

**Variables**:
- `title`: Release title/version
- `content`: Release notes/body
- `link`: GitHub release URL

**Used by**: Continuous import feature for nicolino_releases

## Reusable Templates

### `item_list.tmpl` - Generic Item List

Renders a simple list of items with:

- Optional description paragraph
- Bulleted list of item links

**Variables**:
- `title`: List title (not rendered here, passed from caller)
- `description`: Optional description text
- `items`: Array of `{link, title}` tuples

**Used by**: Galleries index, Listings index, and other feature indexes

## Deprecated Templates

These templates are kept for backwards compatibility but are no longer used by default:

### `folder_index.tmpl` (Deprecated)

Old template for folder indexes. Now replaced by `item_list.tmpl` for consistent styling.

### `listings-index.tmpl` (Deprecated)

Old template for listings index. Now replaced by `item_list.tmpl`.

## CSS Templates

### `base16.tmpl` - Color Scheme CSS

Generates CSS variables for Base16 color schemes:

- Pico CSS theme variables for dark and light modes
- Base16 palette colors (base00-base0F) for custom styles
- Theme switcher integration

**Variables**:
- `dark`: Dark theme object with scheme data
- `light`: Light theme object with scheme data

**Used by**: Base16 feature for `output/css/color_scheme.css`

### `listings-css.tmpl` - Syntax Highlighting CSS

Generates CSS for code syntax highlighting using Tartrazine.

**Variables**:
- `css`: Generated CSS from Tartrazine formatter

**Used by**: Listings feature for `output/css/listings.css`

## Template Variables

Templates have access to:

- **Site config**: `{{ site_title }}`, `{{ site_description }}`, `{{ site_url }}`, etc.
- **Page context**: `{{ title }}`, `{{ content }}`, `{{ breadcrumbs }}`, etc.
- **Feature-specific**: Depends on the feature (e.g., `posts`, `image_list`, `taxonomies`)

## Customization

You can customize templates by:

1. **Modifying built-in templates**: Edit files in `templates/`
2. **Creating custom templates**: Add new `.tmpl` files and reference them in your code
3. **Overriding per-language**: Create language-specific variants if needed

## Template Inheritance

Templates can include other templates using:

```jinja
{% include "templates/title.tmpl" %}
```

This is commonly used to include the `title.tmpl` breadcrumb component in content templates.
