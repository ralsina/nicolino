---
title: "Pictures And Folded Posts"
date: 2026-08-22
tags: [images, demo]
summary: "A picture, a teaser, and everything after the fold."
---

Posts can carry images — themes should flow them nicely or at least
not break.

![A terminal window rendering a nicolino build](/images/nicolino-card.png)

The card above is a plain PNG shipped in the site's `assets/images/`
directory and referenced with an absolute path. No magic: whatever
theme renders this site, the image just works.

<!--more-->

Everything below the `<!--more-->` marker is the post body proper:
index pages show only the summary (`has_teaser` is true), and the
post page shows it all.

## One site, many skins

This same content ships with several interchangeable themes
(`terminal`, `papermod`, `default`): switch `theme:` in `conf.yml`,
rebuild, and the words stay while the look changes.

Colors come from the site's base16 `color_scheme`, so a theme swap
never means re-picking palettes:

```bash
nicolino color_schemes   # list every scheme
```

Code blocks are highlighted at build time, and their token colors
follow the scheme too — try the dark/light toggle in the header.
