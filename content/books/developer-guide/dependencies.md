# Dependencies

This guide explains how Croupier task dependencies work and how features control when they run.

## Croupier Task System

Nicolino uses [Croupier](https://github.com/ralsina/croupier) for task management. Tasks define inputs, outputs, and dependencies. Croupier uses this information to:

- Determine which tasks need to run (only changed files)
- Run tasks in the correct order (dependencies)
- Enable parallel execution (when `--parallel` flag is used)

## Creating Tasks

Tasks are created with inputs and outputs:

```crystal
Croupier::Task.new(
  id: "my_feature/post",
  output: "output/post.html",
  inputs: ["content/post.md"],
  mergeable: false
) do
  # Process the file
  process("content/post.md")
end
```

## Input Dependencies

Tasks list their inputs, and Croupier tracks when those inputs change:

```crystal
# This task will only run if content.md changes
Croupier::Task.new(
  id: "my_task",
  output: "output.html",
  inputs: ["content.md"],  # Input dependency
) do
  # Process content.md
end
```

## Multiple Inputs

Tasks can depend on multiple files:

```crystal
# Runs when ANY input changes
Croupier::Task.new(
  id: "render_page",
  output: "output/page.html",
  inputs: [
    "content/page.md",
    "conf.yml",
    "templates/page.tmpl",
  ],
) do
  # Re-render if any input changes
end
```

## Task Dependencies

Tasks can depend on other tasks:

```crystal
# First task
Croupier::Task.new(
  id: "generate_data",
  output: "output/data.json",
  inputs: ["content/source.md"],
) do
  generate_json
end

# Second task - depends on first task
Croupier::Task.new(
  id: "render_page",
  output: "output/page.html",
  inputs: ["templates/page.tmpl", "kv://generate_data"],
) do
  # Will run after generate_data completes
  data = Croupier::TaskManager.get("kv://generate_data")
  render_with_data(data)
end
```

## Using the KV Store

The key-value store allows tasks to pass data to other tasks:

```crystal
# Producer task
Croupier::Task.new(
  id: "producer",
  output: "kv://my_data",
  inputs: ["source.md"],
  no_save: true  # Don't write to file
) do
  data = process("source.md")
  Croupier::TaskManager.set("kv://my_data", data.to_json)
  ""
end

# Consumer task
Croupier::Task.new(
  id: "consumer",
  output: "output/page.html",
  inputs: ["kv://my_data", "templates/page.tmpl"],
) do
  data = Croupier::TaskManager.get("kv://my_data")
  render(data)
end
```

## Feature Enablement Patterns

### Early Exit Pattern

```crystal
module MyFeature
  def self.enable(is_enabled : Bool)
    return unless is_enabled  # Don't create tasks if disabled
    render
  end
end
```

### Conditional Dependencies

```crystal
module MyFeature
  def self.enable(is_enabled : Bool, posts)
    return unless is_enabled

    # Only create tasks if posts feature is also enabled
    if posts
      create_tasks_with_posts
    else
      create_tasks_standalone
    end
  end
end
```

### Feature Order Matters

In `src/nicolino.cr`, features are enabled in order:

```crystal
# Posts must be enabled before features that use it
posts = Posts.enable(features.includes?("posts"))
Posts.create_taxonomies(posts, features) if posts

# Features that depend on posts
Similarity.enable(features.includes?("similarity"), posts) if posts
Archive.enable(features.includes?("archive"), posts) if posts
```

## Mergeable Tasks

Mark tasks as `mergeable: false` if they shouldn't be combined with other tasks:

```crystal
Croupier::Task.new(
  id: "my_task",
  output: "output.html",
  inputs: ["content.md"],
  mergeable: false  # Don't merge with other tasks
) do
  # Task code
end
```

## Common Dependency Patterns

### Template Dependencies

```crystal
# Include template dependencies so pages re-render when templates change
inputs = ["content/page.md", "conf.yml"] + Templates.get_deps("templates/page.tmpl")
```

### Configuration Dependencies

```crystal
# Re-run when config changes
Croupier::Task.new(
  id: "my_task",
  output: "output/index.html",
  inputs: ["conf.yml", "content/*.md"],
) do
  # Rebuild when config or content changes
end
```

### Global Assets

```crystal
# CSS generation depends on color scheme config
Croupier::Task.new(
  id: "base16_css",
  output: "output/css/color_scheme.css",
  inputs: ["conf.yml", "templates/base16.tmpl"],
) do
  # Generate CSS when schemes change in config
end
```

## Debugging Task Dependencies

Check what tasks are being created and their dependencies:

```bash
# Run with verbose output
./bin/nicolino build --verbose

# Check which inputs changed
./bin/nicolino build --log-level=debug
```

## Best Practices

1. **List all inputs**: Include templates, configs, and source files
2. **Use the KV store**: For passing data between tasks
3. **Order features correctly**: Enable dependencies before dependents
4. **Test incremental builds**: Ensure only changed files are reprocessed
5. **Consider parallel execution**: Design tasks to run independently when possible
