
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

```django
<figure>
    <a href="{{args.link}}"><img src="{{args.src}}"
        alt="{{args.caption}}"/></a>
<figcaption>{{args.caption}}</figcaption>
</figure>
```

Positional arguments (without names) are passed as `args.0`, `args.1`, etc.

## Paired Shortcodes

Paired shortcodes have content between
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

```django
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


## YouTube

Embed YouTube videos by video ID. Example:

```markdown
{{< raw >}}
{{< youtube id="dQw4w9WgXcQ" >}}
{{< /raw >}}
```

You can also specify custom width and height:

```markdown
{{< raw >}}
{{< youtube id="dQw4w9WgXcQ" width="560" height="315" >}}
{{< /raw >}}
```

{{< youtube id="dQw4w9WgXcQ" >}}


## Gallery

Embed image galleries directly in your content. The gallery loads images from the gallery's `gallery.json` file and displays them in a responsive grid with lightbox functionality. Example:

```markdown
{{< raw >}}
{{< gallery name="fancy-turning" >}}
{{< /raw >}}
```

This renders a grid of thumbnail images. Users can click thumbnails to view full-size images in a lightbox.

{{< gallery name="fancy-turning" >}}


## Shell

Execute shell commands during build and include their output in your pages. This is useful for including dynamic content like git commit hashes, dates, or command outputs.

**Warning**: This shortcode executes arbitrary shell commands. Only use it in trusted content.

### Usage

```
{{< raw >}}
{{% shell command="git log -1 --format=%h" %}}
{{< /raw >}}
```

```
{{% shell command="git log -1 --format=%h" %}}
```

### Arguments

- `command` (required) - The shell command to execute
- `cd` (optional) - Directory to change to before running the command (default: current directory)

### Examples

Show current git commit:

```
{{< raw >}}
Current commit: {{% shell command="git log -1 --format=%h" %}}
{{< /raw >}}
```

```
Current commit: {{% shell command="git log -1 --format=%h" %}}
```

Show current date:

```
{{< raw >}}
Built on {{% shell command="date +%Y-%m-%d" %}}
{{< /raw >}}
```

```
Built on {{% shell command="date +%Y-%m-%d" %}}
```

List files in a directory:

```
{{< raw >}}
{{% shell command="ls -1 content/posts | head -5" %}}
{{< /raw >}}
```

```
{{% shell command="ls -1 content/posts | head -5" %}}
```

Run command in specific directory:

```
{{< raw >}}
{{% shell command="pwd" cd="content" %}}
{{< /raw >}}
```

```
{{% shell command="pwd" cd="content" %}}
```

### Error Handling

If a command fails, an error message will be included in the output:

```html
<span class="shell-error">Command failed: [error details]</span>
```

You can style this with CSS to make errors visible during development.
