A Nicolino site follows a simple, predictable directory structure. Understanding this layout will help you organize your content effectively.

```
your-site/
├── conf.yml             # Site configuration
├── content/             # All your content goes here
│   ├── posts/           # Blog posts (see [Posts](posts.md))
│   ├── pages/           # Static pages (see [Pages](pages.md))
│   ├── galleries/       # Image galleries (see [Galleries](galleries.md))
│   ├── listings/        # Code listings (see [Listings](listings.md))
│   └── books/           # Documentation books (see [Books](books.md))
├── assets/              # Static files (CSS, JS, images, etc.)
├── templates/           # Feature templates (e.g., for continuous import)
├── themes/              # Theme directories (see [Themes](themes.md))
└── output/              # Generated site (don't edit this!)
```

## Configuration File

**`conf.yml`** - The main configuration file for your site. This file controls:

- Site metadata (title, description, URL)
- Theme selection
- Feature flags (what features to enable)
- Taxonomies configuration
- Language settings
- And much more

See the [Configuration](#) section for complete details.

## Content Directory

**`content/`** - This is where all your content lives.

> **Note:** Static pages can be placed anywhere in `content/` except in the folders reserved for specific content types (posts, galleries, listings, books). See [pages](pages.html) for details.

### **`content/posts/`**

Blog posts written in markdown or Pandoc formats. Posts are typically displayed in reverse chronological order and can include metadata like date, tags, and author.

See the [Posts](posts.md) chapter for details.

### **`content/galleries/`**

Image galleries. Each subdirectory becomes a gallery with automatically generated thumbnails and responsive images.

See the [Galleries](galleries.md) chapter for details.

### **`content/listings/`**

Syntax-highlighted code listings. Files in this directory are rendered with proper syntax highlighting.

See the [Listings](listings.md) chapter for details.

### **`content/books/`**

Documentation books organized with a `SUMMARY.md` file (like mdbook or gitbook). Each subdirectory containing a `SUMMARY.md` becomes a separate book.

See the [Books](books.md) chapter for details.

## Assets Directory

**`assets/`** - Static files that should be copied to the output directory:

- CSS files (custom styles, override theme styles)
- JavaScript files
- Images, fonts, icons
- Any other static files

Note: Theme assets are always copied first. Your assets can supplement (but not override) theme assets. Use `assets/custom.css` to add custom CSS that loads after the theme CSS.

See the [Themes](themes.md) chapter for more on theming.

## Templates Directory

**`templates/`** - Directory for feature-specific templates. Some features (like [continuous import](cli/continuous_import.md)) use templates stored in this directory.

For example, continuous import templates go in `templates/continuous_import/` and define how imported content is rendered.

See the [Templates](templates.md) chapter for details on template syntax.

## Output Directory

**`output/`** - This is where Nicolino generates your site. **Never edit files in this directory directly** - they will be overwritten on the next build.

The contents of `output/` are what you deploy to your web server.

## Other Files

### **`shard.lock`**

Lock file for Crystal dependencies. Generated automatically, commit this to version control.

### **`shard.yml`**

Crystal dependencies file. You typically don't need to edit this unless you're developing Nicolino itself.

### **`.pre-commit-config.yaml`**

Pre-commit hooks configuration (if you're using git hooks). Optional but recommended for maintaining code quality.
