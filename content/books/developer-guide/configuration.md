# Configuration

This guide explains how features can access and use configuration values.

## The Config Module

Configuration is managed through the `Config` module in `src/config.cr`, which uses the [Totem](https://github.com/icyleaf/totem) YAML parser.

## Accessing Configuration Values

Configuration values are accessible through `Config.options`:

```crystal
# Get a string value
title = Config.options["site_title"].as_s

# Get a nested value
url = Config.options["site"]["url"].as_s

# Get an array
features = Config.options["features"].as_a
```

## Type Safety

Config options are returned as `Totem::Type` which you need to cast:

```crystal
# String
Config.options["site_title"].as_s

# Integer
Config.options["port"].as_i

# Boolean
Config.options["debug"].as_bool

# Array
Config.options["features"].as_a

# Hash
Config.options["site"].as_h
```

## Common Configuration Patterns

### Checking Feature Flags

```crystal
module MyFeature
  def self.enable(is_enabled : Bool)
    return unless is_enabled

    # Check if related features are enabled
    has_posts = Config.options["features"].as_a.includes?("posts")

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

Then access it in your code:

```crystal
module MyFeature
  def self.render
    config = Config.options["my_feature"].as_h

    enabled = config["enabled"].as_bool
    option1 = config["option1"].as_s
    option2 = config["option2"].as_i

    # Use the values
  end
end
```

### Accessing Path Configuration

```crystal
# Get content directory
content_dir = Config.options["content"]?.try(&.as_s) || "content"

# Get output directory
output_dir = Config.options["output"].as_s

# Build paths
Path[content_dir] / "posts"
```

### Safe Access with Defaults

```crystal
# Safe access with default value
posts_dir = Config.options["posts_dir"]?.try(&.as_s) || "posts"

# Nested safe access
title = Config.options.dig?("site", "title")&.as_s || "Default Title"
```

## Available Configuration Keys

Common configuration keys that features might need:

- `site_title` - Site title (string)
- `site_description` - Site description (string)
- `site_url` - Site URL (string)
- `content` - Content directory path (string)
- `output` - Output directory path (string)
- `features` - Enabled features array (array of strings)
- `languages` - Language overrides (hash)
- `taxonomies` - Taxonomy configuration (hash)

## Configuration Best Practices

1. **Provide defaults**: Always provide sensible defaults for optional settings
2. **Type checking**: Cast to the expected type and handle errors gracefully
3. **Validation**: Validate configuration values before using them
4. **Documentation**: Document your feature's configuration options in the user guide

## Example: Feature with Configuration

```crystal
module MyFeature
  def self.render
    # Get feature-specific config
    config = Config.options["my_feature"]?.try(&.as_h) || {} of String => Totem::Type

    # Get options with defaults
    enabled = config["enabled"]?.try(&.as_bool) || true
    max_items = config["max_items"]?.try(&.as_i) || 10

    # Use the configuration
    if enabled
      process_items(max_items)
    end
  end
end
```
