# Multilanguage Sites

This guide explains how Nicolino handles multilingual sites and how to make your feature work with multiple languages.

## Language System Overview

Nicolino supports multilingual sites through:
- Language-specific content files (`post.es.md`, `post.fr.md`)
- Language configuration in `conf.yml`
- Automatic language switching
- Per-language URL generation

## Configuration

Languages are configured in `conf.yml`:

```yaml
languages:
  es:
    site_title: "Mi Sitio"
    site_description: "Un sitio construido con Nicolino"
  fr:
    site_title: "Mon Site"
    site_description: "Un site construit avec Nicolino"
```

## The Locale Module

The `Locale` module manages language detection and configuration:

```crystal
require "./locale"

# Get all configured languages
languages = Locale.languages

# Get default language
default = Locale.default_lang

# Check if a language is configured
if Locale.has_language?("es")
  # Spanish is configured
end
```

## Language-Specific Content

### File Naming Convention

Content files use language suffixes:

```
posts/
  my-post.md         # Default language
  my-post.es.md      # Spanish
  my-post.fr.md      # French
```

### Accessing Language Content

```crystal
# Get available languages for a post
post = Markdown::File.new({Locale.default_lang => "post.md", "es" => "post.es.md"})

# Get content for specific language
content_es = post.text("es")

# Check if language exists
if post.has_lang?("es")
  spanish_content = post.text("es")
end
```

## Processing All Languages

### Iterating Over Languages

```crystal
module MyFeature
  def self.render
    # Process each configured language
    Locale.languages.each do |lang|
      process_language(lang)
    end
  end

  private def self.process_language(lang)
    # Get language-specific content
    content = get_content_for_lang(lang)

    # Generate output
    output = process(content, lang)

    # Write to language-specific path
    File.write("output/#{lang}/page.html", output)
  end
end
```

### Language-Specific Tasks

```crystal
# Create tasks for each language
Locale.languages.each do |lang|
  Croupier::Task.new(
    id: "my_feature/#{lang}",
    output: "output/#{lang}/index.html",
    inputs: ["content/index.#{lang}.md"],
  ) do
    render_for_language(lang)
  end
end
```

## URL Generation

### Language-Aware URLs

```crystal
# Generate URLs with language prefix
def generate_url(lang, slug)
  if lang == Locale.default_lang
    "/#{slug}.html"  # Default: no prefix
  else
    "/#{lang}/#{slug}.html"  # Other languages: prefix
  end
end
```

### Canonical URLs

```crystal
# Add canonical URL to page
canonical = "#{site_url}#{generate_url(lang, slug)}"
```

## Template Integration

### Language Links in Templates

```crystal
# Pass language links to template
ctx = {
  "title" => post.title(lang),
  "content" => post.rendered(lang),
  "language_links" => post.language_links(lang),
  "current_lang" => lang,
}
```

### Language Switcher Component

The `language_switcher.tmpl` template displays available languages:

```jinja
{% include "templates/language_switcher.tmpl" %}
```

## Language-Specific Configuration

### Accessing Language Config

```crystal
module MyFeature
  def self.get_config_value(key, lang)
    # Get base config
    base_value = Config.options[key]?

    # Get language override
    if lang_config = Config.options.dig?("languages", lang)
      lang_value = lang_config[key]?
      return lang_value || base_value
    end

    base_value
  end
end
```

### Using Language-Specific Values

```crystal
# Get title for current language
title = get_config_value("site_title", "es") || "Default Title"
```

## Making Features Language-Aware

### Step 1: Accept Language Parameter

```crystal
module MyFeature
  def self.process(content, lang = Locale.default_lang)
    # Process content for specific language
  end
end
```

### Step 2: Handle Missing Languages

```crystal
# Fallback to default language
content = post.text(lang) || post.text(Locale.default_lang)
```

### Step 3: Generate Language-Aware Output

```crystal
# Create separate outputs per language
Locale.languages.each do |lang|
  output_path = lang == Locale.default_lang ?
    "output/index.html" :
    "output/#{lang}/index.html"

  render(output_path, lang)
end
```

## Common Patterns

### Processing Multilingual Posts

```crystal
posts.each do |post|
  # Process each available language
  post.available_languages.each do |lang|
    title = post.title(lang)
    content = post.rendered(lang)
    url = post.link(lang)

    # Generate output
    generate_page(title, content, url, lang)
  end
end
```

### Language-Specific Data

```crystal
# Store data per language
@data = {} of String => Hash(String, String)

Locale.languages.each do |lang|
  @data[lang] = {
    "title" => get_title(lang),
    "content" => get_content(lang),
  }
end
```

### RSS Feed per Language

```crystal
# Generate separate RSS feeds
Locale.languages.each do |lang|
  feed = generate_feed(lang)
  File.write("output/#{lang}/rss.xml", feed)
end
```

## Breadcrumbs and Navigation

### Multilingual Breadcrumbs

```crystal
breadcrumbs = [
  {name: "Home", link: "/"},
  {name: "Blog", link: "/posts/"},
  {name: post.title(lang), link: post.link(lang)},
]
```

### Language-Specific Nav Items

```crystal
# Filter nav items by language
nav_items = site_nav.select do |item|
  item["lang"]? == lang || !item["lang"]?  # Include items without lang
end
```

## Best Practices

1. **Always provide a default**: Fallback to default language if translation missing
2. **Test all languages**: Verify your feature works for each configured language
3. **Respect language configuration**: Use `Locale.languages`, don't hardcode
4. **Generate consistent URLs**: Follow the language prefix pattern
5. **Include language links**: Allow users to switch between language versions

## Example: Multilingual Feature

```crystal
module MyFeature
  def self.enable(is_enabled : Bool)
    return unless is_enabled
    render
  end

  def self.render
    # Process each language
    Locale.languages.each do |lang|
      process_language(lang)
    end
  end

  private def self.process_language(lang)
    # Get language-specific config
    title = Config.options.dig?("languages", lang, "site_title")&.as_s ||
            Config.options["site_title"].as_s

    # Get content
    content = get_content(lang)

    # Generate output path
    output_path = lang == Locale.default_lang ?
      "output/index.html" :
      "output/#{lang}/index.html"

    # Render with language context
    ctx = {
      "title" => title,
      "content" => content,
      "lang" => lang,
      "language_links" => generate_language_links(lang),
    }

    template = Templates.environment.get_template("templates/my_feature.tmpl")
    html = template.render(ctx)

    File.write(output_path, html)
  end
end
```

## Testing Multilingual Features

1. **Add multiple languages** to `conf.yml`
2. **Create language-specific content files**
3. **Build the site** and check each language's output
4. **Verify language switching** works in navigation
5. **Check canonical URLs** are correct
6. **Test fallback behavior** when content is missing
