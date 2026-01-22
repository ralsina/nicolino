---
title: Hi there, Welcome to Nicolino!
---
{{% figure foo
    src="/nicolino.thumb.jpg"
    link="/nicolino.jpg"
    alt="Nicolino Locche"
    caption="The real Nicolino"
%}}

# What is Nicolino?
Nicolino is a simple, fast and lightweight static site generator written in [Crystal](https://crystal-lang.org).

# Why is Nicolino?

I have written [a large, very flexible, static site generator in Python](https://getnikola.com),
and while it has done a nice job for **14 years** I wanted to see if I could
do a *better* one by making different decisions based on those 14 years.

So, Nicolino. Here are some reasons why I think it's worth using:

=It *is* fast=
    While benchmarks are not very important
    it *does* run [this benchmark](https://www.zachleat.com/web/build-benchmark/) ... fast.
    How fast? Usually faster than [Hugo](https://gohugo.io).

    Usually it will be even faster because Nicolino has incremental builds as its
    core. Everything is incrementally built. Changing your content will only
    trigger the minimal effort needed to keep your site up to date. Usually under a second.

    This whole site, including image galleries and all that builds from scratch in my machine
    in about .8 seconds ... so, fast.

=It *has* features
    Multilingual feeds and pages and posts, separate feeds and pages for any way you want to
    categorize your content ([tags?](/tags) author? color? whatever.) It supports
    [simple image galleries](/galleries), presents [code](/listings) nicely, it even has 90%
    of an implementation of mdbook in it, so it can do [books](/books). It will automatically
    resize images and present them nicely (see Nicolino above), it supports Hugo-compatible
    [shortcodes](/books/user-guide/shortcodes.html) so you can do fancy things markdown
    frowns upon and much more.

    Yes, you can just put code anywhere:

    ```python
    def foo():
        print("bar")
    ```

    I intend Nicolino to be *enough* for most uses so you don't need to use multiple tools.

=It *is* simple=
    Part of the simplicity comes from it being *very* opinionated.

    * It supports only markdown, HTML and trusts pandoc to *slowly* handle anything else.
    * The templates are Crinja (a lot like Jinja)
    * The config is a single YAML file, and so on.

    If you want something super extensible, look at [Nikola](https://getnikola.com) instead.

    It's one binary. You don't need anything else. Keep in mind that the binary provided in the releases is not ideal. It's meant to work on any Linux x86 system but it also is slower,
    specially when it comes to image processing.


# Why the name?

I had written [Nikola](https://getnikola.com) in Python. As a toy I
wrote [Nicoletta](https://github.com/ralsina/nicoletta) which is sort
of the minimal viable static site generator. I [ported it to Crystal](https://ralsina.me/weblog/posts/learning-crystal-by-implementing-a-static-site-generator.html). So, I had
Nikola, Nicoletta, and I needed a name for the fast, small but not too small
Crystal project I was starting. And you know who was deceptively fast and not very large?
Nicolino Locche. So, Nicolino it is.

Who? [This guy.](https://en.wikipedia.org/wiki/Nicolino_Locche)

<iframe width="100%" height="315" src="https://www.youtube.com/embed/gDQltEznD9Q" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
