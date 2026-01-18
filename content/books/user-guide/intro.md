## What is Nicolino?

Nicolino is a Static Site Generator, which means it takes your content,
which is usually [posts](posts.html) and [pages](pages.html) written in
[markdown](https://es.wikipedia.org/wiki/Markdown) and shuffles it
through a render pipeline, which at the end produces a *static* website.

Static in this case means that it doesn't need anything special in the
server where you deploy it. It doesn't "run", it just needs to be uploaded
and it will work fine.

## Why Nicolino?

Honest answer? You are probably going to be fine using many other more
established, more mature SSGs. You can't go wrong using [Hugo](https://hugo.io)
or many others like [Nikola](https://getnikola.com) which I started many
years ago.

On the other hand, Nicolino has an approach you may like, need or enjoy:

=It's batteries included.=
    It has quite a lot of features. You can look at the sidebar and check them out.

    * It will render [books](/books) like gitbook or mdbook (not *quite* as well, but nicely enough )
    * It will do [image galleries](/galleries) (not *quite* like a specialized tool)
    * It will show [code listings](/listings) even if not like github

    See a pattern? It's a swiss army knife. Not great at anything, but what other
    tool lets you do those things (and [more](import.html)) plus a blog plus normal webpages?

=It's pretty fast.=
    Yes, really. 20% faster than Hugo in some benchmarks. Faster or slower than
    other similar software. But pretty fast in general!

    Also, it's built around only doing what needs doing so in normal usage it
    will be even faster. Ideally, when there is nothing to be done, it should be
    instantaneous, and if there is just a few things to do, it should be fast.

=It's reasonable.=
    Whenever possible I am trying to keep it simple. The config file is a simple YAML.
    If you want to create a gallery, create a folder in `content/galleries` if you
    want a new post, throw markdown in `content/posts` and so on. The output should
    be ok.

=It's multilingual.=
    While it still needs work on translations, it TRIES to do the right thing when
    a site is in multiple languages. If there are gaps in a language they are filled
    using another. If a thing is available in more than one language, they are linked
    to each other, and so on.

## So, How do I use it?

Go read the CLI docs for [init,](cli.html#init) [new,](cli.html#new) and [build](cli.html#build) ... that should be enough.

## Who can I complain to?

You can file [issues](https://github.com/ralsina/nicolino/issues) or just contact
me, I am easy to find: Roberto Alsina <roberto.alsina@gmail.com>
