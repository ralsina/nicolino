---
title: Hi there, Welcome to Nicolino!
---

{{% figure foo
    src="/nicolino.thumb.jpg"
    link="/nicolino.jpg"
    alt="Nicolino"
    caption="The real Nicolino"
%}}

# So, what is this?
Nicolino is a simple, fast and lightweight static site generator written in [Crystal](https://crystal-lang.org). Yes, yes, I know,
all the static site generators are simple, fast and lightweight.

# Should You use it?

Oh Jesus, probably not? It *is* good enough that *I* am using it
for new sites, but it's probably not good enough for a regular
user.

# Why?

I have written [a large, very flexible, static site generator in Python](https://getnikola.com),
and I wanted to see what would happen if I made very different
decisions when writing the same sort of software.

So, instead of leveraging the huge Python ecosystem of libraries,
I wrote the core of Nicolino from scratch, using only the standard
library and a few choice dependencies.

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
    I intend to keep it below 2000 lines of code. It currently has around 1550.

# Features (So far)

* Pages compiled from markdown (like this one)
* Many other input formats via [pandoc](https://pandoc.org/)
* Blog posts compiled from markdown, with index page (see [/posts](/posts) )
* RSS feed of latest posts (see [/rss.xml](/rss.xml) )
* Taxonomies (like [tags](/tags), author, etc.) with their own indexes and feeds
* Images are resized and thumbnailed (see [nicolino.jpg](/nicolino.jpg) and [nicolino.thumb.jpg](/nicolino.thumb.jpg) )
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

So, I had Nikola, Nicoletta, and I needed a name for the fast, small but
not too small Crystal project I was starting.

And you know who was deceptively fast and not very large?
Nicolino Locche. So, Nicolino it is.

Who? [This guy.](https://en.wikipedia.org/wiki/Nicolino_Locche)

<iframe width="100%" height="315" src="https://www.youtube.com/embed/gDQltEznD9Q" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
