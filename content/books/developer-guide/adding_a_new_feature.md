# Adding a New Feature

This guide explains how to add a new feature to Nicolino.

## Feature Structure

Features in Nicolino are implemented as Crystal modules. Here's the basic pattern:

```crystal
module MyFeature
  def self.enable(is_enabled : Bool)
    return unless is_enabled
    render
  end

  def self.render
    # Your feature implementation here
  end
end
```

## Registration

Register your feature in `src/nicolino.cr`:

```crystal
require "./my_feature"

# In the main enable method
MyFeature.enable(features.includes?("my_feature"), posts) if posts
```

## Configuration

Add your feature to the `features` array in `conf.yml`:

```yaml
features:
  - posts
  - my_feature
```

## Common Patterns

### Content Processing

If your feature processes content files:

```crystal
def self.render
  inputs = Croupier::TaskManager.tasks.keys.select(&.to_s.ends_with?(".md"))

  inputs.each do |input|
    Croupier::Task.new(
      id: "my_feature/#{File.basename(input)}",
      output: "output/#{File.basename(input, ".md")}.html",
      inputs: [input],
      mergeable: false
    ) do
      # Process the file
      process_file(input)
    end
  end
end
```

### Template Rendering

Use the `Templates` module to render templates:

```crystal
template = Templates.environment.get_template("templates/my_feature.tmpl")
html = template.render({
  "title" => "My Page",
  "content" => content,
})
```

### Adding Navigation

Add your feature to the site navigation in `conf.yml`:

```yaml
site_nav:
  - /my-feature/
```

## Testing Your Feature

1. Build the binary: `make bin`
2. Build a test site: `./bin/nicolino build`
3. Check the output: `ls output/`
4. Run linter: `make lint`

## Examples

Look at existing features for reference:
- `src/posts.cr` - Content processing with metadata
- `src/gallery.cr` - Image processing with thumbnails
- `src/books.cr` - Complex multi-page feature
- `src/search.cr` - JSON data generation
