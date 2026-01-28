# Nicolino

A **good** static site generator.

## Features

- **Markdown-based content** - Write in markdown, get HTML
- **Posts and pages** - Blog posts with RSS feeds and static pages
- **Taxonomies** - Tags, categories, and custom classification systems
- **Image galleries** - Automatic thumbnails with lightbox
- **Books** - mdbook/gitbook-style documentation with hierarchical chapters, sidebar TOC, and navigation
- **Search** - Site search functionality
- **Sitemap** - Automatic XML sitemap generation
- **Fast builds** - Parallel, incremental builds via Croupier task system

## WARNING

This project is still in development and may change suddenly in places like
the configuration file format, but it is ready to start being used.

For more information, visit <https://nicolino.ralsina.me>

## Building for Release (Static Binaries)

The project uses `libvips` for fast image processing, but libvips cannot be statically linked. To create static binaries, we use the `-Dnovips` flag which falls back to `crimage` (a pure-Crystal image library).

**Important trade-offs:**
- **Non-release builds with crimage are very slow** - image processing will take noticeably longer
- **Release builds with crimage are somewhat faster** - but still slower than libvips
- **Static builds require `-Dnovips`** - otherwise linking will fail due to missing libvips static libraries

For development use, build without `-Dnovips` for fast image processing with libvips. For release/static builds, use `-Dnovips` and accept the performance trade-off.
