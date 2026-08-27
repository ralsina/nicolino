---
title: Theme Showcase
date: 2026-08-25
---

Browse live demos of every available Nicolino theme. Each demo is a
complete site with posts, taxonomies, archive, images, base16 color
schemes, and multilingual content — the same content rendered by four
different themes so you can compare them side by side.

## Installing a theme

All four themes ship through the theme registry. List the
available themes, then install any of them into your site:

```bash
nicolino theme list                # show what's available
nicolino theme install terminal    # e.g. install the Terminal theme
```

`nicolino theme install <name>` fetches the theme from
`https://nicolino.ralsina.me/themes.json`, verifies its SHA256, and unpacks
it into your site's `themes/` folder. You can also install from a local
tarball with `nicolino theme install ./path/to/theme.tar.gz`.

Once installed, set the theme in `conf.yml` and rebuild:

```yaml
theme: terminal
```

```bash
nicolino build
```

See the [Themes](/books/user-guide/themes.html) chapter of the User Guide for
full documentation on customizing and porting themes.

{{% tag div class="grid" %}}

{{% card %}}
[![Default theme screenshot](/themes/shots/default.png)](/themes/demo/default/)

### Default

The default Nicolino theme with a classic blog layout and pico.css
styling.

**Author:** Roberto Alsina · **License:** MIT · **Version:** 1.0.0

<p><a href="/themes/demo/default/" role="button">Live Demo</a></p>
{{% /card %}}

{{% card %}}
[![Minimal theme screenshot](/themes/shots/minimal.png)](/themes/demo/minimal/)

### Minimal

Clean, typography-focused theme with sidebar navigation and a
distraction-free reading experience.

**Author:** Roberto Alsina · **License:** MIT · **Version:** 1.0.0

<p><a href="/themes/demo/minimal/" role="button">Live Demo</a></p>
{{% /card %}}

{{% card %}}
[![Terminal theme screenshot](/themes/shots/terminal.png)](/themes/demo/terminal/)

### Terminal

A terminal-styled blog theme ported from Hugo Terminal by panr. Monospace
fonts, dark palette, and a retro feel.

**Author:** panr (Hugo original), ported to Nicolino · **License:** MIT ·
**Version:** 1.0.0

<p><a href="/themes/demo/terminal/" role="button">Live Demo</a></p>
{{% /card %}}

{{% card %}}
[![PaperMod theme screenshot](/themes/shots/papermod.png)](/themes/demo/papermod/)

### PaperMod

Fast, clean and responsive theme ported from Hugo PaperMod by
adityatelange. Focused on readability and performance.

**Author:** adityatelange, nanxiaobei (Hugo original), ported to Nicolino
· **License:** MIT · **Version:** 1.0.0

<p><a href="/themes/demo/papermod/" role="button">Live Demo</a></p>
{{% /card %}}

{{% /tag %}}
