# Nicolino Theme Showcase

A small site for demoing themes with realistic-but-tiny content:
markdown torture test, code fences, an image, taxonomies, archive,
i18n (one translated post, one untranslated), and base16 theming.

## Run it

```bash
cd demo
../bin/nicolino build
../bin/nicolino serve    # http://localhost:8080
```

## Switch themes

Edit `theme:` in `conf.yml` (`terminal`, `papermod` or `default`) and
rebuild. The `terminal` and `papermod` themes are symlinks to the
repo copies, so theme edits show up immediately.

## Switch color scheme

Edit `color_scheme:` in `conf.yml` (list them all with
`../bin/nicolino color_schemes`). Both themes map their palettes
onto base16; the Terminal theme also has a ◐ dark/light toggle.

## Content map

| File | What it demos |
|---|---|
| `content/index.md` (+ `index.es.md`) | home page (translated) |
| `content/posts/markdown-tour.md` (+ `.es.md`) | headings, lists, quotes, tables, TOC; a translated post |
| `content/posts/code-blocks.md` | code fences; untranslated on purpose → `is_fallback` badge on the `es` site |
| `content/posts/images-and-teasers.md` (+ `.es.md`) | image, summary/teaser (`<!--more-->`) |
