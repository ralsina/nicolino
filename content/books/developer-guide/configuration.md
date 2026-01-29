# Configuration

This guide explains how features can access and use configuration values.

## The Config Module

Configuration is managed through the `Config` module in `src/config.cr`, which uses Crystal's `YAML::Serializable` for type-safe configuration parsing.

## Configuration Architecture

The config system separates settings into two categories:

1. **Translatable settings** (`LangConfig`) - Can be overridden per language via `conf.LANG.yml` files

2. **Global settings** (`SiteConfig`) - Applied site-wide, not language-specific

### Translatable Settings

These can vary per language:

- `title` - Site title
- `description` - Site description
- `url` - Site URL
- `footer` - Footer text
- `nav_items` - Navigation items
- `date_output_format` - Date format string
- `locale` - System locale
- `taxonomies` - Taxonomy configuration

### Global Settings

These are site-wide:

- `output` - Output directory
- `content` - Content directory
- `posts` - Posts subdirectory
- `galleries` - Galleries subdirectory
- `theme` - Theme name
- `color_scheme` - Base16 color scheme
- `fonts` - Font configuration
- `image_large` - Max width for large images
- `image_thumb` - Max width for thumbnails
- `pandoc_formats` - File extension to Pandoc format mapping
- `language` - Default language code
- `verbosity` - Logging level
- `import_templates` - Template directory for import

## Accessing Configuration Values

### For Global (Non-Translatable) Settings

Use the direct accessor methods:

```crystal
# Get output directory
output_dir = Config.output

# Get theme
theme = Config.theme

# Get image sizes
large_size = Config.image_large
thumb_size = Config.image_thumb

# Get language
lang = Config.language
```

### For Translatable Settings

Translatable settings are accessed per language:

```crystal
# Get default language config
title = Config.title
description = Config.description
url = Config.url

# Get specific language config
lang_config = Config["es"]
spanish_title = lang_config.title
spanish_url = lang_config.url
```

### For Features

```crystal
# Check if a feature is enabled
features = Config.features
has_posts = features.includes?("posts")

# Or use the features_set for Set operations
features_set = Config.features_set
has_posts = features_set.includes?("posts")
```

### For Taxonomies

```crystal
# Get default language taxonomies
taxonomies = Config.taxonomies
tags_config = taxonomies["tags"]?
```

## Language-Specific Configuration

### Accessing a Specific Language

```crystal
# Get LangConfig for a specific language
lang_config = Config["es"]

# Access translatable properties for that language
title = lang_config.title
description = lang_config.description
url = lang_config.url
locale = lang_config.locale
date_format = lang_config.date_output_format
taxonomies = lang_config.taxonomies
```

### Getting All Available Languages

```crystal
# Returns hash of language code to empty hash
languages = Config.languages
languages.keys # => ["en", "es", "fr"]
```

This works by scanning for `conf.LANG.yml` files.

## Common Configuration Patterns

### Checking Feature Flags

```crystal
module MyFeature
  def self.enable(is_enabled : Bool)
    return unless is_enabled

    # Check if related features are enabled
    features = Config.features
    has_posts = features.includes?("posts")
    has_taxonomies = features.includes?("taxonomies")

    render
  end
end
```

### Reading Custom Feature Settings

If your feature needs custom configuration, add it to `conf.yml`:

```yaml
# In conf.yml
my_feature:
  enabled: true
  option1: "value"
  option2: 42
```

**Note**: The new config system is type-safe and uses structs. Custom top-level keys in `conf.yml` will need to be added to the `ConfigFile` struct in `src/config.cr`.

### Accessing Path Configuration

```crystal
# Get directories (global, not translatable)
content_dir = Config.content
output_dir = Config.output
posts_dir = Config.posts
galleries_dir = Config.galleries

# Build paths
Path[content_dir] / "posts"
```

### Using Language-Specific Settings in Features

```crystal
module MyFeature
  def self.render_for_language(lang : String)
    lang_config = Config[lang]

    # Use language-specific values
    title = lang_config.title
    date_format = lang_config.date_output_format
    locale = lang_config.locale

    # Use global values
    output_dir = Config.output
    theme = Config.theme

    # Render with language context
  end
end
```

## Legacy Compatibility

For legacy code, there's a `Config.options(lang)` method that returns an `OptionsWrapper`:

```crystal
# Legacy access pattern
options = Config.options("es")
output = options.output
theme = options.theme
locale = options.locale
```

**Note**: New code should use the direct accessors or `Config[lang]` instead.

## Configuration Best Practices

1. **Use type-safe accessors**: Prefer `Config.title` over legacy hash access

2. **Respect language contexts**: Use `Config[lang]` for language-specific features

3. **Know what's translatable**: Site metadata, dates, and taxonomies vary by language; paths and theme don't

4. **Provide defaults**: The config system provides defaults for all values

5. **Handle missing languages**: `Config[lang]` falls back to default config if the language file doesn't exist

## Example: Feature with Language Support

```crystal
module MyFeature
  def self.enable(is_enabled : Bool)
    return unless is_enabled

    # Get all available languages
    languages = Config.languages

    # Process for each language
    languages.each do |lang_code, _|
      lang_config = Config[lang_code]

      # Get language-specific values
      title = lang_config.title
      url = lang_config.url
      date_format = lang_config.date_output_format

      # Get global values (same for all languages)
      output_dir = Config.output
      theme = Config.theme

      # Render for this language
      render_language(lang_code, title, url, date_format, output_dir, theme)
    end
  end
end
```

## Adding New Configuration Options

### Adding a Global Option

1. Add property to `SiteConfig` struct

2. Add property to `ConfigFile` struct

3. Add initialization in `Config.config`

4. Add accessor method in `Config` module

### Adding a Translatable Option

1. Add property to `LangConfig` class

2. Add property to `ConfigFile` struct

3. Add initialization in `Config.config` and `load_lang_config`

4. Add accessor method that uses `Config[@@default_lang]`

See `src/config.cr` for examples.
