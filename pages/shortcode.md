---
Title: Shortcodes
---

A shortcode is a small template you can embed in your posts to
provide functionality markdown lacks. They are defined in Jinja
templates in the `shortcodes` directory.

For example, Markdown doesn't have support for the `<figure>` tag,
so you can use this shortcode to embed a figure:

```
{{% raw %}}
{{% figure foo src="/nicolino.thumb.jpg" link="/nicolino.jpg" alt="Nicolino" caption="The real Nicolino" %}}
{{% /raw %}}
```

{{% figure foo src="/nicolino.thumb.jpg" link="/nicolino.jpg" alt="Nicolino" caption="The real Nicolino" %}}

The definition is just a template which can use the arguments
you pass:

```jinja
<figure>
    <a href="{{args.link}}"><img src="{{args.src}}"
        alt="{{args.caption}}"/></a>
<figcaption>{{args.caption}}</figcaption>
</figure>
```

Also, you can have "paired" shortcodes, which have content between
opening and closing tags. For example, there is `raw` which just
passes whatever is inside as-is:

```markdown
{{% raw %}}
{{% raw %}}
This is called "inner"
{{% /raw %}}
{{% /raw %}}
```

In those shortcodes, you can access that content as `inner`

Nicolino does *not* support nested shortcodes.

Shortcodes can start with `{{%` and end with `%}}` or start with `{{<` and end with `>}}`

The difference is that when the shortcode has "inner" content, those called with a `%` will be parsed as markdown before being passed to the template, while those called with a `<` will be passed to the template as-is.

Usually this will make no difference at all because the markdown
parser used in Nicolino is different from Hugo's.
