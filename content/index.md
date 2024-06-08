---
title: Hi there, Welcome to Nicolino!
---

> %lightbox%
> [![The Real Nicolino](nicolino.thumb.jpg)](nicolino.jpg)

# So, what is this?
Nicolino is a simple, fast and lightweight static site generator written in Crystal.

Yes, yes, I know, all the static site generators are simple, fast and lightweight,
but Nicolino is different, it's written in Crystal! 😅

# Should You use it?

Oh Jesus, no. It's not even finished. It's not even close to finished. It's
barely started. It's not even a toy. It's a toy for a toy. It does work, but
it changes too much and too often to be usable.
# Why?

I have written [a large, very flexible, static site generator in Python](https://getnikola.com),
and I wanted to see what would happen if I made very different decisions when
writing the same sort of software.

So, instead of leveraging the huge Python ecosystem of libraries, I wrote
the core of Nicolino from scratch, using only the standard library and a few
choice dependencies.

# What's good about it?

=It *is* fast=
    While benchmarks probably mean nothing since Nicolino is quite incomplete
    it *does* run [this benchmark](https://www.zachleat.com/web/build-benchmark/) ... ok.

    One thing the benchmark doesn't reflect is that Nicolino is
    *much faster than that* in normal use, when it's not doing a
    full build.

    If you add a file or modify an existing page, Nicolino will
    only build the pages that depend on that file.

=It *is* simple=
    Again, this is in part an artifact of Nicolino not being finished yet,
    but it is also a design goal. Nicolino is meant to be simple to use,
    and simple to hack.

    Part of the simplicity comes from it being *very* opinionated. It
    supports only markdown. The templates are Crinja (a lot like Jinja)
    the config is a single YAML file, and so on.

=It *is* lightweight=
    I intend to keep it below 2000 lines of code. It currently has around 1200.

# Features (So far)

* Pages compiled from markdown (like this one)
* Many other input formats via [pandoc](https://pandoc.org/)
* Blog posts compiled from markdown, with index page (see [/posts](/posts) )
* RSS feed of latest posts (see [/rss.xml](/rss.xml) )
* Taxonomies (like tags, author, etc.) with their own indexes and feeds
* Images are resized and thumbnailed (see [nicolino.png](/nicolino.png) and [nicolino.thumb.png](/nicolino.thumb.png) )
* Jinja-like [templates](/templates.html)
* VenoBox based lightbox for images (click on Nicolino above)
* PicoCSS based theme (needs work, of course)
* `serve` mode, so you can see what the site looks like
* `auto` mode, which rebuilds while you edit and automatically reloads
  the pages in the browser
* [Shortcodes](/shortcodes.html) somewhat compatible with Nikola and Hugo
* Incremental builds, so it only rebuilds what's needed
* Image galleries (see [Fancy Turning](/galleries/fancy-turning) )
* Optional table of contents in posts/pages
* code blocks with syntax highlighting using [HighlightJS](https://highlightjs.org/)

```python
def foo():
    print("bar")
```


# Why the name?

I had written [Nikola](https://getnikola.com) in Python. As a toy I
wrote [Nicoletta](https://github.com/ralsina/nicoletta) which is sort
of the minimal viable static site generator. I ported it to Crystal.

So, I had Nikola, Nicoletta, and I needed a name for the Crystal version.

And you know who was deceptively fast? Nicolino Locche. So, Nicolino it is.

Who? [This guy.](https://en.wikipedia.org/wiki/Nicolino_Locche)

<iframe width="560" height="315" src="https://www.youtube.com/embed/gDQltEznD9Q" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
