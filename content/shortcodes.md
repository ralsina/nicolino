---
Title: Shortcodes
toc: true
---

# What are Shortcodes?

A shortcode is a small template you can embed in your posts to
provide functionality markdown lacks. They are defined using
[Crinja templates](https://straight-shoota.github.io/crinja/)
in the `shortcodes` directory.

## Example

Markdown doesn't have support for the `<figure>` tag,
so you can use the `figure` shortcode to embed a figure:

```markdown
{{< raw >}}
{{% figure
    src="/nicolino.thumb.jpg"
    link="/nicolino.jpg"
    alt="Nicolino"
    caption="The real Nicolino"
%}}
{{< /raw >}}
```

{{% figure
    src="/nicolino.thumb.jpg"
    link="/nicolino.jpg"
    alt="Nicolino"
    caption="The real Nicolino"
%}}

The definition is just a template which can use the arguments
you pass:

```jinja
<figure>
    <a href="{{args.link}}"><img src="{{args.src}}"
        alt="{{args.caption}}"/></a>
<figcaption>{{args.caption}}</figcaption>
</figure>
```

Positional arguments (without names) are passed as `args.0`, `args.1`, etc.

## Paired Shortcodes

Ppaired shortcodes have content between
opening and closing tags. For example, there is `raw` which just
passes whatever is inside as-is:

```markdown
{{< raw >}}
{{< raw >}}
This is called "inner"
{{< /raw >}}
{{< /raw >}}
```

In those shortcodes, you can access that content as `inner`.
The template for `raw` is pretty simple:

```jinja
{{inner}}
```

## Inline Shortcodes

A shortcode can be `inline` so it doesn't require a separate template file. For example:

```markdown
{{< raw >}}
{{< foo.inline "this will be in title case" >}}{{ args.0 | title}}{{< /foo.inline >}}
{{< /raw >}}
{{< foo.inline "this will be in title case" >}}{{ args.0 | title}}{{< /foo.inline >}}
```

Inline shortcodes can be handy for one-off cases when you *need* some templating logic
but it's all self-contained.

## Verbatim and Markdown Shortcodes

Shortcodes can start with `{{%` and end with `%}}` or start with `{{<` and end with `>}}`

The difference is that when the shortcode has "inner" content,
those called with a `%` will be parsed as markdown before being passed
to the template, while those called with a `<` will be passed
to the template as-is (thus: verbatim).

## Nested Shortcodes

Nicolino supports nesting shortcodes as long as the outer shortcode is not verbatim.
For example, you can nest two `tag` shortcodes:

```markdown
{{< raw >}}
{{% tag div class="outer" %}}
{{< tag div class="inner" >}}
This is inside two divs
{{< /tag >}}
{{% /tag %}}
{{< /raw >}}

{{% tag div class="outer" %}}
{{< tag div class="inner" >}}
This is inside two divs
{{< /tag >}}
{{% /tag %}}
```


# Included Shortcodes

## Figure

Support for the `<figure>` tag. Example

```markdown
{{< raw >}}
{{% figure foo
    src="/nicolino.thumb.jpg"
    link="/nicolino.jpg"
    alt="Nicolino"
    caption="The real Nicolino"
%}}
{{< /raw >}}
```

## Raw

Used when you want to show content that looks like shortcodes or to
avoid processing markdown in a piece of text. Example:

```markdown
{{< raw >}}
{{< raw >}}
This is **passed** as-is
{{< /raw >}}
{{< /raw >}}

{{< raw >}}
This is **passed** as-is
{{< /raw >}}

```


## Tag

Used to wrap markdown with any required tag. Example

```markdown
{{< raw >}}
{{% tag div class="pico-background-orange-350" %}}
This has an **orange** background.
{{% /tag %}}
{{< /raw >}}
```

{{% tag div class="pico-background-orange-350" %}}
This has an **orange** background.
{{% /tag %}}
