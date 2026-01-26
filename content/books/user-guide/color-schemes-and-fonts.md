Nicolino provides built-in support for customizing the color scheme and fonts of your site through simple configuration options. This allows you to personalize your site's appearance without creating a custom theme.

## Color Schemes

Color schemes are based on the [Base16](https://base16-project.org/) standard, which provides consistent color palettes with both dark and light variants.

### Built-in Schemes

Nicolino includes all official Base16 color schemes. Some popular options:

- `default` - Default Base16 (Atelier Cave Light / Atelier Cave)
- `tokyo-night` - Tokyo Night theme
- `nord` - Nord color scheme
- `dracula` - Dracula theme
- `monokai` - Monokai theme
- `solarized` - Solarized theme
- `github` - GitHub's color scheme

For a complete list of available schemes, see [sixteen.ralsina.me](https://sixteen.ralsina.me/).

### Setting the Color Scheme

Add the `color_scheme` option to your `conf.yml`:

```yaml
site:
  title: My Site
  color_scheme: tokyo-night
```

The scheme will automatically generate:

- Pico CSS theme variables for dark and light modes
- Base16 palette colors (base00-base0F) for custom styles
- Syntax highlighting colors for code blocks
- Theme switcher integration (users can toggle between light/dark)

### Theme Switcher

All themes include a dark mode toggle in the navigation. When users switch themes, the entire color scheme updates automatically - including UI elements, code syntax highlighting, and any custom styles using Base16 colors.

### Using Base16 Colors in Custom CSS

The generated `style.css` includes CSS custom properties for all Base16 colors that you can use in your custom styles:

```css
/* Base16 palette colors are available as --b16-base00 through --b16-base0F */
.my-custom-element {
  background-color: var(--b16-base02);  /* Lighter background */
  color: var(--b16-base05);              /* Default foreground */
  border-color: var(--b16-base08);       /* Variables, etc */
}

/* Use semantic Pico CSS variables */
.highlight {
  color: var(--pico-primary);            /* Primary accent color */
  background: var(--pico-code-background-color);
}
```

#### Base16 Color Reference

| Variable | Usage                          |
|----------|--------------------------------|
| `--b16-base00` | Default background       |
| `--b16-base01` | Lighter background      |
| `--b16-base02` | Selection background    |
| `--b16-base03` | Comments, secondary     |
| `--b16-base04` | Darker foreground       |
| `--b16-base05` | Default foreground      |
| `--b16-base06` | Lighter foreground      |
| `--b16-base07` | Lightest foreground     |
| `--b16-base08` | Variables, etc          |
| `--b16-base09` | Integers, constants     |
| `--b16-base0A` | Classes, search match   |
| `--b16-base0B` | Strings                 |
| `--b16-base0C` | Support, regex          |
| `--b16-base0D` | Functions, methods      |
| `--b16-base0E` | Keywords                |
| `--b16-base0F` | Builtin, punctuation    |

## Fonts

Nicolino supports configuring custom fonts through the `fonts` option in `conf.yml`. You can use any font family from Google Fonts or specify local fonts.

### Default Fonts

By default, Nicolino uses these Google Fonts:

- **Quicksand** (400, 600, 700) - Sans-serif body text
- **Sono** (400) - Monospace code
- **Comfortaa** (400, 700) - Display/headings

### Font Configuration

Fonts are configured as an array in `conf.yml`:

```yaml
site:
  fonts:
    - family: Quicksand
      source: google
      weights: [400, 600, 700]
      role: sans-serif

    - family: Sono
      source: google
      weights: [400]
      role: monospace

    - family: Comfortaa
      source: google
      weights: [400, 700]
      role: display
```

### Font Roles

Each font has a `role` that determines where it's used:

- **sans-serif** - Body text and general content
- **monospace** - Code blocks and technical content
- **display** - Headings, titles, navigation elements

### Using Google Fonts

To use Google Fonts, set `source: google` and specify the font family name and weights:

```yaml
site:
  fonts:
    - family: Inter
      source: google
      weights: [400, 500, 600, 700]
      role: sans-serif

    - family: Fira Code
      source: google
      weights: [400, 500]
      role: monospace

    - family: Montserrat
      source: google
      weights: [700, 800]
      role: display
```

Nicolino will automatically:

- Generate the correct Google Fonts import URL
- Add the `@import` at the top of `style.css`
- Create CSS font stacks with appropriate fallbacks

### Using Local Fonts

For self-hosted fonts, omit the `source` field or set it to any value other than `google`:

```yaml
site:
  fonts:
    - family: "My Custom Font"
      weights: [400, 700]
      role: sans-serif
```

You'll need to add the `@font-face` declarations in your `assets/custom.css`:

```css
@font-face {
  font-family: "My Custom Font";
  src: url("/fonts/my-custom-font.woff2") format("woff2");
  font-weight: 400;
}
```

### Font Weights

Specify weights as numbers:

- `100` - Thin
- `300` - Light
- `400` - Regular
- `500` - Medium
- `600` - Semi-bold
- `700` - Bold
- `900` - Black

Not all fonts support all weights. Check your font's documentation for available options.

## Complete Example

Here's a complete `conf.yml` with color scheme and font configuration:

```yaml
site:
  title: My Awesome Site
  description: A blog about technology and design
  color_scheme: tokyo-night

  fonts:
    - family: Inter
      source: google
      weights: [400, 500, 600, 700]
      role: sans-serif

    - family: JetBrains Mono
      source: google
      weights: [400, 500]
      role: monospace

    - family: Space Grotesk
      source: google
      weights: [700]
      role: display

features:
  - base16
  - posts
  - pages
  - taxonomies
```

## How It Works

The `base16` feature generates `output/css/style.css` which includes:

1. **Google Fonts import** (if configured) - Always at the top for valid CSS
2. **Font family variables** - CSS custom properties for each font role
3. **Pico CSS theme variables** - Dark and light mode color schemes
4. **Base16 palette colors** - All 16 palette colors as CSS variables
5. **Syntax highlighting** - Highlight.js theme colors for code blocks

The CSS is loaded in this order in `page.tmpl`:

1. `theme.css` - Theme-specific styles
2. `style.css` - Color scheme and fonts (generated from base16 feature)
3. `custom.css` - Your custom overrides (loaded last)

## Tips

- **Test both themes**: Always check your site in both light and dark modes using the theme switcher
- **Font performance**: Only include the weights you actually need to reduce page load time
- **Accessibility**: Ensure sufficient contrast between text and background colors
- **Consistency**: The same fonts and colors apply across all features (posts, pages, galleries, etc.)
- **Custom CSS**: Use `assets/custom.css` for additional styling while leveraging the CSS variables from `style.css`
