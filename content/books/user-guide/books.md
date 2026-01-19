The Books feature provides mdbook/gitbook-style documentation with hierarchical chapters, navigation, and table of contents.

## How It Works

The Books feature organizes documentation into:

- **Books** - Complete documentation sets
- **Chapters** - Individual content files
- **Sections** - Hierarchical organization
- **Navigation** - Previous/Next chapter links
- **Table of Contents** - Collapsible sidebar TOC

## Directory Structure

Each book gets its own directory:

```
content/books/
  user-guide/
    SUMMARY.md
    templates.md
    color_schemes.md
    features/
      color_schemes.md
  developer-guide/
    SUMMARY.md
    architecture.md
    contributing.md
```

## SUMMARY.md

The `SUMMARY.md` file defines your book's structure:

```markdown
# Book Title

Book description goes here.

- [Chapter One](chapter1.md)
- [Chapter Two](chapter2.md)
- [Section Title]()
  - [Subchapter A](subchapter-a.md)
  - [Subchapter B](subchapter-b.md)
```

**Structure:**
- **H1 header** (`# Title`) - Book title and description
- **List items** with links - Chapters with content files
- **List items** without links - Section dividers (no content page)

## Generated Pages

For each book, the following pages are created:

```
output/books/
  book-name/
    index.html           # Book landing page
    chapter1.html        # Chapter pages
    chapter2.html
    subchapter-a.html
  index.html            # Books index (all books)
```

## Book Landing Page

The book index (`/books/book-name/`) displays:

- **Book title** and description
- **Full table of contents**
- **"Start Reading"** link to first chapter

## Chapter Pages

Each chapter page includes:

- **Collapsible sidebar TOC** - With current chapter highlighted
- **Chapter content** - Rendered markdown
- **Navigation buttons** - Previous/Next chapter links
- **Breadcrumbs** - Books > Book Name > Chapter

## Book Navigation

Navigation between chapters:

- **Previous button** - Goes to previous chapter (or book index for first chapter)
- **Next button** - Goes to next chapter
- **Sidebar TOC** - Click any chapter to navigate
- **Auto-expansion** - Current chapter section is expanded

## Hierarchical Structure

Organize chapters into sections:

```markdown
# My Book

- [Getting Started](intro.md)
- [Advanced Topics]()
  - [Feature One](feature1.md)
  - [Feature Two](feature2.md)
  - [Deep Dive]()
    - [Details](details.md)
```

This creates nested sections in the TOC.

## Books Index

A main index at `/books/` lists all available books:

```
Books
├── User Guide
├── Developer Guide
└── API Reference
```

## Configuration

Enable the Books feature in `conf.yml`:

```yaml
features:
  - books
```

No additional configuration is needed. Books are auto-discovered from `content/books/`.

## Markdown in Books

Book chapters support:

- **Standard markdown** - All markdown syntax
- **Shortcodes** - Include dynamic content
- **Code blocks** - With syntax highlighting
- **Tables** - Markdown tables
- **Images** - Relative and absolute links
- **Internal links** - Link between chapters

## Cross-Referencing

Link to other chapters:

```markdown
See [Templates](templates.md) for more details.
```

The link will automatically work within the book.

## Customization

Books use these templates:

- `templates/book_index.tmpl` - Book landing page
- `templates/book_chapter.tmpl` - Chapter pages
- `templates/book_toc_item.tmpl` - TOC component (internal)

Customize the layout, styling, and behavior by editing these templates.

## Styling

Book pages include:

- **Responsive sidebar** - Collapsible on mobile
- **Active chapter highlighting** - Current chapter is marked
- **Smooth navigation** - Animated transitions
- **Theme support** - Dark/light mode compatible

## Per-Language Books

Books support multilingual content:

```
content/books/
  user-guide/
    SUMMARY.md
    intro.md
  user-guide-es/
    SUMMARY.md
    introduccion.md
```

Each language gets its own book with independent structure.
