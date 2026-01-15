# Architecture

Nicolino is built with a modular, task-based architecture using Crystal.

## Core Components

### Croupier Task System

Nicolino uses the [Croupier](https://github.com/ralsina/croupier) library for parallel task execution. Tasks can run in parallel (when `--parallel` flag is used) and the system handles dependencies automatically.

### Configuration

Configuration is managed through `conf.yml` using the [Totem](https://github.com/icyleaf/totem) YAML parser. The config file controls:
- Site metadata (title, description, URL)
- Feature flags
- Directory paths
- Language settings

### Template Engine

Templates use [Crinja](https://github.com/staight-shoota/crinja) (Jinja2-compatible) and are stored in `templates/` with `.tmpl` extension.

## Module Structure

Each feature is implemented as a separate Crystal module in `src/`:
- `posts.cr` - Blog posts
- `gallery.cr` - Image galleries
- `books.cr` - MDBook/GitBook-style documentation
- `search.cr` - Site search
- `taxonomies.cr` - Tags and categories
- And more...

## Data Flow

1. Load configuration from `conf.yml`
2. Create tasks based on enabled features
3. Execute tasks (in parallel if `--parallel` is used)
4. Generate output files in `output/`
