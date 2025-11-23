# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nicolino is a Static Site Generator (SSG) written in Crystal. It's designed as a modular, performant system that processes Markdown, HTML, and Pandoc content to generate static websites. The architecture uses a task-based system (Croupier) for parallel processing and feature toggles for flexibility.

## Build and Development Commands

### Building
```bash
# Development build (no --release flag per user instructions)
make bin                    # Build development binary
shards build -d --error-trace  # Direct build command

# Multithreaded build (optional)
make mt                     # Build with preview_mt
```

### Code Quality
```bash
make test                   # Run linting (main "test" is ameba)
make lint                   # Run ameba linter with auto-fix
ameba --all --fix          # Direct linting command
```

### Running the Tool
```bash
./bin/nicolino build        # Build the site
./bin/nicolino serve        # Development server with live reload
./bin/nicolino auto         # Continuous rebuild mode
./bin/nicolino new post     # Create new content
./bin/nicolino init         # Initialize new site
./bin/nicolino clean        # Clean build artifacts
./bin/nicolino validate     # Validate configuration
```

## Architecture Overview

### Core Module Structure
The codebase follows a modular architecture where each feature is implemented as a separate Crystal module:

- **`src/nicolino.cr`**: Main build orchestration using Croupier task system
- **`src/config.cr`**: Configuration management using Totem YAML parser
- **`src/template.cr`**: Template engine integration using Crinja (Jinja2-like)
- **`src/markdown.cr`**: Markdown processing via cr-discount
- **`src/commands/`**: CLI command implementations using Polydocopt
- **Feature modules**: `gallery.cr`, `taxonomies.cr`, `search.cr`, `sitemap.cr`, etc.

### Task-Based Build System
The build process uses Croupier for parallel task execution:
1. Load configuration from `conf.yml`
2. Create tasks based on enabled features in the `features` array
3. Execute tasks in parallel (if `--parallel` flag is used)
4. Features can be selectively enabled/disabled via configuration

### Configuration System
- **Main config**: `conf.yml` using Totem YAML parser
- **Feature flags**: Array in `features` section controls what gets built
- **Multi-language support**: Optional `languages` section for overrides
- **Taxonomies**: Configurable classification systems (tags, categories)
- **Paths**: Configurable content, output, and feature-specific directories

### Available Features (enabled via config)
- `assets` - Static asset copying
- `base16` - Color scheme generation
- `folder_indexes` - Directory index pages
- `galleries` - Image galleries with thumbnails
- `images` - Image processing and optimization
- `pages` - Static pages
- `pandoc` - Pandoc document conversion
- `posts` - Blog posts with RSS feeds
- `search` - Site search functionality
- `sitemap` - XML sitemap generation
- `taxonomies` - Content classification (tags/categories)

## Development Guidelines

### Code Style and Quality
- Use Ameba for linting (`ameba --all --fix`)
- No `not_nil!` usage per user preferences
- Avoid `to_s` as a crutch for nilable values
- Use descriptive parameter names in blocks, not single letters
- Follow Crystal conventions for module naming and structure

### Testing Approach
- Primary verification is through successful builds (`shards build`)
- Linting with Ameba serves as the main quality gate
- No traditional unit tests currently exist

### Binary Development
- Only one binary target: `nicolino` in `src/main.cr`
- Entry point uses Polydocopt for CLI argument parsing
- Commands implemented as structs in `src/commands/` directory

### External Dependencies (lib/)
The `lib/` directory contains external Crystal libraries and should not be modified. Key dependencies include:
- `croupier` - Parallel task execution
- `crinja` - Template engine
- `polydocopt` - CLI argument parsing
- `lexbor` - HTML parsing
- `crystal-vips` - Image processing

## File Organization Patterns

### Content Structure
- `content/` - Source content directory (configurable)
- `content/posts/` - Blog posts
- `content/galleries/` - Image galleries
- `output/` - Generated site (configurable)
- `templates/` - Jinja2-like templates for site rendering

### Configuration Files
- `conf.yml` - Main site configuration
- `.ameba.yml` - Linting rules
- `shard.yml` - Crystal dependencies and project metadata
- `Makefile` - Build automation
- `.pre-commit-config.yaml` - Git hooks for code quality

### Build Targets
The Makefile provides several build configurations, but per user instructions, always use development builds without `--release` flag during development.
