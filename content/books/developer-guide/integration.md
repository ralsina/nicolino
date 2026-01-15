# Integration

This guide explains how to integrate your feature with existing Nicolino features and systems.

## Integrating with Posts

Many features integrate with the `Posts` feature to process blog posts.

### Accessing Posts

```crystal
module MyFeature
  def self.enable(is_enabled : Bool, posts)
    return unless is_enabled
    return unless posts  # Only work if posts feature is enabled

    # posts is an Array(Markdown::File)
    posts.each do |post|
      process_post(post)
    end
  end
end
```

### Adding Post Metadata

You can add custom metadata processing:

```crystal
# In your feature's enable method
posts.each do |post|
  if metadata = post.metadata
    # Access or add metadata
    metadata["my_field"] = "value"
  end
end
```

### Modifying Post Output

Transform post HTML before it's written:

```crystal
# Wrap the existing HTML
wrapped_html = "<div class='my-feature'>#{post.rendered(lang)}</div>"
```

## Integrating with Templates

### Using Existing Templates

```crystal
# Render with page.tmpl wrapper
html = Render.apply_template("templates/page.tmpl", {
  "title" => "My Page",
  "content" => content,
  "breadcrumbs" => breadcrumbs,
})
```

### Including Template Components

```crystal
# Include title.tmpl for breadcrumbs
template = Templates.environment.get_template("templates/page.tmpl")
html = template.render({
  "title" => post.title(lang),
  "content" => post.rendered(lang),
  "breadcrumbs" => post.breadcrumbs(lang),
  "language_links" => post.language_links(lang),
})
```

### Creating Template Variables

Pass data to templates:

```crystal
ctx = {
  "my_data" => my_feature_data,
  "title" => "My Page",
  "content" => content,
}

template = Templates.environment.get_template("templates/my_feature.tmpl")
html = template.render(ctx)
```

## Integrating with Search

### Adding Content to Search Index

The search feature automatically indexes HTML content. Ensure your feature's output is accessible to the search crawler:

```crystal
# Your output will be indexed if:
# 1. It's in the output/ directory
# 2. It has an .html extension
# 3. It's within a <main> tag
```

### Custom Search Indexing

If you need custom search indexing:

```crystal
# Create a search.json entry
{
  "title" => "My Page",
  "text" => extracted_text,
  "url" => "/my-page/",
  "id" => index,
}
```

## Integrating with Taxonomies

### Adding Taxonomy Support

```crystal
module MyFeature
  def self.enable(is_enabled : Bool, posts)
    return unless is_enabled

    # Process taxonomies if enabled
    if Config.options["features"].as_a.includes?("taxonomies")
      process_with_taxonomies(posts)
    end
  end
end
```

### Accessing Taxonomy Data

```crystal
# Get taxonomy from post metadata
if taxonomies = post.taxonomies
  tags = taxonomies["tags"]?
  categories = taxonomies["categories"]?
end
```

## Integrating with Navigation

### Adding to Site Navigation

Configure in `conf.yml`:

```yaml
site_nav:
  - /my-feature/
```

### Dynamic Navigation

Create navigation items programmatically:

```crystal
# Generate nav items from your feature's content
nav_items = my_content.map do |item|
  {
    "title" => item.title,
    "link" => item.link,
  }
end
```

## Integrating with Multilingual Support

### Language-Aware Processing

```crystal
module MyFeature
  def self.render
    # Get all configured languages
    languages = Config.options["languages"]?.try(&.as_h) || {} of String => Totem::Type

    # Process for each language
    languages.each do |lang_code, lang_config|
      process_language(lang_code, lang_config)
    end
  end
end
```

### Language Links

Add language switcher support:

```crystal
# Include language_links in template context
ctx = {
  "title" => title,
  "content" => content,
  "language_links" => post.language_links(lang),
}
```

## Integrating with Assets

### Registering Assets

```crystal
# Assets are automatically copied from assets/ directory
# Place your feature's assets there:

assets/
  my_feature/
    script.js
    style.css
```

### Generating Assets

Dynamically generate assets:

```crystal
Croupier::Task.new(
  id: "my_feature_css",
  output: "output/css/my_feature.css",
  inputs: ["conf.yml"],
) do
  css = generate_css_from_config
  File.write("output/css/my_feature.css", css)
end
```

## Integrating with RSS Feeds

### Adding to RSS Feed

```crystal
# Posts are automatically added to RSS
# For custom content, add RSS items manually:

rss_items = my_content.map do |item|
  {
    "title" => item.title,
    "link" => "#{site_url}#{item.link}",
    "description" => item.summary,
    "date" => item.date,
  }
end
```

## Feature Interdependencies

### Checking Feature Availability

```crystal
# Check if another feature is enabled
has_posts = Config.options["features"].as_a.includes?("posts")
has_taxonomies = Config.options["features"].as_a.includes?("taxonomies")

# Only enable functionality if dependencies are available
if has_posts && has_taxonomies
  enable_advanced_features
end
```

### Running After Other Features

Order matters in `src/nicolino.cr`:

```crystal
# Posts runs first
posts = Posts.enable(features.includes?("posts"))

# Your feature can use posts data
MyFeature.enable(features.includes?("my_feature"), posts)
```

## Common Integration Points

### On File Change

```crystal
# React to content changes
Croupier::Task.new(
  id: "watch_files",
  output: "output/index.html",
  inputs: ["content/**/*.md"],
) do
  # Rebuild when content changes
end
```

### On Configuration Change

```crystal
# React to config changes
Croupier::Task.new(
  id: "config_change",
  output: "output/data.json",
  inputs: ["conf.yml"],
) do
  # Rebuild when config changes
end
```

### On Template Change

```crystal
# Include template dependencies
inputs = ["content.md"] + Templates.get_deps("templates/my_template.tmpl")
```

## Testing Integrations

1. **Build incrementally**: Change one file and verify only dependent tasks run
2. **Test feature combinations**: Enable multiple features together
3. **Check output order**: Verify tasks run in the correct sequence
4. **Validate data flow**: Ensure data passes correctly between features

## Integration Checklist

- [ ] Feature respects `enabled` flag
- [ ] Feature works with posts (if applicable)
- [ ] Feature respects language settings
- [ ] Feature integrates with navigation
- [ ] Feature handles missing dependencies gracefully
- [ ] Feature's tasks have correct input dependencies
- [ ] Feature's output is accessible to other features
