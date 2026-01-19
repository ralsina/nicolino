Nicolino uses the **Discount** markdown processor to convert markdown content to HTML. Discount is a fast, C-based implementation of markdown that supports several useful extensions beyond standard markdown.

If you're coming from other markdown processors (like GitHub Flavored Markdown, CommonMark, or Pandoc), you may notice some differences in syntax and behavior.

## Basic Markdown

### Paragraphs and Text

Paragraphs are separated by blank lines:

```markdown
This is a paragraph.

This is another paragraph.
```

### Emphasis

```markdown
*italic* or _italic_
**bold** or __bold__
***bold italic*** or ___bold italic___
```

### Headings

```markdown
# Heading 1
## Heading 2
### Heading 3
```

### Links

```markdown
[link text](https://example.com)
[link with title](https://example.com "Link title")
```

### Images

```markdown
![alt text](image.jpg)
![alt text](image.jpg "Image title")
```

### Lists

Unordered lists:

```markdown
- Item 1
- Item 2
  - Nested item
- Item 3
```

Ordered lists:

```markdown
1. First item
2. Second item
3. Third item
```

### Code

Inline code: `` `code` ``

Code blocks:

````markdown
```
code block
```
````

### Blockquotes

```markdown
> This is a blockquote.
> It can span multiple lines.
```

### Horizontal Rules

```markdown

------

```

## Discount Extensions

Discount supports several markdown extensions that are not part of the standard markdown specification:

### Definition Lists

Discount supports PHP Markdown Extra-style definition lists:

```markdown
Term 1
:   Definition 1

Term 2
:   Definition 2a
:   Definition 2b
```

Discount also supports its own original syntax with `=` characters:

```markdown
=Term 1=
    Definition 1

=Term 2=
    Definition 2a
    Definition 2b
```

Both formats render the same way:

<dl>
<dt>Term 1</dt>
<dd>Definition 1</dd>
<dt>Term 2</dt>
<dd>Definition 2a</dd>
<dd>Definition 2b</dd>
</dl>

### Fenced Code Blocks

While Discount supports code blocks with indentation, it also supports fenced code blocks (similar to GitHub Flavored Markdown):

````markdown
```python
def hello():
    print("Hello, world!")
```
````

### Tables

Discount supports basic table syntax:

```markdown
| Header 1 | Header 2 | Header 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |
```

### Strikethrough

```markdown
~~strikethrough text~~
```

## More Information

For complete documentation of Discount's features and extensions, visit the [Discount homepage](https://www.pell.portland.or.us/~orc/Code/discount/).
