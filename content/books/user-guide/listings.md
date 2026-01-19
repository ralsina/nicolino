The Listings feature displays source code files with syntax highlighting and raw source views.

## How It Works

The Listings feature:

1. **Finds** code files in your content directory
2. **Highlights** syntax using Tartrazine
3. **Generates** styled HTML pages for each file
4. **Creates** a listings index page

## Directory Structure

Place code files in `content/listings/`:

```
content/
  listings/
    main.cr
    utils.cr
    config.yml
    script.sh
```

## Supported Languages

Syntax highlighting is available for:

- **Crystal** (.cr)
- **Python** (.py)
- **JavaScript** (.js, .ts)
- **Ruby** (.rb)
- **Shell** (.sh, .bash)
- **YAML** (.yml, .yaml)
- **JSON** (.json)
- **HTML** (.html, .htm)
- **CSS** (.css)
- And many more...

## Output Structure

Each code file generates a page:

```
output/
  listings/
    main.cr.html
    utils.cr.html
    config.yml.html
    script.sh.html
    index.html    # Listings index
```

## Syntax Highlighting

Listings use [Tartrazine](https://github.com/ralsina/tartrazine) for syntax highlighting.

The color scheme is configurable via the `highlight_theme` in `conf.yml` and follows your site's Base16 color scheme.

## Page Features

Each listing page includes:

- **File title** - Filename as heading
- **Highlighted code** - Syntax-colored code block
- **Raw source view** - Collapsible raw source
- **Copy button** - Easy code copying (via browser)

## Listings Index

An index page at `/listings/` shows:

- All code files
- File names
- File sizes
- Last modified dates
- Links to individual listings

## Configuration

Enable the Listings feature in `conf.yml`:

```yaml
features:
  - listings
```

**Listings-specific options:**
```yaml
listings: "listings/"  # Directory name within content/
```

## CSS Generation

Syntax highlighting CSS is generated at:

```
output/css/listings.css
```

This is automatically included in listing pages.

## Excluding Files

To exclude certain files from listings, use `.listingignore`:

```
content/listings/
  .listingignore
  main.cr
  utils.cr
```

In `.listingignore`:

```
private/
  internal/
  *.secret.*
```

## Inline Code in Posts

For short code snippets in posts, use standard markdown code blocks:

`````
code here
````

This uses the same syntax highlighting but doesn't create separate pages.

## File Size Limits

Very large files may take longer to process. Consider:

- Splitting large files into smaller modules
- Using excerpts for documentation purposes
- Linking to external repositories for full source

## Template

Listings use `templates/listing.tmpl` for individual files and `templates/listings-index.tmpl` for the index page.
