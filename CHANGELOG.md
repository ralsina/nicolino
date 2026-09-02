# Changelog

All notable changes to this project will be documented in this file.

## [0.26.2] - 2026-09-02

### 🐛 Bug Fixes

- Update shortcodes to 0.5.0

## [0.26.1] - 2026-08-31

### 🐛 Bug Fixes

- Emit absolute URLs in the RSS feed
- Don't warn on item-less valid feeds during import
- Extract collect_feed_items to satisfy cyclomatic complexity limit

## [0.26.0] - 2026-08-29

### 🚀 Features

- Showcase cards, nicolino theme install docs, catppuccin demos
- Blox theme, ported from Hugo Blox Tailwind
- Port-next-theme hace target
- LoveIt theme, ported from Hugo LoveIt
- Coder theme, ported from Hugo Coder
- Deploy target imports and publishes release posts
- Add mermaid shortcode for rendering diagrams (#74)
- Lock the site directory during build and auto runs (#78)
- Note when an index page is capped to the latest posts
- Breadcrumbs expand on click, not hover
- Enable discount and extra definition lists

### 🐛 Bug Fixes

- Pin port-next-theme agent to glm-5.2 endpoint
- Relativize url_prefix-prefixed links correctly
- Theme port fidelity - reading time and humanized demo dates
- LoveIt port fidelity + stronger translation prompt
- Pin ameba to released 1.7.0 to unbreak CI
- Card shortcode emits Pico's card component
- Sort taxonomy term pages by date, newest first
- Expose the page language to templates
- Remove comment from mermaid shortcode
- Sort taxonomy terms alphabetically on the index page
- Tighten breadcrumb separators
- Render breadcrumbs as inline-flex
- Render figure shortcode as verbatim div block, drop DLDISCOUNT flag
- Drop unused rescue variable in BuildLock.acquire
- Use image bounds for dimensions in novips builds

### 🚜 Refactor

- Extract URL skip check from make_links_relative (#77)

## [0.25.0] - 2026-08-27

### 🚀 Features

- Server-side syntax highlighting for markdown code blocks via
  tartrazine (used by listings before, now everywhere): tz-prefixed
  CSS classes, css/syntax.css with dark/light variants derived from
  the site's color_scheme (or `syntax_theme:` override); opt out
  with `syntax_highlighter: none`; highlight.js CDN scripts dropped
  from all bundled themes
- Translation fallback system (#54): untranslated content is rendered
  from its default-language version (or any available translation),
  flagged with `is_fallback` in the post and page template contexts;
  disable with `content_fallback: false` in conf.yml
- Site-level `language_links` helper shared by posts, index pages,
  taxonomy pages and page folder indexes, so translation-switcher
  menus work everywhere (#54)
- Theme parameters: theme.yml's `params:` section (plus metadata) is
  exposed to all templates as the `theme` variable; sites override
  values via conf.yml's `theme_params:` section
- Terminal theme, ported from the Hugo theme by panr (MIT), with
  base16 color-scheme integration and a dark/light toggle
- PaperMod theme, ported from the Hugo theme by adityatelange (MIT),
  with base16 palette and highlight.js token mapping
- Index pages now render with site/theme constants in scope, so
  templates can use `site_*` and `theme.*` in index.tmpl
- Theme registry: `nicolino theme install/list/remove` fetches themes
  from a remote registry (default `https://nicolino.ralsina.me/themes.json`),
  verifying each tarball's SHA256, so themes can be installed without
  cloning them into the repo by hand
- Root-relative (and `url_prefix`-aware) link relativization: pages served
  under a subpath now rewrite `/css/style.css` links to correct relative
  paths, and the link checker resolves `..` from nested pages

### 🐛 Bug Fixes

- Fix `remove_empty_paragraphs` deleting paragraphs that contain only
  an image (or any element without text), which made markdown images
  disappear from posts whenever the HTML filter pass ran
- Template preprocessor folded `{% if %}` tags whose body was static
  without checking the condition, silently dropping branches that
  test runtime variables (e.g. `is_fallback`, `language_links`)

### 📚 Documentation

- Theme-porting best practices guide (docs/theme-porting.md)
- Theme showcase site (demo/): markdown tour, code blocks, image,
  i18n with fallback badge, base16 scheme switching

## [0.24.0] - 2026-08-24

### 🚀 Features

- Make feature-directory names (books, archive, galleries) configurable (#55)
- Support galleries without an index.md (#59)
- *(bench)* Use hyperfine for timing, add Zola, restructure sites
- User-defined template filters in Lua (#71)
- OpenGraph and Twitter Cards metadata (#42)

### 🐛 Bug Fixes

- Synchronize shared failure state in parallel builds (#56)
- Re-fold templates in auto-rebuild when source changes (#57)
- Make fix_code_classes idempotent (#58)
- Quiet error paths and unsafe date casts (issue #29)
- Adapt to cr-discount NamedTuple compile API
- Restore TOC gating with new cr-discount flags API
- Correct Hugo URL in user guide, fixes #65
- Support --version flag, fixes #63
- *(auto)* Guard inotify watcher behind Linux flag (#62)
- Rewrite .md content links to .html when rendering, fixes #64 (#67)
- Point features page PocketBase example at /pocketbase.html
- Surface silent-failure paths, drop unsafe date casts, fixes #29 (#68)
- Always rebuild static binaries in release pipeline
- Admonition shortcode HTML leak and external data docs (#72, #73)
- Release scripts survive missing or container-built lib/

### 🚜 Refactor

- Consolidate config structs and raise a typed ConfigError (#41)

### 📚 Documentation

- Missing releases
- Document how to install libvips for source builds, refs #62
- External JavaScript chapter with vega-lite chart shortcode (#69)
- Center vega-lite charts in their container

### ⚡ Performance

- Stream sitemap and search index writes to reduce allocations (#61)
- Lock-free Crinja env pool, memoize per-page hot paths

### 🎨 Styling

- Fix all ameba lint failures
- Spell LuaArg's nilable members with ? for bundled ameba

### 🧪 Testing

- Add initial spec suite (#60)

### Build

- Use ralsina/crinja perf/memoize-lookups branch
- Bump versions
- Bump versions
- Build static release binaries for amd64 and arm64
- Add lua5.4-dev to the static build image

### Ci

- Zola scaffolding for benchmark
- Install hyperfine and jq for the smoke test
- Smoke test builds the corpus directly instead of running the benchmark
- Single-invocation benchmark harness, consistent report (#70)

## [0.23.0] - 2026-08-20

### 🚀 Features

- Reproducible benchmark harness + optimized-build CI (#39)
- Complete template dependency detection via AST visitor

### 🐛 Bug Fixes

- Make `nicolino init` work without a `-v` flag (#34)
- Honor configured output, content and default-language paths (#36)
- Don't materialize `kv://` virtual outputs as directories
- Declare template include deps at task creation
- Declare shortcode kv deps so parallel builds can't race them
- Derive unique task ids for croupier 0.14
- Suppress ameba TODO/FIXME warnings
- Remove stale ameba directives and fix line length

### ⚡ Performance

- Optimize HTML processing pipeline
- Add timing instrumentation to Markdown.render
- Parallel content scanning via ContentScanner
- Preprocess templates (inline includes, fold constant subtrees)
- Page post-processing fast paths and parallel content reading
- Compile markdown and pandoc outside the memo mutex
- Pool Crinja environments across waves and rebuilds
- Raise parallel utilization in creation and page post-processing
- Memoize post HTML, language scan, and registry lookups

### 🚜 Refactor

- Remove dead code left behind by the enable_from_scan refactor (#33)
- Deduplicate gallery creation and tidy misc code smells (#35)
- Deduplicate copy-pasted feature logic (#38)

### 📚 Documentation

- Add release notes posts v0.11.1 through v0.21.0
- Cite reproducible benchmark numbers in performance claims

### Build

- Add minimal bench theme + install step

### Ci

- Install libvips before building (#40)
- Build release to default path then copy it aside
- Install ragel for the shortcodes shard postinstall
- Install native deps before shards install

## [0.21.0] - 2026-08-14

### 🐛 Bug Fixes

- Parallel builds no longer crash on large sites: croupier 0.13.0
  fixes the Boehm GC segfaults in `_run_tasks_parallel` (19 consecutive
  cold parallel builds of a 4000-post site without a single crash,
  where croupier 0.12.4 segfaulted on the first attempt)

### ⚡ Performance

- Parallel builds are now actually usable: ~4.7s vs ~14s serial for a
  4000-post site

### 📦 Dependencies

- croupier ~> 0.13.0
- Require Crystal >= 1.20.0 (as croupier 0.13.0 does)

## [0.20.0] - 2026-08-14

### 🚀 Features

- Add gallery card view with thumbnails

### 🐛 Bug Fixes

- Center figures
- Post breadcrumb for posts/foo/index.md
- Bool flag handling
- Title case breadcrumbs
- Show user-friendly error when conf.yml is missing
- Makefile clean target and broken test target
- -q flag silenced all command output

### 🎨 Styling

- Ameba 1.7 autofixes
- Fix remaining ameba 1.7 findings

## [0.19.0] - 2026-01-30

### 🚀 Features

- Improve auto mode reliability and post handling

### 🐛 Bug Fixes

- Correct -q flag handling and clean up auto command

### 📚 Documentation

- Add Import feature card to features page

### Bump

- Release v0.19.0

## [0.18.0] - 2026-01-29

### 🚀 Features

- Add teaser support with "read more" links
- Add installation script for latest release
- Add book support to "nicolino new" command
- Add Pocketbase CMS support to continuous_import

### 🐛 Bug Fixes

- Correct Pocketbase parameter order and URL handling
- Consolidate date parsing with DateUtils helper

### 📚 Documentation

- Add performance warning to install script
- README
- Fix getting started doc
- Add book support to "nicolino new" documentation
- Move Pocketbase support to external docker setup

### Bump

- Release v0.18.0

## [0.17.0] - 2026-01-28

### 🚀 Features

- Make shortcode errors fail tasks and timing debug-only

### 🐛 Bug Fixes

- Remove empty paragraphs from Discount's section tag wrapping

### 📚 Documentation

- Fix misleading book feature description

### Bump

- Release v0.17.0

## [0.16.0] - 2026-01-28

### 🚀 Features

- Add sun/moon theme toggle button
- Add expanding search input on hover
- Add PhotoSwipe gallery and fix shortcode indentation
- Add admonition shortcode with base16 styling

### 🐛 Bug Fixes

- Remove Totem dependency and fix import command
- Prevent horizontal scrollbar and fix collapsed sidebar width
- Reduce whitespace in tag shortcode output
- Buggy card shortcode
- Restore listings feature after config flattening
- Listing issues

### 📚 Documentation

- Shortcodes examples improvements
- Add features page and improve index navigation

### Bump

- Release v0.16.0

## [0.15.0] - 2026-01-27

### 🚀 Features

- Add emoji font role support
- Add hero and card shortcodes with new index page
- Improve tag shortcode to support role and id attributes
- Display search results in a proper modal dialog

### 🐛 Bug Fixes

- Hero shortcode syntax

### 📚 Documentation

- Rewrite developer configuration guide for new config schema
- Revamped site
- Updated shortcodes

### 🎨 Styling

- Improve book TOC look
- Remove hardcoded footer text from themes

### Bump

- Release v0.15.0

## [0.14.0] - 2026-01-26

### 🚀 Features

- Add TOC extraction for HTML and Pandoc posts
- Add theme delivery system
- Add font configuration system and color scheme improvements
- Add color_scheme and fonts to default config template
- Add logging when base16 generates style.css
- Add multilingual support with per-language config overrides
- Make locale and date_output_format overridable per-language
- Restore nav_items configuration option

### 🐛 Bug Fixes

- Rewrite downgrade_headers to shift so highest heading is H2
- Remove pytut folder handling from import script
- Use double braces for raw tags in import script
- Force full page reload when style.css changes in auto mode
- Force full page reload for all HTML pages when style.css changes
- Watch actual config file for style.css regeneration
- Reload config when conf.yml changes in auto mode
- Reload config before tasks run in auto mode
- Allow partial language overrides in conf.LANG.yml
- Use localStorage instead of cookies for theme preference

### 🚜 Refactor

- Consolidate theme baking into single ThemeFiles
- Simpler config system with YAML::Serializable
- Rewrite config system using YAML::Serializable
- Rename 'formats' to 'pandoc_formats' for clarity

### 📚 Documentation

- Add comment about language overrides in conf.yml template
- Reorganize conf.yml with clear translatable/non-translatable sections
- Add demo video to auto mode documentation
- Added auto mode video
- Update configuration.md to new flat config format
- Fix misleading font defaults documentation
- Fix misleading images.md documentation

### 🎨 Styling

- Add blank lines above list items in configuration.md

### Bump

- Release v0.14.0

## [0.13.0] - 2026-01-23

### 🚀 Features

- Add per-feature timing breakdown with task counts and averages

### 🐛 Bug Fixes

- Improve site import script handling

### 🚜 Refactor

- Convert books navigation from nested hashes to proper records
- Convert similarity results from mixed-type hashes to typed records
- Extract RSS module, defer date/title loading to task execution

### ⚡ Performance

- Add similarity caching, fix language filtering, improve timing reports
- Parallelize post date loading, remove PostDates module, fix Time.monotonic deprecations

### Build

- Not-release

### Bump

- Release v0.13.0

## [0.12.0] - 2026-01-22

### 🚀 Features

- Auto-install missing shortcodes from baked filesystem
- Use whitespace-trim comments in templates

### 🐛 Bug Fixes

- Remove redundant templates
- Use proper YAML serializer in import script
- Avoid asset conflict
- Improve import script date parsing and shortcode handling
- Use yaml.safe_load for proper frontmatter parsing
- Simplify date conversion to extract date from datetime strings

### 🚜 Refactor

- Convert archive data structures from nested hashes to proper records

### 📚 Documentation

- Tag fixes
- Updated frontpage
- Updated frontpage
- Updated frontpage

### ⚡ Performance

- Add lightweight_value to taxonomy rendering to avoid rendering posts

### Bump

- Release v0.12.0

## [0.11.1] - 2026-01-22

### 🐛 Bug Fixes

- Handle single-string taxonomy values like "tags: release"
- Properly split comma-separated taxonomy values
- Folder_indexes now properly excludes directories with index.md

### 📚 Documentation

- Updated frontpage
- Fix getting-started - auto mode already includes HTTP server
- Add blank lines above lists in getting-started.md
- Fix auto mode port number (8080 not 4000)
- Updates and fixes in release import template

### Bump

- Release v0.11.1

## [0.11.0] - 2026-01-22

### 🚀 Features

- Add creatable registry for nicolino new and improve docs
- Add per-language RSS feeds and taxonomy/folder feeds
- Add optional metadata and hide empty titles in templates
- Require titles for posts
- Add raw HTML reStructuredText support and site import scripts
- Add script for backward-compatible HTML path symlinks
- Use cached HTML for non-markdown posts/pages

### 🐛 Bug Fixes

- Restore Default theme text in footer
- Improve book TOC alignment and make dt bold
- Force date parsing before sorting and limit RSS to 20 posts
- Preserve original filenames in post migration
- Use correct Jinja2 raw syntax {{% raw %}}
- Html files with frontmatter now render content properly
- Avoid ambiguous requirement

### 🚜 Refactor

- Separate post and page folder index generation

### 📚 Documentation

- More docs
- User intro fix
- Fixes
- Restore favicon

### Bump

- Release v0.11.0

## [0.10.0] - 2026-01-19

### 🚀 Features

- Add youtube and gallery shortcodes
- Add youtube and gallery shortcodes, fix gallery grid layout, improve logging
- Add shell shortcode and improve CLI documentation
- Add Django/Jinja2 syntax highlighting support
- Add theming system
- Add theme assets feature
- Add minimal theme with sidebar navigation
- Inject book TOC into main sidebar for minimal theme
- Add Lanyon-inspired theme with sliding sidebar

### 🐛 Bug Fixes

- Restore galleries/index.html generation by adding language_links to Gallery
- Reduce books logging and fix gallery grid layout
- Markdown issues in posts.md
- Add proper hljs classes for code blocks
- Use crimage instead of pluto for -Dnovips fallback
- Restore theme.css from main branch
- Style sidebar navigation links properly in minimal theme
- Make sidebar collapsible on all screen sizes in minimal theme
- Galleries index path duplication
- Resolve template include paths relative to theme directory
- Resolve shortcode template paths correctly

### 🚜 Refactor

- Optimize theme.css

### 📚 Documentation

- User intro
- Fixes
- More docs
- Wrap shell shortcode examples with raw tags
- Add plain code blocks before raw-wrapped shell examples
- Show rendered output instead of raw blocks for shell examples
- Show both raw syntax and rendered output for shell examples
- Fixes
- More docs
- Add themes and markdown chapters, fix book tree structure
- Minor doc fixes

### ◀️ Revert

- Remove lanyon theme experiment

### Bump

- Release v0.10.0

## [0.9.0] - 2026-01-18

### 🚀 Features

- Add book.toml support for mdbook compatibility
- Add copy button to code blocks using highlightjs-copy
- Use official highlightjs-copy CSS instead of custom styles

### 🐛 Bug Fixes

- Use base01 for code block background instead of base00
- Use correct highlightjs-copy plugin initialization
- Make copy button only visible on hover
- Make copy button text visible with proper color

### Bump

- Release v0.9.0

## [0.8.0] - 2026-01-17

### 🚀 Features

- Improve folder indexes and add feature documentation
- Improve color_schemes command and fix theme CSS
- Add highlight.js CSS to base16 color scheme

### 🐛 Bug Fixes

- Correct folder index output path check

### 📚 Documentation

- Fix list formatting in book documentation
- Add missing book and language switcher templates to documentation
- Add Developer Guide book
- Add notes about documentation status
- Point Docs link to /books/ index

### 🎨 Styling

- Make links in headings inherit heading color

### Bump

- Release v0.8.0

## [0.7.0] - 2026-01-15

### 🚀 Features

- Add mdbook/gitbook-style books feature
- Limit blog index to 100 posts with archive link
- Add multilingual blog index language switcher

### 🐛 Bug Fixes

- Replace hyperscript search with JavaScript implementation
- Add book index as previous link for first chapter

### 🚜 Refactor

- Remove obsolete content/docs directory

### 📚 Documentation

- Added release

### Bump

- Release v0.7.0

## [0.6.0] - 2026-01-15

### 🚀 Features

- Use crimage for static builds, convert gallery webp to jpeg
- Add link checker command
- Add continuous import feature for RSS/Atom feeds
- Add MinHash similarity feature for related posts
- Add continuous import documentation and move templates to user_templates
- Add baked-in default template for continuous import
- Add proper breadcrumbs to all pages
- Make all colors respect base16 theme from conf.yml
- Add color_schemes command for theme discovery
- Simplify color scheme config to use family names
- Add --apply option to color_schemes command
- Improve folder_indexes and add docs navigation
- Add common item_list template for consistent index styling
- Add breadcrumbs to all pages using title.tmpl
- Remove 4000/ from folder_indexes exclusion
- Improve title.tmpl breadcrumb styling

### 🐛 Bug Fixes

- Correct post order in index (newest first)
- Remove duplicate Published and Tags from release posts
- Remove duplicate breadcrumb from page template
- Remove duplicate h1 title from item_list template
- Remove useless assignments flagged by linter
- Missing file
- Ensure progress bar reaches 100% on last task completion

### 🚜 Refactor

- Move breadcrumb CSS from title.tmpl to custom.css
- Reorganize CSS into theme.css and custom.css
- Move nicolino_release.tmpl to templates/import/
- Add enable() to all features

### 📚 Documentation

- Add comprehensive link checker documentation
- Move feature documentation to content/docs/
- Remove duplicate titles from feature docs
- Add template documentation and descriptive comments

### ⚡ Performance

- Parallelize search and sitemap generation with chunked processing

### ◀️ Revert

- Undo progress bar 100% fix

### Build

- Set flags
- Disable ARM

### Bump

- Release v0.6.0

## [0.5.0] - 2026-01-13

### 🚀 Features

- Add thumbnail shortcode and fix HTML recursion
- Improve blog post layout and navigation
- Improve breadcrumb navigation in heading
- Improve navigation, breadcrumbs, and metadata display
- Add archive page with collapsible years
- Auto-install missing templates from baked filesystem
- Auto-install missing assets from baked filesystem
- Only show updated timestamp if significantly different
- Add external link display and pandoc conversion script
- Add code listings feature with tartrazine syntax highlighting
- Improve listings with index page and better filenames
- Add tartrazine CSS generation for syntax highlighting

### 🐛 Bug Fixes

- Address critical code quality issues
- Improve error message for missing shortcodes
- Resolve HTML file rendering missing TOC hash key error
- Properly rewind baked files before writing
- Use markdown-smart to prevent quote escaping in pandoc conversion
- Avoid ambiguous requirement
- Disable highlight.js on listing pages to use tartrazine styling

### 🚜 Refactor

- Use block syntax for Croupier Task in auto command
- Use tartrazine auto-detection for language detection
- Use Process.find_executable instead of which command

### ⚡ Performance

- Optimize header downgrading by moving children directly
- Optimize make_links_relative and shortcode replacement

### 🎨 Styling

- Fix ameba linting issues in listings.cr
- Fix all remaining ameba linting issues

### Bump

- Release v0.5.0

## [0.4.0] - 2025-11-24

### 🚀 Features

- Implement hierarchical gallery tree structure support

### 🐛 Bug Fixes

- Resolve template race condition with CSS grid layout
- Resolve thread safety and feature filtering issues
- Remove SVG files from gallery image lists

### 🚜 Refactor

- Convert Croupier task definitions to use block syntax

### ⚡ Performance

- Optimize image processing pipeline
- Implement shortcode fast-path optimization

## [0.3.0] - 2025-05-27

### 🚀 Features

- Make tasks that use crinja serialized

### 🐛 Bug Fixes

- Deprecated sleep usage
- Yield correctly so tasks actually parallelize over threads/fibers
- No more mutex

### Bump

- Release v0.3.0

### Chore

- *(build)* Fixes

## [0.2.1] - 2024-10-07

### 🐛 Bug Fixes

- Provide alternative -Dnovips using imgkit
- Use pluto as novips choice
- Better version/help in CLI

### Build

- Use fork of baked_file_system
- Make static build work
- Add do_release script
- Lock versions
- ARM static build fails

### Bump

- Release v0.2.1

### Chore

- *(build)* Add Hacefile for automation

## [0.2.0] - 2024-07-23

<!-- generated by git-cliff -->
