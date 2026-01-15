
Nicolino includes built-in support for **Base16 color schemes**, making it easy to apply beautiful, consistent theming to your site. The color scheme feature integrates with [Pico.css](https://picocss.com/) and provides both dark and light theme variants.

## How It Works

The color scheme system uses the [sixteen](https://github.com/ralsina/sixteen) Crystal library, which provides access to all official Base16 themes. When you enable the `base16` feature, Nicolino automatically generates a CSS file with CSS custom properties (variables) for your chosen color scheme.

## Configuration

Add the `base16` feature to your `conf.yml`:

```yaml
features:
  - base16
```

Then set your preferred color scheme in the `site` section:

```yaml
site:
  color_scheme: "nord"  # Any Base16 theme name
```

### Available Schemes

Nicolino supports all [official Base16 schemes](https://base16.github.io/). Some popular options include:

- `nord` - An arctic, north-bluish color palette
- `dracula` - A dark theme for beautiful code
- `monokai` - A classic dark theme
- `solarized` - Ethan Schoonover's precision color scheme
- `github` - GitHub's color palette
- `gruvbox` - Retro groove color scheme
- `tokyo-night` - A clean dark theme

You can use any official Base16 theme name. For the full list, visit the [Base16 gallery](https://base16.github.io/).

### Theme Variants

When you specify a color scheme, Nicolino automatically generates both **dark** and **light** variants:

- The dark variant uses your specified theme directly
- The light variant uses the corresponding light theme from the same family

For example, if you specify `nord`, you'll get:
- `nord-dark` for the dark theme
- `nord-light` for the light theme

## Generated CSS

The feature generates `output/css/color_scheme.css` with CSS custom properties like:

```css
:root[data-theme="dark"] {
  --b16-base00: #2e3440;
  --b16-base01: #3b4252;
  --b16-base02: #434c5e;
  /* ... more colors */
}

:root[data-theme="light"] {
  --b16-base00: #eceff4;
  --b16-base01: #e5e9f0;
  /* ... more colors */
}
```

These variables can be used throughout your CSS and templates.

## Theme Switching

Nicolino includes a built-in theme switcher that allows users to toggle between dark and light themes. The theme preference is automatically saved to the user's browser (localStorage) and persists across visits.

The theme switcher is typically included in your site's template and uses JavaScript to:

1. Check for saved user preference
2. Fall back to system preference (dark/light mode)
3. Apply the appropriate theme to the `<html>` element

## Integration with Syntax Highlighting

The color scheme also integrates with [highlight.js](https://highlightjs.org/) for code syntax highlighting. The theme slug is automatically made available as `site_dark_scheme` and `site_light_scheme` in templates, allowing the syntax highlighting to match your site's color scheme.

## Legacy Configuration

For backwards compatibility, Nicolino still supports the older `dark_scheme` and `light_scheme` configuration format. However, using `color_scheme` is recommended as it's simpler and automatically handles both variants.

## Customization

You can override specific colors by adding custom CSS after the color scheme CSS is loaded. For example:

```css
:root[data-theme="dark"] {
  --b16-base0D: #your-custom-color;
}
```

This allows you to use a Base16 scheme as a starting point and customize specific colors to match your branding.
