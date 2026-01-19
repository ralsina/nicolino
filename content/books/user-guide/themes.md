Nicolino uses a theming system to control the appearance and structure of your generated site. Themes allow you to completely customize how your content looks and feels without modifying the core application.

## What is a Theme?

A theme in Nicolino is a collection of **templates** and **assets** that work together to render your site. Every site must have a theme selected.

- **Templates** - Jinja2-like files that define the HTML structure of your pages
- **Assets** - CSS, JavaScript, fonts, images, and other static files that control styling and behavior

Themes are stored in the `themes/` directory in your project root. Each theme has its own subdirectory containing `templates/` and `assets/` folders.

```
themes/
├── default/
│   ├── templates/
│   │   ├── page.tmpl
│   │   ├── post.tmpl
│   │   └── ...
│   └── assets/
│       ├── css/
│       │   └── theme.css
│       └── favicon.ico
└── minimal/
    ├── templates/
    │   └── ...
    └── assets/
        └── ...
```

## How Themes Work

When Nicolino builds your site:

1. **Theme assets are always copied** to the output directory (regardless of the `assets` feature flag)
2. **Templates are loaded** from the selected theme's `templates/` directory
3. **User assets** (from the `assets/` feature) are also copied to the output directory

This means you can:

- Use a theme as-is
- Add custom CSS via `assets/custom.css` which is loaded after theme CSS
- Create entirely custom themes from scratch

## Configuring Your Theme

The theme is selected in your `conf.yml` file under the `options` section:

```yaml
options:
  theme: "minimal"  # or "default", or any theme in themes/
```

If the specified theme doesn't exist, Nicolino will fall back to the `default` theme.

## Included Themes

Nicolino comes with two built-in themes:

### Default Theme

The `default` theme is the theme for [the Nicolino site](https://nicolino.ralsina.me)
so you can expect it to work pretty well and be complete.

- Breadcrumb navigation
- Responsive design
- Support for all content types (posts, pages, books, galleries)
- QuickSand font
- Pico.css-based styling

### Minimal Theme

The `minimal` theme provides:

- Cleaner, simpler layout
- Book table of contents integrated into main sidebar
- Reduced visual chrome
- Focus on content readability

## Creating a Custom Theme

To create your own theme:

1. Create a directory structure in `themes/your-theme/`:
   ```
   themes/your-theme/
   ├── templates/
   └── assets/
   ```

2. Add template files (`.tmpl` extension) to `templates/`
3. Add assets to `assets/` (CSS, JS, fonts, etc.)

4. Set it in `conf.yml`:
   ```yaml
   options:
     theme: "your-theme"
   ```

### Required Templates

While Nicolino will provide built-in templates if you don't override them, a complete theme typically includes:

- `page.tmpl` - Base page template
- `post.tmpl` - Blog post layout
- `index.tmpl` - Index page layout
- `gallery.tmpl` - Gallery page layout
- `book_chapter.tmpl` - Book chapter layout

See the existing themes in `themes/default/` and `themes/minimal/` for reference.

### Template Includes

Templates can include other templates using Jinja2 syntax:

```jinja
{% include "title.tmpl" %}
```

Includes are resolved relative to the current theme's templates directory.

### Theme Assets

Theme assets are copied to the output directory maintaining their directory structure:

```
themes/minimal/assets/css/theme.css → output/css/theme.css
themes/minimal/assets/favicon.ico   → output/favicon.ico
```

## Template Variables

Templates have access to various variables depending on the content type (like `site`, `title`, `content`, `breadcrumbs`, etc.).

For complete documentation of all available template variables, see the [Templates](templates.md) chapter.

## Customizing Theme Styles

If you want to customize a theme's CSS without creating a whole new theme, create an `assets/custom.css` file in your project. This file is loaded after the theme's CSS, allowing you to override styles.

For example:

```bash
/* Override theme colors */
:root {
  --pico-primary: #ff6b6b;
  --pico-background: #f8f9fa;
}

/* Custom heading style */
h1.primary {
  font-size: 2.5rem;
}
```

This approach lets you tweak a theme's appearance while keeping the theme intact.
